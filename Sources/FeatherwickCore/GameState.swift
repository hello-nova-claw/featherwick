import Foundation

public enum Season: String, Codable, Sendable, CaseIterable {
    case spring, summer, autumn, winter
}

public struct Egg: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let layDay: Int
    public let motherID: UUID
    public let colour: EggColour
    public let speckled: Bool
    /// Set when the egg moves from the nest to the carton. Freshness counts nest days only.
    public var collectedDay: Int?
    /// Fertile eggs carry the chick's genome from the moment they are laid.
    /// Nil = not fertile. Hidden from the player until the egg is candled.
    public var fatherID: UUID?
    public var embryo: Genome?
    public var motherBreed: Breed?

    /// True once the player has held it up to a light. Only then does the player know if it is fertile.
    public var candled: Bool?

    public var isFertile: Bool { embryo != nil }
    public var isCandled: Bool { candled == true }
}

/// Eggs being hatched: under a broody hen (henID set) or in the incubator (henID nil).
public struct Clutch: Hashable, Codable, Sendable {
    public var henID: UUID?
    public var eggs: [Egg]
    public var hatchDay: Int
}

/// A bird the fox scared away. It always comes home, once the day has come and a perch is free.
public struct LostBird: Hashable, Codable, Sendable {
    public var bird: Bird
    public var returnsOnDay: Int
}

public struct BreedBookEntry: Hashable, Codable, Sendable {
    public let breed: Breed
    public let colour: FeatherColour
    public let barred: Bool
    public let laced: Bool
    public let silkieFeathered: Bool

    init(_ bird: Bird) {
        let p = bird.phenotype
        breed = bird.breed
        colour = p.colour
        barred = p.isBarred
        laced = p.isLaced
        silkieFeathered = p.isSilkieFeathered
    }
}

public struct EggBookEntry: Hashable, Codable, Sendable {
    public let colour: EggColour
    public let speckled: Bool
}

public enum Phase: Hashable, Codable, Sendable {
    /// The neighbour offers 3 chicks, one of each starter breed.
    case choosingStarter([Bird])
    case playing
}

/// The whole save game. Codable: a save is one JSON file.
public struct GameState: Hashable, Codable, Sendable {
    public var rules: Rules
    public var day = 0
    public var phase: Phase
    public var starterID: UUID?
    public var giftHenGiven = false

    public var coins: Int
    public var fedToday = false
    public var coopDoorOpen = true

    public var perches: Int
    public var nestBoxes: Int
    public var brooderSize: Int
    public var cartons: Int

    /// Eggs the incubator holds. 0 = no incubator yet.
    public var incubatorSize = 0
    public var incubatorGiftGiven = false
    public var hasIncubator: Bool { incubatorSize > 0 }
    public var clutches: [Clutch] = []
    public var chicksHatched = 0

    public var brooder: [Bird] = []
    /// Chicks raised by a broody hen. They stay with her (no brooder, no perch) until big enough.
    public var henChicks: [Bird] = []
    public var coop: [Bird] = []
    public var lost: [LostBird] = []
    /// Grown birds with no perch and no brooder room. The neighbour keeps them safe,
    /// but no eggs can be set until they have a home.
    public var boarding: [Bird] = []
    /// Birds adopted by people in Featherwick. Kept so they can appear in town later.
    public var rehomed: [Bird] = []
    public var nest: [Egg] = []
    public var carton: [Egg] = []

    public var breedBook: Set<BreedBookEntry> = []
    public var eggBook: Set<EggBookEntry> = []

    init(rules: Rules, phase: Phase) {
        self.rules = rules
        self.phase = phase
        coins = rules.startCoins
        perches = rules.startPerches
        nestBoxes = rules.startNestBoxes
        brooderSize = rules.startBrooderSize
        cartons = rules.startCartons
    }

    public var season: Season {
        Season.allCases[(day / rules.daysPerSeason) % Season.allCases.count]
    }

    public var cartonCapacity: Int { cartons * rules.cartonSize }
    public var nestCapacity: Int { nestBoxes * rules.eggsPerNestBox }

    /// Birds at home (brooder and coop). Lost birds are not fed.
    public var birdsAtHome: [Bird] { brooder + henChicks + coop }

    public var incubatorClutch: Clutch? { clutches.first { $0.henID == nil } }
    public func clutch(under henID: UUID) -> Clutch? { clutches.first { $0.henID == henID } }

    public func bird(_ id: UUID) -> Bird? {
        birdsAtHome.first { $0.id == id }
            ?? lost.first { $0.bird.id == id }?.bird
            ?? boarding.first { $0.id == id }
            ?? rehomed.first { $0.id == id }
    }
}
