import Foundation

// Today's jobs and the season goal: a gentle reason to come back each day.
//
// Each morning the game picks up to `Rules.jobsPerDay` small jobs from what the keeper can do now
// (feed the flock, collect the eggs, cuddle Pip...). A job ticks itself off when the keeper does it.
// All of today's jobs done pays a small reward, once. Unfinished jobs simply go at the next morning:
// nothing is lost.
//
// Each season also has one bigger goal (hatch 3 chicks, win a ribbon...). Progress shows as "2 of 3".
// It is checked each night, like the milestones, and pays a bigger reward once. A goal is never
// failed: when its season ends unfinished, the next season brings a new one.
//
// Both are picked from `GameState.shopSeed` and the day, never from the game RNG (see Shop.swift).
// So existing seeds keep their games, and the same day always gives the same jobs.
// Every job and goal reads only what the keeper can see, so none leaks a hidden gene or sex.

/// One kind of small daily job. Table order: append new kinds at the end, so seeded picks stay the same.
public enum JobKind: String, Hashable, Codable, Sendable, CaseIterable {
    /// Feed the flock (basic or premium feed).
    case feed
    /// Collect the eggs from the nest boxes.
    case collectEggs
    /// Cuddle a few birds, named on the job (`Job.birdIDs`, `Job.target` of them).
    case petBirds
    /// Cuddle one named bird (`Job.birdID`).
    case petBird
    /// Give a bird a treat from your hand.
    case giveTreat
    /// Shut the coop door for the night.
    case shutCoop
    /// Sell some eggs at Speckle & Down.
    case sellEggs
    /// Hold an egg up to the light.
    case candleEgg
    /// Set eggs to hatch, in the incubator or under a broody hen.
    case setEggs
    /// Give a new bird its name (`Job.birdID`).
    case nameBird
    /// Enter the county show. Only in the week before a show.
    case enterShow
}

/// One of today's jobs.
public struct Job: Hashable, Codable, Sendable {
    public var kind: JobKind
    /// How many times to do it ("cuddle 3 birds"). 1 for most jobs.
    public var target: Int
    public var progress: Int
    /// The bird the job is about (cuddle Pip, name the new chick). Nil for the rest.
    public var birdID: UUID?
    /// The birds a `petBirds` job names ("cuddle Juniper and Pip"). Nil in saves made before jobs
    /// named their birds: then any bird counts.
    public var birdIDs: [UUID]?

    public init(kind: JobKind, target: Int = 1, progress: Int = 0, birdID: UUID? = nil, birdIDs: [UUID]? = nil) {
        self.kind = kind
        self.target = target
        self.progress = progress
        self.birdID = birdID
        self.birdIDs = birdIDs
    }

    public var isDone: Bool { progress >= target }
}

/// Today's jobs, set in the morning of `day`.
public struct JobBoard: Hashable, Codable, Sendable {
    public var day: Int
    public var jobs: [Job]
    /// True once every job is done and the reward is paid. Paid once a day.
    public var rewarded: Bool

    public init(day: Int, jobs: [Job], rewarded: Bool = false) {
        self.day = day
        self.jobs = jobs
        self.rewarded = rewarded
    }

    public var allDone: Bool { !jobs.isEmpty && jobs.allSatisfy(\.isDone) }
}

/// One kind of season goal. Table order: append new kinds at the end, so seeded picks stay the same.
public enum GoalKind: String, Hashable, Codable, Sendable, CaseIterable {
    /// Hatch a number of chicks.
    case hatchChicks
    /// Add a new entry to the Breed Book.
    case breedBookPage
    /// Find an egg not yet in the Egg Book.
    case newEgg
    /// Win a ribbon (1st to 3rd) at the county show.
    case showRibbon
    /// Help one more bird become friendly.
    case newFriend
    /// Grow the flock by a few birds.
    case growFlock
    /// Collect a number of eggs.
    case collectEggs
}

