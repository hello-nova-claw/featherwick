import SwiftUI

/// What a chicken is doing. The scene picks it; `AnimatedChicken` acts it out.
enum ChickenActivity: Hashable, Sendable {
    case idle, walking, pecking
    /// On the ground, legs tucked under: a lap chicken by a ripple.
    case sitting
}

/// A chicken (painted or path rig, see `ChickenView`) that moves by itself. Walking cycles the legs.
/// Pecking runs one peck, then stands.
/// Idle, it blinks every few seconds and now and then looks somewhere new. The motions are the shared
/// skeleton's (`ChickenMotion`): planted feet, a high step, a body bounce and a head bob.
///
/// Loose parts (a tail, a wattle, thigh fluff) sway after their bones (`FluffFollow`): the lag is worked out
/// from the same motion a moment earlier, so it needs no state. After a peck, frames run on until it settles.
///
/// Cheap when still. Idle blinks and glances come from a `.task` loop that sleeps between them and sets
/// the pose with `withAnimation`, so nothing redraws in between. Only walking and a running peck use a
/// per-frame `TimelineView`; it is paused at all other times. (A steady redraw once made swiping between
/// farm panels stutter.)
///
/// Reduce Motion: no leg cycle, no peck, no glances. Blinks stay.
struct AnimatedChicken: View {
    let colours: ChickenColours
    var height: CGFloat
    var facingRight: Bool
    var activity: ChickenActivity

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Blink and head turn. The task loop animates these; walking and pecking come on top.
    @State private var face: ChickenPose = .rest
    /// When the running peck began. Nil when no peck is running or settling.
    @State private var peckStart: Date?
    /// When a painted bird's walk began or ended, to ease into and out of it.
    @State private var walk = WalkEase()

    private typealias M = ChickenRigMetrics

    init(colours: ChickenColours, height: CGFloat, facingRight: Bool = true, activity: ChickenActivity = .idle) {
        self.colours = colours
        self.height = height
        self.facingRight = facingRight
        self.activity = activity
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !moving)) { context in
            ChickenView(colours: colours, pose: pose(at: context.date), facingRight: facingRight, height: height)
        }
        .task(id: Cue(activity: activity, reduceMotion: reduceMotion)) { await live(activity) }
    }

    /// The task restarts when either changes.
    private struct Cue: Hashable {
        let activity: ChickenActivity
        let reduceMotion: Bool
    }

    /// True while the legs or a peck need a new frame every display refresh.
    private var moving: Bool {
        !reduceMotion
            && (activity == .walking || peckStart != nil || (ChickenView.rig(for: colours).painted && walk.easing))
    }

    /// The pose for this moment, worked out on the skeleton this bird is drawn with (painted or path):
    /// leg angles depend on its leg lengths.
    private func pose(at date: Date) -> ChickenPose {
        let rig: SkeletonRig = ChickenView.rig(for: colours)
        var pose: ChickenPose = motion(rig, at: date)
        if moving {
            pose.sway = FluffFollow.sway(rig) { ago in motion(rig, at: date.addingTimeInterval(-ago)) }
        }
        pose.headTurn = face.headTurn
        pose.blink = face.blink
        return pose
    }

    /// The bones alone at `date`: no face, no sway. A painted bird's walk eases in from standing and out to
    /// what comes next (`WalkEase`); the path rig starts and stops at once, as it always has.
    private func motion(_ rig: SkeletonRig, at date: Date) -> ChickenPose {
        guard !reduceMotion else { return stillMotion(rig, at: date) }
        let walking: Bool = activity == .walking
        let share: Double = rig.painted ? walk.share(at: date, walking: walking, over: M.walkEase) : walking ? 1 : 0
        guard share > 0 else { return stillMotion(rig, at: date) }
        let walked: ChickenPose = ChickenMotion.walk(
            rig, phase: date.timeIntervalSinceReferenceDate / rig.motion.stride)
        return share >= 1 ? walked : .mix(stillMotion(rig, at: date), walked, t: share)
    }

    /// The bones when not walking: sitting, a running peck, or standing.
    private func stillMotion(_ rig: SkeletonRig, at date: Date) -> ChickenPose {
        if activity == .sitting {
            // A pose, not a motion: it holds with Reduce Motion too. Sit down inside `withAnimation` to ease it.
            return ChickenMotion.sitting(rig)
        } else if let peckStart, !reduceMotion {
            return ChickenMotion.peck(rig, progress: date.timeIntervalSince(peckStart) / M.peckDuration)
        }
        return .rest
    }

    /// Runs for as long as the activity lasts: one peck if pecking, then blinks (and glances when idle).
    private func live(_ activity: ChickenActivity) async {
        peckStart = nil
        if activity == .walking {
            walk.begin(at: Date(), over: M.walkEase)
        } else if walk.start != nil {
            walk.end(at: Date(), over: M.walkEase)
        }
        let canLook: Bool = (activity == .idle || activity == .sitting) && !reduceMotion
        if !canLook && face.headTurn != 0 {
            withAnimation(.easeInOut(duration: M.lookDuration)) { face.headTurn = 0 }
        }
        if activity == .pecking && !reduceMotion {
            peckStart = Date()
            // On past the peck until the loose parts settle: the last frame must have no sway in it.
            guard await pause(M.peckDuration + FluffFollow.settle) else { return }
            peckStart = nil
        }
        if walk.stop != nil {
            // Frames run on until the legs are home and the loose parts settle.
            guard await pause(M.walkEase + FluffFollow.settle) else { return }
            walk.stop = nil
        }
        await blinkAndLook(canLook: canLook)
    }

    /// Each chicken draws its own random gaps, so a flock never blinks together.
    private func blinkAndLook(canLook: Bool) async {
        let half: Double = M.blinkDuration / 2
        while true {
            guard await pause(Double.random(in: M.blinkGap)) else { return }
            withAnimation(.easeIn(duration: half)) { face.blink = 1 }
            let stillRunning: Bool = await pause(half)
            withAnimation(.easeOut(duration: half)) { face.blink = 0 }
            guard stillRunning else { return }
            if canLook && Double.random(in: 0..<1) < M.lookChance {
                let turn: Double = M.lookTurns.randomElement() ?? 0
                withAnimation(.easeInOut(duration: M.lookDuration)) { face.headTurn = turn }
            }
        }
    }

    /// Sleeps. False when the task was cancelled (the activity changed or the view went away).
    private func pause(_ seconds: Double) async -> Bool {
        do {
            try await Task.sleep(for: .seconds(seconds))
            return true
        } catch {
            return false
        }
    }
}

