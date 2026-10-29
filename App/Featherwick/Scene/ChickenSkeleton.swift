import Foundation

// The chicken skeleton every bird shares. Each rig (the path rig, or a painted kit) gives its own joint
// positions; the motions (`ChickenMotion`) are written once, as bone angles and foot targets, so every build
// walks and pecks the same way at its own proportions. The art rides on the bones: a part names one bone,
// and moves with it and with every bone above it.
//
// Pure maths: no views and no SwiftUI, so it builds and is tested on Linux. `BoneEffect` (in
// `SkeletonEffect.swift`) applies a bone's transform to a view.
//
//   body       tilts at the hip               (the hip lifts and drops: walking bounce, sitting)
//     tail     flicks at its root
//     neckLow  swings at the shoulder
//       neckHigh  bends at mid-neck
//         head    dips at the throat           (comb, beak, eye ride on it)
//   thigh      swings at the hip              (one per leg; the hip carries it)
//     shank    bends at the hock (backwards, as a chicken's does)
//       toes   curl at the foot

/// One bone of the skeleton. Each turns about its own joint, relative to its parent.
enum Bone: Int, CaseIterable, Sendable {
    case body, tail, neckLow, neckHigh, head
    case thighBack, shankBack, toesBack, thighFront, shankFront, toesFront

    var parent: Bone? {
        switch self {
        case .body, .thighBack, .thighFront: nil
        case .tail, .neckLow: .body
        case .neckHigh: .neckLow
        case .head: .neckHigh
        case .shankBack: .thighBack
        case .toesBack: .shankBack
        case .shankFront: .thighFront
        case .toesFront: .shankFront
        }
    }

    /// The leg this bone belongs to, if any.
    var leg: Leg? {
        switch self {
        case .thighBack, .shankBack, .toesBack: .back
        case .thighFront, .shankFront, .toesFront: .front
        default: nil
        }
    }
}

enum Leg: CaseIterable, Sendable {
    case back, front

    var thigh: Bone { self == .back ? .thighBack : .thighFront }
    var shank: Bone { self == .back ? .shankBack : .shankFront }
    var toes: Bone { self == .back ? .toesBack : .toesFront }
}

/// A build's own motion numbers: how far it pecks, how it steps. Degrees and rig heights.
struct SkeletonMotion: Equatable, Sendable {
    var peckBodyTilt: Double
    var peckNeckSwing: Double
    /// The upper neck's own bend at the bottom of a peck. Shared with the lower neck, the neck curves
    /// down instead of folding at one joint, which would tear painted parts apart. The path rig: 0.
    var peckNeckBend: Double
    /// The tail's own turn at the bottom of a peck. Negative lowers it, against the body's tilt, so a big
    /// tilt does not stand the tail on end. The path rig: 0.
    var peckTail: Double = 0
    /// The head's own dip at the bottom of a peck. A rig with no neck bones pecks with this alone.
    var peckHeadDip: Double
    /// Where the throat goes at the bottom of a peck, from where it is at rest (rig units). Set: the head
    /// moves down this straight line and the two neck bones are solved to follow it, as the legs are, so
    /// the head does not swing out in an arc. `peckHeadDip` is then the head's whole turn on screen. Nil: the
    /// neck swings by `peckNeckSwing` and `peckNeckBend` (the path rig).
    var peckReach: CGPoint? = nil
    /// How far the hip drops at the bottom of a peck (rig heights). Bending legs crouch; stiff legs stay.
    var peckCrouch: Double
    var stepLength: Double
    /// Seconds per stride. A slower stride takes longer steps for the same walking speed.
    var stride: Double = ChickenRigMetrics.stride
    /// Where each foot steps while walking: this far behind (back leg) or in front of (front leg) the middle
    /// of the two feet. Small, so the legs pass each other: a kit drawn mid-stride, feet wide apart, still
    /// walks, not shuffles. Standing keeps the drawn feet.
    var footSpread: Double
    var liftShare: Double
    var toeCurl: Double
    var bounce: Double
    var bodyBob: Double
    var headBob: Double
    var tailFlick: Double

