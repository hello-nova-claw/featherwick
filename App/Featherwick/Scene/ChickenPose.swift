import SwiftUI

// The chicken rig's pose and its numbers. Pure values and functions: no views, no clock, no state.
// The rig is a fixed skeleton. The real art replaces each part's shape and keeps these joints.
//
// Angles follow SwiftUI's `rotationEffect` on a bird that faces right: a positive angle turns
// clockwise on screen. So a positive body tilt or neck swing moves the head forward and down,
// and a positive leg angle swings the foot back.

/// Where one joint of the rig is, and how far every part reaches.
/// Rig units: x is right of the ground point, y is up from the ground, both in rig heights.
/// The ground point is between the feet, at the bottom centre of the rig's frame.
struct ChickenBuild: Equatable, Sendable {
    /// Chicks have no comb, wattle or tail, and a round body.
    let isChick: Bool

    // Legs: each swings at its own hip. The leg runs from the hip down to the ground.
    let backHip: CGPoint
    let frontHip: CGPoint
    let legWidth: CGFloat
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

    // Neck: swings about `shoulder`. Rides on the body.
    let shoulder: CGPoint
    /// Four points: base back, base front, top front, top back.
    let neck: [CGPoint]

    // Head: rides on the neck. It turns about `headCentre`.
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
        legWidth: 0.035, toe: 0.10, backToe: 0.04,
        hip: CGPoint(x: 0, y: 0.40),
        bodyCentre: CGPoint(x: -0.05, y: 0.54), bodySize: CGSize(width: 0.60, height: 0.38),
        wingCentre: CGPoint(x: -0.08, y: 0.54), wingSize: CGSize(width: 0.34, height: 0.20),
        tail: [
            CGPoint(x: -0.22, y: 0.70), CGPoint(x: -0.40, y: 0.90), CGPoint(x: -0.47, y: 0.80),
            CGPoint(x: -0.32, y: 0.52),
        ],
        shoulder: CGPoint(x: 0.16, y: 0.64),
        neck: [
            CGPoint(x: 0.06, y: 0.60), CGPoint(x: 0.24, y: 0.62), CGPoint(x: 0.30, y: 0.84), CGPoint(x: 0.17, y: 0.88),
        ],
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
        legWidth: 0.03, toe: 0.06, backToe: 0.025,
        hip: CGPoint(x: 0, y: 0.14),
        bodyCentre: CGPoint(x: -0.02, y: 0.40), bodySize: CGSize(width: 0.60, height: 0.56),
        wingCentre: CGPoint(x: -0.06, y: 0.40), wingSize: CGSize(width: 0.30, height: 0.20),
        tail: [],
        shoulder: CGPoint(x: 0.10, y: 0.56),
        neck: [
            CGPoint(x: 0.02, y: 0.55), CGPoint(x: 0.20, y: 0.52), CGPoint(x: 0.26, y: 0.70), CGPoint(x: 0.08, y: 0.74),
        ],
        headCentre: CGPoint(x: 0.18, y: 0.72), headRadius: 0.17,
        beak: [CGPoint(x: 0.335, y: 0.745), CGPoint(x: 0.335, y: 0.705), CGPoint(x: 0.40, y: 0.725)],
        eyeCentre: CGPoint(x: 0.24, y: 0.76), eyeRadius: 0.028,
        combBumps: [], combBumpRadius: 0, combBase: CGPoint(x: 0.18, y: 0.89),
        wattleCentre: CGPoint(x: 0.33, y: 0.68), wattleSize: .zero,
        tufts: [CGPoint(x: 0.12, y: 0.88), CGPoint(x: 0.17, y: 0.90), CGPoint(x: 0.22, y: 0.885)],
        tuftRadius: 0.03)

    // Walking. One stride is one step of each leg.
    /// Seconds per stride.
    static let stride: Double = 0.6
    /// Degrees each leg swings either side of straight down.
    static let legSwing: Double = 22
    /// Degrees of body rock and head bob, once per step.
    static let bodyBob: Double = 2
    static let neckBob: Double = 6

    // Pecking.
    /// Seconds for one peck, down and back up.
    static let peckDuration: Double = 0.6
    /// Degrees at the bottom of a peck. With both, an adult's beak reaches the ground.
    static let peckBodyTilt: Double = 25
    static let peckNeckSwing: Double = 55
    /// Parts of the peck: going down, then holding at the bottom. The rest comes back up.
    static let peckDown: Double = 0.4
    static let peckHold: Double = 0.15

    // Sitting.
    /// How far the hip drops to sit, as a part of its standing height. The body then rests on the ground
    /// and the legs fold under it.
    static let sitDrop: Double = 0.85
    /// Seconds to sit down, or to get up.
    static let sitDuration: Double = 0.3

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

