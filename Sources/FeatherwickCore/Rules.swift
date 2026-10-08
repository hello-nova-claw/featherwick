/// Every tunable number in one place. Day counts are in-game days.
/// All values are first guesses, to tune with `pass night` in the CLI.
public struct Rules: Codable, Hashable, Sendable {
    // Growth
    public var growerAge = 7  // chick becomes pullet/cockerel; sex and breed show
    public var adultAge = 21  // point of lay
    public var brooderDays = 7  // chick moves from brooder to coop
    public var giftHenAge = 3  // the neighbour's hen is younger than the starter
    /// Nights a grown bird waits for a perch. Then the neighbour finds it a new home, so a full coop
    /// never holds up the brooder or the incubator for long.
    public var homeWaitNights = 3
    /// Nights a new bird waits for a name. Then it takes the suggested name; the player can rename it.
    public var autoNameNights = 2

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
    public var nestFreshDays = 2  // eggs left in the nest longer than this sell as stale
    public var staleEggPriceFactor = 0.5
    public var broodyNestEggs = 4  // a pile of this many eggs can set a hen broody
    /// From the breed table. A breed missing here never goes broody.
    public var broodyChance: [Breed: Double] = Dictionary(
        uniqueKeysWithValues: BreedTable.all.map { ($0.id, $0.broodiness) })
    public var broodyDays = 7  // a broody hen does not lay

    // Pairing and hatching
    public var fertileChance = 0.85  // with an adult rooster in the coop
    public var broodyHatchDays = 3  // under a broody hen
    public var incubatorHatchDays = 3  // nights in the incubator
    public var chicksToLearnCandling = 1  // the neighbour teaches candling once this many chicks have hatched
    /// Hatch-day notes from the neighbour on a chick that looks like neither parent. Few, so each one is a treat.
    public var hatchWhyNotesPerDay = 1
    public var maxClutch = 6  // eggs under one broody hen
    public var giftIncubatorSize = 1  // the neighbour's old incubator, given with the first fertile egg
    public var incubatorShopAfterGiftDays = 14  // the big incubator comes to the shop at least this long after the gift
    public var bigIncubatorSize = 6  // the one you buy
    public var incubatorPrice = 30
    /// Hens the breeding pen holds, with at most one rooster (see BreedingPen.swift).
    public var penHens = 3

    // Rooster tension (never harm: hens just lay less)
    public var hensPerRooster = 5  // one rooster is always fine; beyond that, 1 per 5 hens
    public var extraRoosterLayPenalty = 0.15

    // Speckle & Down shop. Basic stock is a random starter breed: the keeper learns it on purchase.
    public var pulletPrice = 25  // a young hen
    public var cockerelPrice = 15  // a young rooster
    public var fertileEggPrice = 6  // from a local flock, already candled

    // Making room
    public var coopUpgradePrice = 30
    public var perchesPerUpgrade = 2
    public var maxPerches = 15
    public var rehomeBase: [LifeStage: Int] = [.chick: 2, .grower: 4, .adult: 6]
    public var rareLavenderOrSilkie = 6  // lavender, or silkie feathering on a non-Silkie
    public var rareOliveEggs = 5  // olive, green or chocolate eggs
    public var rareSplash = 4
    public var rareSpeckledEggs = 3
    public var rareSmall = 2  // each of: blue, barred, blue eggs

    // Fox (never kills)
    public var foxChance = 0.5  // chance the fox visits when the coop is left open
    public var fleeChance = 0.5  // chance each bird runs off when it does
    public var lostDaysMin = 1
    public var lostDaysMax = 3  // doubled for each earlier scare
    public var lostDaysCap = 30
    public var scaredNoLayDays = 3  // a frightened hen stops laying for a while

    // Friendliness (see Friendliness.swift)
    public var petTamenessGain = 0.06  // picking a bird up, once a day
    public var treatTamenessGain = 0.04  // a treat from your hand, once a day
    public var chickHandlingBoost = 3.0  // chicks learn trust fastest
    public var growerHandlingBoost = 1.5
    public var motherHenHandlingFactor = 0.5  // a broody hen keeps her chicks wary
    public var brooderChickTameness = 0.2  // hatched in the incubator, raised in the brooder
    public var broodyChickTameness = 0.05  // hatched under a hen
    public var boughtBirdTameness = 0.25  // a young bird from a shop or a neighbour
    public var foxFrightTamenessLoss = 0.15
    public var lostDayTamenessLoss = 0.02  // per day away
    public var maxLostTamenessLoss = 0.3
    public var treatBagSize = 10
    public var treatBagPrice = 5
    public var lapChickenRehomeBonus = 3  // people pay more for a bird that loves a cuddle