/// The season's bigger goal. It runs from `startDay` to the morning of `endDay`.
public struct SeasonGoal: Hashable, Codable, Sendable {
    public var kind: GoalKind
    public var startDay: Int
    /// The first morning after the goal: the next season starts. The goal is still checked that
    /// morning, so a show held then counts.
    public var endDay: Int
    public var target: Int
    /// The measure when the goal was set (chicks hatched, Breed Book entries...). Progress is the rise.
    public var baseline: Int
    /// Eggs collected since the goal was set. Used by `collectEggs` only.
    public var counted: Int
    /// The progress last told to the keeper, so each step is told once.
    public var reported: Int
    /// True once the goal is reached and the reward is paid.
    public var reached: Bool

    public init(
        kind: GoalKind, startDay: Int, endDay: Int, target: Int, baseline: Int, counted: Int = 0,
        reported: Int = 0, reached: Bool = false
    ) {
        self.kind = kind
        self.startDay = startDay
        self.endDay = endDay
        self.target = target
        self.baseline = baseline
        self.counted = counted
        self.reported = reported
        self.reached = reached
    }
}

extension GameState {
    /// Today's jobs. Empty before the first morning, and when daily jobs are off.
    public var todaysJobs: [Job] {
        guard let board = jobBoard, board.day == day else { return [] }
        return board.jobs
    }

    /// True once all of today's jobs are done (and the reward is paid).
    public var todaysJobsRewarded: Bool { jobBoard.map { $0.day == day && $0.rewarded } ?? false }

    /// How far the keeper is with a season goal: 0...target.
    public func progress(of goal: SeasonGoal) -> Int {
        if goal.reached { return goal.target }
        let measured =
            goal.kind == .collectEggs ? goal.counted : Engine.goalMeasure(goal.kind, in: self) - goal.baseline
        return min(goal.target, max(0, measured))
    }

    /// The season a goal belongs to (its last day's season).
    public func season(of goal: SeasonGoal) -> Season { season(onDay: goal.endDay - 1) }
}

extension Engine {
    // MARK: - Picking today's jobs

    /// A seed for the day's jobs, from the shop seed: no game RNG draw. The salt keeps it apart from
    /// the shop's daily special.
    static func jobSeed(_ s: GameState, day: Int, salt: UInt64) -> SeededRNG {
        SeededRNG(seed: s.shopSeed ^ salt ^ UInt64(truncatingIfNeeded: day))
    }

    /// The jobs the keeper can do today, in table order. Each follows the early-game timeline.
    static func availableJobs(_ s: GameState, _ rng: inout SeededRNG) -> [Job] {
        let home = s.birdsAtHome
        let r = s.rules
        var jobs: [Job] = []
        for kind in JobKind.allCases {
            switch kind {
            case .feed:
                if !home.isEmpty { jobs.append(Job(kind: .feed)) }
            case .collectEggs:
                if !s.nest.isEmpty { jobs.append(Job(kind: .collectEggs)) }
            case .petBirds:
                if s.isOpen(.handling), home.count >= 2 {
                    // Its own seed, so naming the birds leaves the rest of the day's picks as they were.
                    var pick = jobSeed(s, day: s.day, salt: 0x5045_5453)  // "PETS"
                    let birds = home.map(\.id).shuffled(using: &pick).prefix(min(max(1, r.jobPetBirds), home.count))
                    jobs.append(Job(kind: .petBirds, target: birds.count, birdIDs: Array(birds)))
                }
            case .petBird:
                if s.isOpen(.handling), !home.isEmpty {
                    let bird = home[Int.random(in: 0..<home.count, using: &rng)]
                    jobs.append(Job(kind: .petBird, birdID: bird.id))
                }
            case .giveTreat:
                if s.isOpen(.treats), !home.isEmpty, s.treats > 0 || s.coins >= r.treatBagPrice {
                    jobs.append(Job(kind: .giveTreat))
                }
            case .shutCoop:
                if s.isOpen(.coopDoor), !s.coop.isEmpty { jobs.append(Job(kind: .shutCoop)) }
            case .sellEggs:
                if s.isOpen(.laying), !s.carton.isEmpty || !s.nest.isEmpty { jobs.append(Job(kind: .sellEggs)) }
            case .candleEgg:
                if s.canCandle, s.carton.contains(where: { !$0.isCandled }) || !s.nest.isEmpty {
                    jobs.append(Job(kind: .candleEgg))
                }
            case .setEggs:
                if canSetEggs(s) { jobs.append(Job(kind: .setEggs)) }
            case .nameBird:
                if let bird = s.unnamedBirds.first { jobs.append(Job(kind: .nameBird, birdID: bird.id)) }
            case .enterShow:
                let until = s.nextShowDay - s.day
                let canShow = home.contains { $0.revealed && !eligibleClasses(for: $0, in: s).isEmpty }
                if s.isOpen(.shows), until <= r.showNoticeDays, s.showEntries.isEmpty, canShow {
                    jobs.append(Job(kind: .enterShow))
                }
            }
        }
        return jobs
    }

