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
    public var hensPerNestBox = 4
    public var floorEggBreakChance = 0.5

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

    public func price(of egg: Egg) -> Int {
        let base = switch egg.colour {
        case .cream: creamEggPrice
        case .brown: brownEggPrice
        case .blue: blueEggPrice
        case .olive: oliveEggPrice
        }
        return base + (egg.speckled ? speckleBonus : 0)
    }
}
