import Foundation

// The county show: a recurring event that turns the judging data layer (Shows.swift) into a game.
//
// A show comes round every `showIntervalDays` (one per season by default). Each show has a theme
// from its season (`ShowTheme`), and the theme's featured kind of class pays a coin bonus. The player
// enters birds (choosing the class: a purebred standard adult may enter its breed class or the pet
// class) and plates of eggs beforehand. On the show morning each entry is judged by the SAME `Judge`
// code used by `judge <name>`, against a field of AI entries of the same class. Placings and prizes
// follow, and first-place ribbons stack up in a trophy case.
//
// The kinds of class differ in difficulty and reward (see `Rules.show*`):
//   - pet (easy): a small field of ordinary birds; pays a few coins and treats
//   - eggs: a bigger field of better plates; pays more coins
//   - breed (hard): the biggest, strongest field; pays the most coins
//
// This is where three of the game's deepest systems finally pay off:
//   - breeding for show type (QuantitativeTrait.showType) wins breed classes
//   - taming (Friendliness) wins the pet class, where crosses compete too
//   - egg quality (shape, shell, freshness) wins egg classes
//
// Cozy rule: entering only ever costs the small fee; a bird can place last but is never harmed.

/// One show per season. The theme's featured kind of class pays `Rules.showFeaturedBonus` more coins.
/// The words (names) live in FeatherwickText.
public enum ShowTheme: String, Hashable, Codable, Sendable, CaseIterable {
    /// Spring: hens lay well, so the egg classes are featured.
    case springEggFair
    /// Summer: a relaxed village fete. The pet class is featured.
    case summerFete
    /// Autumn: the breed classes are featured, though the moult makes condition harder.
    case harvestShow
    /// Winter: the breed classes are featured, against the hardest field of the year.
    case winterChampionship

    public static func forSeason(_ season: Season) -> ShowTheme {
        switch season {
        case .spring: .springEggFair
        case .summer: .summerFete
        case .autumn: .harvestShow
        case .winter: .winterChampionship
        }
    }

    /// The kind of class that pays a bonus at this show.
    public var featured: ShowKind {
        switch self {
        case .springEggFair: .eggs
        case .summerFete: .pet
        case .harvestShow, .winterChampionship: .breed
        }
    }
}

extension GameState {
    /// The theme of the next (or today's) show: the season of `nextShowDay`.
    public var nextShowTheme: ShowTheme { ShowTheme.forSeason(season(onDay: nextShowDay)) }
}

/// One thing entered in the next show: a bird (by id, judged live on show day) or a plate of eggs.
public struct ShowEntry: Hashable, Codable, Sendable {
    /// The bird entered. Nil for an egg plate.
    public var birdID: UUID?
    /// The plate of eggs entered (copies: they go to the show and are judged there). Empty for a bird.
    public var eggs: [Egg]
    /// The class the player chose for this bird. Nil means the bird's default class
    /// (`Engine.showClass(for:in:)`). Old saves load with nil.
    public var showClass: ShowClass?

    public init(birdID: UUID?, eggs: [Egg], showClass: ShowClass? = nil) {
        self.birdID = birdID
        self.eggs = eggs
        self.showClass = showClass
    }
}

/// How one of the player's entries placed at a show. Kept for the trophy case.
public struct ShowResult: Hashable, Codable, Sendable {
    public let day: Int
    public let showClass: ShowClass
    public let entrantName: String
    /// 1 = first, 2 = second… 0 = entered but outside the ribbons (or disqualified).
    public let placing: Int
    /// How many competed in the class, the player's entry included.
    public let fieldSize: Int
    public let score: Int
    /// Coins won.
    public let prize: Int
    // The fields below are optional so that results in older saves still load.
    /// The bird entered. Nil for an egg plate.
    public let birdID: UUID?
    /// Treats won (the pet class pays treats).
    public let treats: Int?
    /// The judge's notes for this entry.
    public let notes: [JudgeNote]?
    /// The show's theme.
    public let theme: ShowTheme?
}

extension Engine {
    /// The class a bird competes in by default: its breed class if it is a purebred adult in a standard
    /// colour, otherwise the pet class (where crosses, growers and off-colour birds are all welcome).
    public static func showClass(for bird: Bird, in s: GameState) -> ShowClass {
        if bird.isPurebred, bird.stage(onDay: s.day, rules: s.rules) == .adult,
            ShowStandard(bird.breed).accepts(Appearance(bird.phenotype))
        {
            return .breed(bird.breed)
        }
        return .pet
    }

    /// Every class this bird may enter today, breed class first. Empty for chicks.
    /// A purebred adult in a standard colour may enter its breed class or the pet class.
    public static func eligibleClasses(for bird: Bird, in s: GameState) -> [ShowClass] {
        guard bird.stage(onDay: s.day, rules: s.rules) != .chick else { return [] }
        let main = showClass(for: bird, in: s)
        return main == .pet ? [.pet] : [main, .pet]
    }

