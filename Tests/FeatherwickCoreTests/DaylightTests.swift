import Foundation
import Testing

@testable import FeatherwickCore

/// Daylight (Daylight.swift): a few slots a day for errands, care always free, sleep once the light is gone.
struct DaylightTests {
    /// A started game with the daylight lesson known, plenty of coins, and two adult hens in the coop.
    static func game(seed: UInt64 = 1) -> (GameState, SeededRNG) {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules(), seed: seed)
        s.coins = 1000
        s.coop.append(adult(.orpington, .hen, day: s.day, rules: s.rules, rng: &rng))
        s.coop.append(adult(.wyandotte, .hen, day: s.day, rules: s.rules, rng: &rng))
        return (s, rng)
    }

    static func rejections(_ ev: [GameEvent]) -> [Rejection] {
        ev.compactMap { if case .rejected(let r) = $0 { r } else { nil } }
    }

    static func slotsSpent(_ ev: [GameEvent]) -> [GameEvent] {
        ev.filter { if case .slotSpent = $0 { true } else { false } }
    }

    // MARK: - Errands

    @Test func aFourthErrandKindWaitsForTheMorning() {
        var (s, rng) = Self.game()
        #expect(s.isOpen(.daylight))
        #expect(s.slotsToday(rules: s.rules) == 3 && s.slotsLeft == 3 && s.timeOfDay == .morning)

        var ev = Engine.apply(.buy(.treats), to: &s, using: &rng)
        #expect(ev.last == .slotSpent(.village, left: 2))
        #expect(s.timeOfDay == .afternoon)
        ev = Engine.apply(.rehome(s.coop[0].id), to: &s, using: &rng)
        #expect(ev.last == .slotSpent(.neighbour, left: 1))
        #expect(s.timeOfDay == .evening)
        s.carton.append(clearEgg(mother: s.coop[0], day: s.day, rng: &rng))
        ev = Engine.apply(.candle, to: &s, using: &rng)
        #expect(ev.last == .slotSpent(.candling, left: 0))
        #expect(s.errandsToday == [.village, .neighbour, .candling])

        let before = s
        #expect(Engine.apply(.upgradeCoop, to: &s, using: &rng) == [.rejected(.noTimeLeft(.building))])
        #expect(s == before)
        // Every errand kind not yet run today is refused the same way, with no change.
        let showBird = s.coop[0].id
        #expect(Engine.apply(.enterShow(showBird), to: &s, using: &rng) == [.rejected(.noTimeLeft(.showDesk))])
        #expect(Engine.apply(.buyIncubator, to: &s, using: &rng) != [.rejected(.noTimeLeft(.village))])
        #expect(Engine.daylightRefusal(for: .upgradeCoop, in: s) == .noTimeLeft(.building))
    }

    @Test func moreOfTheSameErrandIsFree() {
        var (s, rng) = Self.game()
        let first = Engine.apply(.buy(.treats), to: &s, using: &rng)
        let second = Engine.apply(.buy(.treats), to: &s, using: &rng)
        #expect(Self.slotsSpent(first) == [.slotSpent(.village, left: 2)])
        #expect(Self.slotsSpent(second).isEmpty)
        #expect(s.slotsUsed == 1 && s.treats == 2 * s.rules.treatBagSize)

        // Even with no daylight left, the shop is still open to a keeper already in the village.
        _ = Engine.apply(.rest, to: &s, using: &rng)
        _ = Engine.apply(.rest, to: &s, using: &rng)
        #expect(s.slotsLeft == 0)
        #expect(Self.rejections(Engine.apply(.buy(.premiumFeed), to: &s, using: &rng)).isEmpty)
        #expect(s.slotsUsed == 3)
    }

    @Test func aRefusedErrandSpendsNoDaylight() {
        var (s, rng) = Self.game()
        s.coins = 0
        #expect(
            Engine.apply(.buy(.pullet), to: &s, using: &rng)
                == [.rejected(.notEnoughCoins(needed: s.rules.pulletPrice, have: 0))])
        #expect(Engine.apply(.candle, to: &s, using: &rng) == [.rejected(.cartonEmpty)])
        #expect(s.slotsUsed == 0 && s.errandsToday.isEmpty)
    }

    @Test func careIsNeverRefusedForTime() {
        var (s, rng) = Self.game()
        for _ in 0..<3 { _ = Engine.apply(.rest, to: &s, using: &rng) }
        #expect(s.slotsLeft == 0)
        let hen = s.coop[0]
        s.nest.append(clearEgg(mother: hen, day: s.day, rng: &rng))
        s.nest.append(clearEgg(mother: hen, day: s.day, rng: &rng))
        s.treats = 1
        var ev: [GameEvent] = []
        let care: [Command] = [
            .feed, .collectEggs, .pet(hen.id), .giveTreat(hen.id), .sellChosenEggs([s.nest[0].id]), .sellEggs,
            .rename(hen.id, name: "Dot"), .closeCoop,
        ]
        for c in care { ev += Engine.apply(c, to: &s, using: &rng) }
        #expect(Self.rejections(ev).isEmpty)
        #expect(Self.slotsSpent(ev).isEmpty)
        #expect(s.slotsUsed == 3)
        // Setting eggs and the breeding pen are free too.
        for c in [Command.incubate(count: 1), .sit(hen: hen.id, count: 1), .penBird(hen.id)] {
            #expect(Engine.errand(for: c) == nil)
            #expect(Engine.daylightRefusal(for: c, in: s) == nil)
        }
    }

    // MARK: - Rest and sleep

    @Test func sleepWaitsForEvening() {
        var (s, rng) = Self.game()
        let day = s.day
        #expect(Engine.apply(.passNight, to: &s, using: &rng) == [.rejected(.notEveningYet(slotsLeft: 3))])
        _ = Engine.apply(.buy(.treats), to: &s, using: &rng)
        #expect(Engine.apply(.passNight, to: &s, using: &rng) == [.rejected(.notEveningYet(slotsLeft: 2))])
        _ = Engine.apply(.rest, to: &s, using: &rng)
        #expect(Engine.apply(.passNight, to: &s, using: &rng) == [.rejected(.notEveningYet(slotsLeft: 1))])
        #expect(s.day == day)
    }

    @Test func restSpendsOneSlotAndNothingElse() {
        var (s, rng) = Self.game()
        let before = s
        let rngBefore = rng
        let ev = Engine.apply(.rest, to: &s, using: &rng)
        #expect(ev == [.rested(.morning), .slotSpent(nil, left: 2)])
        #expect(s.slotsUsed == before.slotsUsed + 1)
        #expect(rng == rngBefore)  // a rest draws no randomness
        var same = s
        same.slotsUsed = before.slotsUsed
        #expect(same == before)
    }

    @Test func threeRestsThenBed() {
        var (s, rng) = Self.game()
        var times: [TimeOfDay] = []
        for _ in 0..<3 {
            for case .rested(let t) in Engine.apply(.rest, to: &s, using: &rng) { times.append(t) }
        }
        #expect(times == [.morning, .afternoon, .evening])
        let tired = s
        #expect(Engine.apply(.rest, to: &s, using: &rng) == [.rejected(.timeForBed)])
        #expect(s == tired)
        let day = s.day
        let ev = Engine.apply(.passNight, to: &s, using: &rng)
        #expect(s.day == day + 1)
        #expect(ev.contains(.dayStarted(day: s.day, season: s.season)))
    }

    @Test func slotsResetOvernight() {
        var (s, rng) = Self.game()
        _ = Engine.apply(.buy(.treats), to: &s, using: &rng)
        _ = Engine.apply(.rehome(s.coop[0].id), to: &s, using: &rng)
        _ = Engine.apply(.rest, to: &s, using: &rng)
        #expect(s.slotsLeft == 0)
        _ = Engine.apply(.passNight, to: &s, using: &rng)
        #expect(s.slotsUsed == 0 && s.errandsToday.isEmpty)
        #expect(s.slotsLeft == 3 && s.timeOfDay == .morning)
    }

    // MARK: - Longer days

    @Test func aBiggerCoopAndALapChickenGiveMoreDaylight() throws {
        var (s, rng) = Self.game()
        #expect(s.slotsToday(rules: s.rules) == 3)
        let ev = Engine.apply(.upgradeCoop, to: &s, using: &rng)
        #expect(ev.last == .slotSpent(.building, left: 3))
        #expect(s.slotsToday(rules: s.rules) == 4)

        s.coop[0] = s.coop[0].withTameness(1)
        try #require(s.coop[0].friendliness == .lapChicken)
        #expect(s.slotsToday(rules: s.rules) == 5)
        // A second lap chicken adds nothing more.
        s.coop[1] = s.coop[1].withTameness(1)
        #expect(s.slotsToday(rules: s.rules) == 5)

        // Never more than the cap, whatever the bonuses.
        var rules = s.rules
        rules.daySlots = 9
        #expect(s.slotsToday(rules: rules) == s.rules.maxDaySlots)
        #expect(s.rules.maxDaySlots == 5)

        // A lap chicken away from home does not count, and slots left never go below 0.
        s.slotsUsed = 5
        s.lost.append(LostBird(bird: s.coop.removeFirst(), returnsOnDay: s.day + 3))
        s.lost.append(LostBird(bird: s.coop.removeFirst(), returnsOnDay: s.day + 3))
        #expect(s.slotsToday(rules: s.rules) == 4)
        #expect(s.slotsLeft == 0)
    }

    // MARK: - Early game

    @Test func beforeTheLessonNothingWaitsForDaylight() {
        var (s, rng) = EarlyGameTests.newKeeper()
        let lessonDay = s.rules.introductionDay(of: .daylight)
        #expect(lessonDay == 9)
        EarlyGameTests.play(until: lessonDay - 1, &s, &rng)
        #expect(!s.isOpen(.daylight))
        #expect(Engine.apply(.rest, to: &s, using: &rng) == [.rejected(.notYet(.daylight))])

        // Every errand kind, many times over: none is refused for time and no slot is spent.
        s.introduced.formUnion(Feature.allCases.filter { $0 != .daylight })
        s.canCandle = true
        s.coop.append(adult(.orpington, .hen, day: s.day, rules: s.rules, rng: &rng))
        s.coop.append(adult(.wyandotte, .hen, day: s.day, rules: s.rules, rng: &rng))
        s.carton.append(clearEgg(mother: s.coop[0], day: s.day, rng: &rng))
        var ev: [GameEvent] = []
        let errands: [Command] = [
            .buy(.treats), .candle, .upgradeCoop, .enterShow(s.coop[0].id), .rehome(s.coop[1].id), .buy(.premiumFeed),
            .buyIncubator, .upgradeCoop,
        ]
        for c in errands { ev += Engine.apply(c, to: &s, using: &rng) }
        #expect(Self.rejections(ev).isEmpty)
        #expect(Self.slotsSpent(ev).isEmpty)
        #expect(s.slotsUsed == 0 && s.errandsToday.isEmpty)

        // Sleep is free, and the lesson comes in the morning. From then on, sleep waits for evening.
        let night = Engine.apply(.passNight, to: &s, using: &rng)
        #expect(s.day == lessonDay)
        #expect(night.contains(.introduced(.daylight)))
        #expect(s.isOpen(.daylight))
        #expect(
            Self.rejections(Engine.apply(.passNight, to: &s, using: &rng)).first
                == .notEveningYet(slotsLeft: s.slotsLeft))
    }

    @Test func aGameWithoutTheEarlyGameKnowsTheLesson() {
        var rng = SeededRNG(seed: 4)
        #expect(Engine.newGame(earlyGame: false, using: &rng).isOpen(.daylight))
        #expect(Feature.breedBook < Feature.daylight && Feature.daylight < Feature.birdShop)
    }

    // MARK: - Saves and determinism

    @Test func anOldSaveLoadsWithAFreshDay() throws {
        let s = try SaveFormat.decode(SaveFormatTests.fixture("save-v0")).state
        #expect(s.slotsUsed == 0)
        #expect(s.errandsToday.isEmpty)
        #expect(s.rules.daySlots == 3)
        #expect(s.rules.slotBonusCoopUpgraded == 1 && s.rules.slotBonusLapChicken == 1)
        #expect(s.rules.maxDaySlots == 5)
        #expect(s.rules.introductionDay(of: .daylight) == 9)
    }

    @Test func aSaveKeepsTodaysDaylight() throws {
        var (s, rng) = Self.game()
        _ = Engine.apply(.buy(.treats), to: &s, using: &rng)
        let loaded = try SaveFormat.decode(SaveFormat.encode(SaveGame(state: s, rng: rng))).state
        #expect(loaded.slotsUsed == 1 && loaded.errandsToday == [.village])
    }

    @Test func theSameSeedPlaysTheSameGame() {
        func play() -> (GameState, SeededRNG) {
            var rng = SeededRNG(seed: 2026)
            var s = Engine.newGame(using: &rng)
            _ = Engine.apply(.chooseStarter(index: 1, name: "Pip"), to: &s, using: &rng)
            for _ in 0..<40 {
                for c in [Command.feed, .collectEggs, .buy(.treats), .candle, .sellClearEggs, .closeCoop] {
                    _ = Engine.apply(c, to: &s, using: &rng)
                }
                Engine.restUntilEvening(&s, using: &rng)
                _ = Engine.apply(.passNight, to: &s, using: &rng)
            }
            return (s, rng)
        }
        let (a, rngA) = play()
        let (b, rngB) = play()
        #expect(a.day == 40)
        #expect(a == b)
        #expect(rngA == rngB)
    }
}
