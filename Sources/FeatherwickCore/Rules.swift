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
    /// From the breed table. A breed missing here never goes broody.
    public var broodyChance: [Breed: Double] = Dictionary(uniqueKeysWithValues: BreedTable.all.map { ($0.id, $0.broodiness) })
    public var broodyDays = 7              // a broody hen does not lay

    // Pairing and hatching
    public var fertileChance = 0.85        // with an adult rooster in the coop
    public var broodyHatchDays = 3         // under a broody hen
    public var incubatorHatchDays = 1      // overnight
    public var maxClutch = 6               // eggs under one broody hen
    public var giftIncubatorSize = 1       // the neighbour's old incubator, given with the first fertile egg
    public var bigIncubatorSize = 6        // the one you buy
    public var incubatorPrice = 40

    // Rooster tension (never harm: hens just lay less)
    public var hensPerRooster = 5          // one rooster is always fine; beyond that, 1 per 5 hens
    public var extraRoosterLayPenalty = 0.15

    // Speckle & Down shop
    public var pulletPrice = 25            // a young hen, breed and sex known
    public var cockerelPrice = 15          // a young rooster
    public var fertileEggPrice = 6         // from a local flock, already candled

    // Making room
    public var coopUpgradePrice = 30
    public var perchesPerUpgrade = 2
    public var maxPerches = 15
    public var rehomeBase: [LifeStage: Int] = [.chick: 2, .grower: 4, .adult: 6]
    public var rareLavenderOrSilkie = 6    // lavender, or silkie feathering on a non-Silkie
    public var rareOliveEggs = 5
    public var rareSplash = 4
    public var rareSpeckledEggs = 3
    public var rareSmall = 2               // each of: blue, barred, blue eggs

    // Fox (never kills)
    public var foxChance = 0.5       // chance the fox visits when the coop is left open
    public var fleeChance = 0.5      // chance each bird runs off when it does
    public var lostDaysMin = 1
    public var lostDaysMax = 3       // doubled for each earlier scare
    public var lostDaysCap = 30
    public var scaredNoLayDays = 3   // a frightened hen stops laying for a while

    // Friendliness (see Friendliness.swift)
    public var petTamenessGain = 0.06        // picking a bird up, once a day
    public var treatTamenessGain = 0.04      // a treat from your hand, once a day
    public var chickHandlingBoost = 3.0      // chicks learn trust fastest
    public var growerHandlingBoost = 1.5
    public var motherHenHandlingFactor = 0.5 // a broody hen keeps her chicks wary
    public var brooderChickTameness = 0.2    // hatched in the incubator, raised in the brooder
    public var broodyChickTameness = 0.05    // hatched under a hen
    public var boughtBirdTameness = 0.25     // a young bird from a shop or a neighbour
    public var foxFrightTamenessLoss = 0.15
    public var lostDayTamenessLoss = 0.02    // per day away
    public var maxLostTamenessLoss = 0.3
    public var treatBagSize = 10
    public var treatBagPrice = 5
    public var rareBreedPulletPrice = 40     // a pullet of a breed unlocked by a storyline
    public var lapChickenRehomeBonus = 3     // people pay more for a bird that loves a cuddle

    // Inbreeding (see Pedigree.swift). Lay chance and show condition drop by the bird's coefficient, capped.
    public var maxInbreedingLayLoss = 0.5
    public var maxInbreedingConditionLoss = 0.3

    // Economy
    public var startCoins = 20
    // Basic feed is free and unlimited. Feeding is still a daily task: unfed hens don't lay.
    public var creamEggPrice = 1
    public var brownEggPrice = 2
    public var blueEggPrice = 3
    public var oliveEggPrice = 4
    public var speckleBonus = 1

    // County show (see ShowEvent.swift). A recurring event that rewards selective breeding, taming
    // and egg quality. Entering costs a small fee (a coin sink); ribbons pay out.
    public var showIntervalDays = 28   // one show each season
    public var showCompetitors = 5     // AI entries in each class
    public var showEntryFee = 3        // per entry, paid when you enter
    public var showPrizeFirst = 20
    public var showPrizeSecond = 10
    public var showPrizeThird = 5

    public init() {}

    public static let standard = Rules()

    /// Coins a neighbour pays to adopt a bird. Rarer birds are worth more.
    ///
    /// Anti-gaming rule: only traits the player can already see count. An unrevealed chick is worth
    /// the base price, so neither the price nor the `value` check leaks hidden genes, and hatching
    /// chicks to sell them unseen is not a shortcut. Egg traits count once a hen is laying.
    public func rehomeValue(of bird: Bird, onDay day: Int) -> Int {
        let stage = bird.stage(onDay: day, rules: self)
        var value = rehomeBase[stage] ?? 0
        guard bird.revealed else { return value }
        let p = bird.phenotype
        if p.colour == .lavender { value += rareLavenderOrSilkie }
        if p.isSilkieFeathered && !bird.breed.definition.fixes(Feathering.silkie) { value += rareLavenderOrSilkie }
        if p.colour == .splash { value += rareSplash }
        if p.colour == .blue { value += rareSmall }
        if p.isBarred { value += rareSmall }
        if bird.friendliness == .lapChicken { value += lapChickenRehomeBonus }
        if bird.sex == .hen, stage == .adult, let egg = p.eggColour {
            if egg == .olive { value += rareOliveEggs } else if egg == .blue { value += rareSmall }
            if p.eggIsSpeckled { value += rareSpeckledEggs }
        }
        return value
    }

    /// Roosters in the coop beyond what the hens can bear. Cockerels count too.
    public func extraRoosters(inCoop coop: [Bird], onDay day: Int) -> Int {
        let roosters = coop.filter { $0.sex == .rooster && $0.stage(onDay: day, rules: self) >= .grower }.count
        let hens = coop.filter { $0.sex == .hen && $0.stage(onDay: day, rules: self) >= .grower }.count
        let allowed = max(1, (hens + hensPerRooster - 1) / hensPerRooster)
        return max(0, roosters - allowed)
    }

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