    /// The class an entered bird competes in: the chosen class while the bird may still enter it,
    /// otherwise its default class.
    public static func entryClass(_ entry: ShowEntry, of bird: Bird, in s: GameState) -> ShowClass {
        if let chosen = entry.showClass, eligibleClasses(for: bird, in: s).contains(chosen) { return chosen }
        return showClass(for: bird, in: s)
    }

    /// The prize for a placing in a class at a show with this theme (coins, treats).
    /// Placings 1–3 pay. The theme's featured kind pays `showFeaturedBonus` times the coins.
    public static func prize(
        for placing: Int, in cls: ShowClass, theme: ShowTheme, rules: Rules
    ) -> (coins: Int, treats: Int) {
        let kind = cls.kind
        let i = placing - 1
        let coinTable = rules.showPrizeCoins[kind] ?? []
        let treatTable = rules.showPrizeTreats[kind] ?? []
        var coins = placing >= 1 && coinTable.indices.contains(i) ? coinTable[i] : 0
        let treats = placing >= 1 && treatTable.indices.contains(i) ? treatTable[i] : 0
        if kind == theme.featured { coins = Int((Double(coins) * rules.showFeaturedBonus).rounded()) }
        return (coins, treats)
    }

    /// How many random candidates each AI entry is the best of. Winter draws the strongest field.
    static func rivalPicks(for kind: ShowKind, theme: ShowTheme, _ r: Rules) -> Int {
        let extra = theme == .winterChampionship ? r.winterChampionshipExtraPicks : 0
        return max(1, (r.showRivalPicks[kind] ?? 1) + extra)
    }

    // MARK: - Entering

    /// Enters a bird in a class: the chosen one, or its default class when `chosen` is nil.
    static func enterShow(_ id: UUID, in chosen: ShowClass?, _ s: inout GameState) -> [GameEvent] {
        guard let bird = s.bird(id), s.birdsAtHome.contains(where: { $0.id == id }) else {
            return [.rejected(.birdNotHome)]
        }
        let eligible = eligibleClasses(for: bird, in: s)
        guard let cls = chosen ?? eligible.first, eligible.contains(cls) else {
            return [.rejected(.notShowEligible)]
        }
        guard !s.showEntries.contains(where: { $0.birdID == id }) else { return [.rejected(.alreadyEntered)] }
        let fee = s.rules.showEntryFee
        guard s.coins >= fee else { return [.rejected(.notEnoughCoins(needed: fee, have: s.coins))] }
        s.coins -= fee
        s.showEntries.append(ShowEntry(birdID: id, eggs: [], showClass: chosen))
        return [.enteredInShow(id, cls)]
    }

    /// Enters the best matched plate in the carton.
    static func enterEggs(_ s: inout GameState) -> [GameEvent] {
        guard let best = Judge.bestPlates(from: s.carton, state: s).first else { return [.rejected(.noMatchedPlate)] }
        return enterPlate(best.eggs, &s)
    }

    /// Enters exactly these carton eggs as a plate: `ShowPoints.eggPlate` eggs of one colour,
    /// all speckled or all plain.
    static func enterEggPlate(_ ids: [UUID], _ s: inout GameState) -> [GameEvent] {
        let wanted = Set(ids)
        let plate = s.carton.filter { wanted.contains($0.id) }
        let matched = plate.allSatisfy { $0.colour == plate.first?.colour && $0.speckled == plate.first?.speckled }
        guard ids.count == ShowPoints.eggPlate, wanted.count == ids.count, plate.count == ids.count, matched else {
            return [.rejected(.noMatchedPlate)]
        }
        return enterPlate(plate, &s)
    }

    /// Pays the fee and sends the plate to the show.
    static func enterPlate(_ plate: [Egg], _ s: inout GameState) -> [GameEvent] {
        guard let first = plate.first else { return [.rejected(.noMatchedPlate)] }
        let fee = s.rules.showEntryFee
        guard s.coins >= fee else { return [.rejected(.notEnoughCoins(needed: fee, have: s.coins))] }
        s.coins -= fee
        let ids = Set(plate.map(\.id))
        s.carton.removeAll { ids.contains($0.id) }  // the plate goes to the show
        s.showEntries.append(ShowEntry(birdID: nil, eggs: plate))
        return [.enteredInShow(nil, .eggs(first.colour))]
    }

    // MARK: - Show day (called from passNight)

