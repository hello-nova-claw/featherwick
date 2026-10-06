import Foundation
import Testing

@testable import FeatherwickCore

/// Today's jobs and season goals (Jobs.swift): set each morning, ticked off by play, paid once, never failed.
struct JobsTests {
    /// A started game with every feature open, no fox, and jobs and season goals on.
    /// Its first morning has exactly 3 jobs to choose from: feed, pick up Pip, give a treat.
    static func game(seed: UInt64 = 3) -> (GameState, SeededRNG) {
        var rng = SeededRNG(seed: seed)
        var r = Rules.standard
        r.foxChance = 0
        var s = Engine.newGame(rules: r, earlyGame: false, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        return (s, rng)
    }

    static func sleep(_ s: inout GameState, _ rng: inout SeededRNG) -> [GameEvent] {
        Engine.apply(.passNight, to: &s, using: &rng)
    }

    /// The part of the early game a job needs, if any.
    static func feature(for kind: JobKind) -> Feature? {
        switch kind {
        case .petBirds, .petBird: .handling
        case .giveTreat: .treats
        case .shutCoop: .coopDoor
        case .sellEggs: .laying
        case .enterShow: .shows
        default: nil
        }
    }

    // MARK: - Today's jobs

    @Test func jobsAreSetEachMorning() {
        var (s, rng) = Self.game()
        #expect(s.jobBoard == nil && s.todaysJobs.isEmpty)  // none before the first morning
        let ev = Self.sleep(&s, &rng)
        #expect(s.jobBoard?.day == 1)
        #expect(Set(s.todaysJobs.map(\.kind)) == [.feed, .petBird, .giveTreat])
        #expect(s.todaysJobs.first { $0.kind == .petBird }?.birdID == s.starterID)
        #expect(ev.contains(.jobsSet(count: 3)))
        _ = Self.sleep(&s, &rng)
        #expect(s.jobBoard?.day == 2)
        #expect(s.todaysJobs.count <= s.rules.jobsPerDay)
    }

    @Test func jobsAreTheSameForTheSameSeedAndDay() {
        func play() -> [JobBoard?] {
            var (s, rng) = Self.game(seed: 8)
            var boards: [JobBoard?] = []
            for _ in 0..<30 {
                night(&s, &rng)
                boards.append(s.jobBoard)
                #expect(Engine.pickJobs(s) == s.todaysJobs)  // asking again gives the same jobs
            }
            return boards
        }
        #expect(play() == play())
    }

    /// Jobs come from the shop seed and the day, so a game with jobs plays out exactly like one without.
    @Test func jobsDrawNothingFromTheGameRNG() {
        func play(jobs: Int) -> (GameState, SeededRNG) {
            var rng = SeededRNG(seed: 21)
            var r = Rules.standard
            r.jobsPerDay = jobs
            r.seasonGoals = false
            var s = Engine.newGame(rules: r, using: &rng)
            _ = Engine.apply(.chooseStarter(index: 1, name: "Pip"), to: &s, using: &rng)
            // Feeding and shutting the door never finish a day's jobs alone, so no reward changes the coins.
            for _ in 0..<40 { night(&s, &rng) }
            return (s, rng)
        }
        let (withJobs, rngWithJobs) = play(jobs: 3)
        let (noJobs, rngNoJobs) = play(jobs: 0)
        #expect(withJobs.jobBoard != nil && noJobs.jobBoard == nil)
        #expect(rngWithJobs == rngNoJobs)
        var same = withJobs
        same.jobBoard = nil
        same.rules = noJobs.rules
        #expect(same == noJobs)
    }

    @Test func jobsFollowTheEarlyGame() {
        var rng = SeededRNG(seed: 4)
        var s = Engine.newGame(using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Basil"), to: &s, using: &rng)
        night(&s, &rng)
        // Day 1: only handling is open. No treats, no coop door, no shop yet.
        #expect(Set(s.todaysJobs.map(\.kind)) == [.feed, .petBird])
        for _ in 0..<45 {
            night(&s, &rng)
            for job in s.todaysJobs {
                if let f = Self.feature(for: job.kind) { #expect(s.isOpen(f), "day \(s.day): \(job.kind)") }
                if job.kind == .candleEgg { #expect(s.canCandle) }
            }
        }
    }

    @Test func doingAJobTicksItOff() {
        var (s, rng) = Self.game()
        _ = Self.sleep(&s, &rng)
        #expect(Engine.apply(.feed, to: &s, using: &rng) == [.fed(units: 1), .jobDone(.feed)])
        #expect(s.todaysJobs.first { $0.kind == .feed }?.isDone == true)
        // Refused commands tick nothing.
        #expect(Engine.apply(.feed, to: &s, using: &rng) == [.rejected(.alreadyFed)])
        #expect(s.todaysJobs.count(where: \.isDone) == 1)
    }

    @Test func allJobsDonePaysOnce() throws {
        var (s, rng) = Self.game()
        _ = Self.sleep(&s, &rng)
        let pip = try #require(s.starterID)
        _ = Engine.apply(.feed, to: &s, using: &rng)
        #expect(Engine.apply(.pet(pip), to: &s, using: &rng).contains(.jobDone(.petBird)))
        _ = Engine.apply(.buy(.treats), to: &s, using: &rng)
        let coins = s.coins
        let ev = Engine.apply(.giveTreat(pip), to: &s, using: &rng)
        #expect(ev.contains(.jobDone(.giveTreat)))
        #expect(ev.contains(.allJobsDone(coins: s.rules.jobsRewardCoins)))
        #expect(s.coins == coins + s.rules.jobsRewardCoins)
        #expect(s.todaysJobsRewarded)
        // Nothing more to earn today.
        let more = Engine.apply(.feedPremium, to: &s, using: &rng) + Engine.apply(.closeCoop, to: &s, using: &rng)
        #expect(!more.contains { if case .allJobsDone = $0 { true } else { false } })
        #expect(s.coins == coins + s.rules.jobsRewardCoins)
    }

    @Test func unfinishedJobsSimplyGoInTheMorning() {
        var (s, rng) = Self.game()
        _ = Self.sleep(&s, &rng)
        let coins = s.coins
        _ = Self.sleep(&s, &rng)
        #expect(s.jobBoard?.day == 2)
        #expect(s.todaysJobs.allSatisfy { $0.progress == 0 })
        #expect(s.coins == coins)
        // Yesterday's board ticks nothing.
        s.jobBoard?.day = 1
        #expect(Engine.apply(.feed, to: &s, using: &rng) == [.fed(units: 1)])
    }

    @Test func pickingUpSeveralBirdsCountsEachOne() {
        var (s, rng) = Self.game()
        var job = Job(kind: .petBirds, target: 2)
        _ = Self.sleep(&s, &rng)
        s.coop = [adult(.orpington, .hen, day: s.day, rules: s.rules, rng: &rng)]
        s.jobBoard = JobBoard(day: s.day, jobs: [job])
        let first = Engine.apply(.pet(s.coop[0].id), to: &s, using: &rng)
        #expect(!first.contains(.jobDone(.petBirds)))
        job.progress = 1
        #expect(s.todaysJobs == [job])
        let second = Engine.apply(.pet(s.brooder[0].id), to: &s, using: &rng)
        #expect(second.contains(.jobDone(.petBirds)))
        #expect(second.contains(.allJobsDone(coins: s.rules.jobsRewardCoins)))
    }

    @Test func theShowWeekBringsTheShowJobFirst() {
        var (s, rng) = Self.game()
        s.day = s.rules.showIntervalDays - 2
        s.coop.append(ShowEventTests.championOrpington(in: s, rng: &rng))
        #expect(Engine.pickJobs(s).first?.kind == .enterShow)
        s.day = 10  // weeks before the show: no show job
        #expect(!Engine.pickJobs(s).contains { $0.kind == .enterShow })
    }

    @Test func aNewBirdWaitingForANameIsAJob() {
        var (s, rng) = Self.game()
        _ = Engine.apply(.buy(.pullet), to: &s, using: &rng)
        let pullet = s.coop.last!
        #expect(pullet.needsName == true)
        _ = Self.sleep(&s, &rng)
        let job = s.todaysJobs.first
        #expect(job?.kind == .nameBird && job?.birdID == pullet.id)
        let ev = Engine.apply(.rename(pullet.id, name: "Clementine"), to: &s, using: &rng)
        #expect(ev.contains(.jobDone(.nameBird)))
    }

    @Test func dailyJobsCanBeTurnedOff() {
        var (s, rng) = Self.game()
        s.rules.jobsPerDay = 0
        let ev = Self.sleep(&s, &rng)
        #expect(s.jobBoard == nil && s.todaysJobs.isEmpty)
        #expect(!ev.contains { if case .jobsSet = $0 { true } else { false } })
    }

    // MARK: - The season goal

    @Test func aGoalIsSetOnTheFirstMorning() throws {
        var (s, rng) = Self.game()
        #expect(s.seasonGoal == nil)
        let ev = Self.sleep(&s, &rng)
        let goal = try #require(s.seasonGoal)
        #expect(ev.contains(.seasonGoalSet(goal.kind, previous: nil)))
        #expect(goal.startDay == 1 && goal.endDay == s.rules.daysPerSeason)
        #expect(s.progress(of: goal) == 0 && !goal.reached)
        #expect(s.season(of: goal) == .spring)
    }

    @Test func aGoalProgressesAndPaysOnce() {
        var (s, rng) = Self.game()
        _ = Self.sleep(&s, &rng)
        s.seasonGoal = SeasonGoal(
            kind: .hatchChicks, startDay: s.day, endDay: s.day + 10, target: 3, baseline: s.chicksHatched)
        s.chicksHatched += 1
        let first = Self.sleep(&s, &rng)
        #expect(first.contains(.seasonGoalProgress(.hatchChicks, progress: 1, target: 3)))
        #expect(s.seasonGoal.map { s.progress(of: $0) } == 1)
        // The same progress is told once.
        let quiet = Self.sleep(&s, &rng)
        #expect(!quiet.contains { if case .seasonGoalProgress = $0 { true } else { false } })

        s.chicksHatched += 2
        let coins = s.coins
        let reached = Self.sleep(&s, &rng)
        #expect(reached.contains(.seasonGoalReached(.hatchChicks, coins: s.rules.seasonGoalRewardCoins)))
        #expect(s.coins == coins + s.rules.seasonGoalRewardCoins)
        #expect(s.seasonGoal?.reached == true && s.seasonGoal?.kind == .hatchChicks)

        // Paid once; the reached goal stays until the season turns.
        let later = Self.sleep(&s, &rng)
        #expect(!later.contains { if case .seasonGoalReached = $0 { true } else { false } })
        #expect(s.coins == coins + s.rules.seasonGoalRewardCoins)
        s.chicksHatched += 5
        while s.day < (s.seasonGoal?.endDay ?? 0) - 1 { _ = Self.sleep(&s, &rng) }
        let turn = Self.sleep(&s, &rng)
        #expect(turn.contains { if case .seasonGoalSet(_, previous: nil) = $0 { true } else { false } })
        #expect(s.seasonGoal?.reached == false)
    }

    @Test func anUnfinishedGoalMakesWayKindly() {
        var (s, rng) = Self.game()
        _ = Self.sleep(&s, &rng)
        s.seasonGoal = SeasonGoal(
            kind: .hatchChicks, startDay: s.day, endDay: s.day + 1, target: 3, baseline: s.chicksHatched)
        let coins = s.coins
        let ev = Self.sleep(&s, &rng)
        #expect(!ev.contains { if case .seasonGoalReached = $0 { true } else { false } })
        #expect(ev.contains { if case .seasonGoalSet(_, previous: .hatchChicks) = $0 { true } else { false } })
        #expect(s.seasonGoal?.kind != .hatchChicks)  // a fresh goal, not the same one again
        #expect(s.seasonGoal?.startDay == s.day)
        #expect(s.coins == coins)  // nothing is taken away
    }

    @Test func collectedEggsCountForAnEggGoal() {
        var (s, rng) = Self.game()
        _ = Self.sleep(&s, &rng)
        s.seasonGoal = SeasonGoal(kind: .collectEggs, startDay: s.day, endDay: s.day + 10, target: 3, baseline: 0)
        s.nest = (0..<3).map { _ in clearEgg(mother: s.brooder[0], day: s.day, rng: &rng) }
        _ = Engine.apply(.collectEggs, to: &s, using: &rng)
        #expect(s.seasonGoal?.counted == 3)
        let ev = Self.sleep(&s, &rng)
        #expect(ev.contains(.seasonGoalReached(.collectEggs, coins: s.rules.seasonGoalRewardCoins)))
    }

    @Test func aGoalSetLateInASeasonRunsOnThroughTheNext() {
        var (s, _) = Self.game()
        s.day = s.rules.daysPerSeason - 2
        #expect(Engine.goalEndDay(s) == s.rules.daysPerSeason * 2)
        s.day = 3
        #expect(Engine.goalEndDay(s) == s.rules.daysPerSeason)
    }

    @Test func seasonGoalsCanBeTurnedOff() {
        var (s, rng) = Self.game()
        s.rules.seasonGoals = false
        _ = Self.sleep(&s, &rng)
        #expect(s.seasonGoal == nil)
    }

    // MARK: - Saves

    @Test func jobsAndGoalsSurviveASave() throws {
        var (s, rng) = Self.game()
        for _ in 0..<5 { night(&s, &rng) }
        _ = Engine.apply(.feed, to: &s, using: &rng)
        #expect(s.jobBoard != nil && s.seasonGoal != nil)
        let loaded = try SaveFormat.decode(SaveFormat.encode(SaveGame(state: s, rng: rng)))
        #expect(loaded.state.jobBoard == s.jobBoard)
        #expect(loaded.state.seasonGoal == s.seasonGoal)
    }

    @Test func anOldSaveGetsJobsAndAGoalFromTheNextMorning() throws {
        var game = try SaveFormat.decode(SaveFormatTests.fixture("save-v0"))
        #expect(game.state.jobBoard == nil && game.state.seasonGoal == nil)
        #expect(game.state.rules.jobsPerDay == Rules.standard.jobsPerDay)
        #expect(game.state.rules.seasonGoals)
        let day = game.state.day
        _ = Engine.apply(.passNight, to: &game.state, using: &game.rng)
        #expect(game.state.jobBoard?.day == day + 1)
        #expect(!game.state.todaysJobs.isEmpty)
        #expect(game.state.seasonGoal != nil)
    }
}
