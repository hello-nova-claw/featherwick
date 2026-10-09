import Foundation
import Testing

@testable import FeatherwickCore

/// The story engine: people, choice steps, rewards that depend on a choice, loans, debts, the post and the
/// village calendar. The stories here are test stories, so the engine is checked apart from the game's content.
struct StoryEngineTests {
    /// A test story: a bird comes on loan at once, then a choice: send her home with a gift egg, or keep her.
    static let lending = Storyline(
        id: "testLoan", person: .hazel, trigger: .onDay(2),
        steps: [
            StoryStep(
                id: "lent", goal: .waitDays(0),
                rewards: [.loanBird(LoanSpec(tag: "goldie", owner: .hazel, name: "Goldie", sex: .hen, ageDays: 60))]),
            StoryStep(id: "deciding", goal: .onDay(5)),
            StoryStep(
                id: "decide", goal: .choice(id: "goldie", options: ["return", "keep"]),
                rewards: [
                    .ifChosen("goldie", "return", [.endLoan(birdTag: "goldie"), .giftEgg(.orpington, fertile: true)]),
                    .ifChosen("goldie", "keep", [.offerToKeep(birdTag: "goldie", price: 40)]),
                ]),
        ],
        rewards: [.treats(2)]
    )

    static func game(seed: UInt64 = 3) -> (GameState, SeededRNG) {
        var r = calmRules()
        r.noteChance = 0
        return startedGame(sex: .hen, rules: r, seed: seed)
    }

    /// One night, then the test stories (the game's own stories run in `passNight`).
    static func night(_ s: inout GameState, _ rng: inout SeededRNG, stories: [Storyline] = [lending]) -> [GameEvent] {
        sleepTonight(&s, &rng) + Engine.advanceStories(&s, &rng, stories: stories)
    }

    static func nights(_ n: Int, _ s: inout GameState, _ rng: inout SeededRNG) -> [GameEvent] {
        (0..<n).flatMap { _ in night(&s, &rng) }
    }

    static func goldie(_ s: GameState) -> Bird? { s.loanedBird(tag: "goldie") }

    // MARK: - Choices

    @Test func aChoiceStepWaitsForThePlayerAndThenResolves() throws {
        var (s, rng) = Self.game()
        let ev = Self.nights(6, &s, &rng)
        #expect(ev.contains(.storyStep("testLoan", step: "decide")))
        #expect(s.pendingChoices(in: [Self.lending]).map(\.choice) == ["goldie"])
        // Nights pass; the choice waits, and nothing is lost by waiting.
        _ = Self.nights(10, &s, &rng)
        #expect(s.stories["testLoan"]?.step == 2)
        #expect(Self.goldie(s) != nil)

        // A wrong option or a wrong story is refused, and changes nothing.
        #expect(Engine.choose("testLoan", "sell", &s, &rng, stories: [Self.lending]) == [.rejected(.noSuchChoice)])
        #expect(Engine.choose("nope", "keep", &s, &rng, stories: [Self.lending]) == [.rejected(.noSuchChoice)])
        #expect(s.stories["testLoan"]?.chosen.isEmpty == true)

        let chose = Engine.choose("testLoan", "keep", &s, &rng, stories: [Self.lending])
        #expect(chose.first == .chose("testLoan", "keep"))
        #expect(chose.contains(.storyFinished("testLoan")))
        #expect(s.stories["testLoan"]?.chosen == ["goldie": "keep"])
        #expect(s.pendingChoices(in: [Self.lending]).isEmpty)
        // Once made, a choice is not made again.
        #expect(Engine.choose("testLoan", "return", &s, &rng, stories: [Self.lending]) == [.rejected(.noSuchChoice)])
    }

