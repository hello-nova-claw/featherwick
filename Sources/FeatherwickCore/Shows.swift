import Foundation

// Show judging: the data layer.
//
// Three kinds of class, as at a real poultry show:
//   - breed classes: purebred adults, judged against their breed standard
//   - the pet class: any bird, judged on condition and friendliness
//   - egg classes: a plate of eggs of one colour
//
// Breed standards come from the breed table: a colour is standard for a breed if one of the
// breed's colour varieties produces it. So a new breed or variety gets a standard for free.

/// The colour as a show standard names it: "gold laced", "blue laced", "barred black", "lavender".
/// The one authoritative formatter; the Breed Book and the CLI all defer to it.
public func featherColourName(_ colour: FeatherColour, barred: Bool, laced: Bool) -> String {
    if laced { return colour == .buff ? "gold laced" : "\(colour.rawValue) laced" }
    if barred { return "barred \(colour.rawValue)" }
    return colour.rawValue
}

/// What a bird looks like, in the words a standard uses. Worked out from the phenotype.
public struct Appearance: Hashable, Codable, Sendable {
    public let colour: FeatherColour
    public let barred: Bool
    public let laced: Bool
    public let silkieFeathered: Bool

    public init(_ p: Phenotype) {
        colour = p.colour
        barred = p.isBarred
        laced = p.isLaced
        silkieFeathered = p.isSilkieFeathered
    }

    /// "gold laced", "barred black", "blue".
    public var colourName: String { featherColourName(colour, barred: barred, laced: laced) }
}

public enum ShowClass: Hashable, Codable, Sendable {
    case breed(Breed)
    case pet
    case eggs(EggColour)

    public var name: String {
        switch self {
        case .breed(let b): b.definition.displayName
        case .pet: "Pet chicken"
        case .eggs(let c): "\(c.rawValue.capitalized) eggs"
        }
    }

    /// The kind of class. Prizes, field size and rival strength are set per kind (see `Rules.show*`).
    public var kind: ShowKind {
        switch self {
        case .breed: .breed
        case .pet: .pet
        case .eggs: .eggs
        }
    }
}

/// The three kinds of class. Ranked by difficulty: pet (easy) < eggs < breed (hard).
/// A harder kind has a bigger, stronger field and pays more coins.
public enum ShowKind: String, Hashable, Codable, Sendable, CaseIterable {
    case pet, eggs, breed
}

/// A breed's show standard.
public struct ShowStandard: Sendable {
    public let breed: Breed
    /// The colours a judge accepts for this breed.
    public let colours: [Appearance]

    public init(_ breed: Breed) {
        self.breed = breed
        var seen: [Appearance] = []
        for variety in breed.definition.varieties {
            let look = Appearance(Phenotype(breed.purebred(.hen, variety: variety)))
            if !seen.contains(look) { seen.append(look) }
        }
        colours = seen
    }

    public func accepts(_ look: Appearance) -> Bool { colours.contains(look) }
}

/// What the judge says. The UI turns these into words.
public enum JudgeNote: Hashable, Codable, Sendable {
    // Entry
    case tooYoung
    case notPurebred
    case wrongBreedClass
    case notAStandardColour(String)
    case wrongFeathering
    case notMatched
    case plateNeeds(Int)
    // Breed and colour
    case standardColour(String)
    /// The feathering the standard asks for: silkie (true for a Silkie) or normal.
    case feathering(silkie: Bool)
    /// Show type: body size, shape and carriage (`QuantitativeTrait.showType`).
    case type(Band)
    // Condition
    /// No longer given: every bird moulted in autumn, so it marked nothing that set one bird apart.
    /// Kept so old show results still load.
    case moulting
    case stressed
    case broody
    case hungry
    case inFineCondition
    /// Free-ranged and foraged the night before: shows in slightly better condition.
    case foraged
    /// Inbred: real judges see less vigour in closely bred birds. Only when `Rules.inbreedingMatters` is on.
    case lacksVigour
    case friendliness(Friendliness)
    // Eggs
    case shape(Band)
    case shell(Band)
    case staleEggs(Int)

    public enum Band: String, Hashable, Codable, Sendable, CaseIterable {
        case poor, fair, good, excellent

        init(_ fraction: Double) {
            self = fraction >= 0.75 ? .excellent : fraction >= 0.55 ? .good : fraction >= 0.35 ? .fair : .poor
        }
    }
}

/// A grade card, like the ribbons at a country show. Grades are absolute; placings against other
/// entries come with show days.
public enum Grade: String, Hashable, Codable, Sendable, CaseOrdered {
    case disqualified, fair, good, veryGood, excellent

    init(score: Int) {
        self = score >= 85 ? .excellent : score >= 70 ? .veryGood : score >= 55 ? .good : .fair
    }
}

