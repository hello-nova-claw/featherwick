// Storylines: small puzzles told through Featherwick's people, which lead to gifts and unlocks.
//
// A storyline starts when its trigger is met, then moves through steps. Each step has a goal:
// some are checked every night (wait some days, hatch chicks), some need the player to act
// (deliver eggs). When the last step is done, the rewards are given: a gift bird (it waits for a
// free perch, so the coop never overfills) and shop unlocks.
//
// The engine knows only IDs. The words people say live in the UI, keyed by story and step ID.
//
// To add a storyline: add one `Storyline` to `Storylines.all`, then its words in the UI.
// Rules: every goal must stay possible (no dead ends), and rewards are given once.

public enum StoryGoal: Hashable, Codable, Sendable {
    /// The player has hatched at least this many chicks, ever. Checked each night.
    case chicksHatched(atLeast: Int)
    /// The player hands over this many eggs they KNOW are fertile (candled). Needs `deliver`.
    /// Always possible: the shop sells fertile eggs.
    case deliverFertileEggs(Int)
    /// Some days pass after the step starts. Checked each night.
    case waitDays(Int)

    public var needsDelivery: Bool {
        if case .deliverFertileEggs = self { true } else { false }
    }
}

public enum StoryReward: Hashable, Codable, Sendable {
    /// A young purebred bird, sex and breed known.
    case giftBird(Breed, Sex)
    /// Speckle & Down starts selling young birds of this breed.
    case unlockShopBreed(Breed)
}

public struct StoryStep: Hashable, Sendable {
    public let id: String
    public let goal: StoryGoal
}

public struct Storyline: Hashable, Sendable, Identifiable {
    public let id: String
    /// When the story starts.
    public let trigger: StoryGoal
    /// Other storylines that must be finished first.
    public let after: [String]
    public let steps: [StoryStep]
    public let rewards: [StoryReward]
}

/// Where a storyline is in this game.
public struct StoryProgress: Hashable, Codable, Sendable {
    /// Index into the steps. Equal to the step count when every step is done.
    public var step: Int
    public var stepStartedDay: Int
    public var rewarded: Bool

    public init(step: Int = 0, stepStartedDay: Int, rewarded: Bool = false) {
        self.step = step
        self.stepStartedDay = stepStartedDay
        self.rewarded = rewarded
    }
}

public enum Storylines {
    /// A neighbour's Silkie hen is broody with nothing to sit on. Bring her eggs you know are
    /// fertile; when they hatch, the neighbour thanks you with one of her own Silkie pullets.
    /// Real keepers do keep Silkies for exactly this: they are the most famous broody hens.
    public static let broodySilkie = Storyline(
        id: "broodySilkie",
        trigger: .chicksHatched(atLeast: 1),
        after: [],
        steps: [
            StoryStep(id: "bringEggs", goal: .deliverFertileEggs(3)),
            StoryStep(id: "sitting", goal: .waitDays(4)),
        ],
        rewards: [.giftBird(.silkie, .hen), .unlockShopBreed(.silkie)]
    )

    /// Once the Silkie story is done, a neighbour who keeps Wyandottes admires your growing flock
    /// and, a few days later, brings round one of her laced girls. A pure gift of time, no errands.
    public static let lacedGift = Storyline(
        id: "lacedGift",
        trigger: .chicksHatched(atLeast: 4),
        after: ["broodySilkie"],
        steps: [
            StoryStep(id: "admiring", goal: .waitDays(3))
        ],
        rewards: [.giftBird(.wyandotte, .hen)]
    )

    /// A travelling keeper is retiring her heritage Australorp line and looking for good homes.
    /// Hatch a proper flock, hand her a few fertile eggs to prove you can raise them, and after she
    /// settles in she leaves you a hen — and tells Speckle & Down to stock the breed for you.
    public static let heritageBreed = Storyline(
        id: "heritageBreed",
        trigger: .chicksHatched(atLeast: 8),
        after: ["lacedGift"],
        steps: [
            StoryStep(id: "bringEggs", goal: .deliverFertileEggs(4)),
            StoryStep(id: "settling", goal: .waitDays(4)),
        ],
        rewards: [.giftBird(.australorp, .hen), .unlockShopBreed(.australorp)]
    )

    public static let all: [Storyline] = [broodySilkie, lacedGift, heritageBreed]

    public static func story(_ id: String) -> Storyline? { all.first { $0.id == id } }
}