    private typealias M = ChickenRigMetrics

    /// The path rig's numbers. A rig with shorter legs takes shorter steps and smaller bounces.
    static func standard(hipHeight: Double) -> SkeletonMotion {
        let k: Double = hipHeight / Double(M.adult.hip.y)
        return SkeletonMotion(
            peckBodyTilt: M.peckBodyTilt, peckNeckSwing: M.peckNeckSwing, peckNeckBend: 0, peckHeadDip: M.peckHeadDip,
            peckCrouch: M.peckCrouch * k,
            stepLength: M.stepLength * k, footSpread: M.footSpread * k, liftShare: M.liftShare, toeCurl: M.toeCurl,
            bounce: M.bounce * k,
            bodyBob: M.bodyBob, headBob: M.headBob, tailFlick: M.tailFlick)
    }
}

/// One rig's skeleton: where each of its bones' joints is at rest (rig units), and where each foot meets
/// the ground. A rig need not have every bone: a part on a missing bone moves with the nearest bone above it.
struct SkeletonRig: Equatable, Sendable {
    var joints: [Bone: CGPoint]
    /// The foot (the top of the toes) of each leg at rest. Leg targets are set for this point.
    var feet: [Leg: CGPoint]
    var motion: SkeletonMotion
    /// How far the hip drops to sit (rig units). Nil: `sitDrop` of the hip's height (the path rig). A
    /// painted kit sets the height of its belly, so the belly rests on the ground.
    var sitHeight: Double? = nil

    /// The body's joint: the hip, where the body tilts.
    var hip: CGPoint { joints[.body] ?? .zero }

    func has(_ bone: Bone) -> Bool { joints[bone] != nil }

    /// A leg bends at the hock when its rig has a shank. A one-piece (stiff) leg only swings at the hip.
    func bends(_ leg: Leg) -> Bool { has(leg.thigh) && has(leg.shank) }

    /// The bone a part on `bone` moves with: the bone itself, or the nearest bone above it in this rig.
    func carrier(of bone: Bone) -> Bone? {
        var next: Bone? = bone
        while let b = next {
            if has(b) { return b }
            next = b.parent
        }
        return nil
    }

    /// The bones a part on `bone` moves with, its own first: the order nested groups apply them.
    func chain(of bone: Bone) -> [Bone] {
        var out: [Bone] = []
        var next: Bone? = carrier(of: bone)
        while let b = next {
            if has(b) { out.append(b) }
            next = b.parent
        }
        return out
    }

    /// The path rig's skeleton, from its build.
    static func path(_ b: ChickenBuild) -> SkeletonRig {
        SkeletonRig(
            joints: [
                .body: b.hip, .tail: b.tailRoot, .neckLow: b.shoulder, .neckHigh: b.neckMid, .head: b.throat,
                .thighBack: b.backHip, .shankBack: b.backHock, .toesBack: b.backFoot,
                .thighFront: b.frontHip, .shankFront: b.frontHock, .toesFront: b.frontFoot,
            ],
            feet: [.back: b.backFoot, .front: b.frontFoot],
            motion: pathMotion(b))
    }

    /// The path rig walks on its own drawn feet: its foot spread is half the gap between them.
    private static func pathMotion(_ b: ChickenBuild) -> SkeletonMotion {
        var motion = SkeletonMotion.standard(hipHeight: Double(b.hip.y))
        motion.footSpread = Double(abs(b.frontFoot.x - b.backFoot.x)) / 2
        return motion
    }

    static let adult = path(ChickenRigMetrics.adult)
    static let chick = path(ChickenRigMetrics.chick)
}

/// A 2D affine transform, `(x, y) -> (a·x + c·y + tx, b·x + d·y + ty)`, as `CGAffineTransform` has it.
struct Affine: Equatable, Sendable {
    var a: Double = 1
    var b: Double = 0
    var c: Double = 0
    var d: Double = 1
    var tx: Double = 0
    var ty: Double = 0

    static let identity = Affine()

