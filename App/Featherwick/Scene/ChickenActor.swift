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
/// Reduce Motion: no leg cycle, no peck, no glances. Blinks stay. Frozen for a UI test: no blinks either.
struct AnimatedChicken: View {
    let colours: ChickenColours
    var height: CGFloat
    var facingRight: Bool
    var activity: ChickenActivity

    @Environment(\.sceneMotion) private var motion
    /// Blink and head turn. The task loop animates these; walking and pecking come on top.
    @State private var face: ChickenPose = .rest
    /// When the running peck began. Nil when no peck is running or settling.
    @State private var peckStart: Date?

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
        .task(id: Cue(activity: activity, motion: motion)) { await live(activity) }
    }

    /// The task restarts when either changes.
    private struct Cue: Hashable {
        let activity: ChickenActivity
        let motion: SceneMotion
    }

    /// True while the legs or a peck need a new frame every display refresh.
    private var moving: Bool {
        !motion.isStill && (activity == .walking || peckStart != nil)
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

    /// The bones alone at `date`: no face, no sway.
    private func motion(_ rig: SkeletonRig, at date: Date) -> ChickenPose {
        if activity == .sitting {
            // A pose, not a motion: it holds with Reduce Motion too. Sit down inside `withAnimation` to ease it.
            return ChickenMotion.sitting(rig)
        } else if !motion.isStill && activity == .walking {
            return ChickenMotion.walk(rig, phase: date.timeIntervalSinceReferenceDate / M.stride)
        } else if let peckStart, !motion.isStill {
            return ChickenMotion.peck(rig, progress: date.timeIntervalSince(peckStart) / M.peckDuration)
        }
        return .rest
    }

    /// Runs for as long as the activity lasts: one peck if pecking, then blinks (and glances when idle).
    private func live(_ activity: ChickenActivity) async {
        peckStart = nil
        let canLook: Bool = (activity == .idle || activity == .sitting) && !motion.isStill
        if !canLook && face.headTurn != 0 {
            withAnimation(.easeInOut(duration: M.lookDuration)) { face.headTurn = 0 }
        }
        if activity == .pecking && !motion.isStill {
            peckStart = Date()
            // On past the peck until the loose parts settle: the last frame must have no sway in it.
            guard await pause(M.peckDuration + FluffFollow.settle) else { return }
            peckStart = nil
        }
        guard motion.blinks else { return }
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