    @Test func theChoiceDecidesTheRewards() throws {
        var (kept, rngK) = Self.game()
        var (returned, rngR) = Self.game()
        _ = Self.nights(6, &kept, &rngK)
        _ = Self.nights(6, &returned, &rngR)
        let treats = kept.treats

        let keep = Engine.choose("testLoan", "keep", &kept, &rngK, stories: [Self.lending])
        #expect(keep.contains { if case .loanKept = $0 { true } else { false } })
        #expect(!keep.contains { if case .storyGiftEgg = $0 { true } else { false } })
        #expect(kept.debts.map(\.coins) == [40])
        #expect(kept.treats == treats + 2)  // the story's own reward comes either way

        let cartonBefore = returned.carton.count
        let back = Engine.choose("testLoan", "return", &returned, &rngR, stories: [Self.lending])
        #expect(back.contains { if case .loanReturned(_, to: .hazel) = $0 { true } else { false } })
        #expect(back.contains(.storyGiftEgg("testLoan", .orpington)))
        #expect(returned.debts.isEmpty)
        #expect(returned.carton.count == cartonBefore + 1)
        let egg = try #require(returned.carton.last)
        #expect(egg.isCandled && egg.isFertile && egg.motherBreed == .orpington)
    }

    // MARK: - Loans

    @Test func aLoanedBirdComesWithHerOwnBoxAndCannotBeRehomedPennedOrRenamed() throws {
        var (s, rng) = Self.game()
        s.perches = 1  // only the starter's perch
        _ = Self.nights(2, &s, &rng)
        let goldie = try #require(Self.goldie(s))
        #expect(s.coop.contains { $0.id == goldie.id })
        #expect(goldie.name == "Goldie" && goldie.revealed && goldie.loan?.owner == .hazel)
        #expect(s.perchesUsed == s.coop.count - 1)

        #expect(Engine.apply(.rehome(goldie.id), to: &s, using: &rng).first == .rejected(.onLoan))
        #expect(Engine.apply(.penBird(goldie.id), to: &s, using: &rng).first == .rejected(.onLoan))
        #expect(Engine.apply(.rename(goldie.id, name: "Mine"), to: &s, using: &rng).first == .rejected(.onLoan))
        #expect(Engine.rehomeBlocker(goldie.id, in: s) == .onLoan)
        // She is cared for like any bird, and only the pet class is hers to enter.
        #expect(Engine.apply(.pet(goldie.id), to: &s, using: &rng).first == .handled(goldie.id, .pet))
        #expect(Engine.eligibleClasses(for: goldie, in: s) == [.pet])
    }

    @Test func theKeeperCannotRehomeTheirLastOwnBirdWhileALoanedBirdIsHere() throws {
        var (s, rng) = Self.game()
        _ = Self.nights(2, &s, &rng)
        #expect(Self.goldie(s) != nil)
        let starter = try #require(s.starterID)
        #expect(Engine.rehomeBlocker(starter, in: s) == .lastBird)
    }

    @Test func aLoanEndsOnItsDay() throws {
        var (s, rng) = Self.game()
        let short = Storyline(
            id: "shortLoan", person: .bea, trigger: .onDay(2),
            steps: [
                StoryStep(
                    id: "lent", goal: .waitDays(0),
                    rewards: [
                        .loanBird(
                            LoanSpec(tag: "tilly", owner: .bea, name: "Tilly", sex: .hen, ageDays: 40, stayDays: 3))
                    ])
            ])
        while s.loanedBird(tag: "tilly") == nil { _ = Self.night(&s, &rng, stories: [short]) }
        let tilly = try #require(s.loanedBird(tag: "tilly"))
        let arrived = s.day
        #expect(tilly.loan?.returnDay == arrived + 3)
        var ev: [GameEvent] = []
        while s.day < arrived + 2 { ev += sleepTonight(&s, &rng) }
        #expect(s.loanedBird(tag: "tilly") != nil)
        ev = sleepTonight(&s, &rng)
        #expect(s.day == arrived + 3)
        #expect(ev.contains(.loanReturned(tilly.id, to: .bea)))
        #expect(s.loanedBird(tag: "tilly") == nil && s.bird(tilly.id) == nil)
        // Her family-tree record stays, with the look the keeper saw.
        #expect(s.pedigree[tilly.id]?.look != nil)
    }

    @Test func keepingClearsTheLoanAndTheBirdIsTheKeepers() throws {
        var (s, rng) = Self.game()
        _ = Self.nights(6, &s, &rng)
        let goldie = try #require(Self.goldie(s))
        _ = Engine.choose("testLoan", "keep", &s, &rng, stories: [Self.lending])
        let mine = try #require(s.bird(goldie.id))
        #expect(mine.loan == nil && mine.name == "Goldie" && mine.genome == goldie.genome)
        #expect(Engine.rehomeBlocker(goldie.id, in: s) == nil)
        #expect(s.perchesUsed == s.coop.count)
    }