    /// Clockwise on screen (y down) by `degrees`, about `p`: what SwiftUI's `rotationEffect` does.
    static func rotation(_ degrees: Double, about p: CGPoint) -> Affine {
        let r: Double = degrees * Double.pi / 180
        let cs: Double = cos(r)
        let sn: Double = sin(r)
        let x: Double = Double(p.x)
        let y: Double = Double(p.y)
        return Affine(a: cs, b: sn, c: -sn, d: cs, tx: x - x * cs + y * sn, ty: y - x * sn - y * cs)
    }

    static func scale(x sx: Double, y sy: Double, about p: CGPoint) -> Affine {
        Affine(a: sx, b: 0, c: 0, d: sy, tx: Double(p.x) * (1 - sx), ty: Double(p.y) * (1 - sy))
    }

    static func translation(x: Double, y: Double) -> Affine { Affine(tx: x, ty: y) }

    /// This transform, then `next`.
    func then(_ n: Affine) -> Affine {
        Affine(
            a: a * n.a + b * n.c, b: a * n.b + b * n.d, c: c * n.a + d * n.c, d: c * n.b + d * n.d,
            tx: tx * n.a + ty * n.c + n.tx, ty: tx * n.b + ty * n.d + n.ty)
    }

    func apply(_ p: CGPoint) -> CGPoint {
        let x: Double = Double(p.x)
        let y: Double = Double(p.y)
        return CGPoint(x: a * x + c * y + tx, y: b * x + d * y + ty)
    }
}

/// A loose part: it sways about `root` (rig units; nil is its bone's joint) by `amount` times its bone's lag.
/// 1 is the full spring; less is stiffer.
struct Follow: Equatable, Sendable {
    var amount: Double
    var root: CGPoint?
}

/// Forward kinematics: where the skeleton puts a part, in the rig's frame (points, y down).
enum Skeleton {
    private typealias M = ChickenRigMetrics

    /// A point in rig units, in the frame of a rig `height` points tall: the ground point is the bottom centre.
    static func frame(_ p: CGPoint, height: Double) -> CGPoint {
        let ground: Double = height * Double(ChickenRigMetrics.widthRatio) / 2
        return CGPoint(x: ground + Double(p.x) * height, y: height - Double(p.y) * height)
    }

    /// The transform for a part on `bone` (nil: on no bone, so only the hip moves it). A loose part
    /// (`follow`) first sways about its root, by its bone's lag (`ChickenPose.sway`). Then its own bone
    /// turns, then each bone above it. The hip's lift carries the body, and the legs when they can bend; a
    /// stiff leg stays on the ground and squashes down instead when the bird sits.
    static func transform(
        of bone: Bone?, rig: SkeletonRig, pose: ChickenPose, height: Double, follow: Follow? = nil
    ) -> Affine {
        let chain: [Bone] = bone.map(rig.chain(of:)) ?? []
        var t: Affine = .identity
        if let follow, let carrier = chain.first, let root = follow.root ?? rig.joints[carrier] {
            let lag: Double = min(M.followMax, max(-M.followMax, pose.sway[carrier.rawValue]))
            t = .rotation(follow.amount * lag, about: frame(root, height: height))
        }
        for link in chain {
            guard let joint = rig.joints[link] else { continue }
            let pivot: CGPoint = frame(joint, height: height)
            t = t.then(.rotation(pose[link], about: pivot))
            if let leg = link.leg, link == leg.thigh, !rig.bends(leg) {
                // Never exactly 0: a flat scale has no inverse.
                let squash: Double = max(0.01, 1 - min(1, max(0, pose.sit)) * ChickenRigMetrics.sitDrop)
                t = t.then(.scale(x: 1, y: squash, about: frame(CGPoint(x: joint.x, y: 0), height: height)))
            }
        }
        let leg: Leg? = chain.last?.leg
        if leg.map(rig.bends) ?? true {
            t = t.then(.translation(x: 0, y: -pose.rise * height))
        }
        return t
    }

