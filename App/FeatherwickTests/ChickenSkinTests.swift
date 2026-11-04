import Foundation
import Testing

@testable import Featherwick

/// The skin that bends a painted kit's body, neck, head and tail as one image (`ChickenSkin`). Pure maths:
/// the shader (`ChickenSkin.metal`) does the same per pixel.
@Suite struct ChickenSkinTests {
    /// The path rig's joints with the hen kits' peck: the body tips 50°, the throat goes a little forward.
    private let rig: SkeletonRig = {
        var rig: SkeletonRig = .adult
        rig.motion.peckBodyTilt = 50
        rig.motion.peckCrouch = 0.12
        rig.motion.peckHeadDip = 80
        rig.motion.peckTail = -22
        rig.motion.peckReach = CGPoint(x: 0.1, y: -0.6)
        return rig
    }()
    private let height: Double = 100

    /// The hen kit's reaches, on the path rig's joints.
    private var skin: ChickenSkin {
        let reaches: [Bone: ChickenSkin.Reach] = [
            .tail: .init(radius: 0.12, width: 0.3), .neckLow: .init(radius: 0.072, width: 0.13),
            .neckHigh: .init(radius: 0.048, width: 0.15), .head: .init(radius: 0.04, width: 0.2),
        ]
        return ChickenSkin(rig: rig, radii: reaches)!
    }

    private func transforms(_ pose: ChickenPose) -> [Affine] {
        skin.bones.map { Skeleton.transform(of: $0.bone, rig: rig, pose: pose, height: height) }
    }

    /// The bones are the body, then each bent bone after its parent.
    @Test func theBodyIsTheRoot() {
        #expect(skin.bones.map(\.bone) == [.body, .tail, .neckLow, .neckHigh, .head])
        #expect(skin.bones[0].parent == nil)
        for (i, bone) in skin.bones.enumerated().dropFirst() {
            #expect((bone.parent ?? i) < i, "\(bone.bone)")
        }
    }

    /// Every point's weights add up to 1. Paint well inside the body is all body; paint on the head is all head.
    @Test func weightsAddUpAndStayWithTheirBone() {
        for x in stride(from: -0.5, through: 0.5, by: 0.05) {
            for y in stride(from: 0, through: 1, by: 0.05) {
                let w: [Double] = skin.weights(at: CGPoint(x: x, y: y))
                #expect(abs(w.reduce(0, +) - 1) < 1e-9)
            }
        }
        let belly: [Double] = skin.weights(at: CGPoint(x: rig.hip.x, y: rig.hip.y - 0.1))
        #expect(belly[0] > 0.999)
        let head: CGPoint = rig.joints[.head]!
        let headWeights: [Double] = skin.weights(at: CGPoint(x: head.x + 0.03, y: head.y + 0.04))
        #expect(headWeights[4] > 0.99)
    }

    /// The neck reaches only its own paint: the back behind it has none of the neck's weight, so a peck does
    /// not pull the back along with the neck.
    @Test func theNeckDoesNotReachTheBack() {
        let low: CGPoint = rig.joints[.neckLow]!
        let back = CGPoint(x: low.x - 0.3, y: low.y + 0.02)
        let neck: Double = skin.weights(at: back)[2...].reduce(0, +)
        #expect(neck < 0.001)
    }

    /// At rest the skin moves nothing.
    @Test func theRestPoseMovesNothing() {
        let t: [Affine] = transforms(.rest)
        for p in [CGPoint(x: 40, y: 50), CGPoint(x: 80, y: 20), CGPoint(x: 70, y: 70)] {
            let at: CGPoint = skin.place(p, transforms: t, height: height)
            #expect(hypot(Double(at.x - p.x), Double(at.y - p.y)) < 1e-9)
        }
    }

    /// Where the bend folds, the top part's paint comes first: the order starts with the bone of the last
    /// part drawn, then each one below it, then the bones with no part.
    @Test func theTopPartsBoneComesFirst() {
        #expect(skin.order(drawing: [.tail, .neckLow, .body]) == [0, 2, 1, 4, 3])
        #expect(skin.order(drawing: [.neckHigh, .head, .head]) == [4, 3, 2, 1, 0])
    }

    /// The skin reads only the bones it is given: a rig with no neck bones bends at the tail alone, and a
    /// rig with no bone in the list has no skin.
    @Test func aSkinNeedsItsBones() {
        var stiff: SkeletonRig = rig
        stiff.joints[.neckLow] = nil
        stiff.joints[.neckHigh] = nil
        let tailOnly: ChickenSkin? = ChickenSkin(rig: stiff, radii: [.tail: .init(radius: 0.1, width: 0.3)])
        #expect(tailOnly?.bones.map(\.bone) == [.body, .tail])
        #expect(ChickenSkin(rig: stiff, radii: [.neckLow: .init(radius: 0.1, width: 0.1)]) == nil)
    }
}