    /// Eggs could be set today: the incubator is free, or a broody hen sits on nothing, and there are
    /// eggs worth trying (known fertile, or unchecked with a grown rooster in the coop).
    static func canSetEggs(_ s: GameState) -> Bool {
        let rooster = s.coop.contains {
            $0.revealed && $0.sex == .rooster && $0.stage(onDay: s.day, rules: s.rules) == .adult
        }
        let eggs =
            s.carton.contains { $0.isCandled && $0.isFertile }
            || (rooster && (s.carton.contains { !$0.isCandled } || !s.nest.isEmpty))
        guard eggs else { return false }
        let incubator = s.hasIncubator && incubatorBlocker(s) == nil
        let broody = s.coop.contains { sitBlocker($0.id, s) == nil }
        return incubator || broody
    }

    /// Picks today's jobs: timely ones first (the show, a name), then a seeded draw from the rest.
    /// Only one of the two "cuddle" jobs, so the list does not repeat itself.
    static func pickJobs(_ s: GameState) -> [Job] {
        var rng = jobSeed(s, day: s.day, salt: 0x4A4F_4253)  // "JOBS"
        var rest = availableJobs(s, &rng)
        if rest.contains(where: { $0.kind == .petBirds }), rest.contains(where: { $0.kind == .petBird }) {
            let drop: JobKind = Bool.random(using: &rng) ? .petBirds : .petBird
            rest.removeAll { $0.kind == drop }
        }
        let timely: Set<JobKind> = [.enterShow, .nameBird]
        let first = rest.filter { timely.contains($0.kind) }.sorted { $0.kind == .enterShow && $1.kind != .enterShow }
        rest.removeAll { timely.contains($0.kind) }
        rest.shuffle(using: &rng)
        return Array((first + rest).prefix(max(0, s.rules.jobsPerDay)))
    }

    /// Each morning: set today's jobs. Yesterday's jobs go, done or not. Deterministic: no game RNG.
    static func setTodaysJobs(_ s: inout GameState) -> [GameEvent] {
        guard s.rules.jobsPerDay > 0 else {
            s.jobBoard = nil
            return []
        }
        let jobs = pickJobs(s)
        s.jobBoard = JobBoard(day: s.day, jobs: jobs)
        return jobs.isEmpty ? [] : [.jobsSet(count: jobs.count)]
    }

    // MARK: - Doing jobs

    /// True when this event is one step of the job.
    static func counts(_ e: GameEvent, for job: Job) -> Bool {
        switch (job.kind, e) {
        case (.feed, .fed), (.feed, .fedPremium): true
        case (.collectEggs, .eggsCollected): true
        case (.petBirds, .handled(let id, .pet)): job.birdIDs?.contains(id) ?? true
        case (.petBird, .handled(let id, .pet)): id == job.birdID
        case (.giveTreat, .handled(_, .treat)): true
        case (.shutCoop, .coopClosed): true
        case (.sellEggs, .eggsSold): true
        case (.candleEgg, .candled): true
        case (.setEggs, .eggsSet): true
        case (.nameBird, .renamed(let id)): id == job.birdID
        case (.enterShow, .enteredInShow): true
        default: false
        }
    }