    /// A point on a part riding `bone` (rig units in and out, y up): for tests and for placing things.
    static func place(
        _ p: CGPoint, on bone: Bone?, rig: SkeletonRig, pose: ChickenPose, follow: Follow? = nil
    ) -> CGPoint {
        let h: Double = 1
        let moved: CGPoint = transform(of: bone, rig: rig, pose: pose, height: h, follow: follow)
            .apply(frame(p, height: h))
        let ground: Double = Double(ChickenRigMetrics.widthRatio) / 2
        return CGPoint(x: Double(moved.x) - ground, y: h - Double(moved.y))
    }
}

/// The motions, written once for every rig: each gives a pose for one rig at one moment. Legs are placed,
/// not swung: a foot target is set and the leg angles are solved (two-bone inverse kinematics), so a planted
/// foot stays planted while the body bounces, and a bird with longer legs simply takes the same steps.
enum ChickenMotion {
    private typealias M = ChickenRigMetrics

    /// Walking. `phase` counts strides: each whole number is the start of a stride. Each foot is planted for
    /// `stance` of its cycle, sliding back under the body as it walks on, then lifts high with its toes
    /// curled and swings forward. The legs are half a stride apart. The body rises over each planted foot and
    /// rocks; the head holds still, then thrusts forward, once a step; the tail flicks.
    static func walk(_ rig: SkeletonRig, phase: Double) -> ChickenPose {
        let m: SkeletonMotion = rig.motion
        let p: Double = fraction(phase)
        var pose = ChickenPose()
        // Two bumps a stride, at the middle of each foot's stance (the back foot's is at 0.3).
        pose.rise = m.bounce * 0.5 * (1 + cos(4 * Double.pi * (p - M.stance / 2)))
        pose[.body] = m.bodyBob * sin(4 * Double.pi * p)
        pose[.tail] = m.tailFlick * sin(4 * Double.pi * p + 1)
        for (leg, offset) in [(Leg.back, 0.0), (Leg.front, 0.5)] {
            place(leg, at: fraction(p + offset), rig: rig, pose: &pose)
        }
        headBob(rig, step: fraction(2 * p), pose: &pose)
        return pose
    }

    /// One peck. `progress` runs from 0 (standing) to 1 (back up). The hip crouches, the body tips at the hip,
    /// the neck swings down, and the head dips, then all come back. The feet stay planted.
    static func peck(_ rig: SkeletonRig, progress: Double) -> ChickenPose {
        let p: Double = min(1, max(0, progress))
        let up: Double = M.peckDown + M.peckHold
        let depth: Double
        if p < M.peckDown {
            depth = ease(p / M.peckDown)
        } else if p < up {
            depth = 1
        } else {
            depth = 1 - ease((p - up) / (1 - up))
        }
        var pose = ChickenPose()
        pose[.body] = depth * rig.motion.peckBodyTilt
        pose[.neckLow] = depth * rig.motion.peckNeckSwing
        pose[.neckHigh] = depth * rig.motion.peckNeckBend
        pose[.tail] = depth * rig.motion.peckTail
        pose[.head] = depth * rig.motion.peckHeadDip
        pose.rise = -depth * rig.motion.peckCrouch
        if let reach = rig.motion.peckReach {
            reachNeck(rig, by: reach, depth: depth, pose: &pose)
            pose[.head] = depth * rig.motion.peckHeadDip - pose[.body] - pose[.neckLow] - pose[.neckHigh]
        }
        for leg in Leg.allCases {
            guard let foot = rig.feet[leg] else { continue }
            solve(leg, target: foot, curl: 0, rig: rig, pose: &pose)
        }
        return pose
    }

    /// Sitting (`amount` 1) or part way down: the hip drops by `sitHeight` (or `sitDrop` of its height) and
    /// the legs fold under it, feet where they stood. A stiff leg squashes instead (see `Skeleton.transform`).
    static func sitting(_ rig: SkeletonRig, amount: Double = 1) -> ChickenPose {
        let s: Double = min(1, max(0, amount))
        var pose = ChickenPose()
        pose.sit = s
        pose.rise = -s * (rig.sitHeight ?? M.sitDrop * Double(rig.hip.y))
        for leg in Leg.allCases {
            guard let foot = rig.feet[leg] else { continue }
            solve(leg, target: foot, curl: 0, rig: rig, pose: &pose)
        }
        return pose
    }

