import Foundation

// Storylines: small puzzles told through Featherwick's people, which lead to gifts and unlocks.
//
// A storyline belongs to one person. It starts when its trigger is met, then moves through steps.
// Each step has a goal: some are checked every night (wait some days, hatch chicks, a day comes),
// some need the player to act (deliver eggs, make a choice). A step may give rewards when it is done,
// and the story gives its own rewards when the last step is done. A gift bird waits for a free perch,
// so the coop never overfills.
//
// Braided arcs: a choice step offers two or three options. The choice is kept in `StoryProgress.chosen`,
// and rewards can depend on it (`StoryReward.ifChosen`). No option locks content: every option leads on.
//
// The engine knows only IDs. The words people say live in FeatherwickText, keyed by story, step and option.
//
// To add a storyline: append one `Storyline` to `Storylines.all`, then its words in `storyText`.
// Rules: every goal must stay possible (no dead ends), and rewards are given once.

/// The people of Featherwick. Each system has a person (see README "Storylines").
/// The words (names, about lines) live in FeatherwickText.
public enum Person: String, Hashable, Codable, Sendable, CaseIterable {
    /// The neighbour over the back fence: genetics, the breeding pen, the lessons.
    case hazel
    /// Speckle & Down: the shop and the village news.
    case wren
    /// The show judge.
    case dot
    /// The kid down the lane: friendliness.
    case teddy
    /// The baker: egg colours.
    case okafor
    /// The rescue: rehoming.
    case bea
}

public indirect enum StoryGoal: Hashable, Codable, Sendable {
    /// The player has hatched at least this many chicks, ever. Checked each night.
    case chicksHatched(atLeast: Int)
    /// The player hands over this many eggs they KNOW are fertile (candled). Needs `deliver`.
    /// Always possible: the shop sells fertile eggs.
    case deliverFertileEggs(Int)
    /// Some days pass after the step starts. Checked each night.
    case waitDays(Int)
    /// This game day has come (an absolute day, not days since the step started). The early game uses it.
    case onDay(Int)
    /// The player picks one option (`Command.choose`). The choice is kept under `id` in `StoryProgress.chosen`.
    /// Two or three options, never four. No option is wrong.
    case choice(id: String, options: [String])
    /// The player has entered the county show at least once.
    case showEntered
    /// A bird or plate of the player's placed in the top `top` at a county show.
    case showPlaced(top: Int)
    /// At least `count` birds at home are this friendly or friendlier.
    case friendliness(band: Friendliness, count: Int)
    /// The Egg Book has this colour (speckled or plain).
    case eggBookHas(EggColour)
    /// At least this many birds have gone to new homes in Featherwick.
    case birdRehomed(atLeast: Int)
    /// The player has paid this debt.
    case coinsPaid(debtID: String)
    /// Any one of these goals is met. For "whichever comes first".
    case anyOf([StoryGoal])

    /// True when the player must act to finish the step: the night never finishes it.
    public var needsPlayer: Bool {
        switch self {
        case .deliverFertileEggs, .choice: true
        default: false
        }
    }

    public var needsDelivery: Bool {
        if case .deliverFertileEggs = self { true } else { false }
    }
}

/// What a bird on loan is like. The lender names her: the keeper cannot rename a loaned bird.
public struct LoanSpec: Hashable, Codable, Sendable {
    /// Stable tag for this loan, such as "marigold". `endLoan` and `offerToKeep` find the bird by it.
    public var tag: String
    public var owner: Person
    /// The bird's name, given by her owner.
    public var name: String
    /// The bird's breed. Nil: the starter's breed.
    public var breed: Breed?
    public var sex: Sex
    /// Her age on the day she arrives.
    public var ageDays: Int
    /// Nights she stays. Nil: she stays until a story ends the loan (`endLoan` or `offerToKeep`).
    public var stayDays: Int?

