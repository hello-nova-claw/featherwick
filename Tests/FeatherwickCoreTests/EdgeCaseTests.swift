import Foundation
import Testing

@testable import FeatherwickCore

/// A started game where the starter hen is an adult in the coop.
func adultHenGame(_ rules: Rules = calmRules()) -> (GameState, SeededRNG) {
    var (s, rng) = startedGame(sex: .hen, rules: rules)
    while s.day < rules.adultAge { night(&s, &rng) }
    return (s, rng)
}

func plainBird(_ breed: Breed = .orpington, _ sex: Sex = .hen, hatchDay: Int = 0, rng: inout SeededRNG) -> Bird {
    Bird(
        id: makeID(using: &rng), name: "\(breed.rawValue)-\(sex.rawValue)", breed: breed,
        genome: breed.purebred(sex), hatchDay: hatchDay, origin: "Test", revealed: true)
}

func count(_ ev: [GameEvent], _ match: (GameEvent) -> Bool) -> Int { ev.filter(match).count }

// MARK: - Starting

struct StartingEdgeCases {
    static let allCommandsButChoose: [Command] = [
        .feed, .collectEggs, .sellEggs, .sellClearEggs, .candle, .closeCoop, .passNight,
        .buyIncubator, .incubate(count: 1), .sit(hen: UUID(), count: 1),
        .rename(UUID(), name: "x"), .rehome(UUID()), .upgradeCoop,
        .incubateEggs([UUID()]), .sitEggs(hen: UUID(), eggs: [UUID()]), .sellChosenEggs([UUID()]),
    ]

    @Test(arguments: allCommandsButChoose)
    func everyCommandWaitsForTheStarter(_ command: Command) {
        var rng = SeededRNG(seed: 1)
        var s = Engine.newGame(using: &rng)
        let before = s
        #expect(Engine.apply(command, to: &s, using: &rng) == [.rejected(.chooseStarterFirst)])
        #expect(s == before)
    }

    @Test func choosingTwiceIsRejected() {
        var (s, rng) = startedGame(sex: .hen)
        #expect(
            Engine.apply(.chooseStarter(index: 0, name: "Again"), to: &s, using: &rng) == [.rejected(.alreadyStarted)])
        #expect(s.brooder.count == 1)
    }

    @Test(arguments: [-1, 3, 99])
    func outOfRangeChickIsRejected(_ index: Int) {
        var rng = SeededRNG(seed: 1)
        var s = Engine.newGame(using: &rng)
        #expect(Engine.apply(.chooseStarter(index: index, name: "x"), to: &s, using: &rng) == [.rejected(.noSuchChick)])
    }

    @Test func blankNameBecomesChick() {
        var rng = SeededRNG(seed: 1)
        var s = Engine.newGame(using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "   "), to: &s, using: &rng)
        #expect(s.brooder[0].name == "Chick")
    }

    @Test func starterChicksHaveUniqueIDs() {
        for seed in UInt64(1)...50 {
            var rng = SeededRNG(seed: seed)
            guard case .choosingStarter(let chicks) = Engine.newGame(using: &rng).phase else { continue }
            #expect(Set(chicks.map(\.id)).count == 3)
        }
    }
}

// MARK: - Feeding and the coop door

struct FeedingAndDoorEdgeCases {
    @Test func feedingTwiceInADayIsRejected() {
        var (s, rng) = startedGame(sex: .hen)
        _ = Engine.apply(.feed, to: &s, using: &rng)
        #expect(Engine.apply(.feed, to: &s, using: &rng) == [.rejected(.alreadyFed)])
    }

    @Test func feedingResetsOvernight() {
        var (s, rng) = startedGame(sex: .hen)
        _ = Engine.apply(.feed, to: &s, using: &rng)
        night(&s, &rng, feed: false)
        #expect(!s.fedToday)
        #expect(Engine.apply(.feed, to: &s, using: &rng) == [.fed(units: 1)])
    }