    // Inbreeding (see Pedigree.swift). Lay chance and show condition drop by the bird's coefficient, capped.
    /// Off by default: playtests found the penalty (and its numbers) a worry, not fun, in a cozy game.
    /// The coefficient is still recorded at hatch, so the penalty can return later. Old saves load as off.
    public var inbreedingMatters = false
    public var maxInbreedingLayLoss = 0.5
    public var maxInbreedingConditionLoss = 0.3

    // Economy
    public var startCoins = 25
    // Basic feed is free and unlimited. Feeding is still a daily task: unfed hens don't lay.
    public var creamEggPrice = 1
    public var brownEggPrice = 2
    public var blueEggPrice = 3
    public var oliveEggPrice = 4
    public var chocolateEggPrice = 4
    public var greenEggPrice = 4
    public var speckleBonus = 1

    // County show (see ShowEvent.swift). A recurring event that rewards selective breeding, taming
    // and egg quality. Entering costs a small fee (a coin sink); ribbons pay out.
    // Each kind of class has its own difficulty and prizes: pet (easy) < eggs < breed (hard).
    public var showIntervalDays = 28  // one show each season
    public var showEntryFee = 3  // per entry, paid when you enter
    /// AI entries in each class. The field grows with difficulty.
    public var showCompetitorsByKind: [ShowKind: Int] = [.pet: 3, .eggs: 5, .breed: 7]
    /// Each AI entry is the best of this many random candidates, so harder fields are stronger.
    public var showRivalPicks: [ShowKind: Int] = [.pet: 1, .eggs: 2, .breed: 3]
    /// Coins for 1st, 2nd and 3rd.
    public var showPrizeCoins: [ShowKind: [Int]] = [.pet: [8, 4, 2], .eggs: [15, 8, 4], .breed: [30, 15, 8]]
    /// Treats for 1st, 2nd and 3rd. The pet class pays in treats too.
    public var showPrizeTreats: [ShowKind: [Int]] = [.pet: [3, 2, 1], .eggs: [0, 0, 0], .breed: [0, 0, 0]]
    /// Coins are multiplied by this (and rounded) in the kind of class the season's show features.
    public var showFeaturedBonus = 1.5
    /// The Winter Championship draws the strongest field: every class's rival picks go up by this.
    public var winterChampionshipExtraPicks = 1
    // Flock turnover (cozy: hens slow with age and retire, they never die).
    public var layDeclineStartDays = 252  // full for about nine in-game months before slowing
    public var layDeclineFloor = 0.4  // the least a laying hen's age factor falls to
    public var retirementAgeDays = 504  // about 4.5 in-game years: she becomes a beloved non-layer

    // Premium feed: an optional coin sink. Basic feed stays free; premium feed feeds the flock
    // for the day AND lifts laying a little. One bag is several day-portions.
    public var premiumFeedPrice = 8
    public var premiumFeedBagSize = 7
    public var premiumFeedLayBonus = 0.25  // multiplies the day's lay chance when premium-fed
    // Foraging (see Engine.passNight). Leaving the coop door open overnight risks the fox, but if the
    // flock survives they free-range: they come back fed (no feeding needed) and a little the better for it.
    public var forageLayBonus = 0.1  // hens lay a little more readily the day after foraging
    public var forageConditionBonus = 0.1  // foraging birds show in slightly better condition
    // A rival's own day before a show, on its own farm (never the keeper's): odds it was not fed, had
    // a good forage, or had a fright. Drawn from the rival's ID, so they move no game randomness.
    public var rivalHungryChance = 0.15
    public var rivalForagedChance = 0.3
    public var rivalStressedChance = 0.08

    // Rehoming a fine bird (see `rehomeValue`). An average bird gets no quality bonus; a top bird
    // is worth several times a plain one.
    public var rehomeTypeBonus = 16  // a perfect show type; scaled down to 0 at average type
    public var rehomeEggShapeBonus = 6  // a laying hen with perfect egg shape; 0 at average
    public var rehomeRibbonBonus = 6  // each 1st, 2nd or 3rd place the bird won at a show
    public var rehomeMaxRibbons = 5  // ribbons past this many add no more
    public var rehomeStandardPurebredFactor = 1.5  // quality bonuses count more on a purebred in a standard colour