public struct JudgeCard: Hashable, Codable, Sendable {
    public let showClass: ShowClass
    /// 0...100. Zero when disqualified.
    public let score: Int
    public let grade: Grade
    public let notes: [JudgeNote]
}

/// Points per part of the judging. Each kind of class adds up to 100.
public enum ShowPoints {
    public static let breedType = 50, breedColour = 30, breedCondition = 20
    public static let petCondition = 50, petFriendliness = 50
    public static let eggMatch = 30, eggShape = 30, eggShell = 20, eggFreshness = 20
    public static let eggPlate = 3
}

public enum Judge {
    /// How a bird looks today, 0...1. Care decides condition, not genes.
    public static func condition(of bird: Bird, in s: GameState) -> (value: Double, notes: [JudgeNote]) {
        var value = 1.0
        var notes: [JudgeNote] = []
        if s.day < bird.noLayUntilDay {
            value -= 0.4
            notes.append(.stressed)
        }
        if bird.isBroody(onDay: s.day) {
            value -= 0.3
            notes.append(.broody)
        }
        if !s.fedToday {
            value -= 0.2
            notes.append(.hungry)
        }
        if s.foragedToday {
            value = min(1, value + s.rules.forageConditionBonus)
            notes.append(.foraged)
        }
        if lacksVigour(bird, s.rules), let f = bird.inbreeding {
            value -= min(s.rules.maxInbreedingConditionLoss, f)
            notes.append(.lacksVigour)
        }
        if notes.isEmpty { notes.append(.inFineCondition) }
        return (max(0, value), notes)
    }

    /// Closely bred birds show less vigour. Only when `Rules.inbreedingMatters` is on.
    static func lacksVigour(_ bird: Bird, _ rules: Rules) -> Bool {
        guard rules.inbreedingMatters, let f = bird.inbreeding else { return false }
        return f >= 0.0625
    }

    /// What the keeper can know now about a bird's condition on the next show day, so a broody spell
    /// or a fright is never a surprise at the show. Empty when nothing is in the way.
    /// The same checks as `condition(of:in:)`, looked at on the show day. Hunger shows only on the eve
    /// of the show: the judge sees whether the flock was fed the day before.
    public static func forecast(for bird: Bird, in s: GameState) -> [JudgeNote] {
        let day = s.nextShowDay
        var notes: [JudgeNote] = []
        if day < bird.noLayUntilDay { notes.append(.stressed) }
        if bird.isBroody(onDay: day) { notes.append(.broody) }
        if day == s.day + 1, !s.fedToday { notes.append(.hungry) }
        if lacksVigour(bird, s.rules) { notes.append(.lacksVigour) }
        return notes
    }

    public static func judge(_ bird: Bird, in showClass: ShowClass, state s: GameState) -> JudgeCard {
        switch showClass {
        case .breed(let breed): breedClass(bird, breed, s)
        case .pet: petClass(bird, s)
        case .eggs: disqualified(showClass, .wrongBreedClass)
        }
    }

    static func disqualified(_ showClass: ShowClass, _ notes: JudgeNote...) -> JudgeCard {
        JudgeCard(showClass: showClass, score: 0, grade: .disqualified, notes: notes)
    }

    static func card(_ showClass: ShowClass, _ points: Double, _ notes: [JudgeNote]) -> JudgeCard {
        let score = min(100, max(0, Int(points.rounded())))
        return JudgeCard(showClass: showClass, score: score, grade: Grade(score: score), notes: notes)
    }

    static func breedClass(_ bird: Bird, _ breed: Breed, _ s: GameState) -> JudgeCard {
        let cls = ShowClass.breed(breed)
        guard bird.stage(onDay: s.day, rules: s.rules) == .adult else { return disqualified(cls, .tooYoung) }
        guard bird.isPurebred else { return disqualified(cls, .notPurebred) }
        guard bird.breed == breed else { return disqualified(cls, .wrongBreedClass) }

        let standard = ShowStandard(breed)
        let look = Appearance(bird.phenotype)
        if let expected = standard.colours.first?.silkieFeathered, expected != look.silkieFeathered {
            return disqualified(cls, .wrongFeathering)
        }
        guard standard.accepts(look) else { return disqualified(cls, .notAStandardColour(look.colourName)) }

        let type = QuantitativeTrait.showType.fraction(bird.genome)
        let (condition, conditionNotes) = condition(of: bird, in: s)
        let points =
            type * Double(ShowPoints.breedType) + Double(ShowPoints.breedColour)
            + condition * Double(ShowPoints.breedCondition)
        let notes: [JudgeNote] = [
            .standardColour(look.colourName), .feathering(silkie: look.silkieFeathered), .type(.init(type)),
        ]
        return card(cls, points, notes + conditionNotes)
    }