    @Test func nothingToFeedWhenEveryBirdIsLost() {
        var (s, rng) = adultHenGame()
        s.rules.foxChance = 1
        night(&s, &rng, close: false)
        #expect(s.birdsAtHome.isEmpty)
        #expect(Engine.apply(.feed, to: &s, using: &rng) == [.rejected(.nothingToFeed)])
    }

    @Test func boardingBirdsAreNotFedByThePlayer() {
        var (s, rng) = startedGame(sex: .hen)
        s.boarding.append(plainBird(rng: &rng))
        #expect(Engine.apply(.feed, to: &s, using: &rng) == [.fed(units: 1)])
    }

    @Test func closingTwiceIsRejectedAndTheDoorOpensInTheMorning() {
        var (s, rng) = startedGame(sex: .hen)
        _ = Engine.apply(.closeCoop, to: &s, using: &rng)
        #expect(Engine.apply(.closeCoop, to: &s, using: &rng) == [.rejected(.coopAlreadyClosed)])
        night(&s, &rng, close: false)
        #expect(s.coopDoorOpen)
    }
}

// MARK: - Fox and lost birds

struct FoxEdgeCases {
    @Test func foxLeavesBroodyHensAlone() {
        var (s, rng) = adultHenGame()
        s.coop[0].broodyUntilDay = s.day + 5
        s.rules.foxChance = 1
        let ev = night(&s, &rng, close: false)
        #expect(ev.contains(.quietNight))
        #expect(s.lost.isEmpty)
    }

    @Test func foxCannotReachTheBrooder() {
        var (s, rng) = startedGame(sex: .hen)
        s.rules.foxChance = 1
        s.rules.fleeChance = 1
        for _ in 0..<5 { night(&s, &rng, close: false) }
        #expect(s.lost.isEmpty && s.brooder.count == 1)
    }

    @Test func aFoxVisitAlwaysScaresAtLeastOneBird() {
        var (s, rng) = adultHenGame()
        s.rules.foxChance = 1
        s.rules.fleeChance = 0
        let ev = night(&s, &rng, close: false)
        #expect(count(ev) { if case .foxVisited(let ids) = $0 { ids.count == 1 } else { false } } == 1)
    }

    @Test func aScaredHenLaysAgainOnHerNoLayDay() {
        var r = calmRules()
        r.lostDaysMin = 1
        r.lostDaysMax = 1
        r.broodyChance = [:]
        var (s, rng) = adultHenGame(r)
        s.rules.foxChance = 1
        night(&s, &rng, close: false)
        s.rules.foxChance = 0
        var back = false
        while !back { back = night(&s, &rng).contains { if case .birdReturned = $0 { true } else { false } } }
        let noLayUntil = s.coop[0].noLayUntilDay
        var layDays: [Int] = []
        for _ in 0..<5 {
            if night(&s, &rng).contains(where: { if case .eggLaid = $0 { true } else { false } }) {
                layDays.append(s.day)
            }
        }
        #expect(layDays.first == noLayUntil)
    }

    @Test func earlierReturnDayGetsTheOnlyPerch() {
        var r = calmRules()
        r.startPerches = 1
        var (s, rng) = startedGame(sex: .hen, rules: r)
        s.brooder.removeAll()
        let early = plainBird(rng: &rng)
        let late = plainBird(rng: &rng)
        s.lost = [LostBird(bird: late, returnsOnDay: s.day + 1), LostBird(bird: early, returnsOnDay: s.day)]
        let ev = night(&s, &rng)
        #expect(ev.contains(.birdReturned(early.id)))
        #expect(ev.contains(.birdWaitingForPerch(late.id)))
    }

    @Test func lostTimeNeverOverflows() {
        var rng = SeededRNG(seed: 1)
        for scares in [10, 63, 64, 1000, Int.max] {
            let d = Engine.lostDays(timesScared: scares, rules: .standard, &rng)
            #expect(d <= Rules.standard.lostDaysCap && d >= 1)
        }
    }

