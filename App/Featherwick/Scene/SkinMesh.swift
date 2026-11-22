import Foundation

// The skin drawn forwards: a run's rest picture cut into triangles, each moved by its corners' blend of
// bones and drawn stretched to its new place. Each triangle's three corners are placed exactly as the skin
// places paint (`ChickenSkin.place`), and the paint between them follows straight lines. So the bend is
// smooth to within a cell, and neighbours share their corners: no seam. Pure maths; `SkinEffect` draws it.

/// A run's paint, cut into a grid of triangles with their bones' weights at the corners. Built once a kit.
///
/// It runs every frame of a walk, in Debug builds too, so the per-frame work reads flat arrays: each
/// corner's weights listed sparsely, the triangles already in draw order.
struct SkinMesh: Equatable, Sendable {
    /// The grid's bottom left corner and its cell's side, rig units (y up).
    let origin: CGPoint
    let cell: Double
    let columns: Int
    let rows: Int
    /// The triangles that hold paint, top first: by the rank of their `top` bone in the run's order, so
    /// where the bend folds, the top part's paint comes first.
    let triangles: [Triangle]
    /// Grid corners, row by row from the bottom, `columns + 1` a row.
    var cornerCount: Int { (columns + 1) * (rows + 1) }

    /// Each corner's bones with any weight: `shares[firstShare[i]..<firstShare[i + 1]]`.
    private let shares: [Share]
    private let firstShare: [Int]
    /// The corners any triangle uses.
    private let used: [Int]
    /// Each kept triangle's cell and half, as `(row × columns + column) × 2 + half`.
    private let kept: Set<Int>
    /// The triangles as the frame's work reads them: three corners, the cell's column and row, and the half.
    private let flat: [Int]

    private struct Share: Equatable, Sendable {
        var bone: Int
        var weight: Double
    }

    struct Triangle: Equatable, Sendable {
        /// Grid corners, counter-clockwise from the cell's bottom left.
        var corners: [Int]
        /// The bone all three corners ride whole, or nil where they blend.
        var rigid: Int?
        /// The bone with most of the triangle's weight. Where the bend folds, its rank in the run's order
        /// says which paint is on top.
        var top: Int
        /// Its cell, and which half: 0 below the cell's diagonal (bottom left to top right), 1 above.
        var column: Int
        var row: Int
        var half: Int
    }

    /// Cuts `paint` (rig units) into cells of side `cell`. `covers(column, row)` says whether a cell may
    /// hold paint; the cells that cannot are left out, so they cost nothing to draw. `order` is the run's
    /// bones, top first (`ChickenSkin.order(drawing:)`).
    init(skin: ChickenSkin, paint: CGRect, cell: Double, order: [Int], covers: (Int, Int) -> Bool) {
        let columns: Int = max(1, Int((Double(paint.width) / cell).rounded(.up)))
        let rows: Int = max(1, Int((Double(paint.height) / cell).rounded(.up)))
        self.origin = paint.origin
        self.cell = cell
        self.columns = columns
        self.rows = rows
        var weights: [[Double]] = []
        weights.reserveCapacity((columns + 1) * (rows + 1))
        for row in 0...rows {
            for column in 0...columns {
                let p = CGPoint(
                    x: Double(paint.minX) + Double(column) * cell, y: Double(paint.minY) + Double(row) * cell)
                weights.append(skin.weights(at: p))
            }
        }
        var shares: [Share] = []
        var firstShare: [Int] = []
        for w in weights {
            firstShare.append(shares.count)
            for (bone, weight) in w.enumerated() where weight > 0 { shares.append(Share(bone: bone, weight: weight)) }
        }
        firstShare.append(shares.count)
        self.shares = shares
        self.firstShare = firstShare
        var triangles: [Triangle] = []
        for row in 0..<rows {
            for column in 0..<columns where covers(column, row) {
                let bottomLeft: Int = row * (columns + 1) + column
                let bottomRight: Int = bottomLeft + 1
                let topLeft: Int = bottomLeft + columns + 1
                let topRight: Int = topLeft + 1
                for (half, corners) in [[bottomLeft, bottomRight, topRight], [bottomLeft, topRight, topLeft]]
                    .enumerated()
                {
                    triangles.append(Self.triangle(corners, column: column, row: row, half: half, weights: weights))
                }
            }
        }
        let rank: [Int: Int] = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        self.triangles = triangles.enumerated().sorted { a, b in
            (rank[a.element.top] ?? order.count, a.offset) < (rank[b.element.top] ?? order.count, b.offset)
        }.map(\.element)
        self.used = Array(Set(triangles.flatMap(\.corners))).sorted()
        self.kept = Set(triangles.map { ($0.row * columns + $0.column) * 2 + $0.half })
        self.flat = self.triangles.flatMap { $0.corners + [$0.column, $0.row, $0.half] }
    }