    @Test func aScaredLoanedBirdComesHomeWithoutAFreePerch() throws {
        var (s, rng) = Self.game()
        _ = Self.nights(2, &s, &rng)
        let goldie = try #require(Self.goldie(s))
        s.coop.removeAll { $0.id == goldie.id }
        s.lost.append(LostBird(bird: goldie, returnsOnDay: s.day + 1))
        s.perches = s.perchesUsed  // every perch taken
        let ev = Self.night(&s, &rng)
        #expect(ev.contains(.birdReturned(goldie.id)))
        #expect(s.coop.contains { $0.id == goldie.id })
    }

    @Test func keepingWaitsForAFreePerch() throws {
        var (s, rng) = Self.game()
        _ = Self.nights(6, &s, &rng)
        s.perches = s.perchesUsed  // every perch of the keeper's own is taken
        let ev = Engine.choose("testLoan", "keep", &s, &rng, stories: [Self.lending])
        #expect(ev.contains(.storyGiftWaitingForRoom("testLoan")))
        #expect(Self.goldie(s) != nil && s.debts.isEmpty)
        #expect(InvariantTests.problems(in: s).isEmpty)
        s.perches += 1
        _ = Self.night(&s, &rng)
        #expect(Self.goldie(s) == nil && s.debts.count == 1)
        #expect(InvariantTests.problems(in: s).isEmpty)
    }

    @Test func aLoanedBirdsShowEntryGoesHomeWithHerAndTheFeeComesBack() throws {
        var (s, rng) = Self.game()
        let short = Storyline(
            id: "shortLoan", person: .bea, trigger: .onDay(2),
            steps: [
                StoryStep(
                    id: "lent", goal: .waitDays(0),
                    rewards: [
                        .loanBird(
                            LoanSpec(tag: "tilly", owner: .bea, name: "Tilly", sex: .hen, ageDays: 40, stayDays: 1))
                    ])
            ])
        while s.loanedBird(tag: "tilly") == nil { _ = Self.night(&s, &rng, stories: [short]) }
        let tilly = try #require(s.loanedBird(tag: "tilly"))
        s.coins = 100
        _ = Engine.apply(.enterShowIn(tilly.id, .pet), to: &s, using: &rng)
        #expect(s.showEntries.contains { $0.birdID == tilly.id })
        let paid = s.coins
        _ = sleepTonight(&s, &rng)
        #expect(s.bird(tilly.id) == nil)
        #expect(!s.showEntries.contains { $0.birdID == tilly.id })
        #expect(s.coins == paid + s.rules.showEntryFee)
    }

    @Test func aLoanedHenCannotBeSetOnEggs() throws {
        var (s, rng) = Self.game()
        _ = Self.nights(2, &s, &rng)
        let goldie = try #require(Self.goldie(s))
        if let i = s.coop.firstIndex(where: { $0.id == goldie.id }) { s.coop[i].broodyUntilDay = s.day + 10 }
        #expect(Engine.sitBlocker(goldie.id, s) == .onLoan)
    }

    @Test func aLoanedBirdIsNotPartOfTheKeepersOwnFlock() throws {
        var (s, rng) = Self.game()
        _ = Self.nights(2, &s, &rng)
        #expect(s.ownedBirds.count == s.ownBirds.count + 1)
        #expect(Engine.goalMeasure(.growFlock, in: s) == s.ownBirds.count)
    }

    // MARK: - Debts

    @Test func aDebtPaysOnceAndIsMentionedAtMostOnceASeason() throws {
        var (s, rng) = Self.game()
        _ = Self.nights(6, &s, &rng)
        _ = Engine.choose("testLoan", "keep", &s, &rng, stories: [Self.lending])
        let id = try #require(s.debts.first?.id)

        var reminders = 0
        for _ in 0..<(s.rules.debtReminderDays * 2) {
            reminders += Self.night(&s, &rng).count { if case .debtReminder = $0 { true } else { false } }
        }
        #expect(reminders == 2)

        s.coins = 10
        #expect(Engine.apply(.payDebt(id), to: &s, using: &rng) == [.rejected(.notEnoughCoins(needed: 40, have: 10))])
        #expect(s.debts.count == 1)
        s.coins = 100
        #expect(Engine.apply(.payDebt(id), to: &s, using: &rng) == [.debtPaid(id, to: .hazel, coins: 40)])
        #expect(s.coins == 60 && s.debts.isEmpty && s.debtsPaid.contains(id))
        #expect(Engine.apply(.payDebt(id), to: &s, using: &rng) == [.rejected(.noSuchDebt)])
        #expect(Engine.goalMet(.coinsPaid(debtID: id), s, since: s.day))
    }