    // MARK: - Legs

    /// A leg at `u` (0..<1) of its own cycle: planted and sliding back, then lifted and swinging forward.
    private static func place(_ leg: Leg, at u: Double, rig: SkeletonRig, pose: inout ChickenPose) {
        guard let drawn = rig.feet[leg] else { return }
        let m: SkeletonMotion = rig.motion
        let feet: [CGPoint] = Leg.allCases.compactMap { rig.feet[$0] }
        let middle: Double = feet.map { Double($0.x) }.reduce(0, +) / Double(feet.count)
        // One foot has no pair to step apart from, so it steps around where it is drawn.
        let spread: Double = feet.count > 1 ? m.footSpread : 0
        let foot = CGPoint(x: middle + (leg == .back ? -spread : spread), y: Double(drawn.y))
        let half: Double = m.stepLength / 2
        let lift: Double = m.liftShare * Double(rig.hip.y)
        let target: CGPoint
        let curl: Double
        if u < M.stance {
            let s: Double = u / M.stance
            target = CGPoint(x: Double(foot.x) + half - 2 * half * s, y: Double(foot.y))
            curl = 0
        } else {
            let s: Double = (u - M.stance) / (1 - M.stance)
            let arc: Double = sin(Double.pi * s)
            target = CGPoint(x: Double(foot.x) - half + 2 * half * ease(s), y: Double(foot.y) + lift * arc)
            curl = m.toeCurl * arc
        }
        solve(leg, target: target, curl: curl, rig: rig, pose: &pose)
    }

    /// Sets the leg's angles so its foot reaches `target` (rig units) from the hip, lifted by `pose.rise`.
    /// The toes stay flat on the ground, plus `curl`. A stiff leg only points at the target.
    static func solve(_ leg: Leg, target: CGPoint, curl: Double, rig: SkeletonRig, pose: inout ChickenPose) {
        guard let hip0 = rig.joints[leg.thigh], let foot0 = rig.feet[leg] else { return }
        guard rig.bends(leg), let hock0 = rig.joints[leg.shank] else {
            // Stiff: the leg turns at the hip to point at the target. It does not ride the hip's lift.
            pose[leg.thigh] = -degrees(angle(from: hip0, to: target) - angle(from: hip0, to: foot0))
            return
        }
        let hip = CGPoint(x: hip0.x, y: hip0.y + CGFloat(pose.rise))
        let a: Double = distance(hip0, hock0)
        let b: Double = distance(hock0, foot0)
        let reach: Double = min(a + b - 1e-6, max(abs(a - b) + 1e-6, distance(hip, target)))
        let toTarget: Double = angle(from: hip, to: target)
        let spread: Double = acos(min(1, max(-1, (a * a + reach * reach - b * b) / (2 * a * reach))))
        // The hock bends to the same side it does at rest (backwards).
        let side: Double = cross(sub(foot0, hip0), sub(hock0, hip0)) >= 0 ? 1 : -1
        let thighAngle: Double = toTarget + side * spread
        let hock = CGPoint(x: Double(hip.x) + a * cos(thighAngle), y: Double(hip.y) + a * sin(thighAngle))
        let shankAngle: Double = angle(from: hock, to: target)
        let thighTurn: Double = thighAngle - angle(from: hip0, to: hock0)
        let shankTurn: Double = shankAngle - angle(from: hock0, to: foot0)
        // Clockwise on screen is positive, so a turn up (counter-clockwise, y up) is negative.
        pose[leg.thigh] = -degrees(thighTurn)
        pose[leg.shank] = -degrees(shankTurn - thighTurn)
        if rig.has(leg.toes) { pose[leg.toes] = degrees(shankTurn) + curl }
    }

