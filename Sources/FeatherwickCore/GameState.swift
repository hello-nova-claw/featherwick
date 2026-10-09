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
    public var fatherBreed: Breed?
    public var motherPurebred: Bool?
    public var fatherPurebred: Bool?

    /// True once the player has held it up to a light. Only then does the player know if it is fertile.
    public var candled: Bool?

    /// Egg shape score for egg shows, from the hen's egg-shape genes (0...max). Nil for old eggs.
    public var shape: Int?
    /// Shell quality for egg shows, 0...1, from the hen's age and care when she laid it. Nil for old eggs.
    public var shell: Double?

    public var isFertile: Bool { embryo != nil }
    public var isCandled: Bool { candled == true }
}

public enum ShopItem: String, Hashable, Codable, Sendable, CaseIterable {
    case pullet, cockerel, fertileEgg, treats, premiumFeed
}

/// The safety net. A flock of only roosters, with too few coins for a pullet, can never lay or hatch.
/// Someone in Featherwick then offers a young hen in trade for one rooster. The offer stays until
/// it is taken or no longer needed.
public struct TradeOffer: Hashable, Codable, Sendable {
    public var roosterID: UUID
    public var hen: Bird
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
    /// The breed (purebred) or cross name (crossbred).
    public let variety: String
    public let isCross: Bool
    public let colour: FeatherColour
    public let barred: Bool
    public let laced: Bool
    public let silkieFeathered: Bool

