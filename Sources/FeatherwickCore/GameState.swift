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
    public var feedStock: Int
    public var fedToday = false
    public var coopDoorOpen = true

    public var perches: Int
    public var nestBoxes: Int
    public var brooderSize: Int
    public var cartons: Int

    public var brooder: [Bird] = []
    public var coop: [Bird] = []
    public var lost: [LostBird] = []
    public var nest: [Egg] = []
    public var carton: [Egg] = []

    public var breedBook: Set<BreedBookEntry> = []
    public var eggBook: Set<EggBookEntry> = []

    init(rules: Rules, phase: Phase) {
        self.rules = rules
        self.phase = phase
        coins = rules.startCoins
        feedStock = rules.startFeed
        perches = rules.startPerches
        nestBoxes = rules.startNestBoxes
        brooderSize = rules.startBrooderSize
        cartons = rules.startCartons
    }

    public var season: Season {
        Season.allCases[(day / rules.daysPerSeason) % Season.allCases.count]
    }

    public var cartonCapacity: Int { cartons * rules.cartonSize }

    /// Birds at home (brooder and coop). Lost birds are not fed.
    public var birdsAtHome: [Bird] { brooder + coop }

    public func bird(_ id: UUID) -> Bird? {
        birdsAtHome.first { $0.id == id } ?? lost.first { $0.bird.id == id }?.bird
    }
}