    @Test func aLostBirdTakesAPerchFreedByRehoming() {
        var r = calmRules()
        r.startPerches = 1
        var (s, rng) = startedGame(sex: .hen, rules: r)
        s.brooder.removeAll()
        let resident = plainBird(rng: &rng)
        let wanderer = plainBird(.araucana, rng: &rng)
        s.coop = [resident]
        s.lost = [LostBird(bird: wanderer, returnsOnDay: s.day)]
        #expect(night(&s, &rng).contains(.birdWaitingForPerch(wanderer.id)))
        _ = Engine.apply(.rehome(resident.id), to: &s, using: &rng)
        #expect(night(&s, &rng).contains(.birdReturned(wanderer.id)))
    }
}

// MARK: - Growth, reveals and the gift hen

struct GrowthEdgeCases {
    @Test func aBirdIsRevealedOnlyOnce() {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        var ev: [GameEvent] = []
        for _ in 0..<40 { ev += night(&s, &rng) }
        #expect(count(ev) { if case .revealed = $0 { true } else { false } } == 1)
    }

    @Test func identicalBirdsMakeOneBreedBookEntry() {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        var twin = s.brooder[0]
        twin = Bird(
            id: makeID(using: &rng), name: "Twin", breed: twin.breed, genome: twin.genome,
            hatchDay: twin.hatchDay, origin: "Test")
        s.brooder.append(twin)
        var ev: [GameEvent] = []
        for _ in 0..<10 { ev += night(&s, &rng) }
        #expect(s.breedBook.count == 1)
        #expect(count(ev) { if case .newBreedBookEntry = $0 { true } else { false } } == 1)
    }

    @Test func noGiftHenIfTheRoosterStarterWasRehomedFirst() {
        var (s, rng) = startedGame(sex: .rooster, rules: calmRules())
        night(&s, &rng)
        let starter = s.brooder[0].id
        s.brooder.append(plainBird(rng: &rng))  // so the starter is not the last bird
        _ = Engine.apply(.rehome(starter), to: &s, using: &rng)
        var ev: [GameEvent] = []
        for _ in 0..<15 { ev += night(&s, &rng) }
        #expect(!ev.contains { if case .neighbourGaveHen = $0 { true } else { false } })
        #expect(s.starterID == nil)
    }

    @Test func giftHenGoesToTheCoopWhenTheBrooderIsFull() {
        var r = calmRules()
        r.startBrooderSize = 1
        var (s, rng) = startedGame(sex: .rooster, rules: r)
        var giftID: UUID?
        for _ in 0..<r.growerAge {
            for e in night(&s, &rng) { if case .neighbourGaveHen(let id) = e { giftID = id } }
        }
        #expect(s.coop.contains { $0.id == giftID })
        #expect(s.coop.count <= s.perches)
    }
}

// MARK: - Laying, seasons and nest boxes

struct LayingEdgeCases {
    @Test func roostersNeverLay() {
        var (s, rng) = startedGame(sex: .rooster, rules: calmRules())
        let rooster = s.brooder[0].id
        var ev: [GameEvent] = []
        for _ in 0..<40 { ev += night(&s, &rng) }
        #expect(!ev.contains { if case .eggLaid(_, rooster) = $0 { true } else { false } })
    }

    @Test func pulletsDoNotLay() {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        var ev: [GameEvent] = []
        while s.day < s.rules.adultAge - 1 { ev += night(&s, &rng) }
        #expect(!ev.contains { if case .eggLaid = $0 { true } else { false } })
    }

    @Test func noHungerMessageWithoutLayingHens() {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        #expect(!night(&s, &rng, feed: false).contains(.noEggsHungry))
    }

    @Test func zeroLayChanceMeansNoEggs() {
        var r = calmRules()
        r.layChance = [.spring: 0, .summer: 0, .autumn: 0, .winter: 0]
        var (s, rng) = adultHenGame(r)
        for _ in 0..<10 { night(&s, &rng) }
        #expect(s.nest.isEmpty)
    }

