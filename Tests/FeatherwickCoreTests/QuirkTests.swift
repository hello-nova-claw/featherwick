import Foundation
import Testing

@testable import FeatherwickCore

struct QuirkTests {
    /// Many birds of both sexes, with fresh IDs.
    static func birds(_ n: Int = 400, revealed: Bool = true) -> [Bird] {
        var rng = SeededRNG(seed: 0x5155_4952)
        return (0..<n).map { i in
            var b = plainBird(.orpington, i.isMultiple(of: 2) ? .hen : .rooster, rng: &rng)
            b.revealed = revealed
            return b
        }
    }

    static let state = GameState(rules: .standard, phase: .playing)

    @Test func everyBirdHasTwoDifferentNeutralQuirks() {
        for bird in Self.birds() {
            let neutral = Quirks.of(bird, in: Self.state).filter { $0.sex == nil }
            #expect(neutral.count == 2)
            #expect(Set(neutral).count == 2)
        }
    }

    @Test func quirksComeFromTheIDAlone() throws {
        let birds = Self.birds(50)
        let first = birds.map { Quirks.of($0, in: Self.state) }
        // The same bird again, and the same bird after a save and load: the same quirks.
        #expect(birds.map { Quirks.of($0, in: Self.state) } == first)
        let reloaded = try JSONDecoder().decode([Bird].self, from: JSONEncoder().encode(birds))
        #expect(reloaded.map { Quirks.of($0, in: Self.state) } == first)
        // Different birds get different quirks: the pick is not one fixed pair.
        #expect(Set(first.map { $0.prefix(2).map(\.rawValue) }).count > 10)
    }

    @Test func aChickWithItsSexHiddenHasOnlyNeutralQuirks() {
        for bird in Self.birds(revealed: false) {
            let quirks = Quirks.of(bird, in: Self.state)
            #expect(quirks.count == 2)
            #expect(quirks.allSatisfy { $0.sex == nil })
        }
    }

    @Test func aSexQuirkNeverGoesToTheWrongSex() {
        var withThird = 0
        for bird in Self.birds() {
            let quirks = Quirks.of(bird, in: Self.state)
            #expect(quirks.count <= 3)
            for q in quirks where q.sex != nil {
                #expect(q.sex == bird.sex)
                withThird += 1
            }
        }
        // About half of grown birds gain one: neither none nor all.
        #expect(withThird > 120 && withThird < 280)
    }

    @Test func noBirdGainsASexQuirkWhenTheShareIsNone() {
        var s = Self.state
        s.rules.quirkSexShare = 0
        #expect(Self.birds().allSatisfy { Quirks.of($0, in: s).count == 2 })
    }

    @Test func neutralQuirksStayTheSameWhenTheSexShows() {
        for var bird in Self.birds(revealed: false) {
            let before = Quirks.of(bird, in: Self.state)
            bird.revealed = true
            let after = Quirks.of(bird, in: Self.state)
            #expect(Array(after.prefix(2)) == before)
        }
    }

    /// Read from the table, not counted, so an appended quirk breaks no test.
    @Test func theSetsAreAsDesigned() {
        // Every quirk is in exactly one set: neutral, hens only or roosters only.
        let sets = Quirk.neutral + Quirk.only(.hen) + Quirk.only(.rooster)
        #expect(sets.count == Quirk.allCases.count && Set(sets) == Set(Quirk.allCases))
        #expect(Set(Quirk.only(.hen)).isSuperset(of: [.singsWhenLaying, .broodsOverGolfBalls]))
        #expect(Quirk.only(.rooster).contains(.runsAtTheFox))
        // Enough neutral quirks for every bird to have its own pair.
        #expect(Quirk.neutral.count > Quirks.neutralCount)
        // Raw values are what any later save or table keys on: they must not change.
        #expect(Quirk.dustBathLover.rawValue == "dustBathLover")
        #expect(Quirk.alwaysLastToBed.rawValue == "alwaysLastToBed")
    }

    /// A save made before quirks had no `quirkSexShare`: it loads with the starting share.
    @Test func anOldSaveGetsTheStartingQuirkShare() throws {
        let data = try SaveFormatTests.fixture("save-v0")
        #expect(!String(decoding: data, as: UTF8.self).contains("quirkSexShare"))
        let game = try SaveFormat.decode(data)
        #expect(game.state.rules.quirkSexShare == 0.5)
    }

    // MARK: - No effect on the game

    /// One seeded game played by a simple keeper. With `look`, every bird's quirks are read
    /// after every command. Returns the events, the final state and the RNG.
    static func play(seed: UInt64, days: Int, look: Bool) -> (events: [GameEvent], state: GameState, rng: SeededRNG) {
        var rng = SeededRNG(seed: seed)
        var s = Engine.newGame(using: &rng)
        var events: [GameEvent] = []
        func run(_ c: Command) {
            events += Engine.apply(c, to: &s, using: &rng)
            if look { for bird in s.ownedBirds { _ = Quirks.of(bird, in: s) } }
        }
        run(.chooseStarter(index: 0, name: "Quill"))
        for _ in 0..<days {
            run(.feed)
            run(.collectEggs)
            if !s.hasIncubator, s.coins >= s.rules.incubatorPrice { run(.buyIncubator) }
            if s.hasIncubator, s.incubatorClutch == nil, !s.carton.isEmpty { run(.incubate(count: 2)) }
            run(.closeCoop)
            events += Engine.restUntilEvening(&s, using: &rng)
            run(.passNight)
        }
        return (events, s, rng)
    }

    /// The state is compared as a value, not as JSON bytes: JSON writes sets and enum-keyed
    /// dictionaries in hash order, which differs between two equal states (see `SaveFormatTests`).
    @Test func readingQuirksChangesNothingInTheGame() {
        let plain = Self.play(seed: 2026, days: 60, look: false)
        let looked = Self.play(seed: 2026, days: 60, look: true)
        #expect(plain.events == looked.events)
        #expect(plain.state == looked.state)
        #expect(plain.rng == looked.rng)
        // The game got as far as a sex reveal, so the third quirk was read too.
        #expect(plain.events.contains { if case .revealed = $0 { true } else { false } })
        #expect(plain.state.ownedBirds.contains { $0.revealed })
    }

    @Test func aPlayedFlockIsTheSameWithQuirksRead() {
        let s = Simulation.play(seed: 7, days: 40)
        for bird in s.ownedBirds { _ = Quirks.of(bird, in: s) }
        #expect(Simulation.play(seed: 7, days: 40) == s)
    }
}
