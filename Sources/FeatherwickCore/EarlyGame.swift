import Foundation

// The early game: a tutorial told as a fixed timeline, so a new keeper learns one thing at a time.
//
// A new game starts with one chick and almost nothing else. Each morning on the timeline the
// neighbour introduces one more thing: a lesson (handling, the coop door) or a part of the game
// that opens (treats, the bird pens at Speckle & Down, more perches, the county show, the big
// incubator). Until then, the commands for it are refused with `.notYet(feature)`.
//
// The days are in `Rules.featureDays`. The county show opens `Rules.showNoticeDays` before the
// first show, and the neighbour then suggests one bird and one class for it (`ShowTip`).
//
// Saves from before the early game have every feature open (see `GameState.introduced`).

/// One step of the early game. Each is introduced once, on its day, with the neighbour's words.
/// Steps that are only lessons (`handling`, `coopDoor`, `breedBook`, `laying`) lock nothing.
/// `daylight` locks only `rest`; once it is introduced, errands take daylight (see Daylight.swift).
/// Cases are in timeline order. Saves keep the raw values only, never the order, so a reorder is safe.
public enum Feature: String, Hashable, Codable, Sendable, CaseOrdered {
    /// Lesson: pick the chick up every day. Chicks learn trust fastest.
    case handling
    /// The neighbour gives a few mealworms, and Speckle & Down sells treats.
    case treats
    /// Lesson: shut the coop door at night, or let the flock forage. Comes with Marigold, the first coop hen.
    case coopDoor
    /// Lesson: hens lay when they were fed the day before. Collect the eggs, sell them.
    case laying
    /// Speckle & Down sells premium feed.
    case premiumFeed
    /// Lesson: the sex shows, and the bird goes in the Breed Book. Every breed and colour you keep does.
    case breedBook
    /// Lesson: there is only so much daylight. Errands take a slot of the day; care is always free.
    case daylight
    /// Speckle & Down sells birds and fertile eggs: pullets, cockerels, the daily special, story breeds.
    case birdShop
    /// More perches for the coop.
    case coopUpgrade
    /// The county show: entering, and the show screens. Opens a week before the first show.
    case shows
    /// The big incubator at Speckle & Down. (The neighbour's small one comes with the first fertile egg,
    /// laid or bought.)
    case incubatorShop
    /// The breeding pen: the keeper chooses which rooster fathers which hens' eggs.
    case breedingPen
}

/// The neighbour's advice for the next show: one of the keeper's birds, and the class it is most
/// likely to do well in today.
public struct ShowTip: Hashable, Codable, Sendable {
    public var birdID: UUID
    public var showClass: ShowClass
    /// The day of the show this tip is for.
    public var showDay: Int

    public init(birdID: UUID, showClass: ShowClass, showDay: Int) {
        self.birdID = birdID
        self.showClass = showClass
        self.showDay = showDay
    }
}

extension Rules {
    /// The morning a feature is introduced. The county show opens `showNoticeDays` before the first show.
    public func introductionDay(of feature: Feature) -> Int {
        if feature == .shows { return max(1, showIntervalDays - showNoticeDays) }
        // A save from before a feature existed has no day for it in its own rules: use the standard day.
        return featureDays[feature] ?? Rules.standard.featureDays[feature] ?? 0
    }
}

extension GameState {
    /// True when the keeper has been introduced to this part of the game.
    public func isOpen(_ feature: Feature) -> Bool { introduced.contains(feature) }

    /// The morning a feature is introduced in this game. As in the rules, except that the big incubator
    /// comes to the shop at least `incubatorShopAfterGiftDays` after the neighbour gives her old one,
    /// so the gift has time to feel like a gift.
    public func introductionDay(of feature: Feature) -> Int {
        let day = rules.introductionDay(of: feature)
        guard feature == .incubatorShop, let gift = incubatorGiftDay else { return day }
        return max(day, gift + rules.incubatorShopAfterGiftDays)
    }

    /// The next feature still to come, and its day. Nil once the early game is over.
    public var nextFeature: (feature: Feature, day: Int)? {
        Feature.allCases.filter { !isOpen($0) }
            .map { (feature: $0, day: introductionDay(of: $0)) }
            .min { ($0.day, $0.feature) < ($1.day, $1.feature) }
    }
}

