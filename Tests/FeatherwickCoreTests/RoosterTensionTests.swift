import Foundation
import Testing
@testable import FeatherwickCore

struct RoosterTensionTests {
    func flock(roosters: Int, hens: Int, rules: Rules) -> (GameState, SeededRNG) {
        var (s, rng) = startedGame(sex: .hen, rules: rules)
        s.brooder.removeAll()
        s.perches = 30
        let born = s.day - rules.adultAge
        s.coop = (0..<roosters).map { _ in plainBird(.orpington, .rooster, hatchDay: born, rng: &rng) }
            + (0..<hens).map { _ in plainBird(.araucana, .hen, hatchDay: born, rng: &rng) }
        return (s, rng)
    }

    @Test(arguments: [
        (roosters: 1, hens: 0, extra: 0),
        (roosters: 1, hens: 1, extra: 0),   // the rooster start: always fine
        (roosters: 1, hens: 12, extra: 0),  // one rooster is always fine
        (roosters: 2, hens: 1, extra: 1),
        (roosters: 2, hens: 5, extra: 1),
        (roosters: 2, hens: 6, extra: 0),   // 6 hens allow 2 roosters
        (roosters: 3, hens: 10, extra: 1),
        (roosters: 4, hens: 2, extra: 3),
    ])
    func extraRoosterCount(_ c: (roosters: Int, hens: Int, extra: Int)) {
        let (s, _) = flock(roosters: c.roosters, hens: c.hens, rules: calmRules())
        #expect(s.rules.extraRoosters(inCoop: s.coop, onDay: s.day) == c.extra)
    }

    @Test func chicksDoNotCountButCockerelsDo() {
        let r = calmRules()
        var (s, rng) = flock(roosters: 1, hens: 1, rules: r)
        s.coop.append(plainBird(.wyandotte, .rooster, hatchDay: s.day, rng: &rng))  // a chick
        #expect(r.extraRoosters(inCoop: s.coop, onDay: s.day) == 0)
        s.coop.append(plainBird(.wyandotte, .rooster, hatchDay: s.day - r.growerAge, rng: &rng))  // a cockerel
        #expect(r.extraRoosters(inCoop: s.coop, onDay: s.day) == 1)
    }

    @Test func tooManyRoostersUnsettleTheHens() {
        var r = calmRules()
        r.broodyChance = [:]
        r.extraRoosterLayPenalty = 0.5
        var (s, rng) = flock(roosters: 3, hens: 1, rules: r)  // 2 extra: laying chance 1 - 2 x 0.5 = 0
        var ev: [GameEvent] = []
        for _ in 0..<10 { ev += night(&s, &rng) }
        #expect(ev.contains(.roostersSquabbling(extra: 2)))
        #expect(!ev.contains { if case .eggLaid = $0 { true } else { false } })
        #expect(s.ownedBirds.count == 4)  // nobody hurt, nobody gone
    }

    @Test func theRoosterNudgeIsShownOnce() {
        var r = calmRules()
        r.broodyChance = [:]
        var (s, rng) = flock(roosters: 3, hens: 2, rules: r)  // 1 extra: tension flagged every night
        var ev: [GameEvent] = []
        for _ in 0..<10 { ev += night(&s, &rng) }
        let squabbles = ev.filter { if case .roostersSquabbling = $0 { true } else { false } }.count
        let nudges = ev.filter { $0 == .roosterAdvice }.count
        #expect(squabbles > 1)   // the problem keeps being flagged
        #expect(nudges == 1)     // but the how-to-fix tip shows only once
        #expect(s.roosterAdviceGiven)
    }

    @Test func rehomingTheExtraRoosterSettlesThem() {
        var r = calmRules()
        r.broodyChance = [:]
        r.extraRoosterLayPenalty = 1
        var (s, rng) = flock(roosters: 2, hens: 1, rules: r)
        #expect(!night(&s, &rng).contains { if case .eggLaid = $0 { true } else { false } })
        _ = Engine.apply(.rehome(s.coop[0].id), to: &s, using: &rng)
        let ev = night(&s, &rng)
        #expect(!ev.contains { if case .roostersSquabbling = $0 { true } else { false } })
        #expect(ev.contains { if case .eggLaid = $0 { true } else { false } })
    }

    @Test func roosterOnlyFlocksMakeNoSquabbleMessageAboutHens() {
        var (s, rng) = flock(roosters: 3, hens: 0, rules: calmRules())
        #expect(!night(&s, &rng).contains { if case .roostersSquabbling = $0 { true } else { false } })
    }
}
