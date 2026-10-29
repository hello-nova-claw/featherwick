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

    /// At rest the skin moves nothing, and every pixel finds its own paint.
    @Test func theRestPoseMovesNothing() {
        let t: [Affine] = transforms(.rest)
        for p in [CGPoint(x: 40, y: 50), CGPoint(x: 80, y: 20), CGPoint(x: 70, y: 70)] {
            let found: [CGPoint] = skin.sources(of: p, transforms: t, height: height)
            #expect(found.count == 1)
            #expect(found.first.map { hypot(Double($0.x - p.x), Double($0.y - p.y)) < 1e-6 } ?? false)
        }
    }

    /// Through a whole peck, every pixel the skin puts paint on finds a rest point, and every rest point it
    /// finds lands back on that pixel. So a fully painted frame bends with no hole. Where the bend folds, a
    /// layer under another may be missed; `PartKitTests` checks that none of the hens' paint goes clear.
    @Test func everyPixelOfAPeckFindsPaint() {
        var empty: Int = 0
        for progress in [0.1, 0.2, 0.3, 0.4, 0.5] {
            let t: [Affine] = transforms(ChickenMotion.peck(rig, progress: progress))
            for x in stride(from: 0.0, through: 120, by: 5) {
                for y in stride(from: 0.0, through: 100, by: 5) {
                    let at: CGPoint = skin.place(CGPoint(x: x, y: y), transforms: t, height: height)
                    let found: [CGPoint] = skin.sources(of: at, transforms: t, height: height)
                    if found.isEmpty { empty += 1 }
                    for q in found {
                        let back: CGPoint = skin.place(q, transforms: t, height: height)
                        #expect(hypot(Double(back.x - at.x), Double(back.y - at.y)) <= 1)
                    }
                }
            }
        }
        #expect(empty == 0, "\(empty) pixels found no rest point")
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

    /// At rest every start is the same, so the shader solves once a pixel, from a start it tries everywhere.
    /// A peck bends enough to need more.
    @Test func theRestPoseNeedsOneStart() {
        let order: [Int] = skin.order(drawing: [.tail, .body])
        let rest: [ChickenSkin.Start] = skin.starts(order: order, transforms: transforms(.rest), height: height)
        #expect(rest.count == 1)
        #expect(rest.first?.bone == nil)
        let peck: [Affine] = transforms(ChickenMotion.peck(rig, progress: 0.4))
        #expect(skin.starts(order: order, transforms: peck, height: height).count > 3)
    }

    /// Bent paint lands inside the reach box of its rest bounds, so the shader may clear every pixel outside.
    @Test func bentPaintStaysInsideItsReach() {
        let paint = CGRect(x: 20, y: 10, width: 70, height: 80)
        for progress in [0.1, 0.3, 0.5] {
            let t: [Affine] = transforms(ChickenMotion.peck(rig, progress: progress))
            let reach: CGRect = skin.reach(of: paint, transforms: t).insetBy(dx: -1e-6, dy: -1e-6)
            for x in stride(from: paint.minX, through: paint.maxX, by: 5) {
                for y in stride(from: paint.minY, through: paint.maxY, by: 5) {
                    #expect(reach.contains(skin.place(CGPoint(x: x, y: y), transforms: t, height: height)))
                }
            }
        }
    }

    /// The packed starts are what the shader reads: `floatsPerStart` floats a start, the inverse moved by the
    /// margin, then its bone (-1 for one tried everywhere).
    @Test func packedStartsMatchTheShader() {
        let offset = CGPoint(x: 10, y: 20)
        let rest: [ChickenSkin.Start] = skin.starts(order: [0], transforms: transforms(.rest), height: height)
        let floats: [Float] = skin.packed(starts: rest, offset: offset)
        #expect(floats == [1, 0, 0, 1, 0, 0, -1])
        let peck: [Affine] = transforms(ChickenMotion.peck(rig, progress: 0.4))
        let starts: [ChickenSkin.Start] = skin.starts(order: [4, 3, 2, 1, 0], transforms: peck, height: height)
        let packed: [Float] = skin.packed(starts: starts, offset: offset)
        #expect(packed.count == starts.count * ChickenSkin.floatsPerStart)
        // The first start's inverse takes its own move of a point back to the point.
        let p = CGPoint(x: 60, y: 30)
        let moved: CGPoint = starts[0].transform.apply(p)
        let x: Double = Double(packed[0]) * (moved.x + 10) + Double(packed[2]) * (moved.y + 20) + Double(packed[4])
        let y: Double = Double(packed[1]) * (moved.x + 10) + Double(packed[3]) * (moved.y + 20) + Double(packed[5])
        #expect(abs(x - (p.x + 10)) < 1e-3 && abs(y - (p.y + 20)) < 1e-3)
    }

    /// The packed skin is what the shader reads: `floatsPerBone` floats a bone, each joint moved by the margin.
    @Test func packedFloatsMatchTheShader() {
        let floats: [Float] = skin.packed(transforms: transforms(.rest), height: height, offset: CGPoint(x: 10, y: 20))
        #expect(floats.count == skin.bones.count * ChickenSkin.floatsPerBone)
        let hip: CGPoint = Skeleton.frame(rig.hip, height: height)
        #expect(abs(Double(floats[0]) - (Double(hip.x) + 10)) < 1e-3)
        #expect(abs(Double(floats[1]) - (Double(hip.y) + 20)) < 1e-3)
        // At rest each transform stays the identity, margin or not.
        #expect(floats[7] == 1 && floats[10] == 1 && floats[11] == 0 && floats[12] == 0)
    }
}