    private static func triangle(_ corners: [Int], column: Int, row: Int, half: Int, weights: [[Double]]) -> Triangle {
        let bones: Int = weights[corners[0]].count
        var sum = [Double](repeating: 0, count: bones)
        for corner in corners {
            for (i, w) in weights[corner].enumerated() { sum[i] += w }
        }
        let top: Int = sum.indices.max { sum[$0] < sum[$1] } ?? 0
        let whole: Bool = corners.allSatisfy { weights[$0][top] > 1 - 1e-9 }
        return Triangle(corners: corners, rigid: whole ? top : nil, top: top, column: column, row: row, half: half)
    }

    /// A grid corner at rest, in the frame (points, y down).
    func rest(_ corner: Int, height: Double) -> CGPoint {
        let column: Int = corner % (columns + 1)
        let row: Int = corner / (columns + 1)
        let x: Double = Double(origin.x) + Double(column) * cell
        let y: Double = Double(origin.y) + Double(row) * cell
        return Skeleton.frame(CGPoint(x: x, y: y), height: height)
    }

    /// Every grid corner a triangle uses, where the skin puts it for one pose, in the frame (points, y
    /// down). Corners no triangle uses stay at zero.
    func moved(transforms: [Affine], height: Double) -> [CGPoint] {
        var out = [CGPoint](repeating: .zero, count: cornerCount)
        let ground: Double = height * Double(ChickenRigMetrics.widthRatio) / 2
        let x0: Double = ground + Double(origin.x) * height
        let y0: Double = height - Double(origin.y) * height
        let step: Double = cell * height
        let across: Int = columns + 1
        out.withUnsafeMutableBufferPointer { out in
            shares.withUnsafeBufferPointer { shares in
                firstShare.withUnsafeBufferPointer { first in
                    transforms.withUnsafeBufferPointer { t in
                        for corner in used {
                            let px: Double = x0 + Double(corner % across) * step
                            let py: Double = y0 - Double(corner / across) * step
                            var x: Double = 0
                            var y: Double = 0
                            for s in first[corner]..<first[corner + 1] where shares[s].bone < t.count {
                                let m: Affine = t[shares[s].bone]
                                let w: Double = shares[s].weight
                                x += w * (m.a * px + m.c * py + m.tx)
                                y += w * (m.b * px + m.d * py + m.ty)
                            }
                            out[corner] = CGPoint(x: x, y: y)
                        }
                    }
                }
            }
        }
        return out
    }

    /// Where the mesh puts rest point `p` (rig units) for a pose whose corners are `moved`: straight between
    /// the corners of the triangle that holds it. Nil outside every triangle.
    func place(_ p: CGPoint, moved: [CGPoint]) -> CGPoint? {
        let x: Double = (Double(p.x) - Double(origin.x)) / cell
        let y: Double = (Double(p.y) - Double(origin.y)) / cell
        let column: Int = Int(x.rounded(.down))
        let row: Int = Int(y.rounded(.down))
        guard column >= 0, column < columns, row >= 0, row < rows else { return nil }
        let u: Double = x - Double(column)
        let v: Double = y - Double(row)
        let half: Int = v <= u ? 0 : 1
        guard kept.contains((row * columns + column) * 2 + half) else { return nil }
        let bottomLeft: CGPoint = moved[row * (columns + 1) + column]
        let bottomRight: CGPoint = moved[row * (columns + 1) + column + 1]
        let topLeft: CGPoint = moved[(row + 1) * (columns + 1) + column]
        let topRight: CGPoint = moved[(row + 1) * (columns + 1) + column + 1]
        let (along, up): (CGPoint, CGPoint) =
            half == 0 ? (bottomRight - bottomLeft, topRight - bottomRight) : (topRight - topLeft, topLeft - bottomLeft)
        return CGPoint(
            x: Double(bottomLeft.x) + u * Double(along.x) + v * Double(up.x),
            y: Double(bottomLeft.y) + u * Double(along.y) + v * Double(up.y))
    }