/// When a painted bird's walk began or ended, so it eases in from standing and out to what comes next, over
/// `over` seconds. Pure, so it is tested without a view.
///
/// A walk that turns round part way (it stops while still easing in, or starts again while easing out)
/// carries on from where it was: the share of walk on show never jumps. SwiftUI draws a new activity before
/// the task calls `begin` or `end`, so the share is right before then too.
struct WalkEase: Equatable {
    /// When the walk began, as if eased in from standing. Nil when not walking.
    var start: Date?
    /// When the walk ended, as if eased out from a full walk. Nil once the legs are home.
    var stop: Date?

    /// True while a walk is easing in or out, or has not yet been told it ended.
    var easing: Bool { start != nil || stop != nil }

    /// How much of the walk shows at `date`: 0 standing, 1 walking, eased between.
    func share(at date: Date, walking: Bool, over seconds: Double) -> Double {
        let t: Double
        if walking {
            if let start {
                t = date.timeIntervalSince(start) / seconds
            } else if let stop {
                // Walking again before `begin`: carry on back from where the ease out is.
                t = 1 - date.timeIntervalSince(stop) / seconds
            } else {
                t = 0
            }
        } else if let stop {
            t = 1 - date.timeIntervalSince(stop) / seconds
        } else if let start {
            // Stopped before `end`: as far into the walk as it has eased.
            t = date.timeIntervalSince(start) / seconds
        } else {
            t = 0
        }
        return ChickenMotion.ease(min(1, max(0, t)))
    }

    /// The walk starts at `date`, from where any ease out has got to.
    mutating func begin(at date: Date, over seconds: Double) {
        let shown: Double = stop.map { 1 - min(1, max(0, date.timeIntervalSince($0) / seconds)) } ?? 0
        start = date.addingTimeInterval(-shown * seconds)
        stop = nil
    }

    /// The walk ends at `date`, from where any ease in has got to.
    mutating func end(at date: Date, over seconds: Double) {
        let shown: Double = start.map { min(1, max(0, date.timeIntervalSince($0) / seconds)) } ?? 1
        stop = date.addingTimeInterval(-(1 - shown) * seconds)
        start = nil
    }
}