/// The rig's joints at one moment. Every animation is a sequence of these.
struct ChickenPose: Equatable, Sendable {
    /// Body tilt at the hip. Positive tips the bird forward to peck.
    var bodyTilt: Angle = .zero
    /// Neck swing at the shoulder. Positive swings the head forward and down.
    var neckSwing: Angle = .zero
    /// -1 looks back, 0 is side profile, 1 looks at the viewer.
    var headTurn: Double = 0
    /// 0 is open, 1 is shut: how far the eyelid has grown down over the eye.
    var blink: Double = 0
    /// Leg swings at the hip. Positive swings the foot back.
    var legBack: Angle = .zero
    var legFront: Angle = .zero
    /// 0 stands, 1 sits: the body drops by `sitDrop` of the hip height and the legs fold under it.
    var sit: Double = 0

    /// Standing still, looking ahead, eyes open.
    static let rest = ChickenPose()

    /// Sitting on the ground, looking ahead.
    static let sitting = ChickenPose(sit: 1)

    private typealias M = ChickenRigMetrics

    /// Walking. `phase` counts strides: each whole number is the start of a stride.
    /// The legs swing opposite each other; the body rocks and the head bobs once per step.
    static func walk(phase: Double) -> ChickenPose {
        let turn: Double = 2 * Double.pi * phase.truncatingRemainder(dividingBy: 1)
        let swing: Double = sin(turn) * M.legSwing
        let step: Double = sin(2 * turn)
        var pose = ChickenPose()
        pose.legBack = .degrees(swing)
        pose.legFront = .degrees(-swing)
        pose.bodyTilt = .degrees(step * M.bodyBob)
        pose.neckSwing = .degrees(step * M.neckBob)
        return pose
    }

    /// One peck. `progress` runs from 0 (standing) to 1 (back up). The body tips at the hip and the neck
    /// swings down, then both come back.
    static func peck(progress: Double) -> ChickenPose {
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
        pose.bodyTilt = .degrees(depth * M.peckBodyTilt)
        pose.neckSwing = .degrees(depth * M.peckNeckSwing)
        return pose
    }

    /// Standing, with the head turned. -1 looks back, 0 is side profile, 1 looks at the viewer.
    static func look(turn: Double) -> ChickenPose {
        var pose = ChickenPose()
        pose.headTurn = min(1, max(-1, turn))
        return pose
    }

    /// The pose part way from `a` (t = 0) to `b` (t = 1), joint by joint.
    static func mix(_ a: ChickenPose, _ b: ChickenPose, t: Double) -> ChickenPose {
        func angle(_ x: Angle, _ y: Angle) -> Angle { .degrees(x.degrees + (y.degrees - x.degrees) * t) }
        func number(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
        return ChickenPose(
            bodyTilt: angle(a.bodyTilt, b.bodyTilt), neckSwing: angle(a.neckSwing, b.neckSwing),
            headTurn: number(a.headTurn, b.headTurn), blink: number(a.blink, b.blink),
            legBack: angle(a.legBack, b.legBack), legFront: angle(a.legFront, b.legFront), sit: number(a.sit, b.sit))
    }

    /// How wide the face is drawn for `headTurn`: 1 in profile, narrower towards the viewer, and
    /// negative (mirrored, beak pointing back) when looking back. It passes 0 as the beak turns away.
    var faceScale: Double {
        let t: Double = min(1, max(-1, headTurn))
        if t < 0 { return cos(t * Double.pi) }
        return 1 - (1 - M.frontFaceScale) * t
    }

    /// Smooth start and stop.
    private static func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }
}
