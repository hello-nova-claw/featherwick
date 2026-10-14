import Foundation

// The chicken skeleton's builds, numbers and pose. Pure values and functions: no views, no clock, no state,
// and no SwiftUI, so the skeleton maths builds and is tested on Linux too (see `ChickenSkeleton.swift`).
//
// Angles are in degrees and follow SwiftUI's `rotationEffect` on a bird that faces right: a positive angle
// turns clockwise on screen. So a positive body tilt or neck swing moves the head forward and down, a
// positive thigh angle swings the leg back, and a positive hock angle swings the foot back and up.

/// Where each joint of the path rig is, and how far every part reaches.
/// Rig units: x is right of the ground point, y is up from the ground, both in rig heights.
/// The ground point is between the feet, at the bottom centre of the rig's frame.
struct ChickenBuild: Equatable, Sendable {
    /// Chicks have no comb, wattle or tail, and a round body.
    let isChick: Bool

    // Legs. Each leg is a thigh (the feathered drumstick) from the hip down to the hock, a bare shank from
    // the hock down to the foot, and toes along the ground from the foot. The hock bends backwards.
    let backHip: CGPoint
    let frontHip: CGPoint
    let backHock: CGPoint
    let frontHock: CGPoint
    /// Where the shank meets the toes, just above the ground.
    let backFoot: CGPoint
    let frontFoot: CGPoint
    let legWidth: CGFloat
    /// The drumstick's width and height, around the middle of the thigh.
    let thighSize: CGSize
    /// Toe length in front of the foot, and the short back toe.
    let toe: CGFloat
    let backToe: CGFloat

    // Body: tilts about `hip` to peck. Tail and wing ride on it.
    let hip: CGPoint
    let bodyCentre: CGPoint
    let bodySize: CGSize
    let wingCentre: CGPoint
    let wingSize: CGSize
    /// A four-point fan, base to tip. Empty for chicks.
    let tail: [CGPoint]
    /// The tail flicks about this point.
    let tailRoot: CGPoint

    // Neck: the lower neck swings about `shoulder`, the upper neck about `neckMid`. Rides on the body.
    let shoulder: CGPoint
    let neckMid: CGPoint
    /// Four points: base back, base front, top front, top back.
    let neck: [CGPoint]

    // Head: dips about `throat`, on the upper neck. It turns (looks) about `headCentre`.
    let throat: CGPoint
    let headCentre: CGPoint
    let headRadius: CGFloat
    /// Three points: top of the base, bottom of the base, tip.
    let beak: [CGPoint]
    let eyeCentre: CGPoint
    let eyeRadius: CGFloat
    /// Comb bumps along the top of the head. The comb grows from `combBase`.
    let combBumps: [CGPoint]
    let combBumpRadius: CGFloat
    let combBase: CGPoint
    let wattleCentre: CGPoint
    let wattleSize: CGSize
    /// Little down tufts on a chick's head.
    let tufts: [CGPoint]
    let tuftRadius: CGFloat

    /// The eyelid covers this square around the eye when fully shut.
    var eyelidReach: CGFloat { eyeRadius * 1.4 }
    /// The wattle hangs from its top edge, so it grows down from there.
    var wattleTop: CGPoint { CGPoint(x: wattleCentre.x, y: wattleCentre.y + wattleSize.height / 2) }
    /// The eyelid grows down from its top edge.
    var eyelidTop: CGPoint { CGPoint(x: eyeCentre.x, y: eyeCentre.y + eyelidReach) }
}

/// Every number of the chicken rig and its motions, in one place.
enum ChickenRigMetrics {
    /// The rig's frame is this many rig heights wide (tail to beak, with room to peck).
    static let widthRatio: CGFloat = 1.2

