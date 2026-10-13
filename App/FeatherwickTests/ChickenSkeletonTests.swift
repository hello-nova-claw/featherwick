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

    /// A pose survives the trip through its animation vector, and an empty zero adds as zeros.
    @Test func posesRoundTripThroughTheirVector() {
        var pose: ChickenPose = ChickenMotion.walk(adult, phase: 0.37)
        pose.headTurn = 0.6
        pose.blink = 0.3
        #expect(ChickenPose(vector: pose.vector) == pose)
        let v = PoseVector(pose.vector)
        #expect(PoseVector.zero + v == v)
        #expect(v - v == .zero)
        let half: ChickenPose = .mix(.rest, pose, t: 0.5)
        #expect(abs(half[.thighBack] - pose[.thighBack] / 2) < 1e-12)
    }
}