    @Test func seasonsTurnInOrderAndWrap() {
        var r = calmRules()
        r.daysPerSeason = 2
        var (s, rng) = startedGame(sex: .hen, rules: r)
        var seasons: [Season] = []
        for _ in 0..<8 {
            for e in night(&s, &rng) { if case .seasonChanged(let season) = e { seasons.append(season) } }
        }
        #expect(seasons == [.summer, .autumn, .winter, .spring])
    }

    @Test func floorEggsThatSurviveStillCount() {
        var r = calmRules()
        r.floorEggBreakChance = 0
        r.broodyChance = [:]
        var (s, rng) = adultHenGame(r)
        s.nest = (0..<s.nestCapacity).map { _ in clearEgg(mother: s.coop[0], day: s.day, rng: &rng) }
        night(&s, &rng)
        #expect(s.nest.count == s.nestCapacity + 1)
    }

    @Test func newEggColourIsAnnouncedOnce() {
        var r = calmRules()
        r.broodyChance = [:]
        var (s, rng) = startedGame(sex: .hen, rules: r)
        var ev: [GameEvent] = []
        for _ in 0..<(r.adultAge + 5) { ev += night(&s, &rng) }
        #expect(count(ev) { if case .newEggBookEntry = $0 { true } else { false } } == 1)
    }

    @Test func eggColourByBreed() {
        #expect(Phenotype(Breed.orpington.purebred(.hen)).eggColour == .brown)
        #expect(Phenotype(Breed.wyandotte.purebred(.hen)).eggColour == .brown)
        #expect(Phenotype(Breed.araucana.purebred(.hen)).eggColour == .blue)
        #expect(Phenotype(Breed.silkie.purebred(.hen)).eggColour == .cream)
    }
}

// MARK: - Collecting, selling and freshness

struct EggHandlingEdgeCases {
    @Test func collectingAnEmptyNestIsRejected() {
        var (s, rng) = startedGame(sex: .hen)
        #expect(Engine.apply(.collectEggs, to: &s, using: &rng) == [.rejected(.noEggsInNest)])
    }

    @Test func collectingStampsTheDay() {
        var (s, rng) = startedGame(sex: .hen)
        s.day = 9
        s.nest = [clearEgg(mother: s.brooder[0], day: 7, rng: &rng)]
        s.nest[0].collectedDay = nil
        _ = Engine.apply(.collectEggs, to: &s, using: &rng)
        #expect(s.carton[0].collectedDay == 9)
    }

    @Test func freshnessBoundary() {
        let r = Rules.standard
        let id = UUID()
        let fresh = Egg(id: id, layDay: 0, motherID: id, colour: .brown, speckled: false, collectedDay: r.nestFreshDays)
        let stale = Egg(
            id: id, layDay: 0, motherID: id, colour: .brown, speckled: false, collectedDay: r.nestFreshDays + 1)
        #expect(!r.isStale(fresh, onDay: 100))
        #expect(r.isStale(stale, onDay: 100))
    }

    @Test func sellingClearEggsWhenAllAreKnownFertileSellsNothing() {
        var (s, rng) = startedGame(sex: .hen)
        let hen = plainBird(.araucana, rng: &rng)
        let rooster = plainBird(.orpington, .rooster, rng: &rng)
        var egg = fertileEgg(mother: hen, father: rooster, day: 0, rng: &rng)
        egg.candled = true
        s.carton = [egg]
        #expect(Engine.apply(.sellClearEggs, to: &s, using: &rng) == [.rejected(.cartonEmpty)])
        #expect(s.carton.count == 1)
    }

    @Test func twoCartonsHoldTwentyFour() {
        var (s, rng) = startedGame(sex: .hen)
        s.cartons = 2
        s.nest = (0..<30).map { _ in clearEgg(mother: s.brooder[0], day: 0, rng: &rng) }
        #expect(Engine.apply(.collectEggs, to: &s, using: &rng) == [.eggsCollected(count: 24, leftInNest: 6)])
    }