    /// Solves the two neck bones for a peck `depth` of the way down. At the bottom the throat is `by` (rig
    /// units) from its rest place. On the way, the throat goes round the base of the neck (wherever the
    /// body has put it), its distance from the base shrinking a little at halfway (`peckTuck`), so the head
    /// neither swings out forward nor folds the neck. The neck bends to the same side it does at rest.
    private static func reachNeck(_ rig: SkeletonRig, by offset: CGPoint, depth: Double, pose: inout ChickenPose) {
        guard let low0 = rig.joints[.neckLow], let mid0 = rig.joints[.neckHigh], let throat0 = rig.joints[.head]
        else { return }
        var bottom = ChickenPose()
        bottom[.body] = rig.motion.peckBodyTilt
        bottom.rise = -rig.motion.peckCrouch
        let baseAtBottom: CGPoint = Skeleton.place(low0, on: .body, rig: rig, pose: bottom)
        let goal = CGPoint(x: throat0.x + offset.x, y: throat0.y + offset.y)
        let fromAngle: Double = angle(from: low0, to: throat0)
        let turn: Double = wrap(angle(from: baseAtBottom, to: goal) - fromAngle)
        let fromLength: Double = distance(low0, throat0)
        let toLength: Double = distance(baseAtBottom, goal)
        let length: Double = (fromLength + depth * (toLength - fromLength)) * (1 - M.peckTuck * sin(Double.pi * depth))
        let direction: Double = fromAngle + depth * turn
        let base: CGPoint = Skeleton.place(low0, on: .body, rig: rig, pose: pose)
        let target = CGPoint(x: Double(base.x) + length * cos(direction), y: Double(base.y) + length * sin(direction))
        let a: Double = distance(low0, mid0)
        let b: Double = distance(mid0, throat0)
        let reach: Double = min(a + b - 1e-6, max(abs(a - b) + 1e-6, distance(base, target)))
        let spread: Double = acos(min(1, max(-1, (a * a + reach * reach - b * b) / (2 * a * reach))))
        let side: Double = cross(sub(throat0, low0), sub(mid0, low0)) >= 0 ? 1 : -1
        let lowAngle: Double = angle(from: base, to: target) + side * spread
        let mid = CGPoint(x: Double(base.x) + a * cos(lowAngle), y: Double(base.y) + a * sin(lowAngle))
        let highAngle: Double = angle(from: mid, to: target)
        let lowTurn: Double = wrap(lowAngle - angle(from: low0, to: mid0))
        let highTurn: Double = wrap(highAngle - angle(from: mid0, to: throat0))
        // Clockwise on screen is positive. The body's tilt already turns the neck, so take it off.
        pose[.neckLow] = -degrees(lowTurn) - pose[.body]
        pose[.neckHigh] = -degrees(wrap(highTurn - lowTurn))
    }

    // MARK: - Head

    /// The head bob, once a step: it holds still while the body walks on (sliding back on the bird), then
    /// thrusts forward. The lower neck swings it, and the head turns back by the same angle so it stays level
    /// and never leaves its neck. A rig without both bones does not bob.
    private static func headBob(_ rig: SkeletonRig, step t: Double, pose: inout ChickenPose) {
        guard let shoulder = rig.joints[.neckLow], let throat = rig.joints[.head] else { return }
        let length: Double = max(0.01, distance(shoulder, throat))
        let hold: Double = M.headHold
        let slide: Double
        if t < hold {
            slide = rig.motion.headBob * (0.5 - t / hold)
        } else {
            slide = rig.motion.headBob * (-0.5 + ease((t - hold) / (1 - hold)))
        }
        // A forward slide is a clockwise swing of the neck (for a head above and in front of the shoulder).
        let swing: Double = degrees(slide / length)
        pose[.neckLow] += swing
        pose[.head] -= swing
    }

    // MARK: - Helpers