    /// A grower or adult, facing right.
    static let adult = ChickenBuild(
        isChick: false,
        backHip: CGPoint(x: -0.04, y: 0.40), frontHip: CGPoint(x: 0.04, y: 0.40),
        // Bent at rest, as a chicken stands: room for the hip to bounce and the feet to step without
        // straightening the leg.
        backHock: CGPoint(x: -0.12, y: 0.23), frontHock: CGPoint(x: -0.04, y: 0.23),
        backFoot: CGPoint(x: -0.04, y: 0.03), frontFoot: CGPoint(x: 0.04, y: 0.03),
        legWidth: 0.035, thighSize: CGSize(width: 0.10, height: 0.17), toe: 0.10, backToe: 0.04,
        hip: CGPoint(x: 0, y: 0.40),
        bodyCentre: CGPoint(x: -0.05, y: 0.54), bodySize: CGSize(width: 0.60, height: 0.38),
        wingCentre: CGPoint(x: -0.08, y: 0.54), wingSize: CGSize(width: 0.34, height: 0.20),
        tail: [
            CGPoint(x: -0.22, y: 0.70), CGPoint(x: -0.40, y: 0.90), CGPoint(x: -0.47, y: 0.80),
            CGPoint(x: -0.32, y: 0.52),
        ],
        tailRoot: CGPoint(x: -0.24, y: 0.62),
        shoulder: CGPoint(x: 0.16, y: 0.64), neckMid: CGPoint(x: 0.22, y: 0.74),
        neck: [
            CGPoint(x: 0.06, y: 0.60), CGPoint(x: 0.24, y: 0.62), CGPoint(x: 0.30, y: 0.84), CGPoint(x: 0.17, y: 0.88),
        ],
        throat: CGPoint(x: 0.25, y: 0.80),
        headCentre: CGPoint(x: 0.24, y: 0.86), headRadius: 0.085,
        beak: [CGPoint(x: 0.31, y: 0.885), CGPoint(x: 0.31, y: 0.845), CGPoint(x: 0.385, y: 0.862)],
        eyeCentre: CGPoint(x: 0.26, y: 0.875), eyeRadius: 0.017,
        combBumps: [CGPoint(x: 0.19, y: 0.94), CGPoint(x: 0.235, y: 0.96), CGPoint(x: 0.28, y: 0.94)],
        combBumpRadius: 0.032, combBase: CGPoint(x: 0.235, y: 0.925),
        wattleCentre: CGPoint(x: 0.31, y: 0.80), wattleSize: CGSize(width: 0.045, height: 0.075),
        tufts: [], tuftRadius: 0)

    /// A chick, facing right: a round ball of down on short legs, with a big head.
    static let chick = ChickenBuild(
        isChick: true,
        backHip: CGPoint(x: -0.05, y: 0.14), frontHip: CGPoint(x: 0.05, y: 0.14),
        backHock: CGPoint(x: -0.09, y: 0.08), frontHock: CGPoint(x: 0.01, y: 0.08),
        backFoot: CGPoint(x: -0.05, y: 0.02), frontFoot: CGPoint(x: 0.05, y: 0.02),
        legWidth: 0.03, thighSize: CGSize(width: 0.08, height: 0.08), toe: 0.06, backToe: 0.025,
        hip: CGPoint(x: 0, y: 0.14),
        bodyCentre: CGPoint(x: -0.02, y: 0.40), bodySize: CGSize(width: 0.60, height: 0.56),
        wingCentre: CGPoint(x: -0.06, y: 0.40), wingSize: CGSize(width: 0.30, height: 0.20),
        tail: [], tailRoot: CGPoint(x: -0.28, y: 0.40),
        shoulder: CGPoint(x: 0.10, y: 0.56), neckMid: CGPoint(x: 0.14, y: 0.62),
        neck: [
            CGPoint(x: 0.02, y: 0.55), CGPoint(x: 0.20, y: 0.52), CGPoint(x: 0.26, y: 0.70), CGPoint(x: 0.08, y: 0.74),
        ],
        throat: CGPoint(x: 0.20, y: 0.60),
        headCentre: CGPoint(x: 0.18, y: 0.72), headRadius: 0.17,
        beak: [CGPoint(x: 0.335, y: 0.745), CGPoint(x: 0.335, y: 0.705), CGPoint(x: 0.40, y: 0.725)],
        eyeCentre: CGPoint(x: 0.24, y: 0.76), eyeRadius: 0.028,
        combBumps: [], combBumpRadius: 0, combBase: CGPoint(x: 0.18, y: 0.89),
        wattleCentre: CGPoint(x: 0.33, y: 0.68), wattleSize: .zero,
        tufts: [CGPoint(x: 0.12, y: 0.88), CGPoint(x: 0.17, y: 0.90), CGPoint(x: 0.22, y: 0.885)],
        tuftRadius: 0.03)