    @Test func choosingAndPayingCostNoDaylight() {
        #expect(Engine.errand(for: .choose(story: "x", option: "y")) == nil)
        #expect(Engine.errand(for: .payDebt("x")) == nil)
    }

    // MARK: - Goals

    @Test func newGoalsReadOnlyWhatTheKeeperHasDone() throws {
        let (s, _) = Self.game()
        #expect(Engine.goalMet(.onDay(s.day), s, since: 0))
        #expect(!Engine.goalMet(.onDay(s.day + 1), s, since: 0))
        #expect(!Engine.goalMet(.showEntered, s, since: 0))
        #expect(!Engine.goalMet(.showPlaced(top: 3), s, since: 0))
        #expect(!Engine.goalMet(.birdRehomed(atLeast: 1), s, since: 0))
        #expect(!Engine.goalMet(.eggBookHas(.brown), s, since: 0))
        #expect(Engine.goalMet(.friendliness(band: .wild, count: 1), s, since: 0))
        #expect(!Engine.goalMet(.friendliness(band: .wild, count: 99), s, since: 0))
        #expect(Engine.goalMet(.anyOf([.showEntered, .onDay(s.day)]), s, since: 0))
        #expect(!Engine.goalMet(.anyOf([.showEntered, .onDay(s.day + 9)]), s, since: 0))
        #expect(!Engine.goalMet(.choice(id: "c", options: ["a", "b"]), s, since: 0))
        #expect(Engine.goalMet(.choice(id: "c", options: ["a", "b"]), s, since: 0, chosen: ["c": "a"]))
    }