    /// Smooth start and stop.
    static func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }

    private static func fraction(_ x: Double) -> Double { x - x.rounded(.down) }

    /// An angle in radians brought into -π...π, so a turn never goes the long way round.
    private static func wrap(_ a: Double) -> Double { remainder(a, 2 * Double.pi) }

    private static func degrees(_ radians: Double) -> Double {
        var d: Double = radians * 180 / Double.pi
        while d > 180 { d -= 360 }
        while d < -180 { d += 360 }
        return d
    }

    private static func angle(from p: CGPoint, to q: CGPoint) -> Double { atan2(Double(q.y - p.y), Double(q.x - p.x)) }

    private static func distance(_ p: CGPoint, _ q: CGPoint) -> Double { hypot(Double(q.x - p.x), Double(q.y - p.y)) }

    private static func sub(_ p: CGPoint, _ q: CGPoint) -> CGPoint { CGPoint(x: p.x - q.x, y: p.y - q.y) }

    private static func cross(_ u: CGPoint, _ v: CGPoint) -> Double { Double(u.x * v.y - u.y * v.x) }
}

/// Fluff follow: how far each bone's loose parts lag behind it. A loose part is a damped spring on its bone.
/// The spring's output is a weighted mean of where the bone pointed over the last `followWindow` seconds,
/// so it needs no state: give it the motion as a function of time and it works out the lag for any moment.
/// A bone that has not turned in the window has no lag, so a still bird sways not at all.
enum FluffFollow {
    private typealias M = ChickenRigMetrics

    /// The spring's response to a sudden turn, sampled every `followStep` seconds back from now, scaled to
    /// add up to 1 (so a bone that holds still gives exactly its own angle).
    static let weights: [Double] = {
        let w: Double = 2 * Double.pi * M.followHz
        let z: Double = M.followDamping
        let wd: Double = w * (1 - z * z).squareRoot()
        let count: Int = Int((M.followWindow / M.followStep).rounded())
        let raw: [Double] = (0...count).map { k in
            let t: Double = Double(k) * M.followStep
            return exp(-z * w * t) * sin(wd * t)
        }
        let total: Double = raw.reduce(0, +)
        return raw.map { $0 / total }
    }()

    /// Each bone's lag at this moment, in degrees, in `Bone.allCases` order. `motion(s)` is the pose `s`
    /// seconds ago (0 is now). A bone's turn is its whole turn on screen: its own angle and every one above.
    static func sway(_ rig: SkeletonRig, motion: (Double) -> ChickenPose) -> [Double] {
        var spring: [Double] = Array(repeating: 0, count: Bone.allCases.count)
        var now: [Double] = spring
        for (k, weight) in weights.enumerated() {
            let pose: ChickenPose = motion(Double(k) * M.followStep)
            for bone in Bone.allCases where rig.has(bone) {
                let turn: Double = rig.chain(of: bone).reduce(0) { $0 + pose[$1] }
                spring[bone.rawValue] += weight * turn
                if k == 0 { now[bone.rawValue] = turn }
            }
        }
        return zip(spring, now).map { $0 - $1 }
    }

    /// Seconds the spring takes to settle after the bone stops: keep drawing frames this long after a motion.
    static var settle: Double { M.followWindow }
}

/// A pose as a list of numbers that SwiftUI can interpolate (`VectorArithmetic`, in `SkeletonEffect.swift`).
/// Lists of different lengths add as if the shorter one ended in zeros, so `zero` can be empty.
struct PoseVector: AdditiveArithmetic, Sendable {
    var values: [Double]

    init(_ values: [Double]) { self.values = values }

    static let zero = PoseVector([])

    static func + (l: PoseVector, r: PoseVector) -> PoseVector { combine(l, r, +) }
    static func - (l: PoseVector, r: PoseVector) -> PoseVector { combine(l, r, -) }

    mutating func scale(by rhs: Double) { values = values.map { $0 * rhs } }

    var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }

    static func == (l: PoseVector, r: PoseVector) -> Bool {
        let n: Int = max(l.values.count, r.values.count)
        return (0..<n).allSatisfy { i in l.value(i) == r.value(i) }
    }

    private func value(_ i: Int) -> Double { i < values.count ? values[i] : 0 }

    private static func combine(_ l: PoseVector, _ r: PoseVector, _ f: (Double, Double) -> Double) -> PoseVector {
        let n: Int = max(l.values.count, r.values.count)
        return PoseVector((0..<n).map { i in f(l.value(i), r.value(i)) })
    }
}