    // Walking. One stride is one step of each leg. The feet are placed (inverse kinematics), not swung.
    /// Seconds per stride.
    static let stride: Double = 0.6
    /// The part of a leg's cycle its foot is on the ground. The rest it lifts and swings forward.
    static let stance: Double = 0.6
    /// How far a planted foot slides back under the body in one stance, in rig heights, for a grown bird.
    /// Matched to the scene's walking speed (about 0.4 heights a second), so the feet do not skate.
    static let stepLength: Double = 0.16
    /// While walking, a painted kit's feet step this far behind or in front of the middle of its two feet (rig
    /// heights, for a grown bird), whatever their drawn gap. The path rig steps on its own drawn feet.
    static let footSpread: Double = 0.04
    /// How high a foot lifts at the top of its swing, as a part of the hip's height: a high, deliberate step.
    static let liftShare: Double = 0.32
    /// Degrees the toes curl under while the foot is in the air.
    static let toeCurl: Double = 50
    /// The body rises this much (rig heights) over each planted foot, and rocks this many degrees.
    static let bounce: Double = 0.012
    static let bodyBob: Double = 2
    /// The head bob: it holds still while the body walks on, then thrusts forward. How far it moves (rig
    /// heights), and the part of each step spent holding. The lower neck swings it; the head turns back by
    /// the same angle, so it stays level and never leaves its neck.
    static let headBob: Double = 0.06
    static let headHold: Double = 0.7
    /// Degrees the tail flicks on each step.
    static let tailFlick: Double = 4

    // Pecking.
    /// Seconds for one peck, down and back up.
    static let peckDuration: Double = 0.6
    /// Degrees at the bottom of a peck, and how far the hip crouches (rig heights; the legs bend, the feet
    /// stay). With all four, an adult's beak reaches the ground: a tall bird has to crouch to peck.
    static let peckBodyTilt: Double = 42
    static let peckNeckSwing: Double = 88
    static let peckHeadDip: Double = 10
    static let peckCrouch: Double = 0.12
    /// A kit that pecks by reach (`peckReach`): how much nearer the base of the neck the head comes at
    /// halfway down, as a part of the neck's length. Keeps the head from swinging out forward.
    static let peckTuck: Double = 0.25
    /// Parts of the peck: going down, then holding at the bottom. The rest comes back up.
    static let peckDown: Double = 0.4
    static let peckHold: Double = 0.15

    // Sitting.
    /// How far the hip drops to sit, as a part of its standing height. The body then rests on the ground
    /// and the legs fold under it.
    static let sitDrop: Double = 0.85
    /// Seconds to sit down, or to get up.
    static let sitDuration: Double = 0.3

    // Fluff follow. A loose part (a tail, a wattle, thigh fluff) is a damped spring on its bone: it lags
    // behind each turn, swings a little past, and settles. See `FluffFollow`.
    /// The spring's swing, in swings a second, and its damping (0 swings for ever, 1 does not swing past).
    static let followHz: Double = 3
    static let followDamping: Double = 0.4
    /// The spring looks back this far, in samples this far apart (seconds). Past it the swing is gone.
    static let followWindow: Double = 0.5
    static let followStep: Double = 1.0 / 30
    /// A part never lags more than this many degrees behind its bone, however fast the bone turns.
    static let followMax: Double = 20
    /// How loose each path rig part is: 1 is the full spring, 0 is stiff.
    static let tailFollow: Double = 1
    static let wattleFollow: Double = 1
    static let thighFollow: Double = 0.25
    static let wingFollow: Double = 0.35