    // Speckle & Down's daily special: one young bird of a named breed, sex and colour.
    public var shopSpecialPulletPrice = 35
    public var shopSpecialCockerelPrice = 20
    public var shopRareChance = 0.08  // chance the special is a rare colour for its breed
    public var shopRarePremium = 15  // added to the price of a rare-colour special

    // Early game (see EarlyGame.swift): the morning each feature is introduced. A new keeper starts with
    // one chick (sex shows on day `growerAge`) and learns one thing at a time.
    public var featureDays: [Feature: Int] = [
        .handling: 1, .treats: 2, .premiumFeed: 4, .coopDoor: 6, .breedBook: 8, .daylight: 9, .birdShop: 10,
        .coopUpgrade: 14, .laying: 18, .incubatorShop: 29, .breedingPen: 35,
    ]
    /// The county show opens this many days before the first show (`.shows` has no entry above).
    public var showNoticeDays = 7
    /// Mealworms the neighbour gives when she shows you treats.
    public var welcomeTreats = 3
    /// The neighbour suggests a bird's breed class when it places 1st to 3rd in at least this share
    /// of practice fields. Otherwise she suggests the pet class.
    public var showTipBreedClassOdds = 0.4
    /// Practice fields judged to find the neighbour's show tip.
    public var showTipTrials = 24

    // Today's jobs and season goals (see Jobs.swift). Gentle nudges: nothing is lost by skipping them.
    public var jobsPerDay = 3  // jobs picked each morning; 0 turns daily jobs off
    public var jobsRewardCoins = 5  // paid once a day, when every job is done
    public var jobPetBirds = 3  // "cuddle Juniper, Pip and Hazel" (fewer if the flock is smaller)
    public var seasonGoals = true  // false turns season goals off
    public var seasonGoalRewardCoins = 25  // paid once, when the season goal is reached
    public var seasonGoalMinDays = 7  // a goal set later in a season runs on through the next one
    public var seasonGoalChicks = 3  // "hatch 3 chicks"
    public var seasonGoalFlockGrowth = 2  // "grow the flock by 2 birds"
    public var seasonGoalEggsPerHen = 8  // "collect N eggs": this many per hen in the coop...
    public var seasonGoalMaxEggs = 40  // ...but never more than this

    // Daylight (see Daylight.swift): a day has a few slots for errands. Care is always free.
    public var daySlots = 3  // errands in a plain day
    public var slotBonusCoopUpgraded = 1  // once the coop has been upgraded at least once
    public var slotBonusLapChicken = 1  // a lap chicken at home: the keeper's day goes further
    public var maxDaySlots = 5  // never more than this, whatever the bonuses

    // "What might hatch" (see Planner.swift). The planner says only what the keeper could work out.
    /// Seen chicks a parent needs, none showing an allele it may hide, before the planner calls it
    /// "likely" that the parent lacks it. A carrier passes the allele to half its chicks, so 5 chicks
    /// without it happen to a carrier only 1 time in 32: likely, never proven.
    public var plannerLikelyAfterChicks = 5
    /// "Not possible" lines in one pair's forecast, at most. The traits the family showed come first,
    /// so the list stays short and says what the keeper hoped for.
    public var plannerNotPossibleLines = 4
    /// The largest "in N" a ratio line uses (2, 4, 8 or 16). Finer shares are "possible" instead.
    public var plannerMaxRatioDenominator = 16

    // Flock record book (see Records.swift).
    /// Days behind the "last N days" egg count.
    public var recordWindowDays = 14

    public init() {}

    /// How an adult hen's laying falls with age: full until `layDeclineStartDays`, then down to
    /// `layDeclineFloor`, reaching 0 at retirement (retired hens don't lay at all). Real heritage
    /// hens lay their best in the first year or two and slow steadily after.
    public func layAgeFactor(ageDays: Int) -> Double {
        guard ageDays > layDeclineStartDays else { return 1 }
        if ageDays >= retirementAgeDays { return 0 }
        let span = Double(retirementAgeDays - layDeclineStartDays)
        let past = Double(ageDays - layDeclineStartDays)
        return max(layDeclineFloor, 1 - (1 - layDeclineFloor) * (past / span))
    }

    public static let standard = Rules()

