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

/// A number a story uses: written in the table, or read from the game's own rules when the story runs.
/// So tuning `Rules` (Marigold's price, her age, the days she stays) changes the story, as rule 3 asks.
/// An integer literal is a fixed number: `.waitDays(4)`.
public enum StoryNumber: Hashable, Codable, Sendable, ExpressibleByIntegerLiteral {
    case fixed(Int)
    case rule(RulesNumber)

    public init(integerLiteral value: Int) { self = .fixed(value) }

    /// The number in this game.
    public func value(in rules: Rules) -> Int {
        switch self {
        case .fixed(let n): n
        case .rule(let r): rules.number(r)
        }
    }
}

/// A number in `Rules` that a story table can name.
public enum RulesNumber: String, Hashable, Codable, Sendable {
    case marigoldPrice, marigoldAgeDays, marigoldStayDays
}

extension Rules {
    public func number(_ n: RulesNumber) -> Int {
        switch n {
        case .marigoldPrice: marigoldPrice
        case .marigoldAgeDays: marigoldAgeDays
        case .marigoldStayDays: marigoldStayDays
        }
    }
}

public indirect enum StoryGoal: Hashable, Codable, Sendable {
    /// The player has hatched at least this many chicks, ever. Checked each night.
    case chicksHatched(atLeast: Int)
    /// The player hands over this many eggs they KNOW are fertile (candled). Needs `deliver`.
    /// Always possible: the shop sells fertile eggs.
    case deliverFertileEggs(Int)
    /// Some days pass after the step starts. Checked each night.
    case waitDays(StoryNumber)
    /// This game day has come (an absolute day, not days since the step started). The early game uses it.
    case onDay(Int)
    /// The morning the early game introduces this feature, in this game (`GameState.introductionDay(of:)`).
    /// So a story step follows the game's own `featureDays`.
    case featureDay(Feature)
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
    /// Any one of these goals is met. For "whichever comes first". Not for choices or deliveries: those
    /// are step goals on their own, so the player is always offered them (`StoryTests` checks this).
    case anyOf([StoryGoal])
    /// Every one of these goals is met. For "this, but not before day N". Not for choices or deliveries,
    /// as for `anyOf`.
    case allOf([StoryGoal])
    /// The game began as a new keeper's, with the early game (`GameState.earlyGameStories`). The early-game
    /// stories start with it. A save from before them never meets it, so it gets no retroactive loan.
    case newKeeper
    /// The player hands over this many eggs of this colour from the carton. Needs `deliver`.
    case deliverEggs(colour: EggColour, count: Int)
    /// The player hands over this many eggs of a colour new to the Egg Book. Needs `deliver`. The colours
    /// that count are fixed when the step starts (`StoryProgress.wantedColours`, see `Engine.prepare`).
    /// Always possible: at least one counting colour is laid by a breed Speckle & Down sells.
    case deliverEggsOfNewColour(count: Int)
    /// The player picks one of two breeds, as `choice` does. The breeds come from what the keeper can
    /// see (birds whose breed shows, then the Breed Book), fixed when the step starts and kept in
    /// `StoryProgress.options` as breed raw values. A flock of one breed is offered a second breed.
    case choiceOfBreeds(id: String)
    /// `then` if the player picked `option` in the choice `choice` of this story, else `otherwise`.
    /// For a step that depends on an earlier choice ("bring them now" or "wait for a new colour").
    case ifChosen(String, String, then: StoryGoal, otherwise: StoryGoal)

    /// True when the player must act to finish the step: the night never finishes it.
    public var needsPlayer: Bool {
        switch self {
        case .deliverFertileEggs, .choice, .deliverEggs, .deliverEggsOfNewColour, .choiceOfBreeds: true
        case .ifChosen(_, _, let a, let b): a.needsPlayer || b.needsPlayer
        default: false
        }
    }

    /// True when the step waits for `deliver`. For `ifChosen`, true if either branch does
    /// (`resolved(_:)` gives the branch that applies).
    public var needsDelivery: Bool {
        switch self {
        case .deliverFertileEggs, .deliverEggs, .deliverEggsOfNewColour: true
        case .ifChosen(_, _, let a, let b): a.needsDelivery || b.needsDelivery
        default: false
        }
    }

    /// The goal that applies, given the story's choices: `ifChosen` picks its branch. Other goals are
    /// themselves. A choice not made yet takes the `otherwise` branch.
    public func resolved(_ chosen: [String: String]) -> StoryGoal {
        if case .ifChosen(let choice, let option, let a, let b) = self {
            return (chosen[choice] == option ? a : b).resolved(chosen)
        }
        return self
    }

    /// The choice ID and the options offered now, for a choice goal. Nil for other goals.
    func choiceOptions(_ p: StoryProgress) -> (String, [String])? {
        switch self {
        case .choice(let id, let options): (id, options)
        case .choiceOfBreeds(let id): (id, p.options ?? [])
        default: nil
        }
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
    public var ageDays: StoryNumber
    /// Nights she stays. Nil: she stays until a story ends the loan (`endLoan` or `offerToKeep`).
    public var stayDays: Int?
    /// True: she is the starter's mother (a hen of the starter's breed). Her genes fit the starter's, and
    /// the starter's family tree gets her (see BorrowedHen.swift).
    public var motherOfStarter: Bool

    public init(
        tag: String, owner: Person, name: String, breed: Breed? = nil, sex: Sex, ageDays: StoryNumber,
        stayDays: Int? = nil, motherOfStarter: Bool = false
    ) {
        self.tag = tag
        self.owner = owner
        self.name = name
        self.breed = breed
        self.sex = sex
        self.ageDays = ageDays
        self.stayDays = stayDays
        self.motherOfStarter = motherOfStarter
    }

    private enum CodingKeys: String, CodingKey {
        case tag, owner, name, breed, sex, ageDays, stayDays, motherOfStarter
    }

    /// Specs live in the story table, not in saves. Still, one written before `motherOfStarter` reads as false.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tag = try c.decode(String.self, forKey: .tag)
        owner = try c.decode(Person.self, forKey: .owner)
        name = try c.decode(String.self, forKey: .name)
        breed = try c.decodeIfPresent(Breed.self, forKey: .breed)
        sex = try c.decode(Sex.self, forKey: .sex)
        ageDays = try c.decode(StoryNumber.self, forKey: .ageDays)
        stayDays = try c.decodeIfPresent(Int.self, forKey: .stayDays)
        motherOfStarter = try c.decodeIfPresent(Bool.self, forKey: .motherOfStarter) ?? false
    }
}