    @Test func candlingAnEmptyCartonIsRejected() {
        var (s, rng) = startedGame(sex: .hen)
        #expect(Engine.apply(.candle, to: &s, using: &rng) == [.rejected(.cartonEmpty)])
    }
}

// MARK: - Incubator and broody hens

struct HatchingEdgeCases {
    func gameWithIncubator(fertile: Int, clear: Int = 0) -> (GameState, SeededRNG) {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        s.incubatorSize = 6
        let hen = plainBird(.araucana, rng: &rng)
        let rooster = plainBird(.orpington, .rooster, rng: &rng)
        s.carton =
            (0..<fertile).map { _ in fertileEgg(mother: hen, father: rooster, day: 0, rng: &rng) }
            + (0..<clear).map { _ in clearEgg(mother: hen, day: 0, rng: &rng) }
        return (s, rng)
    }

    @Test(arguments: [0, -1, -50])
    func incubatingZeroOrFewerIsRejected(_ n: Int) {
        var (s, rng) = gameWithIncubator(fertile: 2)
        #expect(Engine.apply(.incubate(count: n), to: &s, using: &rng) == [.rejected(.invalidAmount)])
    }

    @Test func incubatorTopsUpOnTheSameDayUntilFull() {
        var (s, rng) = gameWithIncubator(fertile: 3)
        s.incubatorSize = 2
        s.brooderSize = 6
        _ = Engine.apply(.incubate(count: 1), to: &s, using: &rng)
        _ = Engine.apply(.incubate(count: 1), to: &s, using: &rng)
        #expect(s.clutches.count == 1 && s.incubatorClutch?.eggs.count == 2)
        #expect(Engine.apply(.incubate(count: 1), to: &s, using: &rng) == [.rejected(.incubatorFull(room: 0))])
    }

    @Test func incubatorEggsKeepTheirBrooderPlaces() {
        var (s, rng) = gameWithIncubator(fertile: 1)
        s.rules.incubatorHatchDays = 3
        s.brooderSize = 2  // the starter and the chick to come
        _ = Engine.apply(.incubate(count: 1), to: &s, using: &rng)
        // A grown chick of a broody hen, with every perch taken, must not take the incubator chick's place.
        var mother = plainBird(rng: &rng)
        mother.broodyUntilDay = s.day + 10
        s.coop = [mother]
        s.perches = 1
        var chick = plainBird(hatchDay: s.day - s.rules.brooderDays, rng: &rng)
        chick.raisedBy = mother.id
        s.henChicks = [chick]
        _ = Engine.findHomes(&s)
        #expect(s.brooder.count == 1 && s.boarding.map(\.id) == [chick.id])
    }

    @Test func eggsFromAnEarlierDayKeepTheIncubatorBusy() {
        var (s, rng) = gameWithIncubator(fertile: 3)
        s.rules.incubatorHatchDays = 3
        s.brooderSize = 6
        _ = Engine.apply(.incubate(count: 1), to: &s, using: &rng)
        night(&s, &rng)
        #expect(Engine.apply(.incubate(count: 1), to: &s, using: &rng) == [.rejected(.incubatorBusy)])
    }

    @Test func theChosenEggsAreTheOnesSet() {
        var (s, rng) = gameWithIncubator(fertile: 4)
        s.brooderSize = 6
        let picked = [s.carton[3].id, s.carton[1].id]
        let ev = Engine.apply(.incubateEggs(picked), to: &s, using: &rng)
        #expect(ev.contains(.eggsSet(count: 2, hen: nil, hatchDay: s.day + s.rules.incubatorHatchDays)))
        #expect(Set(s.incubatorClutch!.eggs.map(\.id)) == Set(picked))
        #expect(s.carton.count == 2 && s.carton.allSatisfy { !picked.contains($0.id) })
    }