    // Shell depth (`QuantitativeTrait.brownDepth`, as a share 0...1). These are fixed for every game,
    // not saved per game, because an egg's colour is part of the bird's look (`Phenotype`), which
    // needs no rules. Average depth (0.5) gives brown and olive, so older birds keep their colours.
    /// Brown coating above this depth gives chocolate eggs.
    public static let chocolateShellDepth = 0.8
    /// Brown coating over blue at this depth or more gives olive; below it, green.
    public static let oliveShellDepth = 0.4

    /// Coins a neighbour pays to adopt a bird. Rarer and finer birds are worth more.
    ///
    /// Anti-gaming rule: only traits the player can already see count. An unrevealed chick is worth
    /// the base price, so neither the price nor the `value` check leaks hidden genes, and hatching
    /// chicks to sell them unseen is not a shortcut. Egg traits count once a hen is laying.
    ///
    /// Quality counts too: show type (a keeper can see it in a grown bird), egg shape for a laying hen,
    /// and `ribbons` (1st to 3rd places the bird won). A purebred in a standard colour gets more for
    /// its quality, because breeders pay for good stock. `GameState.rehomeValue(of:)` counts the ribbons.
    public func rehomeValue(of bird: Bird, onDay day: Int, ribbons: Int = 0) -> Int {
        let stage = bird.stage(onDay: day, rules: self)
        var value = rehomeBase[stage] ?? 0
        guard bird.revealed else { return value }
        let p = bird.phenotype
        value += qualityBonus(of: bird, onDay: day, ribbons: ribbons)
        if p.colour == .lavender { value += rareLavenderOrSilkie }
        if p.isSilkieFeathered && !bird.breed.definition.fixes(Feathering.silkie) { value += rareLavenderOrSilkie }
        if p.colour == .splash { value += rareSplash }
        if p.colour == .blue { value += rareSmall }
        if p.isBarred { value += rareSmall }
        if bird.friendliness == .lapChicken { value += lapChickenRehomeBonus }
        if bird.sex == .hen, stage == .adult, let egg = p.eggColour {
            switch egg {
            case .olive, .green, .chocolate: value += rareOliveEggs
            case .blue: value += rareSmall
            case .cream, .brown: break
            }
            if p.eggIsSpeckled { value += rareSpeckledEggs }
        }
        return value
    }

    /// The part of the rehome value that comes from quality: type, egg shape and ribbons.
    /// Only above-average quality counts, so a plain bird keeps its plain price.
    func qualityBonus(of bird: Bird, onDay day: Int, ribbons: Int) -> Int {
        let stage = bird.stage(onDay: day, rules: self)
        // 0 at average (or below), 1 at the best possible score.
        func aboveAverage(_ trait: QuantitativeTrait) -> Double {
            max(0, trait.fraction(bird.genome) - 0.5) * 2
        }
        var bonus = aboveAverage(.showType) * Double(rehomeTypeBonus)
        if bird.sex == .hen, stage == .adult, !bird.isRetired(onDay: day, rules: self) {
            bonus += aboveAverage(.eggShape) * Double(rehomeEggShapeBonus)
        }
        bonus += Double(min(max(0, ribbons), rehomeMaxRibbons) * rehomeRibbonBonus)
        if bird.isPurebred, ShowStandard(bird.breed).accepts(Appearance(bird.phenotype)) {
            bonus *= rehomeStandardPurebredFactor
        }
        return Int(bonus.rounded())
    }

    /// Roosters in the coop beyond what the hens can bear. Cockerels count too.
    public func extraRoosters(inCoop coop: [Bird], onDay day: Int) -> Int {
        let roosters = coop.count(where: { $0.sex == .rooster && $0.stage(onDay: day, rules: self) >= .grower })
        let hens = coop.count(where: { $0.sex == .hen && $0.stage(onDay: day, rules: self) >= .grower })
        let allowed = max(1, (hens + hensPerRooster - 1) / hensPerRooster)
        return max(0, roosters - allowed)
    }

    public func isStale(_ egg: Egg, onDay day: Int) -> Bool {
        (egg.collectedDay ?? day) - egg.layDay > nestFreshDays
    }

    public func price(of egg: Egg, onDay day: Int) -> Int {
        var base =
            switch egg.colour {
            case .cream: creamEggPrice
            case .brown: brownEggPrice
            case .blue: blueEggPrice
            case .olive: oliveEggPrice
            case .chocolate: chocolateEggPrice
            case .green: greenEggPrice
            }
        base += egg.speckled ? speckleBonus : 0
        guard isStale(egg, onDay: day) else { return base }
        return max(1, Int((Double(base) * staleEggPriceFactor).rounded(.down)))
    }
}