    /// After each command (not the night): tick off the jobs it did, and pay once all are done.
    /// Also counts collected eggs for a `collectEggs` season goal. A command that did nothing for a
    /// job changes nothing.
    static func progressJobs(after events: [GameEvent], _ s: inout GameState) -> [GameEvent] {
        var out: [GameEvent] = []
        if var board = s.jobBoard, board.day == s.day, !board.rewarded {
            var moved = false
            for i in board.jobs.indices where !board.jobs[i].isDone {
                let job = board.jobs[i]
                let progress: Int
                if job.kind == .petBirds, let ids = job.birdIDs {
                    progress = namedBirdsCuddled(ids, s)
                } else if job.kind == .petBird, let id = job.birdID {
                    progress = namedBirdsCuddled([id], s)
                } else {
                    progress = job.progress + events.count(where: { counts($0, for: job) })
                }
                guard progress > job.progress else { continue }
                moved = true
                board.jobs[i].progress = min(job.target, progress)
                if board.jobs[i].isDone { out.append(.jobDone(job.kind)) }
            }
            if board.allDone {
                board.rewarded = true
                s.coins += s.rules.jobsRewardCoins
                out.append(.allJobsDone(coins: s.rules.jobsRewardCoins))
            }
            // Keep a step of a job that is not done yet too ("1 of 3 birds cuddled").
            if moved { s.jobBoard = board }
        }
        if var goal = s.seasonGoal, goal.kind == .collectEggs, !goal.reached {
            let collected = events.reduce(0) { n, e in
                if case .eggsCollected(let count, _) = e { return n + count }
                return n
            }
            if collected > 0 {
                goal.counted += collected
                s.seasonGoal = goal
            }
        }
        return out
    }

    /// Steps done on a "cuddle Juniper and Pip" (or "cuddle Pip") job: each named bird cuddled today
    /// counts once. Cozy rule: a named bird that has left home (rehomed, lost, away) counts as done,
    /// so the job can always be finished. It ticks off with the keeper's next command.
    static func namedBirdsCuddled(_ ids: [UUID], _ s: GameState) -> Int {
        let home = s.birdsAtHome
        return ids.count(where: { id in
            guard let bird = home.first(where: { $0.id == id }) else { return true }
            return bird.lastPettedDay == s.day
        })
    }

    // MARK: - The season goal

    /// The measure a goal watches, from what the keeper can see. `collectEggs` counts in the goal.
    static func goalMeasure(_ kind: GoalKind, in s: GameState) -> Int {
        switch kind {
        case .hatchChicks: s.chicksHatched
        case .breedBookPage: s.breedBook.count
        case .newEgg: s.eggBook.count
        case .showRibbon: s.showResults.count(where: { (1...3).contains($0.placing) })
        case .newFriend: s.ownedBirds.count(where: { $0.friendliness >= .friendly })
        case .growFlock: s.ownedBirds.count
        case .collectEggs: 0
        }
    }

    /// Visible hens that lay or soon will: grown, not retired.
    static func layingHens(_ s: GameState) -> Int {
        s.coop.count(where: {
            $0.revealed && $0.sex == .hen && !$0.isRetired(onDay: s.day, rules: s.rules)
        })
    }

