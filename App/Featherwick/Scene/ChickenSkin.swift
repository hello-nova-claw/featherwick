import Foundation

// Skinning: the body, neck, head and tail of a painted kit bend as one image, instead of turning as
// separate cut-outs. Each pixel follows a blend of the bones near it, so at a joint the paint bends
// smoothly and no cut edge ever shows. The legs stay rigid parts. Pure maths: `ChickenSkin.metal`
// does the same per pixel on the GPU, and the tests check it here. See "Painted parts" in
// docs/design/README.md.

/// One bone in the skin. Near its joint, paint hands over from its parent to it, along `direction`.
struct SkinBone: Equatable, Sendable {
    var bone: Bone
    /// The joint, in rig units (y up).
    var joint: CGPoint
    /// Unit vector, rig units (y up): which way the bone runs from its joint.
    var direction: CGPoint
    /// Half the hand-over's length, rig units. A small radius is a near-rigid joint (the head); a large one
    /// is a soft bend (the base of the neck).
    var radius: Double
    /// How far either side of its line the bone reaches, rig units. Past it (over `radius`), paint stays
    /// with the parent, so the neck does not pull at the back behind it.
    var width: Double
    /// The index of its parent in `ChickenSkin.bones`. The root (the body) has none.
    var parent: Int?
}

/// A kit's skin: the bones that bend its soft parts, root first. Built from `kit.json`'s `skin`.
struct ChickenSkin: Equatable, Sendable {
    var bones: [SkinBone]

    /// At most this many bones: the shader's fixed loop.
    static let maxBones: Int = 6

    /// How one bone bends: its hand-over radius and its reach, rig units.
    struct Reach: Equatable, Sendable {
        var radius: Double
        var width: Double
    }

    /// The skin for `rig`. `radii` names each bone that bends (not the body, which is always the root) and
    /// how. Nil when the rig has no body joint, or no bone in `radii` is in the rig.
    init?(rig: SkeletonRig, radii: [Bone: Reach]) {
        guard let hip = rig.joints[.body] else { return nil }
        let skinned: [Bone] = Bone.allCases.filter { radii[$0] != nil && rig.has($0) && $0 != .body }
        guard !skinned.isEmpty, skinned.count < Self.maxBones else { return nil }
        // Bone order is parent first (`Bone` lists the body, then the tail, neck and head in chain order).
        var bones: [SkinBone] = [SkinBone(bone: .body, joint: hip, direction: CGPoint(x: 1, y: 0), radius: 0, width: 0)]
        for bone in skinned {
            let parentBone: Bone? = rig.chain(of: bone).dropFirst().first { b in b == .body || skinned.contains(b) }
            guard let parentBone, let parent = bones.firstIndex(where: { $0.bone == parentBone }),
                let joint = rig.joints[bone]
            else { continue }
            // Towards its skinned child's joint; with none, on from its parent's joint.
            let child: CGPoint? = skinned.first { rig.chain(of: $0).dropFirst().first == bone }.flatMap {
                rig.joints[$0]
            }
            let from: CGPoint = child == nil ? bones[parent].joint : joint
            let to: CGPoint = child ?? joint
            let length: Double = max(1e-9, hypot(Double(to.x - from.x), Double(to.y - from.y)))
            let direction = CGPoint(x: Double(to.x - from.x) / length, y: Double(to.y - from.y) / length)
            let reach: Reach = radii[bone] ?? Reach(radius: 0, width: 0)
            bones.append(
                SkinBone(
                    bone: bone, joint: joint, direction: direction, radius: reach.radius, width: reach.width,
                    parent: parent))
        }
        guard bones.count > 1 else { return nil }
        self.bones = bones
    }

    /// The bones that bend, and their parts: parts on any of them (and on the body) are drawn skinned.
    func skins(_ bone: Bone?) -> Bool {
        guard let bone else { return false }
        return bones.contains { $0.bone == bone }
    }

    /// Which bone's paint is on top where the bend folds, for parts drawn on `drawing` (back to front): the
    /// bone of the top part first, then each bone below, then the bones with no part in the run. Indices into
    /// `bones`.
    func order(drawing: [Bone?]) -> [Int] {
        var out: [Int] = []
        for bone in drawing.reversed() {
            if let bone, let i = bones.firstIndex(where: { $0.bone == bone }), !out.contains(i) { out.append(i) }
        }
        for i in bones.indices.reversed() where !out.contains(i) { out.append(i) }
        return out
    }