    @Test func choosingTooManyEggsForTheIncubatorIsRejected() {
        var (s, rng) = gameWithIncubator(fertile: 4)
        s.incubatorSize = 2
        s.brooderSize = 6
        let before = s
        let ev = Engine.apply(.incubateEggs(s.carton.prefix(3).map(\.id)), to: &s, using: &rng)
        #expect(ev == [.rejected(.incubatorFull(room: 2))])
        #expect(s == before)
    }

    @Test func aKnownClearOrMissingEggCannotBeChosen() {
        var (s, rng) = gameWithIncubator(fertile: 1, clear: 1)
        _ = Engine.apply(.candle, to: &s, using: &rng)
        let clear = s.carton.first { !$0.isFertile }!.id
        #expect(Engine.apply(.incubateEggs([clear]), to: &s, using: &rng) == [.rejected(.eggIsClear)])
        #expect(Engine.apply(.incubateEggs([UUID()]), to: &s, using: &rng) == [.rejected(.noSuchEgg)])
        #expect(Engine.apply(.incubateEggs([]), to: &s, using: &rng) == [.rejected(.invalidAmount)])
        #expect(Engine.apply(.sellChosenEggs([UUID()]), to: &s, using: &rng) == [.rejected(.noSuchEgg)])
    }

    @Test func sellingChosenEggsSellsOnlyThose() {
        var (s, rng) = gameWithIncubator(fertile: 2, clear: 2)
        let picked = s.carton[2].id
        let price = s.rules.price(of: s.carton[2], onDay: s.day)
        let coins = s.coins
        let ev = Engine.apply(.sellChosenEggs([picked]), to: &s, using: &rng)
        #expect(ev == [.eggsSold(count: 1, coins: price, stale: 0)])
        #expect(s.coins == coins + price)
        #expect(s.carton.count == 3 && !s.carton.contains { $0.id == picked })
    }

    @Test func allClearEggsSetNothingAndLeaveTheIncubatorFree() {
        var (s, rng) = gameWithIncubator(fertile: 0, clear: 3)
        #expect(Engine.apply(.incubate(count: 3), to: &s, using: &rng) == [.candled(fertile: 0, clear: 3)])
        #expect(s.incubatorClutch == nil)
        #expect(s.carton.count == 3 && s.carton.allSatisfy(\.isCandled))
        // Now all are known clear, so none can be offered.
        #expect(Engine.apply(.incubate(count: 1), to: &s, using: &rng) == [.rejected(.notEnoughEggsInCarton(have: 0))])
    }

    @Test func onlyCoopHensCanSit() {
        var (s, rng) = gameWithIncubator(fertile: 1)
        #expect(Engine.apply(.sit(hen: s.brooder[0].id, count: 1), to: &s, using: &rng) == [.rejected(.noSuchBird)])
    }

