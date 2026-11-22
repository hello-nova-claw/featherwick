import Foundation
import Testing

@testable import Featherwick

/// The shared chicken skeleton: forward kinematics, the leg solver and the motions. Pure maths, no views.
@Suite struct ChickenSkeletonTests {
    private let adult: SkeletonRig = .adult
    private let tolerance: Double = 1e-6

    /// Rotation follows SwiftUI's `rotationEffect`: positive is clockwise on screen (y down).
    @Test func positiveTurnsAreClockwiseOnScreen() {
        let turned: CGPoint = Affine.rotation(90, about: .zero).apply(CGPoint(x: 1, y: 0))
        #expect(abs(turned.x) < tolerance && abs(turned.y - 1) < tolerance)
    }

    /// At rest every bone is where the art is drawn: nothing moves.
    @Test func theRestPoseMovesNothing() {
        for bone in Bone.allCases {
            #expect(Skeleton.transform(of: bone, rig: adult, pose: .rest, height: 100) == .identity, "\(bone)")
        }
    }

    /// The path rigs walk on their own drawn feet: a grown bird's and a chick's foot spread is half the gap
    /// between their feet.
    @Test func pathRigsStepOnTheirDrawnFeet() {
        #expect(abs(adult.motion.footSpread - 0.04) < tolerance)
        #expect(abs(SkeletonRig.chick.motion.footSpread - 0.05) < tolerance)
    }

    /// A peck by reach puts the throat where it is sent, and the neck never folds on the way: the head goes
    /// round the base of the neck, not out in front of it. The tail turns down against the tilt.
    @Test func aPeckByReachLandsWithoutFoldingTheNeck() {
        var rig: SkeletonRig = adult
        rig.motion.peckBodyTilt = 30
        rig.motion.peckCrouch = 0.06
        rig.motion.peckHeadDip = 80
        rig.motion.peckTail = -20
        rig.motion.peckReach = CGPoint(x: 0, y: -0.5)
        let throat: CGPoint = rig.joints[.head]!
        var furthest: Double = 0
        for i in 0...20 {
            let pose: ChickenPose = ChickenMotion.peck(rig, progress: 0.4 * Double(i) / 20)
            #expect(abs(pose[.neckHigh]) < 150, "step \(i)")
            furthest = max(furthest, Double(Skeleton.place(throat, on: .head, rig: rig, pose: pose).x))
        }
        let bottom: ChickenPose = ChickenMotion.peck(rig, progress: 0.45)
        let landed: CGPoint = Skeleton.place(throat, on: .head, rig: rig, pose: bottom)
        #expect(abs(landed.x - throat.x) < tolerance && abs(landed.y - (throat.y - 0.5)) < tolerance)
        #expect(furthest < Double(throat.x) + 0.15)
        #expect(abs(bottom[.tail] + 20) < tolerance)
        // The head's whole turn on screen is the dip.
        let whole: Double = bottom[.body] + bottom[.neckLow] + bottom[.neckHigh] + bottom[.head]
        #expect(abs(whole - 80) < tolerance)
    }

    /// A part on a missing bone moves with the nearest bone above it: a head with no neck rides the body.
    @Test func aMissingBoneHandsOnToItsParent() {
        var rig: SkeletonRig = adult
        rig.joints[.neckLow] = nil
        rig.joints[.neckHigh] = nil
        #expect(rig.chain(of: .head) == [.head, .body])
        rig.joints[.head] = nil
        #expect(rig.carrier(of: .head) == .body)
        #expect(adult.chain(of: .toesFront) == [.toesFront, .shankFront, .thighFront])
    }

    /// The leg solver puts the foot where it is sent, from a lifted or dropped hip, and keeps the toes flat.
    @Test func theLegReachesItsTarget() {
        for leg in Leg.allCases {
            let foot: CGPoint = adult.feet[leg]!
            for (dx, dy, rise) in [(0.0, 0.0, 0.0), (0.06, 0.0, 0.01), (-0.07, 0.05, 0.0), (0.0, 0.0, -0.2)] {
                var pose = ChickenPose()
                pose.rise = rise
                let target = CGPoint(x: foot.x + dx, y: foot.y + dy)
                ChickenMotion.solve(leg, target: target, curl: 0, rig: adult, pose: &pose)
                let reached: CGPoint = Skeleton.place(foot, on: leg.shank, rig: adult, pose: pose)
                #expect(abs(reached.x - target.x) < 1e-4 && abs(reached.y - target.y) < 1e-4, "\(leg) \(dx) \(dy)")
                let toeTip = CGPoint(x: foot.x + 0.1, y: foot.y)
                let tip: CGPoint = Skeleton.place(toeTip, on: leg.toes, rig: adult, pose: pose)
                #expect(abs(tip.y - reached.y) < 1e-4, "toes flat: \(leg)")
            }
        }
    }