    /// How much of the paint at `p` (rig units) is past each bone's joint: 0 well before it, 1 well after,
    /// within the bone's reach either side of its line.
    private func handOver(_ p: CGPoint) -> [Double] {
        bones.map { bone in
            guard bone.parent != nil else { return 1 }
            let dx: Double = Double(p.x - bone.joint.x)
            let dy: Double = Double(p.y - bone.joint.y)
            let along: Double = dx * Double(bone.direction.x) + dy * Double(bone.direction.y)
            let across: Double = abs(dy * Double(bone.direction.x) - dx * Double(bone.direction.y))
            let r: Double = max(1e-9, bone.radius)
            return Self.smooth((along + r) / (2 * r)) * (1 - Self.smooth((across - bone.width) / r))
        }
    }

    private static func smooth(_ x: Double) -> Double {
        let t: Double = min(1, max(0, x))
        return t * t * (3 - 2 * t)
    }

    /// Each bone's share of the paint at `p` (rig units, at rest). They add up to 1. A bone's share is how far
    /// `p` is past its joint and every joint above it, less how far it is past any of its children's. Where
    /// two sibling bones both reach (the tail and the neck, both on the body), the later one wins.
    func weights(at p: CGPoint) -> [Double] {
        let f: [Double] = handOver(p)
        var w: [Double] = bones.indices.map { i in
            var share: Double = 1
            var at: Int? = i
            while let j = at, let parent = bones[j].parent {
                share *= f[j]
                for k in (j + 1)..<bones.count where bones[k].parent == parent { share *= 1 - f[k] }
                at = parent
            }
            for (k, child) in bones.enumerated() where child.parent == i { share *= 1 - f[k] }
            return share
        }
        let total: Double = w.reduce(0, +)
        if total > 1e-9 { w = w.map { $0 / total } } else { w[0] = 1 }
        return w
    }

    /// Where the skin puts the paint at rest point `p`: each bone's transform of it, blended by weight.
    /// `transforms` is one per bone, in `bones` order, in the rig's frame (points, y down); `p` is in that
    /// frame too. `height` turns frame points into rig units for the weights.
    func place(_ p: CGPoint, transforms: [Affine], height: Double) -> CGPoint {
        let w: [Double] = weights(at: Self.rigPoint(p, height: height))
        var x: Double = 0
        var y: Double = 0
        for (i, t) in transforms.enumerated() where i < w.count {
            let q: CGPoint = t.apply(p)
            x += w[i] * Double(q.x)
            y += w[i] * Double(q.y)
        }
        return CGPoint(x: x, y: y)
    }

    /// The rest points that the skin puts at `target` (both in the frame): what the shader draws for a
    /// pixel, top first. Each is solved by Newton steps (the slope found by nudging the point) from one
    /// bone's own inverse, taking the bones in `order` (indices into `bones`, top first; nil: last bone
    /// first). Where the bend folds, two rest points land on one pixel, and both are kept: the shader draws
    /// them top over bottom, as the parts would be. A start that lands further than `tolerance` points away
    /// finds nothing.
    func sources(
        of target: CGPoint, transforms: [Affine], height: Double, order: [Int]? = nil, tolerance: Double = 1
    ) -> [CGPoint] {
        var found: [CGPoint] = []
        for start in order ?? Array(transforms.indices.reversed()) where start < transforms.count {
            // Each bone's own transform, then halfway to its parent's: where a bend folds three deep (the throat
            // in a peck), the middle layer lies between the two.
            var starts: [Affine] = [transforms[start]]
            if let parent = bones[start].parent, parent < transforms.count {
                starts.append(transforms[start].halfway(to: transforms[parent]))
            }
            for from in starts {
                guard let q = solve(target, from: from, transforms: transforms, height: height) else { continue }
                let at: CGPoint = place(q, transforms: transforms, height: height)
                guard hypot(Double(target.x - at.x), Double(target.y - at.y)) <= tolerance else { continue }
                if found.contains(where: { hypot(Double($0.x - q.x), Double($0.y - q.y)) < 0.5 }) { continue }
                found.append(q)
            }
        }
        return found
    }

