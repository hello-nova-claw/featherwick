// The goal ladder: small, always-visible milestones that give the sandbox a direction.
//
// Cozy rule: a milestone is only ever a goal REACHED, never a goal failed. There are no deadlines
// and nothing is lost by not reaching one — the ladder is a gentle "here's a next thing to aim
// for", not a score you can drop. Survival is free (see the engine's invariants); the ladder is
// about thriving.
//
// As everywhere, the engine holds only the id and the test; the words that name and describe each
// goal live in FeatherwickText (`milestoneText`), keyed by id. Only the set of reached ids is saved
// (GameState).
//
// To add one: append a `Milestone` to `Milestones.all` (list order is the ladder order), then its
// words in `milestoneText`. Milestones are checked each night, after the day's events have settled.

public struct Milestone: Identifiable, Sendable {
    public let id: String
    /// False while no breed in the game can make this goal: the journal then says it waits for a new
    /// breed, and gives no hint to chase. It is still reached if the keeper gets there anyway.
    public let isAvailable: Bool
    /// True once the keeper has reached this goal, judged from the whole game state.
    public let isReached: @Sendable (GameState) -> Bool

    public init(id: String, isAvailable: Bool = true, isReached: @escaping @Sendable (GameState) -> Bool) {
        self.id = id
        self.isAvailable = isAvailable
        self.isReached = isReached
    }
}

public enum Milestones {
    /// The ladder, in order: early and easy first, then breeding and taming, then the show ring.
    /// Later goals are appended at the end.
    /// Every test reads only existing, player-visible state, so no milestone can leak hidden genes.
    /// A goal no in-game breed can make yet is marked `isAvailable: false` (chocolate and white eggs).
    public static let all: [Milestone] = [
        Milestone(id: "firstEgg") { !$0.eggBook.isEmpty },
        Milestone(id: "firstHatch") { $0.chicksHatched >= 1 },
        Milestone(id: "firstFriend") { s in s.ownBirds.contains { $0.friendliness >= .friendly } },
        Milestone(id: "growingFlock") { $0.ownBirds.count >= 8 },
        Milestone(id: "blueEgg") { s in s.eggBook.contains { $0.colour == .blue } },
        Milestone(id: "oliveEgg") { s in s.eggBook.contains { $0.colour == .olive } },
        Milestone(id: "speckledEgg") { s in s.eggBook.contains { $0.speckled } },
        Milestone(id: "colourCollector") { $0.breedBook.count >= 8 },
        Milestone(id: "showRibbon") { s in s.showResults.contains { (1...3).contains($0.placing) } },
        Milestone(id: "blueRibbon") { $0.firstPlaceRibbons >= 1 },
        Milestone(id: "lapChicken") { s in s.ownBirds.contains { $0.friendliness == .lapChicken } },
        Milestone(id: "storyteller") { s in s.stories.values.contains { $0.rewarded } },
        // A hen kept to `elderHenAgeDays`. Retirement itself comes much later (`retirementAgeDays`).
        Milestone(id: "elderHen") { s in
            s.ownBirds.contains { $0.revealed && $0.sex == .hen && $0.age(onDay: s.day) >= s.rules.elderHenAgeDays }
        },
        Milestone(id: "chocolateEgg", isAvailable: BreedTable.canLay(.chocolate)) { s in
            s.eggBook.contains { $0.colour == .chocolate }
        },
        Milestone(id: "greenEgg") { s in s.eggBook.contains { $0.colour == .green } },
        // Counted only on the morning the sex shows anyway, so it reveals nothing early.
        Milestone(id: "henOrRoo") { $0.sexGuessesRight >= 1 },
        Milestone(id: "whiteEgg", isAvailable: BreedTable.canLay(.white)) { s in
            s.eggBook.contains { $0.colour == .white }
        },
    ]
}

extension Engine {
    /// Each night, after the day has settled: award any milestone newly reached. Awarded once and
    /// recorded in the save, so the tip never repeats. Deterministic — no randomness.
    static func advanceMilestones(_ s: inout GameState) -> [GameEvent] {
        var ev: [GameEvent] = []
        for m in Milestones.all where !s.milestonesReached.contains(m.id) && m.isReached(s) {
            s.milestonesReached.insert(m.id)
            ev.append(.milestoneReached(m.id))
        }
        return ev
    }
}