    public init(
        tag: String, owner: Person, name: String, breed: Breed? = nil, sex: Sex, ageDays: Int,
        stayDays: Int? = nil
    ) {
        self.tag = tag
        self.owner = owner
        self.name = name
        self.breed = breed
        self.sex = sex
        self.ageDays = ageDays
        self.stayDays = stayDays
    }
}

public indirect enum StoryReward: Hashable, Codable, Sendable {
    /// A young purebred bird, sex and breed known.
    case giftBird(Breed, Sex)
    /// The breed joins Speckle & Down's surprise stock (`GameState.surpriseBreeds`).
    case unlockShopBreed(Breed)
    /// An egg of this breed, in the carton. Already candled, so the keeper knows if it is fertile.
    case giftEgg(Breed, fertile: Bool)
    case coins(Int)
    /// Mealworms for the bag.
    case treats(Int)
    /// A bird comes to stay for a while (see Loans.swift). She needs no perch: she brings her own box.
    case loanBird(LoanSpec)
    /// The loaned bird goes home to her owner.
    case endLoan(birdTag: String)
    /// The keeper keeps the loaned bird. She is the keeper's now, and her price is a debt to her owner,
    /// paid when the keeper can. No price: a gift.
    case offerToKeep(birdTag: String, price: Int)
    /// A note from this person (see Post.swift). The words come from the note's ID.
    case note(Person, String)
    /// These rewards only if the player chose `optionID` in the choice `choiceID` of this story.
    case ifChosen(String, String, [StoryReward])

    /// Gift birds in these rewards, for the free-perch check. Conditional rewards count only when chosen.
    func giftBirds(chosen: [String: String]) -> Int {
        switch self {
        case .giftBird: 1
        case .ifChosen(let choice, let option, let inner):
            chosen[choice] == option ? inner.reduce(0) { $0 + $1.giftBirds(chosen: chosen) } : 0
        default: 0
        }
    }

    /// Gift eggs in these rewards, for the carton check.
    func giftEggs(chosen: [String: String]) -> Int {
        switch self {
        case .giftEgg: 1
        case .ifChosen(let choice, let option, let inner):
            chosen[choice] == option ? inner.reduce(0) { $0 + $1.giftEggs(chosen: chosen) } : 0
        default: 0
        }
    }
}

public struct StoryStep: Hashable, Sendable {
    public let id: String
    public let goal: StoryGoal
    /// Given once, when the goal is met. A step with a gift bird waits for a free perch.
    public let rewards: [StoryReward]

    public init(id: String, goal: StoryGoal, rewards: [StoryReward] = []) {
        self.id = id
        self.goal = goal
        self.rewards = rewards
    }
}

public struct Storyline: Hashable, Sendable, Identifiable {
    public let id: String
    /// Whose story it is.
    public let person: Person
    /// When the story starts.
    public let trigger: StoryGoal
    /// Other storylines that must be finished first.
    public let after: [String]
    public let steps: [StoryStep]
    /// Given once, when the last step is done.
    public let rewards: [StoryReward]

    public init(
        id: String, person: Person, trigger: StoryGoal, after: [String] = [], steps: [StoryStep],
        rewards: [StoryReward] = []
    ) {
        self.id = id
        self.person = person
        self.trigger = trigger
        self.after = after
        self.steps = steps
        self.rewards = rewards
    }

    /// The choice step's options, by choice ID, for front ends.
    public func options(forChoice choiceID: String) -> [String] {
        for step in steps {
            if case .choice(let id, let options) = step.goal, id == choiceID { return options }
        }
        return []
    }
}

/// Where a storyline is in this game.
public struct StoryProgress: Hashable, Codable, Sendable {
    /// Index into the steps. Equal to the step count when every step is done.
    public var step: Int
    public var stepStartedDay: Int
    public var rewarded: Bool
    /// The option picked at each choice step, by choice ID. Remembered for words ("since you kept her").
    /// Empty in saves from before choices (`SaveFormat.fillNewSettings`).
    public var chosen: [String: String]

    public init(step: Int = 0, stepStartedDay: Int, rewarded: Bool = false, chosen: [String: String] = [:]) {
        self.step = step
        self.stepStartedDay = stepStartedDay
        self.rewarded = rewarded
        self.chosen = chosen
    }
}