    private func solve(_ target: CGPoint, from start: Affine, transforms: [Affine], height: Double) -> CGPoint? {
        guard let inverse = start.inverted else { return nil }
        let nudge: Double = height * Self.nudge
        let longest: Double = height * Self.longestStep
        var q: CGPoint = inverse.apply(target)
        for _ in 0..<Self.steps {
            let at: CGPoint = place(q, transforms: transforms, height: height)
            // Landed: a tenth of a point is well under a pixel.
            if hypot(Double(target.x - at.x), Double(target.y - at.y)) < 0.1 { break }
            let ax: CGPoint = place(CGPoint(x: q.x + nudge, y: q.y), transforms: transforms, height: height)
            let ay: CGPoint = place(CGPoint(x: q.x, y: q.y + nudge), transforms: transforms, height: height)
            let slope = Affine(
                a: Double(ax.x - at.x) / nudge, b: Double(ax.y - at.y) / nudge,
                c: Double(ay.x - at.x) / nudge, d: Double(ay.y - at.y) / nudge)
            guard let step = slope.inverted else { break }
            var move: CGPoint = step.apply(CGPoint(x: target.x - at.x, y: target.y - at.y))
            let length: Double = hypot(Double(move.x), Double(move.y))
            if length > longest { move = CGPoint(x: move.x * longest / length, y: move.y * longest / length) }
            q = CGPoint(x: q.x + move.x, y: q.y + move.y)
        }
        return q
    }

    /// Newton steps per start, here and in the shader.
    static let steps: Int = 14
    /// The nudge that finds the slope, and the longest step, in bird heights.
    static let nudge: Double = 0.001
    static let longestStep: Double = 0.1

    private static func rigPoint(_ p: CGPoint, height: Double) -> CGPoint {
        let ground: Double = height * Double(ChickenRigMetrics.widthRatio) / 2
        return CGPoint(x: (Double(p.x) - ground) / height, y: (height - Double(p.y)) / height)
    }

    /// The skin as the shader reads it, for one pose: `floatsPerBone` floats per bone. Points are in the
    /// frame (y down), moved by `offset` (the padding round the frame).
    func packed(transforms: [Affine], height: Double, offset: CGPoint) -> [Float] {
        var out: [Float] = []
        out.reserveCapacity(bones.count * Self.floatsPerBone)
        let ground: Double = height * Double(ChickenRigMetrics.widthRatio) / 2
        for (i, bone) in bones.enumerated() {
            let jx: Double = ground + Double(bone.joint.x) * height + Double(offset.x)
            let jy: Double = height - Double(bone.joint.y) * height + Double(offset.y)
            // The transform about the padded frame: move in, transform, move back.
            let t: Affine = i < transforms.count ? transforms[i] : .identity
            let ox: Double = Double(offset.x)
            let oy: Double = Double(offset.y)
            let tx: Double = t.tx + ox - (t.a * ox + t.c * oy)
            let ty: Double = t.ty + oy - (t.b * ox + t.d * oy)
            out += [
                Float(jx), Float(jy), Float(bone.direction.x), Float(-bone.direction.y),
                Float(bone.radius * height), Float(bone.width * height), Float(bone.parent ?? -1),
                Float(t.a), Float(t.b), Float(t.c), Float(t.d), Float(tx), Float(ty),
            ]
        }
        return out
    }

    /// Joint x, y, direction x, y, radius, width, parent, then the transform's a, b, c, d, tx, ty.
    static let floatsPerBone: Int = 13
}

extension Affine {
    /// Each number halfway to `other`'s: a start for the solve between two bones.
    func halfway(to other: Affine) -> Affine {
        Affine(
            a: (a + other.a) / 2, b: (b + other.b) / 2, c: (c + other.c) / 2, d: (d + other.d) / 2,
            tx: (tx + other.tx) / 2, ty: (ty + other.ty) / 2)
    }

    /// Nil when the transform is flat (no inverse).
    var inverted: Affine? {
        let det: Double = a * d - b * c
        guard abs(det) > 1e-12 else { return nil }
        let ia: Double = d / det
        let ib: Double = -b / det
        let ic: Double = -c / det
        let id: Double = a / det
        return Affine(a: ia, b: ib, c: ic, d: id, tx: -(ia * tx + ic * ty), ty: -(ib * tx + id * ty))
    }
}