    /// If today is a show day, judge every entry against a field of AI entries, place them, pay prizes.
    static func runShowIfToday<R: RandomNumberGenerator>(_ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        guard s.isShowDay else { return [] }
        var ev: [GameEvent] = [.showDay(day: s.day)]
        defer { s.showEntries = [] }  // the show is over, whatever happened
        guard !s.showEntries.isEmpty else {
            ev.append(.showNoEntries)
            return ev
        }
        let theme = ShowTheme.forSeason(s.season)

        // Group the player's entries by class; absent birds (sold, lost, boarding) are quietly withdrawn.
        var byClass: [ShowClass: [(name: String, birdID: UUID?, card: JudgeCard)]] = [:]
        for entry in s.showEntries {
            if let id = entry.birdID {
                guard let bird = s.bird(id), s.birdsAtHome.contains(where: { $0.id == id }) else { continue }
                let cls = entryClass(entry, of: bird, in: s)
                let card = Judge.judge(bird, in: cls, state: s)
                byClass[cls, default: []].append((name: bird.name, birdID: id, card: card))
            } else if let first = entry.eggs.first {
                let cls = ShowClass.eggs(first.colour)
                let card = Judge.judgeEggs(entry.eggs, state: s)
                byClass[cls, default: []].append((name: "your eggs", birdID: nil, card: card))
            }
        }

        // Judge each class against its field. Classes are handled in name order so draws stay deterministic.
        // A harder kind of class has more rivals, and each rival is the best of more candidates.
        var totalCoins = 0
        var totalTreats = 0
        for cls in byClass.keys.sorted(by: { $0.name < $1.name }) {
            var field = byClass[cls]!.map { (name: $0.name, birdID: $0.birdID, card: $0.card, isPlayer: true) }
            let rivals = max(0, s.rules.showCompetitorsByKind[cls.kind] ?? 0)
            let picks = rivalPicks(for: cls.kind, theme: theme, s.rules)
            for _ in 0..<rivals {
                let entry = rival(for: cls, picks: picks, s, &rng)
                field.append((name: entry.name, birdID: nil, card: entry.card, isPlayer: false))
            }
            // Best score first. Ties go to the player (a deterministic home advantage), then by name.
            field.sort {
                if $0.card.score != $1.card.score { return $0.card.score > $1.card.score }
                if $0.isPlayer != $1.isPlayer { return $0.isPlayer }
                return $0.name < $1.name
            }
            for (i, e) in field.enumerated() where e.isPlayer {
                let placing = e.card.grade == .disqualified ? 0 : i + 1
                let won = prize(for: placing, in: cls, theme: theme, rules: s.rules)
                totalCoins += won.coins
                totalTreats += won.treats
                let result = ShowResult(
                    day: s.day, showClass: cls, entrantName: e.name,
                    placing: placing, fieldSize: field.count, score: e.card.score, prize: won.coins,
                    birdID: e.birdID, treats: won.treats, notes: e.card.notes, theme: theme)
                s.showResults.append(result)
                ev.append(.showPlacing(result))
            }
        }
        if totalCoins > 0 {
            s.coins += totalCoins
            ev.append(.showPrizesWon(coins: totalCoins))
        }
        if totalTreats > 0 {
            s.treats += totalTreats
            ev.append(.showTreatsWon(treats: totalTreats))
        }
        return ev
    }

    /// One AI entry: the best of `picks` random candidates. More picks make a stronger field.
    static func rival<R: RandomNumberGenerator>(
        for cls: ShowClass, picks: Int, _ s: GameState, _ rng: inout R
    ) -> (name: String, card: JudgeCard) {
        var best = competitor(for: cls, s, &rng)
        for _ in 1..<max(1, picks) {
            let next = competitor(for: cls, s, &rng)
            if next.card.score > best.card.score { best = next }
        }
        return best
    }

    /// One AI candidate for a class, generated from fresh random IDs so its quality varies (like the
    /// player's own founder birds). Judged by the same `Judge` code, so the field is a fair contest.
    static func competitor<R: RandomNumberGenerator>(
        for cls: ShowClass, _ s: GameState, _ rng: inout R
    ) -> (name: String, card: JudgeCard) {
        switch cls {
        case .breed(let breed):
            let colour = breed.definition.varieties.randomElement(using: &rng)!
            let bird = Bird(
                id: makeID(using: &rng), name: "a \(breed.definition.displayName)", breed: breed,
                genome: breed.purebred(.hen, variety: colour), hatchDay: s.day - s.rules.adultAge,
                origin: "County show", revealed: true
            ).withFounderQuality()
            return (bird.name, Judge.judge(bird, in: cls, state: s))
        case .pet:
            let breed = Breed.starters.randomElement(using: &rng)!
            let colour = breed.definition.varieties.randomElement(using: &rng)!
            let bird = Bird(
                id: makeID(using: &rng), name: "a visitor's \(breed.definition.displayName)", breed: breed,
                genome: breed.purebred(.hen, variety: colour), hatchDay: s.day - s.rules.adultAge,
                origin: "County show", revealed: true
            )
            .withFounderQuality().withTameness(Double.random(in: 0.2...0.95, using: &rng))
            return (bird.name, Judge.judge(bird, in: .pet, state: s))
        case .eggs(let colour):
            // A matched plate from one unseen hen: a single shape and shell across the plate.
            let shape = Int.random(in: 0...QuantitativeTrait.eggShape.maxScore, using: &rng)
            let shell = Double.random(in: 0.3...1.0, using: &rng)
            let eggs = (0..<ShowPoints.eggPlate).map { _ -> Egg in
                var egg = Egg(
                    id: makeID(using: &rng), layDay: s.day, motherID: makeID(using: &rng),
                    colour: colour, speckled: false)
                egg.collectedDay = s.day
                egg.shape = shape
                egg.shell = shell
                return egg
            }
            return ("a plate of \(colour.rawValue) eggs", Judge.judgeEggs(eggs, state: s))
        }
    }
}