    @Test func aBroodyHenWithOnlyClearEggsStaysBroodyButSitsOnNothing() {
        var r = calmRules()
        r.broodyChance = [:]
        var (s, rng) = adultHenGame(r)
        let until = s.day + 4
        s.coop[0].broodyUntilDay = until
        s.carton = (0..<2).map { _ in clearEgg(mother: s.coop[0], day: s.day, rng: &rng) }
        #expect(
            Engine.apply(.sit(hen: s.coop[0].id, count: 2), to: &s, using: &rng) == [.candled(fertile: 0, clear: 2)])
        #expect(s.clutches.isEmpty)
        #expect(s.coop[0].broodyUntilDay == until)
    }

    @Test func aHenSitsOnAtMostSixAndOnlyOneClutch() {
        var r = calmRules()
        r.broodyChance = [:]
        var (s, rng) = adultHenGame(r)
        s.coop[0].broodyUntilDay = s.day + 4
        let rooster = plainBird(.orpington, .rooster, rng: &rng)
        s.carton = (0..<8).map { _ in fertileEgg(mother: s.coop[0], father: rooster, day: s.day, rng: &rng) }
        let hen = s.coop[0].id
        #expect(Engine.apply(.sit(hen: hen, count: 7), to: &s, using: &rng) == [.rejected(.clutchTooBig(max: 6))])
        _ = Engine.apply(.sit(hen: hen, count: 2), to: &s, using: &rng)
        #expect(Engine.apply(.sit(hen: hen, count: 1), to: &s, using: &rng) == [.rejected(.henAlreadySitting)])
    }

    @Test func hatchedChicksAreNumberedAcrossClutchesAndStartHidden() {
        var (s, rng) = gameWithIncubator(fertile: 4)
        s.brooderSize = 6  // room for the starter and 4 chicks
        _ = Engine.apply(.incubate(count: 2), to: &s, using: &rng)
        night(&s, &rng)
        _ = Engine.apply(.incubate(count: 2), to: &s, using: &rng)
        night(&s, &rng)
        let hatched = s.brooder.filter { $0.origin == "Henhaven" }
        #expect(hatched.map(\.name) == ["Chick 1", "Chick 2", "Chick 3", "Chick 4"])
        #expect(hatched.allSatisfy { !$0.revealed })
        #expect(hatched.prefix(2).allSatisfy { $0.hatchDay == 1 } && hatched.suffix(2).allSatisfy { $0.hatchDay == 2 })
    }

    @Test func buyingTheBigIncubatorFirstMeansNoGiftLater() {
        var r = calmRules()
        r.fertileChance = 1
        r.broodyChance = [:]
        var (s, rng) = adultHenGame(r)
        s.coins = 100
        _ = Engine.apply(.buyIncubator, to: &s, using: &rng)
        s.coop.append(plainBird(.araucana, .rooster, hatchDay: s.day - r.adultAge, rng: &rng))
        var ev: [GameEvent] = []
        for _ in 0..<3 { ev += night(&s, &rng) }
        #expect(!ev.contains { if case .neighbourGaveIncubator = $0 { true } else { false } })
        #expect(s.incubatorSize == r.bigIncubatorSize)
    }

    @Test func noRoosterMeansNoIncubatorGift() {
        var r = calmRules()
        r.broodyChance = [:]
        var (s, rng) = adultHenGame(r)
        for _ in 0..<20 { night(&s, &rng) }
        #expect(!s.hasIncubator && !s.incubatorGiftGiven)
    }

    @Test func buyingTheIncubatorNeedsCoins() {
        var (s, rng) = startedGame(sex: .hen)
        let price = s.rules.incubatorPrice
        s.coins = price - 1
        #expect(
            Engine.apply(.buyIncubator, to: &s, using: &rng) == [
                .rejected(.notEnoughCoins(needed: price, have: price - 1))
            ])
        #expect(!s.hasIncubator && s.coins == price - 1)
    }
}

// MARK: - Rehoming, renaming and the coop

struct RoomEdgeCases {
    @Test func anyBirdAtHomeOrBoardingCanBeRehomed() {
        var (s, rng) = startedGame(sex: .hen)
        let boarder = plainBird(hatchDay: -s.rules.adultAge, rng: &rng)  // an adult
        s.boarding = [boarder]
        #expect(Engine.apply(.rehome(boarder.id), to: &s, using: &rng) == [.rehomed(boarder.id, coins: 6)])
        s.coop.append(plainBird(rng: &rng))  // so the chick is not the last bird
        let chick = s.brooder[0].id
        #expect(Engine.apply(.rehome(chick), to: &s, using: &rng) == [.rehomed(chick, coins: 2)])
        #expect(s.bird(chick)?.name == "Pip")  // still known, for messages and town later
    }

    @Test func theLastBirdCannotBeRehomed() {
        var (s, rng) = startedGame(sex: .hen)
        let only = s.brooder[0].id
        #expect(Engine.apply(.rehome(only), to: &s, using: &rng) == [.rejected(.lastBird)])
        // A lost bird still counts as yours, so the bird at home can go.
        s.lost = [LostBird(bird: plainBird(rng: &rng), returnsOnDay: 50)]
        #expect(Engine.apply(.rehome(only), to: &s, using: &rng) == [.rehomed(only, coins: 2)])
    }

