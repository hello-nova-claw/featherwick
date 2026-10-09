import Foundation
import Testing

@testable import FeatherwickCore

/// The four village days: dates, the Hatch-along egg and chick, the Longest Day's quiet night, and the
/// Moult Week and Midwinter Lights gifts. See README "The village calendar".
struct VillageDayTests {
    static func game(seed: UInt64 = 5, rules: Rules = calmRules()) -> (GameState, SeededRNG) {
        var r = rules
        r.noteChance = 0
        return startedGame(sex: .hen, rules: r, seed: seed)
    }

    /// A known-fertile egg in the carton, bought from Speckle & Down (they come candled).
    static func buyFertileEgg(_ s: inout GameState, _ rng: inout SeededRNG) {
        s.coins += s.rules.fertileEggPrice
        _ = Engine.apply(.buy(.fertileEgg), to: &s, using: &rng)
    }

    static func hatchAlongDay(_ s: GameState, year: Int = 0) -> Int { s.rules.date(of: .hatchAlong, inYear: year) }

    // MARK: - Dates

    @Test func everyVillageDayFallsInItsSeasonEveryYear() {
        let s = Self.game().0
        for year in 0..<6 {
            for v in VillageDay.allCases {
                let date = s.rules.date(of: v, inYear: year)
                #expect(s.season(onDay: date) == v.season)
                #expect(s.year(onDay: date) == year)
            }
            // The whole Hatch-along week is in spring.
            let start = Self.hatchAlongDay(s, year: year)
            #expect(s.season(onDay: start + s.rules.hatchAlongWeekDays - 1) == .spring)
        }
    }

    // MARK: - Hatch-along

    @Test func theHatchAlongChickComesThreeNightsAfterTheEgg() {
        var (s, rng) = Self.game()
        s.day = Self.hatchAlongDay(s) + 2  // mid-week
        Self.buyFertileEgg(&s, &rng)
        let eggs = s.carton.count
        let ev = Engine.apply(.giveHatchAlongEgg(nil), to: &s, using: &rng)
        let returns = s.day + s.rules.hatchAlongReturnNights
        #expect(ev.contains(.hatchAlongEggGiven(returnsOnDay: returns)))
        #expect(s.carton.count == eggs - 1)
        #expect(s.hatchAlongChickDue)
        let brooder = Set(s.brooder.map(\.id))
        for _ in 1..<s.rules.hatchAlongReturnNights {
            let night = night(&s, &rng)
            #expect(!night.contains { if case .hatchAlongChickArrived = $0 { true } else { false } })
        }
        let last = night(&s, &rng)
        #expect(s.day == returns)
        let arrived = last.compactMap { e -> UUID? in
            if case .hatchAlongChickArrived(let id) = e { id } else { nil }
        }
        #expect(arrived.count == 1)
        let chick = try? #require(s.brooder.first { !brooder.contains($0.id) })
        #expect(chick?.id == arrived.first)
        // A new chick: a surprise starter breed, its sex and breed not yet shown, waiting for a name.
        #expect(chick.map { Breed.starters.contains($0.breed) } == true)
        #expect(chick?.revealed == false && chick?.needsName == true && chick?.hatchDay == s.day)
        #expect(!s.hatchAlongChickDue)
        // One egg a year.
        s.day = Self.hatchAlongDay(s) + 6
        Self.buyFertileEgg(&s, &rng)
        #expect(Engine.apply(.giveHatchAlongEgg(nil), to: &s, using: &rng) == [.rejected(.hatchAlong(.alreadyGiven))])
    }

    @Test func theHatchAlongTakesAnEggOnlyInItsWeek() {
        var (s, rng) = Self.game()
        Self.buyFertileEgg(&s, &rng)
        let start = Self.hatchAlongDay(s)
        s.day = start - 1
        #expect(s.hatchAlongRefusal() == .notThisWeek)
        s.day = start + s.rules.hatchAlongWeekDays
        #expect(s.hatchAlongRefusal() == .notThisWeek)
        s.day = s.rules.date(of: .longestDay, inYear: 0)
        #expect(Engine.apply(.giveHatchAlongEgg(nil), to: &s, using: &rng) == [.rejected(.hatchAlong(.notThisWeek))])
        s.day = start + s.rules.hatchAlongWeekDays - 1
        #expect(s.hatchAlongRefusal() == nil)
        // Next year's week is open again.
        s.day = Self.hatchAlongDay(s, year: 1)
        #expect(s.hatchAlongRefusal() == nil)
    }