public indirect enum StoryReward: Hashable, Codable, Sendable {
    /// A young purebred bird, sex and breed known.
    case giftBird(Breed, Sex)
    /// The breed joins Speckle & Down's surprise stock (`GameState.surpriseBreeds`).
    case unlockShopBreed(Breed)
    /// An egg of this breed, in the carton. Already candled, so the keeper knows if it is fertile.
    /// Nil breed: the breed of the bird the story lent (`GameState.lentBreeds`), else the starter's.
    case giftEgg(Breed?, fertile: Bool)
    case coins(Int)
    /// Mealworms for the bag.
    case treats(Int)
    /// A bird comes to stay for a while (see Loans.swift). She needs no perch: she brings her own box.
    case loanBird(LoanSpec)
    /// The loaned bird goes home to her owner.
    case endLoan(birdTag: String)
    /// The keeper keeps the loaned bird. She is the keeper's now, and her price is a debt to her owner,
    /// paid when the keeper can. No price: a gift.
    case offerToKeep(birdTag: String, price: StoryNumber)
    /// A note from this person (see Post.swift). The words come from the note's ID.
    case note(Person, String)
    /// This person names the next chick that hatches (`GameState.nextChickNamer`), from their own list
    /// (`NameBook.name(by:for:in:)`). The keeper can rename it.
    case namesNextChick(Person)
    /// These rewards only if the player chose `optionID` in the choice `choiceID` of this story.
    case ifChosen(String, String, [StoryReward])

    /// Birds these rewards add to the keeper's perches, for the free-perch check: gift birds, and a loaned
    /// bird the keeper keeps (she needs a perch of her own then). Conditional rewards count only when chosen.
    func giftBirds(chosen: [String: String]) -> Int {
        switch self {
        case .giftBird, .offerToKeep: 1
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

    /// The tags of the birds this story lends (`loanBird`), in table order.
    public var loanTags: [String] {
        func tags(_ rewards: [StoryReward]) -> [String] {
            rewards.flatMap { reward -> [String] in
                switch reward {
                case .loanBird(let spec): [spec.tag]
                case .ifChosen(_, _, let inner): tags(inner)
                default: []
                }
            }
        }
        return tags(steps.flatMap(\.rewards) + rewards)
    }

    /// Every option a choice can have, by choice ID. A breed choice can offer any in-game breed;
    /// `GameState.pendingChoices` gives the options offered now.
    public func options(forChoice choiceID: String) -> [String] {
        for step in steps {
            if case .choice(let id, let options) = step.goal, id == choiceID { return options }
            if case .choiceOfBreeds(let id) = step.goal, id == choiceID {
                return BreedTable.inGame.map(\.id.rawValue)
            }
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
    /// The options a breed choice offers (`StoryGoal.choiceOfBreeds`), fixed when the step started.
    /// Nil for other steps (cleared when the step finishes), and in older saves. The pick itself is kept
    /// in `chosen`, which is all the words need later.
    public var options: [String]?
    /// The egg colours that count as new for `StoryGoal.deliverEggsOfNewColour`, fixed when the step
    /// started. Nil for other steps (cleared when the step finishes), and in older saves.
    public var wantedColours: [EggColour]?

    public init(step: Int = 0, stepStartedDay: Int, rewarded: Bool = false, chosen: [String: String] = [:]) {
        self.step = step
        self.stepStartedDay = stepStartedDay
        self.rewarded = rewarded
        self.chosen = chosen
    }
}

extension StoryProgress {
    /// Moves on to the next step, which starts today. What the finished step offered is cleared:
    /// the next step fixes its own (`Engine.prepare`).
    mutating func nextStep(onDay day: Int) {
        step += 1
        stepStartedDay = day
        options = nil
        wantedColours = nil
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

    /// Dot, the show judge, notices a new keeper at the entry desk and shows them a breed standard: the
    /// page of one of two breeds from the keeper's own flock. Her notes join that breed's Breed Book page
    /// ("What Dot looks for", `GameState.dotStandardBreed`).
    public static let dotStandard = Storyline(
        id: "dotStandard",
        person: .dot,
        trigger: .showEntered,
        steps: [
            StoryStep(id: "noticed", goal: .waitDays(2)),
            StoryStep(id: "invite", goal: .waitDays(2)),
            StoryStep(
                id: "standard", goal: .choiceOfBreeds(id: dotStandardChoice),
                rewards: BreedTable.inGame.map { breed in
                    .ifChosen(dotStandardChoice, breed.id.rawValue, [.note(.dot, dotStandardNote(breed.id))])
                }),
        ]
    )
    /// The choice ID of Dot's breed choice.
    public static let dotStandardChoice = "standard"
    /// The note ID of Dot's standard page for this breed: "standard-orpington".
    public static func dotStandardNote(_ breed: Breed) -> String { "standard-\(breed.rawValue)" }

    /// Teddy, the kid down the lane, comes to meet the keeper's birds once one wins a ribbon (or on
    /// day 30). He isn't allowed a chicken, so he asks to help. He names the next chick, or has a
    /// drawing day. Later, when a bird is a lap chicken, he is the first to say so.
    public static let teddyHelps = Storyline(
        id: "teddyHelps",
        person: .teddy,
        trigger: .anyOf([.showPlaced(top: 3), .onDay(30)]),
        steps: [
            StoryStep(id: "meeting", goal: .waitDays(2)),
            StoryStep(id: "notAllowed", goal: .waitDays(2)),
            StoryStep(
                id: "help", goal: .choice(id: "help", options: ["name", "drawing"]),
                rewards: [
                    .treats(3),
                    .ifChosen("help", "name", [.namesNextChick(.teddy)]),
                    .ifChosen("help", "drawing", [.note(.teddy, "teddy-drawing")]),
                ]),
            StoryStep(
                id: "lap", goal: .friendliness(band: .lapChicken, count: 1),
                rewards: [.note(.teddy, "teddy-lapChicken")]),
        ]
    )

    /// Mr Okafor, the baker, wants eggs for his shop window: six brown eggs now, or three of a colour the
    /// keeper has not had yet, for more coins. Not before day 14: a new keeper's first fortnight is
    /// Marigold's, and she lays from day 4. Both pay well above the egg price, so the window is worth it.
    /// Then he talks of a market board in the village.
    public static let okaforWindow = Storyline(
        id: "okaforWindow",
        person: .okafor,
        trigger: .allOf([.onDay(14), .eggBookHas(.brown)]),
        steps: [
            StoryStep(id: "asking", goal: .waitDays(1)),
            StoryStep(id: "window", goal: .choice(id: "window", options: ["now", "wait"])),
            StoryStep(
                id: "bring",
                goal: .ifChosen(
                    "window", "now", then: .deliverEggs(colour: .brown, count: 6),
                    otherwise: .deliverEggsOfNewColour(count: 3))),
            StoryStep(
                id: "thanks", goal: .waitDays(0),
                rewards: [
                    .ifChosen("window", "now", [.coins(30)]),
                    .ifChosen("window", "wait", [.coins(50), .note(.okafor, "okafor-window")]),
                ]),
            StoryStep(id: "board", goal: .waitDays(3), rewards: [.note(.okafor, "okafor-marketBoard")]),
        ]
    )

    /// Bea, from the hen rescue, writes about a bird the keeper sent to a new home, by name. Then she asks
    /// the keeper to visit. A third postcard comes once three birds have new homes. No choice.
    public static let beaPostcards = Storyline(
        id: "beaPostcards",
        person: .bea,
        trigger: .birdRehomed(atLeast: 1),
        steps: [
            StoryStep(id: "postcard", goal: .waitDays(2), rewards: [.note(.bea, "bea-postcard")]),
            StoryStep(id: "invite", goal: .waitDays(5), rewards: [.note(.bea, "bea-invite")]),
            StoryStep(id: "third", goal: .birdRehomed(atLeast: 3), rewards: [.note(.bea, "bea-postcard-3")]),
        ]
    )

    /// Append, never insert: the night runs stories in this order.
    public static let all: [Storyline] = [
        broodySilkie, lacedGift, heritageBreed, dotStandard, teddyHelps, okaforWindow, beaPostcards,
        borrowedHen,
    ]

    public static func story(_ id: String) -> Storyline? { all.first { $0.id == id } }
}

extension GameState {
    /// Choices waiting for the player, in story-table order. Front ends offer one button per option.
    public var pendingChoices: [PendingChoice] { pendingChoices(in: Storylines.all) }

    func pendingChoices(in stories: [Storyline]) -> [PendingChoice] {
        stories.compactMap { story in
            guard let p = self.stories[story.id], !p.rewarded, p.step < story.steps.count,
                let (id, options) = story.steps[p.step].goal.resolved(p.chosen).choiceOptions(p),
                p.chosen[id] == nil
            else { return nil }
            return PendingChoice(story: story.id, person: story.person, choice: id, options: options)
        }
    }

    /// Breeds for a breed choice (`StoryGoal.choiceOfBreeds`): first the breeds of birds the keeper owns
    /// whose breed shows, then breeds in the Breed Book, then breeds Speckle & Down sells, then any other
    /// in-game breed, each in breed-table order. Always `count` breeds, so a flock of one breed is never
    /// a dead end. Rule 8: a chick whose breed has not shown yet does not count, so the offer never
    /// depends on a hidden breed.
    func breedsToChooseFrom(_ count: Int = 2) -> [Breed] {
        let inGame = BreedTable.inGame.map(\.id)
        let shown = Set(ownedBirds.filter { $0.revealed && $0.isPurebred && !$0.isOnLoan }.map(\.breed))
        let booked = Set(breedBook.filter { !$0.isCross }.map(\.variety))
        let flock = inGame.filter { shown.contains($0) }
        let book = inGame.filter { booked.contains($0.rawValue) && !shown.contains($0) }
        let rest = inGame.filter { !shown.contains($0) && !booked.contains($0.rawValue) }
        let shop = Set(surpriseBreeds)
        return Array(
            (flock + book + rest.filter { shop.contains($0) } + rest.filter { !shop.contains($0) })
                .prefix(count))
    }

    /// The colours that count for a "new colour" delivery (`StoryGoal.deliverEggsOfNewColour`): colours not
    /// in the Egg Book now. If no breed Speckle & Down sells lays one of them, any colour but brown that
    /// the shop's breeds lay counts instead, so the step can always be done (the Araucana, a starter
    /// breed, lays blue).
    func newEggColoursWanted() -> [EggColour] {
        let have = Set(eggBook.map(\.colour))
        let shop = Set(surpriseBreeds.map(\.definition.eggColour))
        let new = EggColour.allCases.filter { !have.contains($0) }
        if new.contains(where: { shop.contains($0) }) { return new }
        return EggColour.allCases.filter { shop.contains($0) && $0 != .brown }
    }

    /// The breed whose standard Dot showed the keeper, once chosen. Its Breed Book page shows
    /// "What Dot looks for".
    public var dotStandardBreed: Breed? {
        let option = chosen(Storylines.dotStandardChoice, in: Storylines.dotStandard.id)
        return BreedTable.inGame.first { $0.id.rawValue == option }?.id
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
            let goal = step.goal.resolved(progress.chosen)
            prepare(goal, &progress, s)
            guard !goal.needsDelivery, goalMet(goal, s, since: progress.stepStartedDay, chosen: progress.chosen)
            else { break }
            if !step.rewards.isEmpty {
                guard hasRoom(for: step.rewards, chosen: progress.chosen, s) else {
                    ev += waitingForRoom(story, key: "\(story.id).\(step.id).waitingForRoom", &s)
                    break
                }
                ev += grant(step.rewards, story: story, chosen: progress.chosen, &s, &rng)
            }
            progress.nextStep(onDay: s.day)
            if progress.step < story.steps.count {
                ev.append(.storyStep(story.id, step: story.steps[progress.step].id))
            }
        }
        s.stories[story.id] = progress
        if progress.step == story.steps.count { ev += giveRewards(story, &s, &rng) }
        return ev
    }

    /// Fixes what a step offers when it starts, from what the keeper can see then: the breeds of a breed
    /// choice, and the colours a "new colour" delivery wants. Set once, so the offer does not change
    /// while the step waits.
    static func prepare(_ goal: StoryGoal, _ progress: inout StoryProgress, _ s: GameState) {
        switch goal {
        case .choiceOfBreeds where progress.options == nil:
            progress.options = s.breedsToChooseFrom().map(\.rawValue)
        case .deliverEggsOfNewColour where progress.wantedColours == nil:
            progress.wantedColours = s.newEggColoursWanted()
        default: break
        }
    }

    /// A story that asks for eggs known to be fertile needs a keeper who can candle. If the keeper
    /// can't yet, the neighbour teaches candling now, so the step is never stuck.
    static func storyCandlingLesson(_ s: inout GameState, stories: [Storyline] = Storylines.all) -> [GameEvent] {
        guard !s.canCandle, let id = storyAwaitingDelivery(s, in: stories),
            let story = stories.first(where: { $0.id == id }),
            let p = s.stories[id], story.steps.indices.contains(p.step),
            case .deliverFertileEggs = story.steps[p.step].goal.resolved(p.chosen)
        else { return [] }
        s.canCandle = true
        return [.learnedCandling]
    }

    static func goalMet(_ goal: StoryGoal, _ s: GameState, since day: Int, chosen: [String: String] = [:]) -> Bool {
        switch goal {
        case .chicksHatched(let n): s.chicksHatched >= n
        case .waitDays(let n): s.day - day >= n.value(in: s.rules)
        case .deliverFertileEggs: false
        case .onDay(let n): s.day >= n
        case .featureDay(let f): s.day >= s.introductionDay(of: f)
        case .choice(let id, _): chosen[id] != nil
        case .showEntered: !s.showEntries.isEmpty || !s.showResults.isEmpty
        case .showPlaced(let top): s.showResults.contains { (1...max(1, top)).contains($0.placing) }
        case .friendliness(let band, let count): s.birdsAtHome.count(where: { $0.friendliness >= band }) >= count
        case .eggBookHas(let colour): s.eggBook.contains { $0.colour == colour }
        case .birdRehomed(let n): s.rehomed.count >= n
        case .coinsPaid(let id): s.debtsPaid.contains(id)
        case .anyOf(let goals): goals.contains { goalMet($0, s, since: day, chosen: chosen) }
        case .allOf(let goals): goals.allSatisfy { goalMet($0, s, since: day, chosen: chosen) }
        case .newKeeper: s.earlyGameStories
        case .deliverEggs, .deliverEggsOfNewColour: false
        case .choiceOfBreeds(let id): chosen[id] != nil
        case .ifChosen: goalMet(goal.resolved(chosen), s, since: day, chosen: chosen)
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
                // No breed: the breed of the bird this story lent, else the starter's.
                let lent = story.loanTags.compactMap { s.lentBreeds[$0] }.first
                ev += giftEgg(breed ?? lent ?? s.starterBreed, fertile: fertile, story: story, &s, &rng)
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
                ev += keepLoan(tag: tag, price: price.value(in: s.rules), &s)
            case .note(let person, let id):
                s.notesSeen.insert(id)
                ev.append(.noteArrived(person, id))
            case .namesNextChick(let person):
                s.nextChickNamer = person
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
            let (id, options) = story.steps[progress.step].goal.resolved(progress.chosen).choiceOptions(progress),
            progress.chosen[id] == nil, options.contains(option)
        else { return [.rejected(.noSuchChoice)] }
        progress.chosen[id] = option
        s.stories[storyID] = progress
        return [.chose(storyID, option)] + advance(story, &s, &rng)
    }

    /// The player hands over what a story step asks for.
    /// A delivery step gives no rewards of its own: the next step, or the story, gives them.
    static func deliver(
        _ storyID: String, _ s: inout GameState, stories: [Storyline] = Storylines.all
    )
        -> [GameEvent]
    {
        guard let story = stories.first(where: { $0.id == storyID }), var progress = s.stories[storyID],
            progress.step < story.steps.count
        else { return [.rejected(.nothingToDeliver)] }
        let goal = story.steps[progress.step].goal.resolved(progress.chosen)
        switch goal {
        case .deliverFertileEggs(let n):
            let known = s.carton.filter { $0.isCandled && $0.isFertile }
            guard known.count >= n else { return [.rejected(.needFertileEggs(need: n, have: known.count))] }
            let given = Set(known.prefix(n).map(\.id))
            s.carton.removeAll { given.contains($0.id) }
        case .deliverEggs(let colour, let n):
            guard handOver(n, from: [colour], &s) else {
                return [.rejected(.needEggs(colour, need: n, have: s.carton.count(where: { $0.colour == colour })))]
            }
        case .deliverEggsOfNewColour(let n):
            prepare(goal, &progress, s)
            let wanted = progress.wantedColours ?? []
            guard handOver(n, from: Set(wanted), &s) else {
                let best = wanted.map { c in s.carton.count(where: { $0.colour == c }) }.max() ?? 0
                return [.rejected(.needEggsOfNewColour(wanted, need: n, have: best))]
            }
        default:
            return [.rejected(.nothingToDeliver)]
        }
        progress.nextStep(onDay: s.day)
        if progress.step < story.steps.count {
            prepare(story.steps[progress.step].goal.resolved(progress.chosen), &progress, s)
        }
        s.stories[storyID] = progress
        var ev: [GameEvent] = [.delivered(storyID)]
        if progress.step < story.steps.count { ev.append(.storyStep(storyID, step: story.steps[progress.step].id)) }
        return ev + storyCandlingLesson(&s, stories: stories)
    }

    /// Takes `n` eggs of one of these colours from the carton, all of one colour. Eggs the keeper knows
    /// are fertile go last, so a hatching egg stays if it can. False, and nothing taken, if no colour
    /// has enough.
    static func handOver(_ n: Int, from colours: Set<EggColour>, _ s: inout GameState) -> Bool {
        let order = EggColour.allCases.filter { colours.contains($0) }
        guard let colour = order.first(where: { c in s.carton.count(where: { $0.colour == c }) >= n }) else {
            return false
        }
        let eggs = s.carton.filter { $0.colour == colour }.sorted {
            !($0.isCandled && $0.isFertile) && ($1.isCandled && $1.isFertile)
        }
        let given = Set(eggs.prefix(n).map(\.id))
        s.carton.removeAll { given.contains($0.id) }
        return true
    }

    /// The story waiting for the player to hand something over, if any.
    public static func storyAwaitingDelivery(_ s: GameState) -> String? {
        storyAwaitingDelivery(s, in: Storylines.all)
    }

    /// Every story waiting for the player to hand something over, in story-table order. Front ends offer
    /// each at its person's place (Hazel's at the back fence).
    public static func storiesAwaitingDelivery(_ s: GameState) -> [Storyline] {
        Storylines.all.filter { story in
            guard let p = s.stories[story.id], p.step < story.steps.count else { return false }
            return story.steps[p.step].goal.resolved(p.chosen).needsDelivery
        }
    }

    static func storyAwaitingDelivery(_ s: GameState, in stories: [Storyline]) -> String? {
        stories.first { story in
            guard let p = s.stories[story.id], p.step < story.steps.count else { return false }
            return story.steps[p.step].goal.resolved(p.chosen).needsDelivery
        }?.id
    }
}
