import FeatherwickCore
import FeatherwickText
import SwiftUI

// MARK: - Today: the day's jobs and the season goal

/// Today's jobs, ticked as the keeper does them, and the season's bigger goal with its progress.
/// Nothing here can be failed: a job left undone simply goes in the morning.
struct JobsSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        let s = store.state
        let jobs = s.todaysJobs
        SheetPage(context: "Day \(s.day), \(s.season.rawValue)") {
            Text("Today").font(Typeface.title)
            if jobs.isEmpty {
                Text("No jobs yet. New ones come each morning.")
                    .font(Typeface.body).foregroundStyle(palette.inkSoft)
            } else {
                VStack(alignment: .leading, spacing: Space.m) {
                    ForEach(Array(jobs.enumerated()), id: \.offset) { _, job in
                        JobRow(text: jobText(job, s), done: job.isDone)
                    }
                }
                Text(rewardLine(s)).font(Typeface.label).foregroundStyle(palette.inkMuted)
            }
            StitchDivider()
            Text("This season").font(Typeface.title2)
            if let goal = s.seasonGoal {
                GoalBlock(goal: goal)
            } else {
                Text("No goal yet. One comes when there is something to aim for.")
                    .font(Typeface.body).foregroundStyle(palette.inkSoft)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func rewardLine(_ s: GameState) -> String {
        let coins = s.rules.jobsRewardCoins
        if s.todaysJobsRewarded { return "All done. Well done! (+\(coins) coins)" }
        return "Do them all for \(coins) coins. Any you skip simply go tomorrow."
    }
}

/// One job: a filled dab when it is done, a dashed circle while it waits.
struct JobRow: View {
    @Environment(\.palette) private var palette
    let text: String
    let done: Bool

    var body: some View {
        HStack(spacing: Space.m) {
            if done { Dab(colour: palette.inkMuted, size: 18) } else { UnknownDot(size: 18) }
            Text(text).font(Typeface.item)
                .foregroundStyle(done ? palette.inkMuted : palette.ink)
                .strikethrough(done, color: palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(text), \(done ? "done" : "to do")")
    }
}

/// The season goal: what to aim for, a dab for each step (when there are few), and "2 of 3".
struct GoalBlock: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    let goal: SeasonGoal

    var body: some View {
        let s = store.state
        let progress = s.progress(of: goal)
        VStack(alignment: .leading, spacing: Space.s) {
            Text(seasonGoalText(goal, s)).font(Typeface.item)
            HStack(spacing: Space.s) {
                if goal.target <= 8 {
                    HStack(spacing: Space.xs) {
                        ForEach(0..<goal.target, id: \.self) { i in
                            if i < progress { Dab(colour: Pigment.buffNotice) } else { UnknownDot() }
                        }
                    }
                    .accessibilityHidden(true)
                }
                Text(seasonGoalProgressText(goal, s)).font(Typeface.number).monospacedDigit()
            }
            Text(detailLine(s)).font(Typeface.label).foregroundStyle(palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func detailLine(_ s: GameState) -> String {
        let coins = s.rules.seasonGoalRewardCoins
        if goal.reached { return "Reached! You earned \(coins) coins. A new goal comes next season." }
        return "Until day \(goal.endDay), for \(coins) coins. If it waits, a new goal comes. No hurry."
    }
}

/// The farm's "Today" button: the word, and how many of today's jobs are left (a dab once all are done).
struct TodayButtonLabel: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        let jobs = store.state.todaysJobs
        let left = jobs.count(where: { !$0.isDone })
        HStack(spacing: Space.s) {
            Text("Today").font(Typeface.display(23, relativeTo: .title2))
            if left > 0 {
                Text("\(left)").font(Typeface.number).monospacedDigit()
                    .frame(minWidth: 22, minHeight: 22)
                    .background(Circle().fill(Pigment.buffNotice))
            } else if !jobs.isEmpty {
                Dab(colour: palette.inkMuted, size: 12)
            }
        }
        .padding(.horizontal, Space.m)
        .frame(minHeight: 56)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(jobs: jobs.count, left: left))
    }

    private func accessibilityText(jobs: Int, left: Int) -> String {
        if jobs == 0 { return "Today" }
        if left == 0 { return "Today, all jobs done" }
        return "Today, \(left) of \(jobs) job\(jobs == 1 ? "" : "s") left"
    }
}
