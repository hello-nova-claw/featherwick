import FeatherwickCore
import FeatherwickText
import Foundation
import Testing

/// Every front end shows these words, so no event or screen may crash or come out empty.
struct TextTests {
    /// Plays a simple keeper's day for `days` nights and returns each event with the state after it.
    static func play(seed: UInt64, days: Int) -> [(GameEvent, GameState)] {
        var rng = SeededRNG(seed: seed)
        var s = Engine.newGame(using: &rng)
        var seen: [(GameEvent, GameState)] = []
        func run(_ c: Command) {
            for e in Engine.apply(c, to: &s, using: &rng) { seen.append((e, s)) }
        }
        run(.chooseStarter(index: Int(seed % 3), name: "Pip"))
        for day in 0..<days {
            for b in s.unnamedBirds { run(.rename(b.id, name: NameBook.suggestion(for: b, in: s))) }
            run(.feed)
            run(.collectEggs)
            run(.candle)
            if let b = s.coop.first { run(.pet(b.id)) }
            if s.hasIncubator, s.incubatorClutch == nil { run(.incubate(count: 1)) }
            if s.carton.count > 6 { run(.sellClearEggs) }
            if let story = Engine.storyAwaitingDelivery(s) { run(.deliver(story: story)) }
            if s.coop.count >= s.perches { run(.upgradeCoop) }
            if let b = s.coop.first(where: { $0.stage(onDay: s.day, rules: s.rules) == .adult }) {
                run(.enterShow(b.id))
            }
            if day % 3 != 0 { run(.closeCoop) }  // some nights open: fox and foraging
            run(.passNight)
        }
        return seen
    }

    @Test(arguments: [UInt64(1), 2, 3, 4, 5])
    func everyEventHasWords(seed: UInt64) {
        for (event, state) in Self.play(seed: seed, days: 120) {
            guard let words = eventText(event, state) else { continue }
            #expect(!words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(event)")
        }
    }

    @Test func screensHaveWords() {
        var rng = SeededRNG(seed: 9)
        let start = Engine.newGame(using: &rng)
        #expect(!yardLines(start).isEmpty)  // the starter choice
        guard let (_, s) = Self.play(seed: 9, days: 60).last else {
            Issue.record("no events")
            return
        }
        #expect(!yardLines(s).isEmpty)
        #expect(!journalLines(s).isEmpty)
        #expect(!bookLines(s).isEmpty)
        #expect(!showsLines(s).isEmpty)
        for b in s.ownedBirds {
            #expect(birdLabel(b, s).contains(b.name))
            #expect(!treeLines(b.id, s).isEmpty)
        }
    }

    @Test func everyMilestoneHasATitleAndHint() {
        for m in Milestones.all {
            let t = milestoneText(m.id)
            #expect(t.title != m.id, "\(m.id) has no title")
            #expect(!t.hint.isEmpty)
        }
    }
}
