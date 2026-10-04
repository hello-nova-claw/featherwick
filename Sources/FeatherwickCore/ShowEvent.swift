import Foundation

// The county show: a recurring event that turns the judging data layer (Shows.swift) into a game.
//
// A show comes round every `showIntervalDays` (one per season by default). The player enters birds
// and a plate of eggs beforehand; on the show morning each entry is judged by the SAME `Judge` code
// used by `judge <name>`, against a field of AI entries of the same class. Placings and prize coins
// follow, and first-place ribbons stack up in a trophy case.
//
// This is where three of the game's deepest systems finally pay off:
//   - breeding for show type (QuantitativeTrait.showType) wins breed classes
//   - taming (Friendliness) wins the pet class, where crosses compete too
//   - egg quality (shape, shell, freshness) wins egg classes
//
// Cozy rule: entering only ever costs the small fee; a bird can place last but is never harmed.

/// One thing entered in the next show: a bird (by id, judged live on show day) or a plate of eggs.
public struct ShowEntry: Hashable, Codable, Sendable {
    /// The bird entered. Nil for an egg plate.
    public var birdID: UUID?
    /// The plate of eggs entered (copies: they go to the show and are judged there). Empty for a bird.
    public var eggs: [Egg]

    public init(birdID: UUID?, eggs: [Egg]) {
        self.birdID = birdID
        self.eggs = eggs
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
    public let prize: Int
}

extension Engine {
    /// The class a bird competes in: its breed class if it is a purebred adult in a standard colour,
    /// otherwise the pet class (where crosses, growers and off-colour birds are all welcome).
    public static func showClass(for bird: Bird, in s: GameState) -> ShowClass {
        if bird.isPurebred, bird.stage(onDay: s.day, rules: s.rules) == .adult,
            ShowStandard(bird.breed).accepts(Appearance(bird.phenotype))
        {
            return .breed(bird.breed)
        }
        return .pet
    }

    // MARK: - Entering

    static func enterShow(_ id: UUID, _ s: inout GameState) -> [GameEvent] {
        guard let bird = s.bird(id), s.birdsAtHome.contains(where: { $0.id == id }) else {
            return [.rejected(.birdNotHome)]
        }
        guard bird.stage(onDay: s.day, rules: s.rules) != .chick else { return [.rejected(.notShowEligible)] }
        guard !s.showEntries.contains(where: { $0.birdID == id }) else { return [.rejected(.alreadyEntered)] }
        let fee = s.rules.showEntryFee
        guard s.coins >= fee else { return [.rejected(.notEnoughCoins(needed: fee, have: s.coins))] }
        s.coins -= fee
        s.showEntries.append(ShowEntry(birdID: id, eggs: []))
        return [.enteredInShow(id, showClass(for: bird, in: s))]
    }

    static func enterEggs(_ s: inout GameState) -> [GameEvent] {
        guard let best = Judge.bestPlates(from: s.carton, state: s).first else { return [.rejected(.noMatchedPlate)] }
        let fee = s.rules.showEntryFee
        guard s.coins >= fee else { return [.rejected(.notEnoughCoins(needed: fee, have: s.coins))] }
        s.coins -= fee
        let ids = Set(best.eggs.map(\.id))
        s.carton.removeAll { ids.contains($0.id) }  // the plate goes to the show
        s.showEntries.append(ShowEntry(birdID: nil, eggs: best.eggs))
        return [.enteredInShow(nil, best.card.showClass)]
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

        // Group the player's entries by class; absent birds (sold, lost, boarding) are quietly withdrawn.
        var byClass: [ShowClass: [(name: String, card: JudgeCard)]] = [:]
        for entry in s.showEntries {
            if let id = entry.birdID {
                guard let bird = s.bird(id), s.birdsAtHome.contains(where: { $0.id == id }) else { continue }
                let cls = showClass(for: bird, in: s)
                byClass[cls, default: []].append((bird.name, Judge.judge(bird, in: cls, state: s)))
            } else if let first = entry.eggs.first {
                let cls = ShowClass.eggs(first.colour)
                byClass[cls, default: []].append(("your eggs", Judge.judgeEggs(entry.eggs, state: s)))
            }
        }

        // Judge each class against its field. Classes are handled in name order so draws stay deterministic.
        var totalPrize = 0
        for cls in byClass.keys.sorted(by: { $0.name < $1.name }) {
            var field = byClass[cls]!.map { (name: $0.name, card: $0.card, isPlayer: true) }
            for _ in 0..<s.rules.showCompetitors {
                let rival = competitor(for: cls, s, &rng)
                field.append((name: rival.name, card: rival.card, isPlayer: false))
            }
            // Best score first. Ties go to the player (a deterministic home advantage), then by name.
            field.sort {
                if $0.card.score != $1.card.score { return $0.card.score > $1.card.score }
                if $0.isPlayer != $1.isPlayer { return $0.isPlayer }
                return $0.name < $1.name
            }
            for (i, e) in field.enumerated() where e.isPlayer {
                let placing = e.card.grade == .disqualified ? 0 : i + 1
                let prize = prizeFor(placing, s.rules)
                totalPrize += prize
                let result = ShowResult(
                    day: s.day, showClass: cls, entrantName: e.name,
                    placing: placing, fieldSize: field.count, score: e.card.score, prize: prize)
                s.showResults.append(result)
                ev.append(.showPlacing(result))
            }
        }
        if totalPrize > 0 {
            s.coins += totalPrize
            ev.append(.showPrizesWon(coins: totalPrize))
        }
        return ev
    }

    static func prizeFor(_ placing: Int, _ r: Rules) -> Int {
        switch placing {
        case 1: r.showPrizeFirst
        case 2: r.showPrizeSecond
        case 3: r.showPrizeThird
        default: 0
        }
    }

    /// One AI entry for a class, generated from fresh random IDs so its quality varies (like the
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