/// A choice waiting for the player: the story, the choice ID and its options.
public struct PendingChoice: Hashable, Sendable {
    public let story: String
    public let person: Person
    public let choice: String
    public let options: [String]
}

public enum Storylines {
    /// A neighbour's Silkie hen is broody with nothing to sit on. Bring her eggs you know are
    /// fertile; when they hatch, the neighbour thanks you with one of her own Silkie pullets.
    /// Real keepers do keep Silkies for exactly this: they are the most famous broody hens.
    public static let broodySilkie = Storyline(
        id: "broodySilkie",
        person: .hazel,
        trigger: .chicksHatched(atLeast: 1),
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
        person: .hazel,
        trigger: .chicksHatched(atLeast: 4),
        after: ["broodySilkie"],
        steps: [
            StoryStep(id: "admiring", goal: .waitDays(3))
        ],
        rewards: [.giftBird(.wyandotte, .hen)]
    )

    /// A travelling keeper is retiring her heritage Australorp line and looking for good homes.
    /// Hatch a proper flock, hand her a few fertile eggs to prove you can raise them, and after she
    /// settles in she leaves you a hen — and tells Speckle & Down to stock the breed.
    public static let heritageBreed = Storyline(
        id: "heritageBreed",
        person: .hazel,
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

extension GameState {
    /// Choices waiting for the player, in story-table order. Front ends offer one button per option.
    public var pendingChoices: [PendingChoice] { pendingChoices(in: Storylines.all) }

    func pendingChoices(in stories: [Storyline]) -> [PendingChoice] {
        stories.compactMap { story in
            guard let p = self.stories[story.id], !p.rewarded, p.step < story.steps.count,
                case .choice(let id, let options) = story.steps[p.step].goal, p.chosen[id] == nil
            else { return nil }
            return PendingChoice(story: story.id, person: story.person, choice: id, options: options)
        }
    }

    /// The option picked in a story's choice, or nil if it has not been made.
    public func chosen(_ choiceID: String, in storyID: String) -> String? {
        stories[storyID]?.chosen[choiceID]
    }
}

extension Engine {
    /// Each night: start stories whose trigger is met, finish timed steps, give waiting rewards.
    static func advanceStories<R: RandomNumberGenerator>(
        _ s: inout GameState, _ rng: inout R, stories: [Storyline] = Storylines.all
    ) -> [GameEvent] {
        var ev: [GameEvent] = []
        for story in stories {
            if s.stories[story.id] == nil {
                let ready = story.after.allSatisfy { s.stories[$0]?.rewarded == true }
                guard ready, goalMet(story.trigger, s, since: s.day) else { continue }
                s.stories[story.id] = StoryProgress(stepStartedDay: s.day)
                ev.append(.storyStarted(story.id))
            }
            ev += advance(story, &s, &rng)
        }
        return ev + storyCandlingLesson(&s, stories: stories)
    }

    /// Finishes every step of one story whose goal is met, in order, and gives the rewards that come
    /// with them. Delivery steps wait for `deliver`; choice steps finish once the choice is made.
    /// A step whose rewards need room (a perch, a carton space) waits until there is room.
    static func advance<R: RandomNumberGenerator>(
        _ story: Storyline, _ s: inout GameState, _ rng: inout R
    ) -> [GameEvent] {
        guard var progress = s.stories[story.id], !progress.rewarded else { return [] }
        var ev: [GameEvent] = []
        while progress.step < story.steps.count {
            let step = story.steps[progress.step]
            guard !step.goal.needsDelivery,
                goalMet(step.goal, s, since: progress.stepStartedDay, chosen: progress.chosen)
            else { break }
            if !step.rewards.isEmpty {
                guard hasRoom(for: step.rewards, chosen: progress.chosen, s) else {
                    ev += waitingForRoom(story, key: "\(story.id).\(step.id).waitingForRoom", &s)
                    break
                }
                ev += grant(step.rewards, story: story, chosen: progress.chosen, &s, &rng)
            }
            progress.step += 1
            progress.stepStartedDay = s.day
            if progress.step < story.steps.count {
                ev.append(.storyStep(story.id, step: story.steps[progress.step].id))
            }
        }
        s.stories[story.id] = progress
        if progress.step == story.steps.count { ev += giveRewards(story, &s, &rng) }
        return ev
    }

    /// A story that asks for eggs known to be fertile needs a keeper who can candle. If the keeper
    /// can't yet, the neighbour teaches candling now, so the step is never stuck.
    static func storyCandlingLesson(_ s: inout GameState, stories: [Storyline] = Storylines.all) -> [GameEvent] {
        guard !s.canCandle, let id = storyAwaitingDelivery(s, in: stories),
            let story = stories.first(where: { $0.id == id }),
            let step = s.stories[id]?.step, story.steps.indices.contains(step),
            case .deliverFertileEggs = story.steps[step].goal
        else { return [] }
        s.canCandle = true
        return [.learnedCandling]
    }

    static func goalMet(_ goal: StoryGoal, _ s: GameState, since day: Int, chosen: [String: String] = [:]) -> Bool {
        switch goal {
        case .chicksHatched(let n): s.chicksHatched >= n
        case .waitDays(let n): s.day - day >= n
        case .deliverFertileEggs: false
        case .onDay(let n): s.day >= n
        case .choice(let id, _): chosen[id] != nil
        case .showEntered: !s.showEntries.isEmpty || !s.showResults.isEmpty
        case .showPlaced(let top): s.showResults.contains { (1...max(1, top)).contains($0.placing) }
        case .friendliness(let band, let count): s.birdsAtHome.count(where: { $0.friendliness >= band }) >= count
        case .eggBookHas(let colour): s.eggBook.contains { $0.colour == colour }
        case .birdRehomed(let n): s.rehomed.count >= n
        case .coinsPaid(let id): s.debtsPaid.contains(id)
        case .anyOf(let goals): goals.contains { goalMet($0, s, since: day, chosen: chosen) }
        }
    }

    /// The story's own rewards, given once when its last step is done. A gift bird waits for a free perch.
    static func giveRewards<R: RandomNumberGenerator>(
        _ story: Storyline, _ s: inout GameState, _ rng: inout R
    ) -> [GameEvent] {
        let chosen = s.stories[story.id]?.chosen ?? [:]
        guard hasRoom(for: story.rewards, chosen: chosen, s) else {
            return waitingForRoom(story, key: "\(story.id).waitingForRoom", &s)
        }
        var ev = grant(story.rewards, story: story, chosen: chosen, &s, &rng)
        s.stories[story.id]?.rewarded = true
        ev.append(.storyFinished(story.id))
        return ev
    }

    /// The "no room yet" notice, once per story step.
    static func waitingForRoom(_ story: Storyline, key: String, _ s: inout GameState) -> [GameEvent] {
        s.storyNotices.insert(key).inserted ? [.storyGiftWaitingForRoom(story.id)] : []
    }

    /// True when every gift bird has a free perch and every gift egg has a carton space.
    static func hasRoom(for rewards: [StoryReward], chosen: [String: String], _ s: GameState) -> Bool {
        let birds = rewards.reduce(0) { $0 + $1.giftBirds(chosen: chosen) }
        let eggs = rewards.reduce(0) { $0 + $1.giftEggs(chosen: chosen) }
        return s.perchesUsed + birds <= s.perches && s.carton.count + eggs <= s.cartonCapacity
    }

    /// Gives rewards, in order. Conditional rewards are given only for the option the player chose.
    static func grant<R: RandomNumberGenerator>(
        _ rewards: [StoryReward], story: Storyline, chosen: [String: String], _ s: inout GameState, _ rng: inout R
    ) -> [GameEvent] {
        var ev: [GameEvent] = []
        for reward in rewards {
            switch reward {
            case .giftBird(let breed, let sex):
                var bird = Bird(
                    id: makeID(using: &rng), name: "",
                    breed: breed,
                    genome: breed.purebred(sex, variety: breed.definition.varieties.randomElement(using: &rng)),
                    hatchDay: s.day - s.rules.growerAge, origin: Bird.villageOrigin, revealed: true
                ).withFounderQuality().namedByKeeper(in: s)
                bird.tameness = s.rules.boughtBirdTameness
                s.coop.append(bird)
                ev.append(.storyGift(story.id, bird.id))
                ev += recordBreed(bird, into: &s.breedBook)
            case .unlockShopBreed(let breed):
                if s.shopBreeds.insert(breed).inserted { ev.append(.shopUnlocked(breed)) }
            case .giftEgg(let breed, let fertile):
                ev += giftEgg(breed, fertile: fertile, story: story, &s, &rng)
            case .coins(let n):
                s.coins += n
                ev.append(.storyCoins(story.id, n))
            case .treats(let n):
                s.treats += n
                ev.append(.storyTreats(story.id, n))
            case .loanBird(let spec):
                ev += lend(spec, &s, &rng)
            case .endLoan(let tag):
                ev += endLoan(tag: tag, &s)
            case .offerToKeep(let tag, let price):
                ev += keepLoan(tag: tag, price: price, &s)
            case .note(let person, let id):
                s.notesSeen.insert(id)
                ev.append(.noteArrived(person, id))
            case .ifChosen(let choice, let option, let inner):
                if chosen[choice] == option { ev += grant(inner, story: story, chosen: chosen, &s, &rng) }
            }
        }
        return ev
    }

    /// An egg from the giver's own flock: both parents purebred of the breed. Candled, so the keeper
    /// knows. A fertile one brings the neighbour's small incubator if the keeper has none.
    static func giftEgg<R: RandomNumberGenerator>(
        _ breed: Breed, fertile: Bool, story: Storyline, _ s: inout GameState, _ rng: inout R
    ) -> [GameEvent] {
        let mother = youngBird(.hen, origin: Bird.villageOrigin, s, &rng, breed: breed)
        let father = youngBird(.rooster, origin: Bird.villageOrigin, s, &rng, breed: breed)
        var egg = Breeding.layEgg(mother: mother, father: fertile ? father : nil, day: s.day, using: &rng)
        // The parents go on record, so the chick's family tree is not blank. The keeper never saw them.
        s.pedigree[mother.id] = PedigreeRecord(mother, look: nil)
        if fertile { s.pedigree[father.id] = PedigreeRecord(father, look: nil) }
        egg.collectedDay = s.day
        egg.candled = true
        s.carton.append(egg)
        return [.storyGiftEgg(story.id, breed)] + incubatorGiftForFertileEggs(&s)
    }

    /// The player picks an option at a story's choice step. The step finishes at once, with its rewards.
    static func choose<R: RandomNumberGenerator>(
        _ storyID: String, _ option: String, _ s: inout GameState, _ rng: inout R,
        stories: [Storyline] = Storylines.all
    ) -> [GameEvent] {
        guard let story = stories.first(where: { $0.id == storyID }), var progress = s.stories[storyID],
            !progress.rewarded, progress.step < story.steps.count,
            case .choice(let id, let options) = story.steps[progress.step].goal,
            progress.chosen[id] == nil, options.contains(option)
        else { return [.rejected(.noSuchChoice)] }
        progress.chosen[id] = option
        s.stories[storyID] = progress
        return [.chose(storyID, option)] + advance(story, &s, &rng)
    }

    /// The player hands over what a story step asks for.
    /// A delivery step gives no rewards of its own: the next step, or the story, gives them.
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
        default:
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
        storyAwaitingDelivery(s, in: Storylines.all)
    }

    static func storyAwaitingDelivery(_ s: GameState, in stories: [Storyline]) -> String? {
        stories.first { story in
            guard let p = s.stories[story.id], p.step < story.steps.count else { return false }
            return story.steps[p.step].goal.needsDelivery
        }?.id
    }
}
