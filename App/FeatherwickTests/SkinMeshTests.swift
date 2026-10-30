import Foundation
import Testing

@testable import Featherwick

/// The skin drawn forwards (`SkinMesh`): the triangles, where a pose puts them, and the lookup the shader does. Pure maths.
@Suite struct SkinMeshTests {
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
    private let order: [Int] = [4, 3, 2, 1, 0]

    private let skin: ChickenSkin
    /// The whole bird, every cell kept.
    private let mesh: SkinMesh

    init() {
        skin = Self.skin(on: rig)
        mesh = SkinMesh(
            skin: skin, paint: CGRect(x: -0.5, y: 0, width: 1, height: 1), cell: 0.03, order: [4, 3, 2, 1, 0]
        ) { _, _ in true }
    }

    private static func skin(on rig: SkeletonRig) -> ChickenSkin {
        let reaches: [Bone: ChickenSkin.Reach] = [
            .tail: .init(radius: 0.12, width: 0.3), .neckLow: .init(radius: 0.072, width: 0.13),
            .neckHigh: .init(radius: 0.048, width: 0.15), .head: .init(radius: 0.04, width: 0.2),
        ]
        return ChickenSkin(rig: rig, radii: reaches)!
    }

    private func transforms(_ pose: ChickenPose) -> [Affine] {
        skin.bones.map { Skeleton.transform(of: $0.bone, rig: rig, pose: pose, height: height) }
    }

    /// Cells that cannot hold paint are left out; each kept cell is two triangles.
    @Test func emptyCellsAreLeftOut() {
        let half = SkinMesh(skin: skin, paint: CGRect(x: -0.5, y: 0, width: 1, height: 1), cell: 0.1, order: order) {
            c, _ in c < 5
        }
        #expect(half.columns == 10 && half.rows == 10)
        #expect(half.triangles.count == 5 * 10 * 2)
        #expect(half.cornerCount == 11 * 11)
    }

    /// The mesh for a pose, packed for the shader, in a layer round the rest and moved grid.
    private func pack(_ t: [Affine], mesh: SkinMesh? = nil) -> (SkinMesh.Packed, CGPoint, [CGPoint]) {
        let mesh: SkinMesh = mesh ?? self.mesh
        let moved: [CGPoint] = mesh.moved(transforms: t, height: height)
        let layer: CGRect = mesh.restBounds(height: height).union(mesh.reach(moved: moved)).insetBy(dx: -1, dy: -1)
        let offset = CGPoint(x: -layer.minX, y: -layer.minY)
        let packed = mesh.packed(moved: moved, height: height, layer: layer, offset: offset)
        let corner: CGPoint = mesh.rest(0, height: height)
        return (
            packed, CGPoint(x: corner.x + offset.x, y: corner.y + offset.y),
            moved.map {
                CGPoint(x: $0.x + offset.x, y: $0.y + offset.y)
            }
        )
    }

    /// The drift is how far the paint moves: none at rest, and in a peck at least as far as every corner
    /// moved, so SwiftUI draws the head wherever the peck takes it.
    @Test func theDriftCoversEveryCorner() {
        let still: CGSize = mesh.drift(moved: mesh.moved(transforms: transforms(.rest), height: height), height: height)
        #expect(still.width < 1e-9 && still.height < 1e-9)
        let moved: [CGPoint] = mesh.moved(
            transforms: transforms(ChickenMotion.peck(rig, progress: 0.45)), height: height)
        let drift: CGSize = mesh.drift(moved: moved, height: height)
        #expect(drift.width > 10 && drift.height > 10)
        for triangle in mesh.triangles {
            for corner in triangle.corners {
                let rest: CGPoint = mesh.rest(corner, height: height)
                #expect(abs(moved[corner].x - rest.x) <= drift.width && abs(moved[corner].y - rest.y) <= drift.height)
            }
        }
    }

    /// At rest every pixel of the grid finds its own paint, once.
    @Test func theRestPoseMovesNothing() {
        let (packed, grid, _) = pack(transforms(.rest))
        for x in stride(from: grid.x + 0.3, to: grid.x + 99, by: 7.1) {
            for y in stride(from: grid.y - 0.3, to: grid.y - 99, by: -6.7) {
                let found: [CGPoint] = mesh.sources(of: CGPoint(x: x, y: y), packed: packed, grid: grid, height: height)
                #expect(found.count == 1)
                #expect(found.first.map { hypot(Double($0.x - x), Double($0.y - y)) < 1e-3 } ?? false)
            }
        }
    }