    /// At rest the solver gives back the rest pose: no leg twitches when a bird stands still.
    @Test func theSolverAtRestIsStill() {
        var pose = ChickenPose()
        for leg in Leg.allCases {
            ChickenMotion.solve(leg, target: adult.feet[leg]!, curl: 0, rig: adult, pose: &pose)
        }
        for angle in pose.angles { #expect(abs(angle) < 1e-6) }
    }

    /// Walking: a planted foot stays on the ground and slides back under the bird; a lifted foot is in the
    /// air; the hock bends backwards (its joint never crosses in front of the hip-to-foot line).
    @Test func plantedFeetStayDownAndLiftedFeetLift() {
        var lifted = false
        for i in 0..<120 {
            let phase: Double = Double(i) / 120
            let pose: ChickenPose = ChickenMotion.walk(adult, phase: phase)
            for (leg, offset) in [(Leg.back, 0.0), (Leg.front, 0.5)] {
                let u: Double = (phase + offset).truncatingRemainder(dividingBy: 1)
                let foot: CGPoint = adult.feet[leg]!
                let placed: CGPoint = Skeleton.place(foot, on: leg.shank, rig: adult, pose: pose)
                if u < ChickenRigMetrics.stance {
                    #expect(abs(placed.y - foot.y) < 1e-4, "planted \(leg) at \(phase)")
                } else if placed.y > foot.y + 0.05 {
                    lifted = true
                }
                let hip: CGPoint = Skeleton.place(adult.joints[leg.thigh]!, on: leg.thigh, rig: adult, pose: pose)
                let hock: CGPoint = Skeleton.place(adult.joints[leg.shank]!, on: leg.shank, rig: adult, pose: pose)
                #expect(side(hip, placed, hock) * restSide(leg) >= 0, "hock bends backwards: \(leg) at \(phase)")
            }
        }
        #expect(lifted)
    }

    /// A painted bird's lifted thigh swings forward all the way, with its foot: the hock alone lifts the foot,
    /// so the drumstick never kicks back as the foot steps forward.
    @Test func aLiftedThighSwingsForward() {
        var painted: SkeletonRig = adult
        painted.painted = true
        for (leg, offset) in [(Leg.back, 0.0), (Leg.front, 0.5)] {
            var last: Double = .infinity
            for i in 0...40 {
                let u: Double = ChickenRigMetrics.stance + (1 - ChickenRigMetrics.stance) * Double(i) / 40
                let pose: ChickenPose = ChickenMotion.walk(painted, phase: u - offset)
                // Forward is counter-clockwise on screen: a falling angle.
                #expect(pose[leg.thigh] <= last + 0.5, "\(leg) at \(u)")
                last = pose[leg.thigh]
            }
        }
    }

    /// A leg drawn almost straight (hen-b's joints) still walks: the hip drops so no leg is pulled straight,
    /// a planted foot stays on its ground, and no bone snaps between frames, at lift-off and touch-down
    /// included. A leg drawn bent, as the path rig's, barely drops.
    @Test func aStraightLegWalksWithoutSnapping() {
        let joints: [Bone: CGPoint] = [
            .body: CGPoint(x: -0.02, y: 0.361), .thighBack: CGPoint(x: -0.059, y: 0.352),
            .shankBack: CGPoint(x: -0.127, y: 0.19), .toesBack: CGPoint(x: -0.098, y: 0.05),
            .thighFront: CGPoint(x: 0.015, y: 0.352), .shankFront: CGPoint(x: 0.041, y: 0.19),
            .toesFront: CGPoint(x: 0.093, y: 0.052),
        ]
        var motion: SkeletonMotion = .standard(hipHeight: 0.361)
        motion.stepLength = 0.19
        motion.footSpread = 0.06
        motion.liftShare = 0.15
        let rig = SkeletonRig(
            joints: joints, feet: [.back: joints[.toesBack]!, .front: joints[.toesFront]!], motion: motion,
            painted: true)
        #expect(ChickenMotion.walkingSink(rig) > 0.02)
        #expect(ChickenMotion.walkingSink(adult) < 0.01)
        let legs: [Bone] = [.thighBack, .shankBack, .thighFront, .shankFront]
        var last: ChickenPose = ChickenMotion.walk(rig, phase: 0)
        for i in 1...240 {
            let phase: Double = Double(i) / 240
            let pose: ChickenPose = ChickenMotion.walk(rig, phase: phase)
            for bone in legs {
                #expect(abs(pose[bone] - last[bone]) < 3, "\(bone) at \(phase)")
            }
            for (leg, offset) in [(Leg.back, 0.0), (Leg.front, 0.5)] {
                let u: Double = (phase + offset).truncatingRemainder(dividingBy: 1)
                guard u < ChickenRigMetrics.stance else { continue }
                let foot: CGPoint = rig.feet[leg]!
                let placed: CGPoint = Skeleton.place(foot, on: leg.shank, rig: rig, pose: pose)
                #expect(abs(placed.y - foot.y) < 1e-4, "planted \(leg) at \(phase)")
            }
            last = pose
        }
    }

    /// The path rig walks as it always has (#116): its hip only bounces, never drops, and a lifted foot is
    /// reached for directly. Only a painted kit sinks and blends a bent leg.
    @Test func thePathRigWalksAsBefore() {
        for i in 0..<64 {
            let pose: ChickenPose = ChickenMotion.walk(adult, phase: Double(i) / 64)
            #expect(pose.rise >= 0 && pose.rise <= adult.motion.bounce + 1e-9, "rise at \(i)/64")
        }
        // Mid-swing for the back leg: its foot is where the step puts it, reached for directly.
        let u: Double = ChickenRigMetrics.stance + (1 - ChickenRigMetrics.stance) / 2
        let pose: ChickenPose = ChickenMotion.walk(adult, phase: u)
        var direct: ChickenPose = pose
        let foot: CGPoint = adult.feet[.back]!
        let placed: CGPoint = Skeleton.place(foot, on: Leg.back.shank, rig: adult, pose: pose)
        ChickenMotion.solve(.back, target: placed, curl: 0, rig: adult, pose: &direct)
        #expect(abs(direct[.thighBack] - pose[.thighBack]) < 1e-6)
        #expect(abs(direct[.shankBack] - pose[.shankBack]) < 1e-6)
    }

    /// Which side of the hip-to-foot line the hock is on (the sign of the cross product).
    private func side(_ hip: CGPoint, _ foot: CGPoint, _ hock: CGPoint) -> Double {
        Double((foot.x - hip.x) * (hock.y - hip.y) - (foot.y - hip.y) * (hock.x - hip.x))
    }

    private func restSide(_ leg: Leg) -> Double {
        side(adult.joints[leg.thigh]!, adult.feet[leg]!, adult.joints[leg.shank]!)
    }

    /// The head bob turns the neck and the head by equal and opposite angles: the head stays level.
    @Test func theHeadStaysLevelThroughTheBob() {
        for i in 0..<40 {
            let pose: ChickenPose = ChickenMotion.walk(adult, phase: Double(i) / 40)
            #expect(abs(pose[.neckLow] + pose[.neckHigh] + pose[.head]) < 1e-9)
        }
        var moved = false
        for i in 0..<40 where abs(ChickenMotion.walk(adult, phase: Double(i) / 40)[.neckLow]) > 3 { moved = true }
        #expect(moved)
    }

    /// The path rig's peck takes the beak to the ground, with the feet still planted (the legs crouch).
    @Test func aPeckReachesDown() {
        let build: ChickenBuild = ChickenRigMetrics.adult
        let pose: ChickenPose = ChickenMotion.peck(adult, progress: 0.5)
        let beak: CGPoint = Skeleton.place(build.beak[2], on: .head, rig: adult, pose: pose)
        #expect(beak.y < 0.06)
        for leg in Leg.allCases {
            let foot: CGPoint = adult.feet[leg]!
            let placed: CGPoint = Skeleton.place(foot, on: leg.shank, rig: adult, pose: pose)
            #expect(abs(placed.x - foot.x) < 1e-4 && abs(placed.y - foot.y) < 1e-4)
        }
    }

    /// Sitting drops the body by `sitDrop` of the hip's height, and the folded legs keep the feet in place.
    @Test func sittingFoldsTheLegsUnderTheBody() {
        let pose: ChickenPose = ChickenMotion.sitting(adult)
        let hip: CGPoint = Skeleton.place(adult.hip, on: .body, rig: adult, pose: pose)
        #expect(abs(hip.y - adult.hip.y * (1 - ChickenRigMetrics.sitDrop)) < 1e-6)
        for leg in Leg.allCases {
            let foot: CGPoint = adult.feet[leg]!
            let placed: CGPoint = Skeleton.place(foot, on: leg.shank, rig: adult, pose: pose)
            #expect(abs(placed.x - foot.x) < 1e-4 && abs(placed.y - foot.y) < 1e-4)
        }
    }

    /// A stiff (one-piece) leg swings at the hip, stays on the ground when the hip lifts, and squashes to sit.
    @Test func aStiffLegSwingsAndSquashes() {
        var rig: SkeletonRig = adult
        for leg in Leg.allCases {
            rig.joints[leg.shank] = nil
            rig.joints[leg.toes] = nil
        }
        let walking: ChickenPose = ChickenMotion.walk(rig, phase: 0.1)
        #expect(abs(walking[.thighBack]) > 1)
        var lifted = ChickenPose()
        lifted.rise = 0.05
        let foot: CGPoint = rig.feet[.back]!
        #expect(abs(Skeleton.place(foot, on: .thighBack, rig: rig, pose: lifted).y - foot.y) < 1e-9)
        let sitting: ChickenPose = ChickenMotion.sitting(rig)
        let hip: CGPoint = rig.joints[.thighBack]!
        let squashed: CGPoint = Skeleton.place(hip, on: .thighBack, rig: rig, pose: sitting)
        #expect(abs(squashed.y - hip.y * (1 - ChickenRigMetrics.sitDrop)) < 1e-6)
    }

    /// A still bird does not sway: the spring's weights add up to 1, so a bone that holds still has no lag.
    @Test func aStillBoneHasNoSway() {
        #expect(abs(FluffFollow.weights.reduce(0, +) - 1) < 1e-12)
        var bent = ChickenPose()
        bent[.body] = 30
        bent[.neckLow] = 40
        for lag in FluffFollow.sway(adult, motion: { _ in bent }) { #expect(abs(lag) < 1e-9) }
    }

    /// A sudden turn: the loose part first lags behind (the other way), then swings a little past, then
    /// settles. A child bone lags by its whole turn on screen, its parents' turns included.
    @Test func aLoosePartLagsThenSwingsPast() {
        // The body turned 20° `seconds` ago.
        func lag(_ seconds: Double, _ bone: Bone) -> Double {
            FluffFollow.sway(
                adult,
                motion: { ago in
                    var pose = ChickenPose()
                    pose[.body] = ago <= seconds ? 20 : 0
                    return pose
                })[bone.rawValue]
        }
        #expect(lag(0.05, .tail) < -5)
        #expect(lag(0.05, .tail) == lag(0.05, .body))
        let latest: [Double] = stride(from: 0.1, through: 0.45, by: 1.0 / 30).map { lag($0, .body) }
        #expect(latest.contains { $0 > 0.3 }, "swings past")
        #expect(abs(lag(10, .body)) < 1e-9, "settled")
        #expect(lag(0.05, .thighBack) == 0, "the legs do not ride the body")
    }

    /// A loose part turns about its root by its amount times its bone's lag, capped; with no lag it is
    /// exactly its bone.
    @Test func aLoosePartSwaysAboutItsRoot() {
        let root = CGPoint(x: -0.24, y: 0.62)
        let tip = CGPoint(x: -0.45, y: 0.85)
        let loose = Follow(amount: 1, root: root)
        var pose: ChickenPose = ChickenMotion.walk(adult, phase: 0.3)
        let fixed: CGPoint = Skeleton.place(tip, on: .tail, rig: adult, pose: pose)
        #expect(Skeleton.place(tip, on: .tail, rig: adult, pose: pose, follow: loose) == fixed)
        pose.sway[Bone.tail.rawValue] = 90
        let anchored: CGPoint = Skeleton.place(root, on: .tail, rig: adult, pose: pose, follow: loose)
        #expect(anchored == Skeleton.place(root, on: .tail, rig: adult, pose: pose))
        let swung: CGPoint = Skeleton.place(tip, on: .tail, rig: adult, pose: pose, follow: loose)
        let r: Double = hypot(Double(tip.x - root.x), Double(tip.y - root.y))
        let moved: Double = hypot(Double(swung.x - fixed.x), Double(swung.y - fixed.y))
        // Capped at `followMax`: a chord of that angle, not of 90°.
        let chord: Double = 2 * r * sin(ChickenRigMetrics.followMax / 2 * Double.pi / 180)
        #expect(abs(moved - chord) < 1e-9)
    }

    /// A pose survives the trip through its animation vector, and an empty zero adds as zeros.
    @Test func posesRoundTripThroughTheirVector() {
        var pose: ChickenPose = ChickenMotion.walk(adult, phase: 0.37)
        pose.headTurn = 0.6
        pose.blink = 0.3
        pose.sway[Bone.tail.rawValue] = -7
        #expect(ChickenPose(vector: pose.vector) == pose)
        let v = PoseVector(pose.vector)
        #expect(PoseVector.zero + v == v)
        #expect(v - v == .zero)
        let half: ChickenPose = .mix(.rest, pose, t: 0.5)
        #expect(abs(half[.thighBack] - pose[.thighBack] / 2) < 1e-12)
    }
}