    /// The goals the keeper can work on before `endDay`, with their targets, in table order.
    static func availableGoals(_ s: GameState, endDay: Int) -> [(kind: GoalKind, target: Int)] {
        let r = s.rules
        let owned = s.ownedBirds
        let pair =
            owned.contains { $0.revealed && $0.sex == .hen } && owned.contains { $0.revealed && $0.sex == .rooster }
        var goals: [(kind: GoalKind, target: Int)] = []
        for kind in GoalKind.allCases {
            switch kind {
            case .hatchChicks:
                if s.hasIncubator || pair { goals.append((kind, max(1, r.seasonGoalChicks))) }
            case .breedBookPage:
                if s.isOpen(.breedBook), s.isOpen(.birdShop) || pair { goals.append((kind, 1)) }
            case .newEgg:
                let pool = newEggColours()
                let all = pool.count * 2  // each colour, plain and speckled
                let found = s.eggBook.count(where: { pool.contains($0.colour) })
                if s.isOpen(.laying), layingHens(s) > 0, found < all { goals.append((kind, 1)) }
            case .showRibbon:
                if s.isOpen(.shows), s.nextShowDay <= endDay { goals.append((kind, 1)) }
            case .newFriend:
                if s.isOpen(.handling), owned.contains(where: { $0.friendliness < .friendly }) {
                    goals.append((kind, 1))
                }
            case .growFlock:
                if s.isOpen(.birdShop) || s.hasIncubator { goals.append((kind, max(1, r.seasonGoalFlockGrowth))) }
            case .collectEggs:
                let hens = layingHens(s)
                if s.isOpen(.laying), hens > 0 {
                    let eggs = min(max(1, r.seasonGoalMaxEggs), hens * max(1, r.seasonGoalEggsPerHen))
                    goals.append((kind, eggs))
                }
            }
        }
        return goals
    }

    /// Egg colours the "new egg" goal can ask for: those a breed in play can make. Chocolate needs a
    /// breed whose shell depth is above `Rules.chocolateShellDepth`; without one in the game it is
    /// left out, so the goal never waits on an egg the keeper has almost no way to get.
    /// A chocolate egg found anyway still counts as a new egg.
    static func newEggColours() -> [EggColour] {
        let chocolateBreed = BreedTable.inGame.contains {
            $0.fixes(BrownShell.brown) && $0.brownDepth > Rules.chocolateShellDepth
        }
        return EggColour.allCases.filter { $0 != .chocolate || chocolateBreed }
    }

    /// The first morning of the next season. A goal set late in a season runs on through the next
    /// one, so there is always time (`seasonGoalMinDays`).
    static func goalEndDay(_ s: GameState) -> Int {
        let length = max(1, s.rules.daysPerSeason)
        let end = (s.day / length + 1) * length
        return end - s.day < s.rules.seasonGoalMinDays ? end + length : end
    }

    /// Each morning: check the season goal (pay once when reached), tell any new progress, and set a
    /// new goal when the season has turned. An unfinished goal is never failed; it just makes way.
    /// Deterministic: no game RNG.
    static func advanceSeasonGoal(_ s: inout GameState) -> [GameEvent] {
        guard s.rules.seasonGoals else { return [] }
        var ev: [GameEvent] = []
        var previous: GoalKind?
        if var goal = s.seasonGoal {
            let progress = s.progress(of: goal)
            if !goal.reached, progress >= goal.target {
                goal.reached = true
                goal.reported = goal.target
                s.coins += s.rules.seasonGoalRewardCoins
                ev.append(.seasonGoalReached(goal.kind, coins: s.rules.seasonGoalRewardCoins))
            } else if !goal.reached, progress > goal.reported {
                goal.reported = progress
                ev.append(.seasonGoalProgress(goal.kind, progress: progress, target: goal.target))
            }
            s.seasonGoal = goal
            guard s.day >= goal.endDay else { return ev }
            if !goal.reached { previous = goal.kind }
        }
        let endDay = goalEndDay(s)
        let choices = availableGoals(s, endDay: endDay)
        guard !choices.isEmpty else {
            s.seasonGoal = nil  // nothing to aim for yet; look again tomorrow
            return ev
        }
        // A fresh goal if there is one: not the same kind as the goal that just ended.
        let last = s.seasonGoal?.kind
        let fresh = choices.filter { $0.kind != last }
        let pool = fresh.isEmpty ? choices : fresh
        var rng = jobSeed(s, day: s.day, salt: 0x474F_414C)  // "GOAL"
        let pick = pool[Int.random(in: 0..<pool.count, using: &rng)]
        s.seasonGoal = SeasonGoal(
            kind: pick.kind, startDay: s.day, endDay: endDay, target: pick.target,
            baseline: goalMeasure(pick.kind, in: s))
        ev.append(.seasonGoalSet(pick.kind, previous: previous))
        return ev
    }
}