    /// The grid at rest, in the frame: where the run's paint is before the skin moves it.
    func restBounds(height: Double) -> CGRect {
        let a: CGPoint = rest(0, height: height)
        let b: CGPoint = rest(cornerCount - 1, height: height)
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    /// The box round every triangle where `moved` puts it: no paint lands outside.
    func reach(moved: [CGPoint]) -> CGRect {
        guard let first = used.first else { return .null }
        var minX: CGFloat = moved[first].x
        var maxX: CGFloat = minX
        var minY: CGFloat = moved[first].y
        var maxY: CGFloat = minY
        for corner in used {
            let p: CGPoint = moved[corner]
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// How far any paint moves from its rest place in this pose, across and down. A pixel inside a triangle
    /// moves no further than its farthest corner, so the corners bound it. The shader samples that far from
    /// the pixel it draws, and SwiftUI must be told (`maxSampleOffset`), or it draws nothing past the run's
    /// rest picture: a long peck lost its head at the edge of the frame.
    func drift(moved: [CGPoint], height: Double) -> CGSize {
        var x: CGFloat = 0
        var y: CGFloat = 0
        for corner in used {
            let rest: CGPoint = rest(corner, height: height)
            x = max(x, abs(moved[corner].x - rest.x))
            y = max(y, abs(moved[corner].y - rest.y))
        }
        return CGSize(width: x, height: y)
    }

    /// The mesh for one pose as the shader reads it (`ChickenSkin.metal`). Points are in the frame moved by
    /// `offset` (the layer's origin, negated).
    ///
    /// - `triangles`: `floatsPerTriangle` floats each, top first: the inverse matrix (a, b, c, d) that takes a
    ///   pixel's offset from the triangle's first moved corner (the next two floats) to its offset from the rest
    ///   corner, then the triangle's cell (column, row) and half. Offsets from a corner stay small, so a squashed
    ///   triangle's large inverse still lands to a fraction of a point in floats.
    /// - The layer is cut into square tiles of `tile` points, `across` a row from `tileOrigin`. `tiles` holds
    ///   `across × down + 1` starts into `items`; `items` holds, for each tile, the triangles that may cover
    ///   it, top first. So a pixel tests only a few triangles.
    struct Packed {
        var triangles: [Float] = []
        var tiles: [Float] = []
        var items: [Float] = []
        var tileOrigin: CGPoint = .zero
        var tile: Double = 1
        var across: Int = 0
        var down: Int = 0
    }

    func packed(moved: [CGPoint], height: Double, layer: CGRect, offset: CGPoint) -> Packed {
        var out = Packed()
        let tile: Double = max(1, 2 * cell * height)
        let across: Int = max(1, Int((Double(layer.width) / tile).rounded(.up)))
        let down: Int = max(1, Int((Double(layer.height) / tile).rounded(.up)))
        out.tile = tile
        out.tileOrigin = CGPoint(x: layer.minX + offset.x, y: layer.minY + offset.y)
        out.across = across
        out.down = down
        let ox: Double = Double(offset.x)
        let oy: Double = Double(offset.y)
        let tileX: Double = Double(layer.minX)
        let tileY: Double = Double(layer.minY)
        let count: Int = triangles.count
        // A cell's side.
        let side: Double = cell * height
        // Each triangle's tiles, as a box: first, last column, first, last row.
        var boxes = [Int](repeating: 0, count: count * 4)
        var floats = [Float](repeating: 0, count: count * Self.floatsPerTriangle)
        var perTile = [Int](repeating: 0, count: across * down + 1)
        floats.withUnsafeMutableBufferPointer { f in
            boxes.withUnsafeMutableBufferPointer { box in
                perTile.withUnsafeMutableBufferPointer { perTile in
                    moved.withUnsafeBufferPointer { moved in
                        flat.withUnsafeBufferPointer { flat in
                            for n in 0..<count {
                                let k: Int = n * 6
                                let a: CGPoint = moved[flat[k]]
                                let b: CGPoint = moved[flat[k + 1]]
                                let c: CGPoint = moved[flat[k + 2]]
                                let column: Double = Double(flat[k + 3])
                                let row: Double = Double(flat[k + 4])
                                let half: Int = flat[k + 5]
                                // Rest edges from the first corner: half 0 goes right then up-right, half 1
                                // up-right then up.
                                let e1x: Double = side
                                let e1y: Double = half == 0 ? 0 : -side
                                let e2x: Double = half == 0 ? side : 0
                                let e2y: Double = -side
                                // Moved edges, in the layer.
                                let ax: Double = Double(a.x) + ox
                                let ay: Double = Double(a.y) + oy
                                let m1x: Double = Double(b.x) + ox - ax
                                let m1y: Double = Double(b.y) + oy - ay
                                let m2x: Double = Double(c.x) + ox - ax
                                let m2y: Double = Double(c.y) + oy - ay
                                // Back maps moved edges onto rest edges: rest = R × M⁻¹.
                                let det: Double = m1x * m2y - m2x * m1y
                                let i: Int = n * Self.floatsPerTriangle
                                if abs(det) > 1e-12 {
                                    let ia: Double = m2y / det
                                    let ib: Double = -m1y / det
                                    let ic: Double = -m2x / det
                                    let id: Double = m1x / det
                                    // Column-vector form: [e1 e2] × [[ia ic] [ib id]].
                                    let pa: Double = e1x * ia + e2x * ib
                                    let pc: Double = e1x * ic + e2x * id
                                    let pb: Double = e1y * ia + e2y * ib
                                    let pd: Double = e1y * ic + e2y * id
                                    f[i] = Float(pa)
                                    f[i + 1] = Float(pb)
                                    f[i + 2] = Float(pc)
                                    f[i + 3] = Float(pd)
                                } else {
                                    // A flat triangle holds no pixel: every pixel goes back to its first corner,
                                    // which the shader's test turns away.
                                    f[i] = .nan
                                }
                                f[i + 4] = Float(ax)
                                f[i + 5] = Float(ay)
                                f[i + 6] = Float(column)
                                f[i + 7] = Float(row)
                                f[i + 8] = Float(half)
                                // Pairwise: `min` of three takes a list, which a Debug build allocates.
                                let left: Double = Double(min(min(a.x, b.x), c.x))
                                let right: Double = Double(max(max(a.x, b.x), c.x))
                                let top: Double = Double(min(min(a.y, b.y), c.y))
                                let bottom: Double = Double(max(max(a.y, b.y), c.y))
                                let x0: Int = max(0, Int(((left - tileX) / tile).rounded(.down)))
                                let x1: Int = min(across - 1, Int(((right - tileX) / tile).rounded(.down)))
                                let y0: Int = max(0, Int(((top - tileY) / tile).rounded(.down)))
                                let y1: Int = min(down - 1, Int(((bottom - tileY) / tile).rounded(.down)))
                                box[n * 4] = x0
                                box[n * 4 + 1] = x1
                                box[n * 4 + 2] = y0
                                box[n * 4 + 3] = y1
                                guard x0 <= x1, y0 <= y1 else { continue }
                                for y in y0...y1 {
                                    for x in x0...x1 { perTile[y * across + x + 1] += 1 }
                                }
                            }
                        }
                    }
                }
            }
        }
        // Counts to starts, then each tile's list in draw order.
        for t in 0..<(across * down) { perTile[t + 1] += perTile[t] }
        var items = [Float](repeating: 0, count: perTile[across * down])
        var next: [Int] = perTile
        items.withUnsafeMutableBufferPointer { items in
            next.withUnsafeMutableBufferPointer { next in
                for n in 0..<count {
                    let x0: Int = boxes[n * 4]
                    let x1: Int = boxes[n * 4 + 1]
                    let y0: Int = boxes[n * 4 + 2]
                    let y1: Int = boxes[n * 4 + 3]
                    guard x0 <= x1, y0 <= y1 else { continue }
                    for y in y0...y1 {
                        for x in x0...x1 {
                            items[next[y * across + x]] = Float(n)
                            next[y * across + x] += 1
                        }
                    }
                }
            }
        }
        out.triangles = floats
        out.tiles = perTile.map(Float.init)
        out.items = items
        return out
    }

    /// The rest points whose paint lands on pixel `p` (in the layer), top first: what the shader draws
    /// there. `grid` is the rest grid's first corner in the layer.
    /// `painted` says whether the rest drawing has paint at a point (in the layer): clear points are passed
    /// over and do not count towards `maxFolds`, as in the shader.
    func sources(
        of p: CGPoint, packed: Packed, grid: CGPoint, height: Double, painted: (CGPoint) -> Bool = { _ in true }
    ) -> [CGPoint] {
        let side: Double = cell * height
        let x: Int = Int(((Double(p.x) - Double(packed.tileOrigin.x)) / packed.tile).rounded(.down))
        let y: Int = Int(((Double(p.y) - Double(packed.tileOrigin.y)) / packed.tile).rounded(.down))
        guard x >= 0, y >= 0, x < packed.across, y < packed.down else { return [] }
        let tile: Int = y * packed.across + x
        var found: [CGPoint] = []
        for k in Int(packed.tiles[tile])..<Int(packed.tiles[tile + 1]) {
            let t: ArraySlice<Float> = packed.triangles.dropFirst(Int(packed.items[k]) * Self.floatsPerTriangle)
            let f: [Double] = t.prefix(Self.floatsPerTriangle).map(Double.init)
            let dx: Double = Double(p.x) - f[4]
            let dy: Double = Double(p.y) - f[5]
            // From the rest corner, in cells: u across, v up.
            let u: Double = (f[0] * dx + f[2] * dy) / side
            let v: Double = -(f[1] * dx + f[3] * dy) / side
            let e: Double = Self.edge
            guard u >= -e, u <= 1 + e, v >= -e, v <= 1 + e, f[8] < 0.5 ? v <= u + e : v >= u - e else { continue }
            let q = CGPoint(
                x: Double(grid.x) + (f[6] + u) * side, y: Double(grid.y) - (f[7] + v) * side)
            if found.contains(where: { hypot(Double($0.x - q.x), Double($0.y - q.y)) < 0.5 }) { continue }
            guard painted(q) else { continue }
            found.append(q)
            if found.count == Self.maxFolds { break }
        }
        return found
    }

    /// Floats a triangle in `Packed.triangles`.
    static let floatsPerTriangle: Int = 9
    /// How far past its edges, in cells, a triangle still holds a pixel, so a shared edge is never a gap.
    static let edge: Double = 0.001
    /// At most this many layers of paint on one pixel, where the bend folds over itself. Clear layers (the
    /// margin round the paint, which a deep fold lays over itself) do not count.
    static let maxFolds: Int = 4
}

private func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }

extension Affine {
    /// The transform that takes triangle `from` to triangle `to` (three points each). Nil when `from` is flat.
    init?(from: [CGPoint], to: [CGPoint]) {
        guard from.count == 3, to.count == 3 else { return nil }
        self.init(from: from[0], from[1], from[2], to: to[0], to[1], to[2])
    }

    /// The transform that takes triangle `p0 p1 p2` to `q0 q1 q2`. Nil when the first is flat.
    init?(from p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, to q0: CGPoint, _ q1: CGPoint, _ q2: CGPoint) {
        let px: Double = Double(p1.x - p0.x)
        let py: Double = Double(p1.y - p0.y)
        let qx: Double = Double(p2.x - p0.x)
        let qy: Double = Double(p2.y - p0.y)
        let det: Double = px * qy - qx * py
        guard abs(det) > 1e-12 else { return nil }
        let ux: Double = Double(q1.x - q0.x)
        let uy: Double = Double(q1.y - q0.y)
        let vx: Double = Double(q2.x - q0.x)
        let vy: Double = Double(q2.y - q0.y)
        // x' = a x + c y + tx: the edge vectors set a, b, c, d; the first corner sets the shift.
        let a: Double = (ux * qy - vx * py) / det
        let c: Double = (vx * px - ux * qx) / det
        let b: Double = (uy * qy - vy * py) / det
        let d: Double = (vy * px - uy * qx) / det
        let x0: Double = Double(p0.x)
        let y0: Double = Double(p0.y)
        self.init(a: a, b: b, c: c, d: d, tx: Double(q0.x) - (a * x0 + c * y0), ty: Double(q0.y) - (b * x0 + d * y0))
    }
}