    @Test func theHatchAlongNeedsAnEggKnownToBeFertile() {
        var (s, rng) = Self.game()
        s.day = Self.hatchAlongDay(s)
        s.carton = []
        #expect(Engine.apply(.giveHatchAlongEgg(nil), to: &s, using: &rng) == [.rejected(.hatchAlong(.noFertileEgg))])
        Self.buyFertileEgg(&s, &rng)
        var egg = s.carton[0]
        // An egg not yet held to the light is not known to be fertile.
        egg.candled = false
        s.carton[0] = egg
        #expect(s.hatchAlongRefusal(egg: egg.id) == .noFertileEgg)
        s.carton[0].candled = true
        #expect(s.hatchAlongRefusal(egg: UUID()) == .noFertileEgg)
        #expect(
            Engine.apply(.giveHatchAlongEgg(egg.id), to: &s, using: &rng).contains { e in
                if case .hatchAlongEggGiven = e { true } else { false }
            })
        #expect(s.carton.isEmpty)
    }

    @Test func givingAnEggIsTheNeighbourErrand() {
        #expect(Engine.errand(for: .giveHatchAlongEgg(nil)) == .neighbour)
        var (s, rng) = Self.game()
        s.day = Self.hatchAlongDay(s)
        Self.buyFertileEgg(&s, &rng)
        let ev = Engine.apply(.giveHatchAlongEgg(nil), to: &s, using: &rng)
        #expect(ev.contains { if case .slotSpent(.neighbour, _) = $0 { true } else { false } })
    }

    @Test func aHatchAlongChickWithNoRoomWaitsWithHazel() {
        var (s, rng) = Self.game()
        s.day = Self.hatchAlongDay(s) - 1
        night(&s, &rng)  // the starter is grown: she takes her perch
        Self.buyFertileEgg(&s, &rng)
        _ = Engine.apply(.giveHatchAlongEgg(nil), to: &s, using: &rng)
        #expect(!s.coop.isEmpty)
        s.perches = s.perchesUsed  // every perch taken
        var waiting = 0
        for _ in 0..<(s.rules.hatchAlongReturnNights + 4) {
            let ev = night(&s, &rng)
            waiting += ev.count(where: { $0 == .hatchAlongChickWaiting })
            #expect(!ev.contains { if case .hatchAlongChickArrived = $0 { true } else { false } })
        }
        #expect(waiting == 1)  // said once, never nagged
        #expect(s.hatchAlongChickDue && s.boarding.isEmpty && s.rehomed.isEmpty)
        s.perches += 1
        let ev = night(&s, &rng)
        #expect(ev.contains { if case .hatchAlongChickArrived = $0 { true } else { false } })
        #expect(!s.hatchAlongChickDue)
    }

    /// A chick still waiting from last year does not stop this year's egg: the chicks queue, and come
    /// home oldest first as room is made.
    @Test func aWaitingChickDoesNotBlockNextYearsEgg() {
        var (s, rng) = Self.game()
        s.day = Self.hatchAlongDay(s) - 1
        night(&s, &rng)
        Self.buyFertileEgg(&s, &rng)
        _ = Engine.apply(.giveHatchAlongEgg(nil), to: &s, using: &rng)
        let first = s.hatchAlongChickDays
        s.perches = s.perchesUsed  // no room all year
        s.day = Self.hatchAlongDay(s, year: 1) - 1
        night(&s, &rng)
        #expect(s.hatchAlongChickDays == first)
        s.perches = s.perchesUsed
        Self.buyFertileEgg(&s, &rng)
        #expect(s.hatchAlongRefusal() == nil)
        let ev = Engine.apply(.giveHatchAlongEgg(nil), to: &s, using: &rng)
        #expect(ev.contains { if case .hatchAlongEggGiven = $0 { true } else { false } })
        #expect(s.hatchAlongChickDays.count == 2 && s.hatchAlongChickDays.first == first.first)
        var waits = 0
        for _ in 0..<s.rules.hatchAlongReturnNights {
            let night = night(&s, &rng)
            waits += night.count(where: { $0 == .hatchAlongChickWaiting })
            #expect(!night.contains { if case .hatchAlongChickArrived = $0 { true } else { false } })
        }
        #expect(waits == 1)  // only the new chick's notice: last year's was said last year
        // Room for one: the older chick comes first, the newer one keeps waiting.
        s.perches += 1
        let one = night(&s, &rng)
        #expect(one.count(where: { if case .hatchAlongChickArrived = $0 { true } else { false } }) == 1)
        #expect(s.hatchAlongChickDays.count == 1 && s.hatchAlongChickDays.first != first.first)
        s.perches = s.perchesUsed + 1
        s.brooderSize += 1
        let two = night(&s, &rng)
        #expect(two.count(where: { if case .hatchAlongChickArrived = $0 { true } else { false } }) == 1)
        #expect(!s.hatchAlongChickDue)
    }

    @Test func theHatchAlongChickIsTheSameForTheSameGame() {
        func chick() -> Bird? {
            var (s, rng) = Self.game(seed: 8)
            s.day = Self.hatchAlongDay(s)
            Self.buyFertileEgg(&s, &rng)
            _ = Engine.apply(.giveHatchAlongEgg(nil), to: &s, using: &rng)
            for _ in 0..<s.rules.hatchAlongReturnNights { night(&s, &rng) }
            return s.brooder.last
        }
        #expect(chick() != nil)
        #expect(chick() == chick())
    }

    // MARK: - Longest Day

    @Test func theFoxStaysHomeOnTheLongestDayEvenWithTheDoorOpen() {
        var rules = calmRules()
        rules.foxChance = 1
        rules.fleeChance = 1
        var (s, rng) = Self.game(rules: rules)
        s.day = s.rules.date(of: .longestDay, inYear: 1) - 1
        night(&s, &rng)  // door shut; the starter is grown and takes her perch
        #expect(!s.coop.isEmpty && s.foxStaysHome)
        let ev = night(&s, &rng, close: false)
        #expect(ev.contains(.quietNight))
        #expect(!ev.contains { if case .foxVisited = $0 { true } else { false } })
        #expect(ev.contains { if case .birdsForaged = $0 { true } else { false } })
        // The next night is any other night: the fox comes to an open door.
        #expect(!s.foxStaysHome)
        let next = night(&s, &rng, close: false)
        #expect(next.contains { if case .foxVisited = $0 { true } else { false } })
    }

    // MARK: - Moult Week and Midwinter Lights

    @Test func moultTreatsAndMidwinterCoinsComeOnceAYearEveryYear() {
        var (s, rng) = Self.game()
        var treats: [Int: Int] = [:]
        var coins: [Int: Int] = [:]
        var notes: [Int: Int] = [:]
        let end = s.rules.date(of: .midwinterLights, inYear: 1) + 2
        while s.day < end {
            let treatsBefore = s.treats
            let coinsBefore = s.coins
            for e in night(&s, &rng) {
                let year = s.year(onDay: s.day)
                switch e {
                case .villageDayGift(.moultWeek, let c, let t):
                    #expect(c == 0 && t == s.rules.moultWeekTreats)
                    #expect(s.treats == treatsBefore + t)
                    treats[year, default: 0] += 1
                case .villageDayGift(.midwinterLights, let c, let t):
                    #expect(t == 0 && c == s.rules.midwinterCoins)
                    #expect(s.coins == coinsBefore + c)
                    coins[year, default: 0] += 1
                case .noteArrived(.teddy, let id):
                    #expect(s.villageDay(onDay: s.day) == .midwinterLights)
                    #expect(id == VillageDay.midwinterNote(year: year))
                    notes[year, default: 0] += 1
                default: break
                }
            }
        }
        #expect(treats == [0: 1, 1: 1])
        #expect(coins == [0: 1, 1: 1])
        #expect(notes == [0: 1, 1: 1])
        #expect(s.notesSeen.isSuperset(of: [VillageDay.midwinterNote(year: 0), VillageDay.midwinterNote(year: 1)]))
    }

    @Test func everyVillageDayHasItsSceneWithTheYear() {
        var (s, rng) = Self.game()
        for year in 0..<2 {
            for v in VillageDay.allCases {
                s.day = s.rules.date(of: v, inYear: year) - 1
                let ev = night(&s, &rng)
                #expect(ev.contains(.villageDayScene(v, year: year)))
            }
        }
    }

    // MARK: - Saves

    @Test func anOldSaveLoadsAndHearsOfTheNextVillageDay() throws {
        var game = try SaveFormat.decode(SaveFormatTests.fixture("save-v0"))
        #expect(game.state.hatchAlongYears.isEmpty && game.state.hatchAlongChickDays.isEmpty)
        #expect(game.state.rules.hatchAlongWeekDays == Rules.standard.hatchAlongWeekDays)
        #expect(game.state.rules.hatchAlongReturnNights == Rules.standard.hatchAlongReturnNights)
        #expect(game.state.rules.moultWeekTreats == Rules.standard.moultWeekTreats)
        #expect(game.state.rules.midwinterCoins == Rules.standard.midwinterCoins)
        let next = game.state.nextVillageDay
        var heard = false
        for _ in 0..<(game.state.rules.daysPerSeason * 4 + 1) where !heard {
            for e in sleepTonight(&game.state, &game.rng) {
                if case .villageDayComing(let v, _) = e {
                    heard = true
                    #expect(game.state.villageDay(onDay: game.state.day + game.state.rules.villageDayNoticeDays) == v)
                }
            }
        }
        #expect(heard)
        #expect(next.date >= 0)
    }

    @Test func hatchAlongStateSurvivesASave() throws {
        var (s, rng) = Self.game()
        s.day = Self.hatchAlongDay(s)
        Self.buyFertileEgg(&s, &rng)
        _ = Engine.apply(.giveHatchAlongEgg(nil), to: &s, using: &rng)
        let loaded = try SaveFormat.decode(SaveFormat.encode(SaveGame(state: s, rng: rng)))
        #expect(loaded.state.hatchAlongChickDays == s.hatchAlongChickDays)
        #expect(loaded.state.hatchAlongYears == [0])
    }
}