    /// Through a peck, the middle of every triangle, where the pose puts it, finds that paint: no hole. (A squashed
    /// triangle's inverse is less exact in floats, so the match is to a twentieth of a point.) Only
    /// a layer under `maxFolds` others may go unfound, and it would not show.
    @Test func aPeckFindsEveryTriangle() {
        for progress in [0.1, 0.3, 0.5] {
            let t: [Affine] = transforms(ChickenMotion.peck(rig, progress: progress))
            let (packed, grid, moved) = pack(t)
            let offset = CGPoint(x: grid.x - mesh.rest(0, height: height).x, y: grid.y - mesh.rest(0, height: height).y)
            var lost: Int = 0
            for triangle in mesh.triangles {
                let rest: [CGPoint] = triangle.corners.map { mesh.rest($0, height: height) }
                let to: [CGPoint] = triangle.corners.map { moved[$0] }
                let at = CGPoint(x: (to[0].x + to[1].x + to[2].x) / 3, y: (to[0].y + to[1].y + to[2].y) / 3)
                let from = CGPoint(
                    x: (rest[0].x + rest[1].x + rest[2].x) / 3 + offset.x,
                    y: (rest[0].y + rest[1].y + rest[2].y) / 3 + offset.y)
                let found: [CGPoint] = mesh.sources(of: at, packed: packed, grid: grid, height: height)
                // Under the most folds a pixel draws, a deeper layer does not show.
                if found.count == SkinMesh.maxFolds { continue }
                if !found.contains(where: { hypot(Double($0.x - from.x), Double($0.y - from.y)) < 0.05 }) {
                    lost += 1
                }
            }
            #expect(lost == 0, "\(progress): \(lost) triangles not found")
        }
    }

    /// Where the bend folds, the top bone's paint comes first: the triangles are in the order's ranks, and
    /// each tile lists its triangles in that order.
    @Test func theTopBoneComesFirst() {
        let t: [Affine] = transforms(ChickenMotion.peck(rig, progress: 0.4))
        for order in [[0, 1, 2, 3, 4], [4, 3, 2, 1, 0]] {
            let mesh = SkinMesh(skin: skin, paint: CGRect(x: -0.5, y: 0, width: 1, height: 1), cell: 0.03, order: order)
            {
                _, _ in true
            }
            let ranks: [Int] = mesh.triangles.compactMap { order.firstIndex(of: $0.top) }
            #expect(ranks == ranks.sorted())
            let (packed, _, _) = pack(t, mesh: mesh)
            for tile in 0..<(packed.tiles.count - 1) {
                let list: [Int] = (Int(packed.tiles[tile])..<Int(packed.tiles[tile + 1])).map { Int(packed.items[$0]) }
                #expect(list == list.sorted(), "tile \(tile)")
            }
            #expect(packed.triangles.count == mesh.triangles.count * SkinMesh.floatsPerTriangle)
        }
    }

    /// The transform between two triangles takes each corner to its match.
    @Test func aTriangleMapsOntoAnother() throws {
        let from: [CGPoint] = [CGPoint(x: 1, y: 2), CGPoint(x: 5, y: 3), CGPoint(x: 2, y: 7)]
        let to: [CGPoint] = [CGPoint(x: -3, y: 4), CGPoint(x: 6, y: 1), CGPoint(x: 0, y: 9)]
        let t: Affine = try #require(Affine(from: from, to: to))
        for (p, q) in zip(from, to) {
            let at: CGPoint = t.apply(p)
            #expect(hypot(Double(at.x - q.x), Double(at.y - q.y)) < 1e-9)
        }
        #expect(Affine(from: [.zero, CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 2)], to: to) == nil)
    }

    private func lexical(_ a: [CGPoint], _ b: [CGPoint]) -> Bool {
        for (p, q) in zip(a, b) {
            if p.x != q.x { return p.x < q.x }
            if p.y != q.y { return p.y < q.y }
        }
        return false
    }
}
