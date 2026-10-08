import Foundation
import Testing

@testable import FeatherwickCore

/// The goal ladder: milestones are awarded once, recorded in the save, and never punish.
struct MilestoneTests {
    @Test func theLadderHasUniqueIds() {
        #expect(Set(Milestones.all.map(\.id)).count == Milestones.all.count)
    }

    @Test func nothingIsAwardedBeforeTheFirstNight() {
        var rng = SeededRNG(seed: 1)
        var s = Engine.newGame(using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        #expect(s.milestonesReached.isEmpty)  // the ladder only ticks at night
        #expect(!Milestones.all.contains { $0.id == "firstEgg" && $0.isReached(s) })
        #expect(!Milestones.all.contains { $0.id == "firstHatch" && $0.isReached(s) })
    }

    @Test func aMilestoneIsAwardedOnceAndRecorded() {
        var (s, _) = startedGame(sex: .hen)
        s.chicksHatched = 1  // satisfy "first hatch"
        let first = Engine.advanceMilestones(&s)
        #expect(first.contains(.milestoneReached("firstHatch")))
        #expect(s.milestonesReached.contains("firstHatch"))
        let again = Engine.advanceMilestones(&s)  // same state, nothing new
        #expect(!again.contains(.milestoneReached("firstHatch")))
    }

    @Test func milestonesAccumulateThroughPlayWithoutRepeating() {
        var (s, rng) = startedGame(sex: .hen)
        var reached: [String] = []
        for _ in 0..<120 {
            for e in night(&s, &rng) {
                if case .milestoneReached(let id) = e { reached.append(id) }
            }
        }
        #expect(Set(reached).count == reached.count)  // no milestone is ever awarded twice
        #expect(Set(reached) == s.milestonesReached)  // what was announced is what was recorded
        #expect(reached.contains("firstEgg"))  // a laying hen gets there in time
        #expect(reached.allSatisfy { id in Milestones.all.contains { $0.id == id } })
    }

    @Test func chocolateAndGreenEggsAreMilestones() {
        var (s, _) = startedGame(sex: .hen)
        s.eggBook.insert(EggBookEntry(colour: .green, speckled: false))
        s.eggBook.insert(EggBookEntry(colour: .chocolate, speckled: false))
        let events = Engine.advanceMilestones(&s)
        #expect(events.contains(.milestoneReached("greenEgg")))
        #expect(events.contains(.milestoneReached("chocolateEgg")))
    }

    @Test func aWhiteEggIsAMilestone() {
        var (s, _) = startedGame(sex: .hen)
        #expect(!Engine.advanceMilestones(&s).contains(.milestoneReached("whiteEgg")))
        s.eggBook.insert(EggBookEntry(colour: .white, speckled: false))
        #expect(Engine.advanceMilestones(&s).contains(.milestoneReached("whiteEgg")))
        #expect(Milestones.all.last?.id == "whiteEgg")  // appended: the ladder order of saves stays
    }
}