    @Test func theGameStoriesAreHazelsAndNoDeliveryStepGivesItsOwnRewards() {
        #expect(Storylines.all.prefix(3).allSatisfy { $0.person == .hazel })
        for story in Storylines.all {
            for step in story.steps where step.goal.needsDelivery { #expect(step.rewards.isEmpty) }
            for step in story.steps {
                if case .choice(_, let options) = step.goal { #expect((2...3).contains(options.count)) }
            }
        }
    }

    // MARK: - The post

    static let testPool = [
        Note("hello", from: .wren),
        Note("eggs", from: .okafor, when: .hasEggs),
        Note("never", from: .dot, when: .afterStory("noSuchStory")),
    ]

    @Test func thePostDrawsNoGameRandomness() {
        var a = Self.game(seed: 9)
        var b = Self.game(seed: 9)
        a.0.rules.noteChance = 0
        b.0.rules.noteChance = 1
        for _ in 0..<20 {
            _ = sleepTonight(&a.0, &a.1)
            _ = sleepTonight(&b.0, &b.1)
            _ = Engine.deliverPost(&b.0, pool: Self.testPool)
        }
        #expect(a.1 == b.1)
        #expect(a.0.coop.map(\.id) == b.0.coop.map(\.id))
        #expect(a.0.carton.map(\.id) == b.0.carton.map(\.id))
    }

    @Test func thePostNeverRepeatsAndOnlySendsNotesThatFit() {
        var (s, _) = Self.game()
        s.rules.noteChance = 1
        var got: [String] = []
        for day in 0..<50 {
            s.day = 10 + day
            for case .noteArrived(_, let id) in Engine.deliverPost(&s, pool: Self.testPool) { got.append(id) }
        }
        #expect(Set(got).count == got.count)
        #expect(!got.contains("never"))
        #expect(got.contains("hello"))
        #expect(got.contains("eggs") == !s.layRecords.isEmpty)
    }

    @Test func thePostIsTheSameForTheSameSeedAndDay() {
        var (a, _) = Self.game()
        var (b, _) = Self.game()
        a.rules.noteChance = 0.5
        b.rules.noteChance = 0.5
        for day in 0..<30 {
            a.day = day
            b.day = day
            #expect(Engine.deliverPost(&a, pool: Self.testPool) == Engine.deliverPost(&b, pool: Self.testPool))
        }
    }

    // MARK: - The calendar

    @Test func villageDaysFallInTheirSeasonEveryYear() {
        let s = Self.game().0
        for year in 0..<5 {
            for v in VillageDay.allCases {
                let date = s.rules.date(of: v, inYear: year)
                #expect(s.season(onDay: date) == v.season)
                #expect(s.year(onDay: date) == year)
                #expect(s.villageDay(onDay: date) == v)
                // The same day of the season next year.
                #expect(s.rules.date(of: v, inYear: year + 1) - date == s.rules.daysPerSeason * 4)
            }
        }
    }

    @Test func theCalendarSaysAWeekAheadAndOnTheDay() {
        var (s, rng) = Self.game()
        let date = s.rules.date(of: .longestDay, inYear: 0)
        var coming: [Int] = []
        var today: [Int] = []
        while s.day < date + 1 {
            for e in sleepTonight(&s, &rng) {
                if case .villageDayComing(.longestDay, let n) = e {
                    #expect(n == s.rules.villageDayNoticeDays)
                    coming.append(s.day)
                }
                if e == .villageDay(.longestDay) { today.append(s.day) }
            }
        }
        #expect(coming == [date - s.rules.villageDayNoticeDays])
        #expect(today == [date])
    }

    @Test func theNextVillageDaysAreSoonestFirst() {
        var s = Self.game().0
        s.day = s.rules.date(of: .midwinterLights, inYear: 0) + 1
        let next = s.upcomingVillageDays(4)
        #expect(next.map(\.day) == [.hatchAlong, .longestDay, .moultWeek, .midwinterLights])
        #expect(next.allSatisfy { $0.date > s.day })
        #expect(next.map(\.date) == next.map(\.date).sorted())
    }

    // MARK: - Saves

    @Test func anOldSaveLoadsWithNoLoanDebtOrChoice() throws {
        let game = try SaveFormat.decode(SaveFormatTests.fixture("save-v0"))
        #expect(game.state.debts.isEmpty && game.state.debtsPaid.isEmpty && game.state.notesSeen.isEmpty)
        #expect(game.state.loanedBirds.isEmpty)
        #expect(game.state.stories.values.allSatisfy { $0.chosen.isEmpty })
        #expect(game.state.rules.noteChance == Rules.standard.noteChance)
        #expect(game.state.rules.villageDays == Rules.standard.villageDays)
    }

    @Test func storyProgressFromBeforeChoicesLoads() throws {
        var (s, rng) = Self.game()
        s.stories["broodySilkie"] = StoryProgress(stepStartedDay: 1)
        var json = try #require(
            JSONSerialization.jsonObject(with: SaveFormat.encode(SaveGame(state: s, rng: rng))) as? [String: Any])
        var state = try #require(json["state"] as? [String: Any])
        var stories = try #require(state["stories"] as? [String: Any])
        var progress = try #require(stories["broodySilkie"] as? [String: Any])
        progress["chosen"] = nil
        stories["broodySilkie"] = progress
        state["stories"] = stories
        for key in ["debts", "debtsPaid", "notesSeen"] { state[key] = nil }
        json["state"] = state
        let loaded = try SaveFormat.decode(JSONSerialization.data(withJSONObject: json))
        #expect(loaded.state.stories["broodySilkie"]?.chosen == [:])
        #expect(loaded.state.debts.isEmpty)
        _ = rng.next()
    }

    @Test func aLoanAndADebtSurviveASave() throws {
        var (s, rng) = Self.game()
        _ = Self.nights(6, &s, &rng)
        let loaded = try SaveFormat.decode(SaveFormat.encode(SaveGame(state: s, rng: rng)))
        #expect(loaded.state.loanedBird(tag: "goldie") == Self.goldie(s))
        _ = Engine.choose("testLoan", "keep", &s, &rng, stories: [Self.lending])
        let again = try SaveFormat.decode(SaveFormat.encode(SaveGame(state: s, rng: rng)))
        #expect(again.state.debts == s.debts)
        #expect(again.state.stories["testLoan"]?.chosen == ["goldie": "keep"])
    }
}
