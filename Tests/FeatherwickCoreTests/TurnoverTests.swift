import Foundation
import Testing

@testable import FeatherwickCore

// Flock turnover (age-based lay decline + cozy retirement) and the premium-feed coin sink.

struct TurnoverTests {
    /// A calm game with no fox, no broodiness and no floor-egg breakage, so egg counts are clean.
    func layRules() -> Rules {
        var r = Rules.standard
        r.foxChance = 0
        r.layChance = [.spring: 1, .summer: 1, .autumn: 1, .winter: 1]
        r.broodyChance = [:]
        r.floorEggBreakChance = 0
        return r
    }

    /// Replaces the flock with the given revealed hens and gives plenty of room.
    func coopOfHens(_ s: inout GameState, _ hens: [Bird]) {
        s.brooder.removeAll()
        s.perches = 30
        s.nestBoxes = 50
        s.coop = hens
    }

    func eggsLaid(_ ev: [GameEvent], by id: UUID) -> Int {
        ev.count(where: { if case .eggLaid(_, let who) = $0 { who == id } else { false } })
    }

    // MARK: - Age-based decline

    @Test func layAgeFactorFallsWithAgeToAFloorThenZeroAtRetirement() {
        var r = Rules.standard
        r.layDeclineStartDays = 100
        r.layDeclineFloor = 0.4
        r.retirementAgeDays = 300
        #expect(r.layAgeFactor(ageDays: 0) == 1)
        #expect(r.layAgeFactor(ageDays: 100) == 1)  // full until the decline starts
        #expect(r.layAgeFactor(ageDays: 200) < 1)  // falling in the middle
        #expect(r.layAgeFactor(ageDays: 200) > r.layAgeFactor(ageDays: 299))  // monotonically down
        #expect(r.layAgeFactor(ageDays: 299) >= r.layDeclineFloor)  // never below the floor while laying
        #expect(r.layAgeFactor(ageDays: 300) == 0)  // retired: no laying at all
        #expect(r.layAgeFactor(ageDays: 500) == 0)
    }

    @Test func anOldHenLaysLessThanAYoungOne() {
        var r = layRules()
        r.layDeclineStartDays = 20
        r.retirementAgeDays = 400  // neither hen retires during the run
        var (s, rng) = startedGame(sex: .hen, rules: r, seed: 7)
        let young = plainBird(.orpington, .hen, hatchDay: s.day - r.adultAge, rng: &rng)
        let old = plainBird(.orpington, .hen, hatchDay: s.day - 200, rng: &rng)
        coopOfHens(&s, [young, old])

        var ev: [GameEvent] = []
        for _ in 0..<60 { ev += night(&s, &rng) }
        let youngEggs = eggsLaid(ev, by: young.id)
        let oldEggs = eggsLaid(ev, by: old.id)
        #expect(youngEggs > oldEggs)
        #expect(oldEggs > 0)  // she still lays, just less
        #expect(youngEggs >= 55)  // a young hen in her prime lays nearly every day
    }

    // MARK: - Retirement (cozy: she stops laying but keeps her perch)

    @Test func aHenRetiresAtAgeAndStopsLaying() {
        var r = layRules()
        r.retirementAgeDays = 30
        var (s, rng) = startedGame(sex: .hen, rules: r, seed: 3)
        let hen = plainBird(.orpington, .hen, hatchDay: s.day - (r.retirementAgeDays - 1), rng: &rng)
        coopOfHens(&s, [hen])
        #expect(!hen.isRetired(onDay: s.day, rules: r))

        let first = night(&s, &rng)  // she crosses retirement age tonight
        #expect(first.contains(.birdRetired(hen.id)))
        #expect(s.coop.first { $0.id == hen.id }?.isRetired(onDay: s.day, rules: r) == true)
        #expect(s.coop.contains { $0.id == hen.id })  // turnover is gentle: she keeps her perch

        var later: [GameEvent] = []
        for _ in 0..<10 { later += night(&s, &rng) }
        #expect(eggsLaid(later, by: hen.id) == 0)  // a retired hen lays nothing
        #expect(!later.contains(.birdRetired(hen.id)))  // announced once, not every night
    }

    // MARK: - Premium feed

    @Test func premiumFeedRaisesLayOutput() {
        var r = layRules()
        r.layChance = [.spring: 0.5, .summer: 0.5, .autumn: 0.5, .winter: 0.5]  // room to improve
        r.premiumFeedLayBonus = 0.6
        r.layDeclineStartDays = 10_000  // isolate the premium effect from age

        func run(premium: Bool) -> Int {
            var (s, rng) = startedGame(sex: .hen, rules: r, seed: 11)
            let hen = plainBird(.orpington, .hen, hatchDay: s.day - r.adultAge, rng: &rng)
            coopOfHens(&s, [hen])
            s.premiumFeed = 1000
            var ev: [GameEvent] = []
            for _ in 0..<80 {
                _ = Engine.apply(premium ? .feedPremium : .feed, to: &s, using: &rng)
                _ = Engine.apply(.closeCoop, to: &s, using: &rng)
                ev += sleepTonight(&s, &rng)
            }
            return eggsLaid(ev, by: hen.id)
        }
        #expect(run(premium: true) > run(premium: false))
    }

    @Test func buyingPremiumFeedChargesCoinsAndFillsTheBarrel() {
        var (s, rng) = startedGame(sex: .hen, rules: .standard, seed: 1)
        s.coins = 100
        let before = s.coins
        let ev = Engine.apply(.buy(.premiumFeed), to: &s, using: &rng)
        #expect(ev.contains(.boughtPremiumFeed(count: s.rules.premiumFeedBagSize, cost: s.rules.premiumFeedPrice)))
        #expect(s.coins == before - s.rules.premiumFeedPrice)
        #expect(s.premiumFeed == s.rules.premiumFeedBagSize)
    }

    @Test func feedingPremiumConsumesAPortionAndCountsAsFeeding() {
        var (s, rng) = startedGame(sex: .hen, rules: .standard, seed: 1)
        s.premiumFeed = 2
        let ev = Engine.apply(.feedPremium, to: &s, using: &rng)
        #expect(ev.contains { if case .fedPremium = $0 { true } else { false } })
        #expect(s.premiumFeed == 1)
        #expect(s.fedPremiumToday)
        #expect(s.fedToday)  // premium feed covers the day's feeding too
        // Twice in one day is refused.
        #expect(Engine.apply(.feedPremium, to: &s, using: &rng) == [.rejected(.alreadyFedPremium)])
    }

    @Test func feedingPremiumWithAnEmptyBarrelIsRefused() {
        var (s, rng) = startedGame(sex: .hen, rules: .standard, seed: 1)
        s.premiumFeed = 0
        #expect(Engine.apply(.feedPremium, to: &s, using: &rng) == [.rejected(.noPremiumFeed)])
    }
}
