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
        #expect(!jobsLines(s).isEmpty)
        for b in s.ownedBirds {
            #expect(birdLabel(b, s).contains(b.name))
            #expect(!treeLines(b.id, s).isEmpty)
        }
    }

    @Test func everyJobAndGoalHasWords() {
        guard let (_, s) = Self.play(seed: 2, days: 3).last else {
            Issue.record("no events")
            return
        }
        for kind in JobKind.allCases {
            #expect(!jobText(Job(kind: kind), s).isEmpty)
            #expect(jobText(Job(kind: kind, target: 3, progress: 1), s).hasSuffix("(1 of 3)"))
        }
        for kind in GoalKind.allCases {
            let goal = SeasonGoal(kind: kind, startDay: 0, endDay: 28, target: 3, baseline: 0)
            #expect(!seasonGoalText(goal, s).isEmpty)
            #expect(!goalName(kind).isEmpty)
        }
    }

    /// An unfinished goal is never failed: the new goal's words say the last one can rest.
    @Test func anUnfinishedGoalIsLetGoKindly() {
        guard var (_, s) = Self.play(seed: 3, days: 3).last else {
            Issue.record("no events")
            return
        }
        s.seasonGoal = SeasonGoal(kind: .newFriend, startDay: s.day, endDay: s.day + 20, target: 1, baseline: 0)
        let words = eventText(.seasonGoalSet(.newFriend, previous: .hatchChicks), s) ?? ""
        #expect(words.contains("can rest"))
        #expect(!words.lowercased().contains("fail"))
    }

    @Test func everyMilestoneHasATitleAndHint() {
        for m in Milestones.all {
            let t = milestoneText(m.id)
            #expect(t.title != m.id, "\(m.id) has no title")
            #expect(!t.hint.isEmpty)
        }
    }

    /// 4th, 5th and 6th used to show as "3rd" in the app. Every placing needs its own word.
    @Test func placingsHaveTheirOwnOrdinals() {
        #expect(placingText(0) == "not placed")
        #expect(placingText(1) == "1st")
        #expect(placingText(2) == "2nd")
        #expect(placingText(3) == "3rd")
        #expect(placingText(4) == "4th")
        #expect(placingText(6) == "6th")
        #expect(placingText(11) == "11th")
        #expect(placingText(12) == "12th")
        #expect(placingText(21) == "21st")
        #expect(placingText(22) == "22nd")
    }

    /// The daily special names breed, sex and colour; basic stock never names its breed before purchase.
    @Test func theShopSpecialHasWords() {
        let rare = ShopSpecial(breed: .silkie, sex: .hen, colour: .splash, price: 50, isRare: true)
        #expect(shopSpecialText(rare) == "Splash Silkie pullet — rare! 50 coins")
        let laced = ShopSpecial(breed: .wyandotte, sex: .rooster, colour: .buff, price: 20, isRare: false)
        #expect(shopSpecialText(laced) == "Gold laced Wyandotte cockerel 20 coins")

        var rng = SeededRNG(seed: 4)
        var s = Engine.newGame(using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        s.coins = 1000
        for e in Engine.apply(.buySpecial, to: &s, using: &rng) + Engine.apply(.buySpecial, to: &s, using: &rng) {
            let words = eventText(e, s) ?? ""
            #expect(!words.isEmpty, "\(e)")
        }
    }
}