    init(_ bird: Bird) {
        let p = bird.phenotype
        variety = bird.varietyName
        isCross = !bird.isPurebred
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
    /// Treats in the bag (mealworms). Bought at Speckle & Down.
    public var treats = 0
    public var fedToday = false
    public var coopDoorOpen = true

    public var perches: Int
    public var nestBoxes: Int
    public var brooderSize: Int
    public var cartons: Int

    /// Eggs the incubator holds. 0 = no incubator yet.
    public var incubatorSize = 0
    public var incubatorGiftGiven = false
    /// The day the neighbour gave her old incubator. Nil if she has not (or for a save from before this).
    public var incubatorGiftDay: Int?
    /// The keeper's own name, once given. Nil in a save from before the keeper had one.
    public var keeperName: String?
    /// Whether the one-off "too many roosters — rehome one" tip has been shown. New-player nudge, once.
    public var roosterAdviceGiven = false
    public var hasIncubator: Bool { incubatorSize > 0 }
    /// A new keeper can't candle yet: set eggs are a guess, and clear ones come back unhatched.
    /// True by default so saves from before this rule keep the skill; `Engine.newGame` sets it false.
    public var canCandle = true
    public var clutches: [Clutch] = []
    public var chicksHatched = 0

    public var brooder: [Bird] = []
    /// Chicks raised by a broody hen. They stay with her (no brooder, no perch) until big enough.
    public var henChicks: [Bird] = []
    public var coop: [Bird] = []
    /// Ids of coop birds in the breeding pen (see BreedingPen.swift). The birds stay in `coop`:
    /// the pen is a corner of the coop, not extra room. Empty in saves from before the pen.
    public var pen: [UUID] = []
    public var lost: [LostBird] = []
    /// Grown birds with no perch and no brooder room. The neighbour keeps them safe,
    /// but no eggs can be set until they have a home.
    public var boarding: [Bird] = []
    /// Birds adopted by people in Featherwick. Kept so they can appear in town later.
    public var rehomed: [Bird] = []
    /// Family-tree records for birds the player never owned, such as the parents of a bought egg.
    public var pedigree: [UUID: PedigreeRecord] = [:]
    /// Storylines started in this game (see Story.swift).
    public var stories: [String: StoryProgress] = [:]
    /// One-off story notices already shown, so they are not repeated every night.
    public var storyNotices: Set<String> = []
    /// Breeds a storyline added to Speckle & Down's surprise stock (see `surpriseBreeds`).
    public var shopBreeds: Set<Breed> = []
    /// Goal-ladder milestones already reached (see Milestone.swift). Ids only; the words live in the UI.
    public var milestonesReached: Set<String> = []
    public var nest: [Egg] = []
    public var carton: [Egg] = []

    public var tradeOffer: TradeOffer?

    public var breedBook: Set<BreedBookEntry> = []
    /// The day each look first went into the Breed Book, for "Found on day N" on its lore page.
    /// Looks found in saves from before this field have no day.
    public var breedBookDays: [BreedBookEntry: Int] = [:]
    public var eggBook: Set<EggBookEntry> = []
    /// Looks seen on a show podium, first sighting first (see ShowEvent.swift). Not counted as owned:
    /// milestones, jobs and goals count `breedBook` only. `breedBookSeenOnly` hides looks owned since.
    public var seenAtShows: [SeenBreedBookEntry] = []

    /// County show (see ShowEvent.swift): entries held for the next show, and every past result.
    public var showEntries: [ShowEntry] = []
    public var showResults: [ShowResult] = []
    /// Premium feed in the barrel (day-portions). Bought at Speckle & Down.
    public var premiumFeed = 0
    /// Whether the flock was given premium feed today. Resets each night.
    public var fedPremiumToday = false
    /// True when the flock free-ranged and foraged last night (door left open and survived).
    /// Gives a small lay and condition bonus for the day; recomputed each night. See `Rules.forage*`.
    public var foragedToday = false
    /// Seeds Speckle & Down's daily special (see Shop.swift). 0 in saves from before the special.
    public var shopSeed: UInt64 = 0
    /// The day the keeper last bought the daily special. One a day.
    public var specialBoughtDay: Int?
    /// Early-game features introduced so far (see EarlyGame.swift). A new game starts with none.
    /// Every feature by default, so saves from before the early game keep everything open.
    public var introduced: Set<Feature> = Set(Feature.allCases)
    /// The neighbour's advice for the next show. Cleared on show day.
    public var showTip: ShowTip?
    /// Today's jobs (see Jobs.swift). Nil before the first morning, so old saves get jobs from the next one.
    public var jobBoard: JobBoard?
    /// The season's bigger goal (see Jobs.swift). Nil until a morning with something to aim for.
    public var seasonGoal: SeasonGoal?
    /// Daylight slots spent today (see Daylight.swift). Reset each morning.
    public var slotsUsed = 0
    /// The errand kinds already run today. More of the same kind cost no more daylight.
    public var errandsToday: Set<Errand> = []
    /// True once the keeper has met "What might hatch" (after the first hatch surprise). See Planner.swift.
    public var plannerKnown = false
    /// True once the keeper has opened the "What might hatch" panel. The pen shows a notice until then.
    public var plannerOpened = false
    /// Each hen's laying, counted as she lays (see Records.swift). The egg lists lose sold and set eggs,
    /// so this is the only egg history. Empty in saves from before it: `SaveFormat` back-fills it.
    public var layRecords: [HenLayRecord] = []
    /// The inheritance page (see Inheritance.swift): rules the keeper learned by setting eggs from a
    /// penned pair, in the order first seen, each once. An array, not a set, to keep that order.
    /// Empty in saves from before the page.
    public var seenRules: [InheritanceRule] = []
    /// "Hen or roo?" guesses for chicks whose sex does not show yet (see SexGuess.swift). Cleared on
    /// the morning the sex shows, or when the chick leaves.
    public var sexGuesses: [UUID: Sex] = [:]
    /// Guesses that turned out right. The goal ladder reads it.
    public var sexGuessesRight = 0
    /// Coins the keeper owes Featherwick's people (see Loans.swift). No interest, no deadline.
    public var debts: [Debt] = []
    /// Debts paid, by ID. A story can wait for one (`StoryGoal.coinsPaid`).
    public var debtsPaid: Set<String> = []
    /// Notes already delivered (see Post.swift), by ID. A note never comes twice.
    public var notesSeen: Set<String> = []
    /// The years the keeper brought an egg to the Hatch-along (see HatchAlong.swift). One egg a year.
    public var hatchAlongYears: Set<Int> = []
    /// The mornings Hatch-along chicks come back, soonest first. A day stays here from the egg until its
    /// chick is home: with no room, the chick waits with Hazel. One a year, so the list stays short.
    public var hatchAlongChickDays: [Int] = []

    init(rules: Rules, phase: Phase) {
        self.rules = rules
        self.phase = phase
        coins = rules.startCoins
        perches = rules.startPerches
        nestBoxes = rules.startNestBoxes
        brooderSize = rules.startBrooderSize
        cartons = rules.startCartons
    }

    public var season: Season { season(onDay: day) }

    /// The breeds a surprise pullet or cockerel from Speckle & Down can be: the starter breeds, plus
    /// any breed a storyline added. In breed-table order, so a seed always draws the same breed.
    /// No breed has its own named sale: a keeper meets a new breed by surprise, or as the daily special.
    public var surpriseBreeds: [Breed] {
        BreedTable.inGame.filter { $0.isStarter || shopBreeds.contains($0.id) }.map(\.id)
    }

    /// The season on any day, past or future (for example, the day of the next show).
    public func season(onDay day: Int) -> Season {
        Season.allCases[(max(0, day) / max(1, rules.daysPerSeason)) % Season.allCases.count]
    }

    public var cartonCapacity: Int { cartons * rules.cartonSize }
    public var nestCapacity: Int { nestBoxes * rules.eggsPerNestBox }

    /// The day the next county show is held (see Rules.showIntervalDays).
    public var nextShowDay: Int {
        let interval = rules.showIntervalDays
        guard interval > 0 else { return day }
        return ((day / interval) + 1) * interval
    }
    /// True on the morning a show is held.
    public var isShowDay: Bool { rules.showIntervalDays > 0 && day > 0 && day % rules.showIntervalDays == 0 }
    /// First-place ribbons won so far: the trophy count.
    public var firstPlaceRibbons: Int { showResults.count(where: { $0.placing == 1 }) }

    /// Birds at home (brooder and coop). Lost birds are not fed.
    public var birdsAtHome: [Bird] { brooder + henChicks + coop }

    /// Every bird the player owns, wherever it is. Lost and boarding birds always come back.
    public var ownedBirds: [Bird] { birdsAtHome + lost.map(\.bird) + boarding }

    public var incubatorClutch: Clutch? { clutches.first { $0.henID == nil } }
    public func clutch(under henID: UUID) -> Clutch? { clutches.first { $0.henID == henID } }

    public func bird(_ id: UUID) -> Bird? {
        birdsAtHome.first { $0.id == id }
            ?? lost.first { $0.bird.id == id }?.bird
            ?? boarding.first { $0.id == id }
            ?? rehomed.first { $0.id == id }
    }

    /// Nights left before the neighbour finds this waiting bird a new home. Nil if it is not waiting,
    /// or if it is the starter (never sent away).
    public func nightsUntilRehomed(_ id: UUID) -> Int? {
        guard id != starterID, let since = bird(id)?.waitingSinceDay, !rehomed.contains(where: { $0.id == id })
        else { return nil }
        return max(0, rules.homeWaitNights - (day - since))
    }

    /// Grown birds with no perch: waiting in the brooder or boarding with the neighbour.
    public var birdsWaitingForPerch: [Bird] { (brooder + boarding).filter { $0.waitingSinceDay != nil } }

    /// Ribbons (1st to 3rd) this bird won at county shows. Bird classes only, matched by name.
    public func ribbons(for bird: Bird) -> Int {
        showResults.count(where: { r in
            if case .eggs = r.showClass { return false }
            // Results from before birdID existed match by name.
            let isBird = r.birdID.map { $0 == bird.id } ?? (r.entrantName == bird.name)
            return isBird && (1...3).contains(r.placing)
        })
    }

    /// Coins a neighbour pays for this bird today, ribbons included. Front ends show this price.
    public func rehomeValue(of bird: Bird) -> Int {
        rules.rehomeValue(of: bird, onDay: day, ribbons: ribbons(for: bird))
    }
}
