import Foundation
import Testing

@testable import FeatherwickCore

/// The morning report (MorningReport.swift): a night's events sorted into groups, none dropped.
struct MorningReportTests {
    /// How many times each event appears. Events are Hashable, not Comparable, so compare them as counts.
    static func counts(_ events: [GameEvent]) -> [GameEvent: Int] {
        events.reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }

    /// A seeded new game with the early game on, played for `days` by a simple keeper: feed, collect, sell a
    /// full carton, set an egg when there is room, and leave the door open every fifth night. Returns each
    /// night's events with the state after it.
    static func playNights(seed: UInt64, days: Int) -> [(events: [GameEvent], state: GameState)] {
        var rng = SeededRNG(seed: seed)
        var s = Engine.newGame(using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        var nights: [(events: [GameEvent], state: GameState)] = []
        for d in 0..<days {
            _ = Engine.apply(.feed, to: &s, using: &rng)
            if !s.nest.isEmpty { _ = Engine.apply(.collectEggs, to: &s, using: &rng) }
            if s.carton.count >= s.cartonCapacity { _ = Engine.apply(.sellEggs, to: &s, using: &rng) }
            _ = Engine.apply(.incubate(count: 1), to: &s, using: &rng)  // a "no" is fine
            if d % 5 != 4 { _ = Engine.apply(.closeCoop, to: &s, using: &rng) }
            let ev = Engine.apply(.passNight, to: &s, using: &rng)
            nights.append((ev, s))
        }
        return nights
    }

    @Test func everyNightEventLandsInExactlyOneGroup() {
        var seen: Set<MorningReport.Group> = []
        for seed: UInt64 in [1, 7, 2026] {
            for night in Self.playNights(seed: seed, days: 120) {
                let report = MorningReport.from(events: night.events, state: night.state)
                // Nothing dropped, nothing doubled.
                #expect(Self.counts(report.allEvents) == Self.counts(night.events))
                for group in report.shownGroups {
                    #expect(report.events(in: group).allSatisfy { MorningReport.group(of: $0) == group })
                }
                #expect(report.day == night.state.day && report.season == night.state.season)
                seen.formUnion(report.shownGroups)
            }
        }
        // Real nights fill the main groups.
        for group in [MorningReport.Group.morning, .hatched, .fox, .neighbour, .newStock, .shows, .jobs, .eggs] {
            #expect(seen.contains(group), "no night filled \(group)")
        }
    }

    @Test func aHatchLandsInHatched() {
        var (s, rng) = startedGame(sex: .hen)
        s.coins = 100
        _ = Engine.apply(.buy(.fertileEgg), to: &s, using: &rng)
        _ = Engine.apply(.incubate(count: 1), to: &s, using: &rng)
        let ev = night(&s, &rng)
        let report = MorningReport.from(events: ev, state: s)
        let hatched = report.events(in: .hatched)
        #expect(hatched.count == 1)
        #expect(hatched.contains { if case .chicksHatched(let ids, nil) = $0 { ids.count == 1 } else { false } })
        #expect(report.shownGroups.first == .morning)
    }

    @Test func theFoxScaresAndTheBirdsComeHome() {
        var r = Rules.standard
        r.foxChance = 1
        var (s, rng) = startedGame(sex: .hen, rules: r)
        // Grow the starter so she lives in the coop, then leave the door open.
        while s.coop.isEmpty { night(&s, &rng) }
        let fox = night(&s, &rng, close: false)
        let report = MorningReport.from(events: fox, state: s)
        #expect(report.events(in: .fox).contains { if case .foxVisited = $0 { true } else { false } })
        // Cozy: nobody is hurt. She comes home.
        s.rules.foxChance = 0
        var home: [GameEvent] = []
        while !s.lost.isEmpty { home += night(&s, &rng) }
        let back = MorningReport.from(events: home, state: s)
        #expect(back.events(in: .cameHome).contains { if case .birdReturned = $0 { true } else { false } })
    }

    @Test func emptyGroupsAreNotShown() {
        let s = startedGame(sex: .hen).0
        let report = MorningReport.from(events: [.quietNight, .dayStarted(day: 4, season: .summer)], state: s)
        #expect(report.shownGroups == [.morning])
        #expect(report.day == 4 && report.season == .summer)
        #expect(report.events(in: .hatched).isEmpty)
    }
}