extension Engine {
    /// Each night: start stories whose trigger is met, finish timed steps, give waiting rewards.
    static func advanceStories<R: RandomNumberGenerator>(_ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        var ev: [GameEvent] = []
        for story in Storylines.all {
            if s.stories[story.id] == nil {
                let ready = story.after.allSatisfy { s.stories[$0]?.rewarded == true }
                guard ready, goalMet(story.trigger, s, since: s.day) else { continue }
                s.stories[story.id] = StoryProgress(stepStartedDay: s.day)
                ev.append(.storyStarted(story.id))
            }
            guard var progress = s.stories[story.id], !progress.rewarded else { continue }
            // Timed steps finish at night. Delivery steps wait for the player.
            while progress.step < story.steps.count,
                !story.steps[progress.step].goal.needsDelivery,
                goalMet(story.steps[progress.step].goal, s, since: progress.stepStartedDay)
            {
                progress.step += 1
                progress.stepStartedDay = s.day
                if progress.step < story.steps.count {
                    ev.append(.storyStep(story.id, step: story.steps[progress.step].id))
                }
            }
            s.stories[story.id] = progress
            if progress.step == story.steps.count { ev += giveRewards(story, &s, &rng) }
        }
        return ev + storyCandlingLesson(&s)
    }

    /// A story that asks for eggs known to be fertile needs a keeper who can candle. If the keeper
    /// can't yet, the neighbour teaches candling now, so the step is never stuck.
    static func storyCandlingLesson(_ s: inout GameState) -> [GameEvent] {
        guard !s.canCandle, let id = storyAwaitingDelivery(s), let story = Storylines.story(id),
            let step = s.stories[id]?.step, story.steps.indices.contains(step),
            case .deliverFertileEggs = story.steps[step].goal
        else { return [] }
        s.canCandle = true
        return [.learnedCandling]
    }

    static func goalMet(_ goal: StoryGoal, _ s: GameState, since day: Int) -> Bool {
        switch goal {
        case .chicksHatched(let n): s.chicksHatched >= n
        case .waitDays(let n): s.day - day >= n
        case .deliverFertileEggs: false
        }
    }

    /// Rewards are all-or-nothing and given once. A gift bird waits for a free perch.
    static func giveRewards<R: RandomNumberGenerator>(
        _ story: Storyline, _ s: inout GameState, _ rng: inout R
    ) -> [GameEvent] {
        let birds = story.rewards.count(where: { if case .giftBird = $0 { true } else { false } })
        guard s.coop.count + birds <= s.perches else {
            let key = "\(story.id).waitingForRoom"
            if s.storyNotices.insert(key).inserted { return [.storyGiftWaitingForRoom(story.id)] }
            return []
        }
        var ev: [GameEvent] = []
        for reward in story.rewards {
            switch reward {
            case .giftBird(let breed, let sex):
                var bird = Bird(
                    id: makeID(using: &rng), name: "",
                    breed: breed,
                    genome: breed.purebred(sex, variety: breed.definition.varieties.randomElement(using: &rng)),
                    hatchDay: s.day - s.rules.growerAge, origin: "A Featherwick neighbour", revealed: true
                ).withFounderQuality().namedByKeeper(in: s)
                bird.tameness = s.rules.boughtBirdTameness
                s.coop.append(bird)
                ev.append(.storyGift(story.id, bird.id))
                ev += recordBreed(bird, into: &s.breedBook)
            case .unlockShopBreed(let breed):
                if s.shopBreeds.insert(breed).inserted { ev.append(.shopUnlocked(breed)) }
            }
        }
        s.stories[story.id]?.rewarded = true
        ev.append(.storyFinished(story.id))
        return ev
    }

    /// The player hands over what a story step asks for.
    static func deliver(_ storyID: String, _ s: inout GameState) -> [GameEvent] {
        guard let story = Storylines.story(storyID), var progress = s.stories[storyID],
            progress.step < story.steps.count, story.steps[progress.step].goal.needsDelivery
        else { return [.rejected(.nothingToDeliver)] }
        switch story.steps[progress.step].goal {
        case .deliverFertileEggs(let n):
            let known = s.carton.filter { $0.isCandled && $0.isFertile }
            guard known.count >= n else { return [.rejected(.needFertileEggs(need: n, have: known.count))] }
            let given = Set(known.prefix(n).map(\.id))
            s.carton.removeAll { given.contains($0.id) }
        case .chicksHatched, .waitDays:
            return [.rejected(.nothingToDeliver)]
        }
        progress.step += 1
        progress.stepStartedDay = s.day
        s.stories[storyID] = progress
        var ev: [GameEvent] = [.delivered(storyID)]
        if progress.step < story.steps.count { ev.append(.storyStep(storyID, step: story.steps[progress.step].id)) }
        return ev + storyCandlingLesson(&s)
    }

    /// The story waiting for the player to hand something over, if any.
    public static func storyAwaitingDelivery(_ s: GameState) -> String? {
        Storylines.all.first { story in
            guard let p = s.stories[story.id], p.step < story.steps.count else { return false }
            return story.steps[p.step].goal.needsDelivery
        }?.id
    }
}
