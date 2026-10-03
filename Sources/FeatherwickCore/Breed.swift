import Foundation

public enum Breed: String, Hashable, Codable, Sendable, CaseIterable {
    case silkie, orpington, wyandotte, araucana

    /// The neighbour's breeds. Silkie chicks are too easy to spot, so Silkies come later.
    public static let starters: [Breed] = [.orpington, .wyandotte, .araucana]
}

/// Colours a starter bird can come in.
public enum StarterColour: String, Hashable, Codable, Sendable, CaseIterable {
    case black, blue, buff, lavender
}

extension Breed {
    /// A true-breeding starter bird of this breed.
    ///
    /// Breed signatures: Silkie = silkie feathering, Wyandotte = lacing,
    /// Araucana = blue shell, Orpington and Wyandotte = brown coating.
    /// Starter blue birds are Bl/bl+, so two blues can hatch black, blue and splash.
    public func purebred(_ sex: Sex, colour: StarterColour = .black, barred: Bool = false) -> Genome {
        let feathering: AllelePair<Feathering> =
            self == .silkie ? .homozygous(.silkie) : .homozygous(.normal)
        let lacing: AllelePair<Lacing> =
            self == .wyandotte ? .homozygous(.laced) : .homozygous(.solid)
        let blueShell: AllelePair<BlueShell> =
            self == .araucana ? .homozygous(.blue) : .homozygous(.white)
        let brownShell: AllelePair<BrownShell> =
            (self == .orpington || self == .wyandotte) ? .homozygous(.brown) : .homozygous(.noCoating)

        let baseColour: AllelePair<BaseColour> =
            colour == .buff ? .homozygous(.buff) : .homozygous(.black)
        let blue: AllelePair<BlueDilution> =
            colour == .blue ? AllelePair(.blue, .notBlue) : .homozygous(.notBlue)
        let lavender: AllelePair<Lavender> =
            colour == .lavender ? .homozygous(.lavender) : .homozygous(.normal)

        let barring: Barring = barred ? .barred : .plain
        let sexChromosomes: SexChromosomes =
            sex == .hen ? .hen(z: barring) : .rooster(z: .homozygous(barring))

        return Genome(
            sexChromosomes: sexChromosomes,
            feathering: feathering,
            baseColour: baseColour,
            blue: blue,
            lavender: lavender,
            lacing: lacing,
            blueShell: blueShell,
            brownShell: brownShell,
            speckle: .homozygous(.plain)
        )
    }
}

public enum LifeStage: String, Codable, Sendable, Comparable {
    case chick, grower, adult

    public static func < (a: LifeStage, b: LifeStage) -> Bool {
        let order: [LifeStage] = [.chick, .grower, .adult]
        return order.firstIndex(of: a)! < order.firstIndex(of: b)!
    }
}

/// A bird. IDs are global and lineage is kept, so birds can be traded later.
public struct Bird: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    /// V1 PLACEHOLDER RULE: a chick takes its mother's breed (like Pokémon).
    /// Open question: how mixed-breed chicks show in the Breed Book.
    public let breed: Breed
    public let genome: Genome
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
}
