/// Every tunable number in one place. Day counts are in-game days.
/// All values are first guesses, to tune with `pass night` in the CLI.
public struct Rules: Codable, Hashable, Sendable {
    // Growth
    public var growerAge = 7         // chick becomes pullet/cockerel; sex and breed show
    public var adultAge = 21         // point of lay
    public var brooderDays = 7       // chick moves from brooder to coop
    public var giftHenAge = 3        // the neighbour's hen is younger than the starter

    // Seasons
    public var daysPerSeason = 28
    public var layChance: [Season: Double] = [.spring: 0.9, .summer: 0.8, .autumn: 0.4, .winter: 0.5]

    // Coop
    public var startPerches = 3
    public var startNestBoxes = 3
    public var startBrooderSize = 4
    public var startCartons = 1
    public var cartonSize = 12

    // Nest boxes. Hens keep laying when eggs are in the nest (real hens do), so the costs of
    // not collecting are: full boxes (floor eggs break), stale eggs (lower price), and broodiness.
    public var eggsPerNestBox = 4
    public var floorEggBreakChance = 0.5
    public var nestFreshDays = 2           // eggs left in the nest longer than this sell as stale
    public var staleEggPriceFactor = 0.5
    public var broodyNestEggs = 4          // a pile of this many eggs can set a hen broody
    public var broodyChance: [Breed: Double] = [.silkie: 0.6, .orpington: 0.3, .wyandotte: 0.15, .araucana: 0.2]
    public var broodyDays = 7              // a broody hen does not lay

    // Pairing and hatching
    public var fertileChance = 0.85        // with an adult rooster in the coop
    public var broodyHatchDays = 3         // under a broody hen
    public var incubatorHatchDays = 1      // overnight
    public var maxClutch = 6               // eggs under one broody hen
    public var giftIncubatorSize = 1       // the neighbour's old incubator, given with the first fertile egg
    public var bigIncubatorSize = 6        // the one you buy
    public var incubatorPrice = 40

    // Fox (never kills)
    public var foxChance = 0.5       // chance the fox visits when the coop is left open
    public var fleeChance = 0.5      // chance each bird runs off when it does
    public var lostDaysMin = 1
    public var lostDaysMax = 3       // doubled for each earlier scare
    public var lostDaysCap = 30
    public var scaredNoLayDays = 3   // a frightened hen stops laying for a while

    // Economy
    public var startCoins = 20
    public var startFeed = 10        // feed units; 1 unit per bird per day
    public var feedBagUnits = 20
    public var feedBagPrice = 10
    public var creamEggPrice = 1
    public var brownEggPrice = 2
    public var blueEggPrice = 3
    public var oliveEggPrice = 4
    public var speckleBonus = 1

    public init() {}

    public static let standard = Rules()

    public func isStale(_ egg: Egg, onDay day: Int) -> Bool {
        (egg.collectedDay ?? day) - egg.layDay > nestFreshDays
    }

    public func price(of egg: Egg, onDay day: Int) -> Int {
        var base = switch egg.colour {
        case .cream: creamEggPrice
        case .brown: brownEggPrice
        case .blue: blueEggPrice
        case .olive: oliveEggPrice
        }
        base += egg.speckled ? speckleBonus : 0
        guard isStale(egg, onDay: day) else { return base }
        return max(1, Int((Double(base) * staleEggPriceFactor).rounded(.down)))
    }
}