    @Test func lostOrUnknownBirdsCannotBeRehomed() {
        var (s, rng) = startedGame(sex: .hen)
        let wanderer = plainBird(rng: &rng)
        s.lost = [LostBird(bird: wanderer, returnsOnDay: 99)]
        #expect(Engine.apply(.rehome(wanderer.id), to: &s, using: &rng) == [.rejected(.noSuchBird)])
        #expect(Engine.apply(.rehome(UUID()), to: &s, using: &rng) == [.rejected(.noSuchBird)])
    }

    @Test func rehomeValueGrowsWithAge() {
        let r = Rules.standard
        var rng = SeededRNG(seed: 1)
        let bird = plainBird(hatchDay: 0, rng: &rng)
        #expect(r.rehomeValue(of: bird, onDay: 0) == 2)
        #expect(r.rehomeValue(of: bird, onDay: r.growerAge) == 4)
        #expect(r.rehomeValue(of: bird, onDay: r.adultAge) == 6)
    }

    @Test func coopUpgradeStopsAtTheMaximum() {
        var (s, rng) = startedGame(sex: .hen)
        s.coins = 1000
        s.perches = s.rules.maxPerches - 1
        #expect(
            Engine.apply(.upgradeCoop, to: &s, using: &rng) == [.coopUpgraded(perches: s.rules.maxPerches, cost: 30)])
    }

    @Test func renameRules() {
        var (s, rng) = startedGame(sex: .hen)
        let id = s.brooder[0].id
        #expect(Engine.apply(.rename(id, name: "   "), to: &s, using: &rng) == [.rejected(.invalidAmount)])
        #expect(Engine.apply(.rename(UUID(), name: "X"), to: &s, using: &rng) == [.rejected(.noSuchBird)])
        let boarder = plainBird(rng: &rng)
        s.boarding = [boarder]
        #expect(Engine.apply(.rename(boarder.id, name: "  Hazel "), to: &s, using: &rng) == [.renamed(boarder.id)])
        #expect(s.boarding[0].name == "Hazel")
    }
}

// MARK: - Saves

struct SaveEdgeCases {
    @Test func aBusySaveRoundTrips() throws {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        let hen = plainBird(.araucana, rng: &rng)
        let rooster = plainBird(.orpington, .rooster, rng: &rng)
        s.lost = [LostBird(bird: plainBird(rng: &rng), returnsOnDay: 5)]
        s.boarding = [plainBird(.wyandotte, rng: &rng)]
        s.rehomed = [plainBird(.silkie, rng: &rng)]
        s.henChicks = [plainBird(rng: &rng)]
        s.clutches = [
            Clutch(henID: nil, eggs: [fertileEgg(mother: hen, father: rooster, day: 0, rng: &rng)], hatchDay: 1)
        ]
        var candled = fertileEgg(mother: hen, father: rooster, day: 0, rng: &rng)
        candled.candled = true
        s.carton = [candled, clearEgg(mother: hen, day: 0, rng: &rng)]
        s.incubatorSize = 6
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        #expect(loaded == s)
    }

    @Test func aLoadedGameContinuesExactlyLikeAnUnbrokenOne() throws {
        func play(_ s: inout GameState, _ rng: inout SeededRNG, _ nights: Int) {
            for i in 0..<nights { night(&s, &rng, close: i % 4 != 0) }
        }
        var (a, rngA) = startedGame(sex: .hen)
        play(&a, &rngA, 40)

        var (b, rngB) = startedGame(sex: .hen)
        play(&b, &rngB, 20)
        var loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(b))
        var loadedRNG = try JSONDecoder().decode(SeededRNG.self, from: JSONEncoder().encode(rngB))
        play(&loaded, &loadedRNG, 20)
        #expect(loaded == a)
    }
}