    // Looking. The face (beak, eye, comb) narrows as the head turns to the viewer.
    /// Face width when the bird looks straight at the viewer.
    static let frontFaceScale: Double = 0.45
    /// Where an idle bird may look, from -1 (back) to 1 (at the viewer).
    static let lookTurns: [Double] = [-1, -0.5, 0, 0, 0.6, 1]
    /// After a blink, the chance that an idle bird looks somewhere new.
    static let lookChance: Double = 0.35
    static let lookDuration: Double = 0.35

    // Blinking.
    /// Seconds between blinks, a new random gap each time.
    static let blinkGap: ClosedRange<Double> = 3...6
    /// Seconds for one blink, shut and open again.
    static let blinkDuration: Double = 0.16
}

/// The skeleton at one moment: an angle for every bone, and a few moves that are not turns. Every motion is a
/// sequence of these. A pose is worked out for one rig (`ChickenMotion`): leg angles depend on leg lengths.
struct ChickenPose: Equatable, Sendable {
    /// Degrees for each bone, in `Bone.allCases` order. Each bone turns about its own joint, relative to its
    /// parent: a shank angle bends the hock, on top of the thigh's angle.
    var angles: [Double] = Array(repeating: 0, count: Bone.allCases.count)
    /// The hip lifts by this much (rig heights, up). It carries the body, and the legs when they bend.
    var rise: Double = 0
    /// -1 looks back, 0 is side profile, 1 looks at the viewer.
    var headTurn: Double = 0
    /// 0 is open, 1 is shut: how far the eyelid has grown down over the eye.
    var blink: Double = 0
    /// 0 stands, 1 sits. A one-piece (stiff) leg cannot bend, so it squashes to the ground instead.
    var sit: Double = 0
    /// Degrees each bone's loose parts lag behind it (`FluffFollow`), in `Bone.allCases` order. A part turns
    /// by this times its own `Follow.amount`. All 0 when the bird is still.
    var sway: [Double] = Array(repeating: 0, count: Bone.allCases.count)

    /// Standing still, looking ahead, eyes open.
    static let rest = ChickenPose()

    subscript(bone: Bone) -> Double {
        get { angles[bone.rawValue] }
        set { angles[bone.rawValue] = newValue }
    }

    /// How wide the face is drawn for `headTurn`: 1 in profile, narrower towards the viewer, and
    /// negative (mirrored, beak pointing back) when looking back. It passes 0 as the beak turns away.
    var faceScale: Double {
        let t: Double = min(1, max(-1, headTurn))
        if t < 0 { return cos(t * Double.pi) }
        return 1 - (1 - ChickenRigMetrics.frontFaceScale) * t
    }

    /// The pose part way from `a` (t = 0) to `b` (t = 1), value by value.
    static func mix(_ a: ChickenPose, _ b: ChickenPose, t: Double) -> ChickenPose {
        ChickenPose(vector: zip(a.vector, b.vector).map { x, y in x + (y - x) * t })
    }

    /// Every value in one list, for animation: SwiftUI interpolates the list (see `PoseVector`).
    var vector: [Double] { angles + [rise, headTurn, blink, sit] + sway }

    init() {}

    /// The inverse of `vector`. Missing values (a shorter list, such as an animation's zero) are 0.
    init(vector: [Double]) {
        func value(_ i: Int) -> Double { i < vector.count ? vector[i] : 0 }
        let n: Int = Bone.allCases.count
        angles = (0..<n).map(value)
        rise = value(n)
        headTurn = value(n + 1)
        blink = value(n + 2)
        sit = value(n + 3)
        sway = (0..<n).map { value(n + 4 + $0) }
    }
}