extension Engine {
    /// The feature a command needs, if any. Feeding, handling, eggs and the coop door are always open.
    static func feature(for command: Command) -> Feature? {
        switch command {
        case .buy(.treats): .treats
        case .buy(.premiumFeed): .premiumFeed
        case .buy(.pullet), .buy(.cockerel), .buy(.fertileEgg), .buySpecial: .birdShop
        case .upgradeCoop: .coopUpgrade
        case .buyIncubator: .incubatorShop
        case .enterShow, .enterShowIn, .enterEggs, .enterEggPlate: .shows
        case .penBird, .unpenBird: .breedingPen
        case .rest: .daylight
        default: nil
        }
    }

    /// Each morning: introduce every feature whose day has come, in timeline order.
    /// A gift that comes with a feature is given here. Deterministic: no randomness.
    static func introduceFeatures(_ s: inout GameState) -> [GameEvent] {
        var ev: [GameEvent] = []
        let due = Feature.allCases.filter { !s.isOpen($0) && s.introductionDay(of: $0) <= s.day }
        for feature in due {
            s.introduced.insert(feature)
            if feature == .treats { s.treats += s.rules.welcomeTreats }
            ev.append(.introduced(feature))
            if feature == .shows {
                let tip = showTip(in: s)
                s.showTip = tip
                ev.append(.showAnnounced(tip))
            }
        }
        // "What might hatch" lives in the breeding pen, so it opens with the pen at the latest. A keeper
        // who saw a surprise chick first already knows it. A save already past the pen's day gets it tonight.
        if s.isOpen(.breedingPen), !s.plannerKnown {
            s.plannerKnown = true
            ev.append(.plannerShownAtPen)
        }
        return ev
    }

    // MARK: - The neighbour's show tip

    /// The bird and class the neighbour suggests for the next show, judged on the bird as it is today.
    ///
    /// A bird with a good chance of a ribbon in its breed class (`showTipBreedClassOdds`) is the
    /// first choice: the bird with the best odds there. Otherwise the neighbour suggests the pet
    /// class, for the bird with the best odds in it. Ties go to the starter, then to flock order.
    /// Nil when no bird at home can be shown (all chicks).
    ///
    /// The odds come from practice fields drawn from the bird's own ID, not the game RNG, so asking
    /// changes nothing. Only what the keeper can see is judged, so the tip leaks no hidden gene.
    public static func showTip(in s: GameState) -> ShowTip? {
        let showDay = s.nextShowDay
        let theme = ShowTheme.forSeason(s.season(onDay: showDay))
        let showable = s.birdsAtHome.filter { $0.revealed && !eligibleClasses(for: $0, in: s).isEmpty }
        let birds = showable.filter { $0.id == s.starterID } + showable.filter { $0.id != s.starterID }
        var bestBreed: (bird: Bird, cls: ShowClass, odds: Double)?
        var bestPet: (bird: Bird, odds: Double)?
        for bird in birds {
            for cls in eligibleClasses(for: bird, in: s) {
                let odds = ribbonOdds(bird, in: cls, theme: theme, s)
                if cls == .pet {
                    if odds > bestPet?.odds ?? -1 { bestPet = (bird, odds) }
                } else if odds >= s.rules.showTipBreedClassOdds, odds > bestBreed?.odds ?? -1 {
                    bestBreed = (bird, cls, odds)
                }
            }
        }
        if let b = bestBreed { return ShowTip(birdID: b.bird.id, showClass: b.cls, showDay: showDay) }
        if let p = bestPet { return ShowTip(birdID: p.bird.id, showClass: .pet, showDay: showDay) }
        return nil
    }

    /// The share of practice fields in which this bird places 1st to 3rd in this class today.
    /// Uses the same judge and rivals as show day.
    static func ribbonOdds(_ bird: Bird, in cls: ShowClass, theme: ShowTheme, _ s: GameState) -> Double {
        let card = Judge.judge(bird, in: cls, state: s)
        guard card.grade != .disqualified else { return 0 }
        let trials = max(1, s.rules.showTipTrials)
        let rivals = max(0, s.rules.showCompetitorsByKind[cls.kind] ?? 0)
        let picks = rivalPicks(for: cls.kind, theme: theme, s.rules)
        var rng = SeededRNG(seed: ShopSpecial.seed(from: bird.id) ^ 0x5449_50)  // "TIP"
        var ribbons = 0
        for _ in 0..<trials {
            // Ties go to the player, as on show day.
            var ahead = 0
            for _ in 0..<rivals {
                if rival(for: cls, picks: picks, s, &rng).card.score > card.score { ahead += 1 }
            }
            if ahead < 3 { ribbons += 1 }
        }
        return Double(ribbons) / Double(trials)
    }
}
