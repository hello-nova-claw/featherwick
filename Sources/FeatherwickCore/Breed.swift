import Foundation

/// Colours a starter bird can come in. Each one is a colour variety in the breed table.
public enum StarterColour: String, Hashable, Codable, Sendable, CaseIterable {
    case black, blue, buff, lavender

    public var variety: ColourVariety {
        switch self {
        case .black: .black
        case .blue: .blue
        case .buff: .buff
        case .lavender: .lavender
        }
    }
}

/// Real keepers' names for crossbred chickens.
public enum CrossName: String, Hashable, Codable, Sendable, CaseIterable {
    case oliveEgger = "olive egger"  // blue-egg × brown-egg cross
    case easterEgger = "easter egger"  // other crosses with the blue-egg gene
    case barnyardMix = "barnyard mix"  // any other cross
}

public enum LifeStage: String, Codable, Sendable, CaseOrdered {
    case chick, grower, adult
}

/// A bird. IDs are global and lineage is kept, so birds can be traded later.
public struct Bird: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    /// V1 PLACEHOLDER RULE: a chick takes its mother's breed (like Pokémon).
    /// Open question: how mixed-breed chicks show in the Breed Book.
    public let breed: Breed
    public internal(set) var genome: Genome
    public let hatchDay: Int
    public let motherID: UUID?
    public let fatherID: UUID?
    /// Who bred it: "Neighbour", a shop, or (later) another player's ID.
    public let origin: String

    /// True once the player knows its sex and breed (grown enough, or told by the breeder).
    public var revealed: Bool
    public var timesScared: Int
    public var noLayUntilDay: Int
    /// While set and in the future, the hen is broody: she sits and does not lay.
    public var broodyUntilDay: Int?
    /// The broody hen raising this chick. Not always its mother: a broody hen will sit on any hen's eggs.
    public var raisedBy: UUID?
    /// Nil or true: purebred. False: a cross of two breeds (then `breed` is only the mother's line).
    public var purebredFlag: Bool?
    /// Learned trust in people, 0...1: handling, treats, frights, time lost. Nil = an older bird, average.
    public var tameness: Double?
    /// The last day the player picked this bird up. Handling counts once a day.
    public var lastPettedDay: Int?
    /// The last day the player gave this bird a treat. Treats count once a day.
    public var lastTreatDay: Int?
    /// Wright's inbreeding coefficient, fixed at hatch: 0 = unrelated parents, 0.25 = brother × sister.
    public var inbreeding: Double?
    /// True while the player still has to name this bird (hatched or bought). `name` is a placeholder until then.
    public var needsName: Bool?
    /// The first night this bird was seen still without a name. Set and read by the night's auto-naming.
    public var unnamedSinceDay: Int?
    /// The first night this grown bird had no perch. Cleared when it gets one.
    public var waitingSinceDay: Int?
    /// The look the keeper last saw, frozen when the bird went out of sight: rehomed, boarding with
    /// the neighbour, or lost. Nil while it is home. A bird out of sight keeps growing, but the keeper
    /// does not see it lay, so `Knowledge` reads this look, not today's (see `SeenLook(of:in:)`).
    public var lastSeenLook: SeenLook?

    public var isPurebred: Bool { purebredFlag ?? true }

    /// What keepers call a cross. Nil for purebreds.
    public var crossName: CrossName? {
        guard !isPurebred else { return nil }
        let blue = genome.blueShell.has(.blue)
        let brown = genome.brownShell.has(.brown)
        if blue && brown { return .oliveEgger }
        if blue { return .easterEgger }
        return .barnyardMix
    }

    /// The breed for a purebred, the cross name for a crossbred.
    public var varietyName: String { crossName?.rawValue ?? breed.rawValue }

    public func isBroody(onDay day: Int) -> Bool { (broodyUntilDay ?? Int.min) > day }

    public init(
        id: UUID, name: String, breed: Breed, genome: Genome, hatchDay: Int,
        motherID: UUID? = nil, fatherID: UUID? = nil, origin: String,
        revealed: Bool = false, timesScared: Int = 0, noLayUntilDay: Int = 0
    ) {
        self.id = id
        self.name = name
        self.breed = breed
        self.genome = genome
        self.hatchDay = hatchDay
        self.motherID = motherID
        self.fatherID = fatherID
        self.origin = origin
        self.revealed = revealed
        self.timesScared = timesScared
        self.noLayUntilDay = noLayUntilDay
    }

    public var phenotype: Phenotype { Phenotype(genome) }
    public var sex: Sex { genome.sex }

    public func age(onDay day: Int) -> Int { day - hatchDay }

    public func stage(onDay day: Int, rules: Rules) -> LifeStage {
        let age = age(onDay: day)
        if age >= rules.adultAge { return .adult }
        if age >= rules.growerAge { return .grower }
        return .chick
    }

    /// A hen who has reached retirement age: a beloved non-layer. Cozy rule — she never dies,
    /// she just stops laying and keeps her perch. Roosters never retire (they don't lay).
    public func isRetired(onDay day: Int, rules: Rules) -> Bool {
        sex == .hen && age(onDay: day) >= rules.retirementAgeDays
    }
}