    /// Any bird, purebred or cross: judged on condition and on how calmly it sits in the judge's hands.
    static func petClass(_ bird: Bird, _ s: GameState) -> JudgeCard {
        guard bird.stage(onDay: s.day, rules: s.rules) != .chick else { return disqualified(.pet, .tooYoung) }
        let (condition, notes) = condition(of: bird, in: s)
        let points =
            condition * Double(ShowPoints.petCondition)
            + bird.friendlinessScore * Double(ShowPoints.petFriendliness)
        return card(.pet, points, [.friendliness(bird.friendliness)] + notes)
    }

    // MARK: - Eggs

    /// A plate of eggs. Real egg classes want a matched plate: same colour, even shape, clean strong shells.
    public static func judgeEggs(_ eggs: [Egg], state s: GameState) -> JudgeCard {
        guard let first = eggs.first else { return disqualified(.eggs(.cream), .plateNeeds(ShowPoints.eggPlate)) }
        let cls = ShowClass.eggs(first.colour)
        guard eggs.count == ShowPoints.eggPlate else { return disqualified(cls, .plateNeeds(ShowPoints.eggPlate)) }
        guard eggs.allSatisfy({ $0.colour == first.colour && $0.speckled == first.speckled }) else {
            return disqualified(cls, .notMatched)
        }
        let n = Double(eggs.count)
        let shapeMax = Double(QuantitativeTrait.eggShape.maxScore)
        // Eggs laid before these traits existed count as average.
        let shape = eggs.map { Double($0.shape ?? Int(shapeMax / 2)) / shapeMax }.reduce(0, +) / n
        let shell = eggs.map { $0.shell ?? 0.75 }.reduce(0, +) / n
        let stale = eggs.count(where: { s.rules.isStale($0, onDay: s.day) })
        let fresh = 1 - Double(stale) / n
        let points =
            Double(ShowPoints.eggMatch) + shape * Double(ShowPoints.eggShape)
            + shell * Double(ShowPoints.eggShell) + fresh * Double(ShowPoints.eggFreshness)
        var notes: [JudgeNote] = [.shape(.init(shape)), .shell(.init(shell))]
        if stale > 0 { notes.append(.staleEggs(stale)) }
        return card(cls, points, notes)
    }

    /// The best plate the player could make from these eggs, for each egg class, best first.
    public static func bestPlates(from eggs: [Egg], state s: GameState) -> [(eggs: [Egg], card: JudgeCard)] {
        // A matched plate is one colour, all speckled or all plain: the same key as the Egg Book.
        let groups = Dictionary(grouping: eggs) { EggBookEntry(colour: $0.colour, speckled: $0.speckled) }
        var plates: [(eggs: [Egg], card: JudgeCard, speckled: Bool)] = []
        for (kind, group) in groups where group.count >= ShowPoints.eggPlate {
            // Best eggs first; the ID breaks ties so the same carton always makes the same plate.
            let best = group.map { (egg: $0, value: eggValue($0, s)) }
                .sorted { (-$0.value, $0.egg.id.uuidString) < (-$1.value, $1.egg.id.uuidString) }
            let plate = best.prefix(ShowPoints.eggPlate).map(\.egg)
            plates.append((plate, judgeEggs(plate, state: s), kind.speckled))
        }
        // Speckled and plain plates of one colour share a class name, so speckle breaks that tie
        // (Dictionary order is not stable between runs).
        func rank(_ p: (eggs: [Egg], card: JudgeCard, speckled: Bool)) -> (Int, String, Int) {
            (-p.card.score, p.card.showClass.name, p.speckled ? 1 : 0)
        }
        return plates.sorted { rank($0) < rank($1) }.map { (eggs: $0.eggs, card: $0.card) }
    }

    static func eggValue(_ egg: Egg, _ s: GameState) -> Double {
        Double(egg.shape ?? QuantitativeTrait.eggShape.maxScore / 2) / Double(QuantitativeTrait.eggShape.maxScore)
            + (egg.shell ?? 0.75) + (s.rules.isStale(egg, onDay: s.day) ? 0 : 1)
    }

    /// Shell quality of an egg laid today, 0...1. Real shells thin with stress and age. (No summer penalty:
    /// a keeper cannot do anything about the season, so it only felt unfair.)
    public static func shellQuality(of hen: Bird, in s: GameState) -> Double {
        var value = 1.0
        if s.day < hen.noLayUntilDay + s.rules.scaredNoLayDays { value -= 0.3 }  // just over a fright
        let years = hen.age(onDay: s.day) / (s.rules.daysPerSeason * Season.allCases.count)
        value -= 0.1 * Double(years)
        return max(0.1, value)
    }
}
