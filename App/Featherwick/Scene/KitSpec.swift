import FeatherwickCore
import Foundation

// `kit.json` for a painted parts kit, and the skeleton it gives. Pure (no images, no views), so it builds
// and is checked on Linux too. `PartKit.swift` reads the PNGs. See "Painted parts" in docs/design/README.md.
//
// Joints, landmarks and draw order all come from `kit.json`. No part name or position is fixed in code.

/// `kit.json`, as written. Points are `[x, y]` arrays: rig units (x right of the ground point, y up, in bird
/// heights) for pivots and landmarks, pixels for the canvas and the ground point.
struct KitSpec: Decodable, Sendable {
    struct Part: Decodable, Sendable {
        /// The joint this part turns about, in rig units. Needed when the part `rotates`. With `bone`, it
        /// is that bone's joint; a part on a bone whose joint another part gives needs no pivot.
        var pivot: [Double]?
        /// The skeleton bone it rides, by its name in `Bone` ("shankFront"). Format 2: it replaces `rotates`.
        var bone: String?
        /// Format 1: which pose angle turns it, one of `KitJoint.Kind`. `bone` wins when both are set.
        var rotates: String?
        /// The part it moves with. A part with no parent moves with the whole bird.
        var ridesOn: String?
        /// Notes for people. The draw order is `drawOrder`.
        var behind: String?
        var inFront: String?
        /// The token is multiplied by this: above 1 lifts the colour (the hackle).
        var tokenScale: Double?
        /// A non-feather token: comb, beak, eye or legs. Other parts take a feather token.
        var token: String?
    }

    struct Overlay: Decodable, Sendable {
        /// "multiply" (lacing) or "lighten" (barring). Kept for people: the pattern name sets the blend.
        var mode: String
        /// The parts it is drawn over.
        var on: [String]
    }

    /// This build's angles, in degrees. Missing values keep the path rig's angles.
    struct Motion: Decodable, Sendable {
        var peckBodyTilt: Double?
        var peckHeadDip: Double?
        /// A kit whose neck swings at the shoulder (`neckSwing`): the neck's angle at the bottom of a peck.
        var peckNeckSwing: Double?
        /// How far the hip drops at the bottom of a peck, in bird heights. Missing: the standard crouch.
        var peckCrouch: Double?
        var glanceHeadDip: Double?
        var legSwing: Double?
        var stride: Double?
    }

    var build: String
    var canvas: [Double]
    var groundPoint: [Double]
    /// The bird's height in canvas pixels.
    var unit: Double
    var parts: [String: Part]
    /// Back to front.
    var drawOrder: [String]
    var overlays: [String: Overlay]?
    var landmarks: [String: [Double]]?
    var motion: Motion?

    /// A part may ride on at most this many parts, counting itself (eye on head on neck on body).
    static let maxDepth: Int = 4

    /// The patterns a kit can paint, by overlay name.
    static let overlayPatterns: [String: FeatherwickCore.Pattern] = ["lacing": .lacing, "barring": .barring]

    /// Everything wrong with the kit, in words for the log and the tests. Empty when the kit is good.
    /// `files` are the file names in the kit's folder.
    func problems(files: Set<String>) -> [String] {
        var found: [String] = []
        guard canvas.count == 2, canvas[0] > 0, canvas[1] > 0 else { return ["canvas is not [width, height]"] }
        guard groundPoint.count == 2 else { return ["groundPoint is not [x, y]"] }
        guard unit > 0 else { return ["unit is not above 0"] }
        for name in drawOrder where parts[name] == nil { found.append("drawOrder names \(name), which is not a part") }
        for name in parts.keys where !drawOrder.contains(name) { found.append("part \(name) is not in drawOrder") }
        if Set(drawOrder).count != drawOrder.count { found.append("drawOrder names a part twice") }
        for name in drawOrder where !files.contains("\(name).png") { found.append("part \(name) has no \(name).png") }
        for (name, part) in parts.sorted(by: { $0.key < $1.key }) {
            found += partProblems(name, part)
        }
        // Each joint is set once: two pivots for one bone would tear the art.
        var setters: [Bone: [String]] = [:]
        for name in drawOrder {
            if let part = parts[name], part.pivot != nil, let bone = bone(of: name) {
                setters[bone, default: []].append(name)
            }
        }
        for bone in Bone.allCases {
            if let names = setters[bone], names.count > 1 {
                found.append("\(names.joined(separator: " and ")) both set the joint of \(bone.kitName)")
            }
        }
        for (name, overlay) in (overlays ?? [:]).sorted(by: { $0.key < $1.key }) {
            if Self.overlayPatterns[name] == nil { found.append("overlay \(name) is not lacing or barring") }
            if !files.contains("\(name).png") { found.append("overlay \(name) has no \(name).png") }
            for target in overlay.on where parts[target] == nil {
                found.append("overlay \(name) is on \(target), which is not a part")
            }
        }
        for (name, point) in (landmarks ?? [:]).sorted(by: { $0.key < $1.key }) {
            if let problem = pointProblem(point) { found.append("landmark \(name) \(problem)") }
        }
        return found
    }

    private func partProblems(_ name: String, _ part: Part) -> [String] {
        var found: [String] = []
        if let pivot = part.pivot, let problem = pointProblem(pivot) { found.append("pivot of \(name) \(problem)") }
        if let rotates = part.rotates {
            if KitJoint.Kind(rawValue: rotates) == nil { found.append("\(name) rotates with unknown \(rotates)") }
            if part.pivot == nil && part.bone == nil { found.append("\(name) rotates but has no pivot") }
        }
        if let bone = part.bone, Bone(kitName: bone) == nil { found.append("\(name) rides unknown bone \(bone)") }
        if let token = part.token, KitToken(rawValue: token) == nil {
            found.append("\(name) has unknown token \(token)")
        }
        if let parent = part.ridesOn, parts[parent] == nil { found.append("\(name) rides on \(parent), not a part") }
        let links: [String] = chain(of: name)
        if let top = links.last, let above = parts[top]?.ridesOn, parts[above] != nil {
            found.append("\(name) rides on a loop of parts")
        }
        let depth: Int = links.count
        if depth > Self.maxDepth { found.append("\(name) is \(depth) parts deep; at most \(Self.maxDepth)") }
        return found
    }

    /// Nil when the point is two numbers inside the canvas.
    private func pointProblem(_ point: [Double]) -> String? {
        guard point.count == 2 else { return "is not [x, y]" }
        let pixel: CGPoint = canvasPixel(CGPoint(x: point[0], y: point[1]))
        let inside: Bool = pixel.x >= 0 && pixel.y >= 0 && pixel.x <= canvas[0] && pixel.y <= canvas[1]
        return inside ? nil : "lies outside the canvas"
    }

    /// A part, then the part it rides on, and so on up. Stops at a loop or a missing parent.
    func chain(of name: String) -> [String] {
        var out: [String] = []
        var next: String? = name
        while let current = next, parts[current] != nil, !out.contains(current) {
            out.append(current)
            next = parts[current]?.ridesOn
        }
        return out
    }

    /// The bone a part rides itself: its `bone`, else the bone of what it `rotates`. Nil: it rides its parent.
    func bone(of name: String) -> Bone? {
        guard let part = parts[name] else { return nil }
        if let named = part.bone.flatMap(Bone.init(kitName:)) { return named }
        return part.rotates.flatMap(KitJoint.Kind.init(rawValue:))?.bone
    }

    /// The bone a part moves with: its own, or the nearest one up its `ridesOn` chain.
    func carrierBone(of name: String) -> Bone? {
        chain(of: name).lazy.compactMap { bone(of: $0) }.first
    }

    /// The shared skeleton at this kit's joints. Each part with a pivot and a bone puts that bone's joint at
    /// the pivot; a bone with no joint is missing, and parts on it ride the bone above. A leg's foot is its
    /// toes' joint; with no toes, straight below its hock, or below its hip for a one-piece (stiff) leg. The
    /// kit's `motion` sets its angles; `legSwing` sets the step, so a stiff leg swings that far either side.
    var skeleton: SkeletonRig {
        var joints: [Bone: CGPoint] = [:]
        for name in drawOrder {
            guard let p = parts[name]?.pivot, p.count == 2, let bone = bone(of: name) else { continue }
            joints[bone] = CGPoint(x: p[0], y: p[1])
        }
        var feet: [Leg: CGPoint] = [:]
        for leg in Leg.allCases {
            if let toes = joints[leg.toes], joints[leg.shank] != nil {
                feet[leg] = toes
            } else if let above = joints[leg.shank] ?? joints[leg.thigh] {
                feet[leg] = CGPoint(x: above.x, y: 0)
            }
        }
        let hipHeight: Double = max(0.01, Double((joints[.body] ?? .zero).y))
        var motion = SkeletonMotion.standard(hipHeight: hipHeight)
        if let m = self.motion {
            if let v = m.peckBodyTilt { motion.peckBodyTilt = v }
            if let v = m.peckNeckSwing { motion.peckNeckSwing = v }
            if let v = m.peckHeadDip { motion.peckHeadDip = v }
            if let v = m.peckCrouch { motion.peckCrouch = v }
            let legHeight: Double = Leg.allCases.compactMap { joints[$0.thigh].map { Double($0.y) } }.max() ?? 0
            if let swing = m.legSwing, legHeight > 0 {
                motion.stepLength = 2 * legHeight * tan(swing * Double.pi / 180)
            }
        }
        return SkeletonRig(joints: joints, feet: feet, motion: motion)
    }

    /// Rig units to canvas pixels (y down).
    func canvasPixel(_ p: CGPoint) -> CGPoint {
        CGPoint(x: groundPoint[0] + p.x * unit, y: groundPoint[1] - p.y * unit)
    }

    /// Canvas pixels (y down) to rig units.
    func rigPoint(pixel p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - groundPoint[0]) / unit, y: (groundPoint[1] - p.y) / unit)
    }
}

/// The colour a part takes. A kit names comb, beak, eye or legs; other parts take a feather token.
enum KitToken: String, Sendable {
    case feathers, hackle, tail, comb, beak, eye, legs

    /// With no token in the kit: the bare leg takes the leg token (a bird's legs follow its genes, not its
    /// feathers). That is a part on a shank or toes, or a one-piece leg (`legBack`, `legFront`). A thigh
    /// is the feathered drumstick, so it does not. Then the same split as the path rig: the tail takes the
    /// tail token, the neck and head the hackle, the rest the body feathers. These three names are the only
    /// part names the code knows, besides "eye" for the eyelid and "comb" for where it grows from.
    static func implied(for part: String, in spec: KitSpec) -> KitToken {
        let bone: Bone? = spec.carrierBone(of: part)
        let bare: Bool = bone.map { $0.leg != nil && $0 != $0.leg?.thigh } ?? false
        let oneLeg: Bool = spec.chain(of: part).contains { link in
            let kind = spec.parts[link]?.rotates.flatMap(KitJoint.Kind.init(rawValue:))
            return spec.parts[link]?.bone == nil && (kind == .legBack || kind == .legFront)
        }
        if bare || oneLeg { return .legs }
        switch part {
        case "tail": return .tail
        case "neck", "head": return .hackle
        default: return .feathers
        }
    }
}

/// Format 1 joints: the `rotates` names. Format 2 names the bone itself (`Part.bone`).
enum KitJoint {
    enum Kind: String, Sendable {
        case legBack, legFront, bodyTilt
        /// The head turns down at the throat. A kit whose neck rides on the body pecks with this.
        case headDip
        /// The neck swings at the shoulder, as on the path rig.
        case neckSwing

        /// The skeleton bone this joint is. A one-piece leg is the thigh: it swings at the hip and cannot bend.
        var bone: Bone {
            switch self {
            case .legBack: .thighBack
            case .legFront: .thighFront
            case .bodyTilt: .body
            case .headDip: .head
            case .neckSwing: .neckLow
            }
        }
    }
}

extension Bone {
    /// The bone's name in `kit.json`: its case name ("neckLow", "toesFront").
    var kitName: String { String(describing: self) }

    init?(kitName: String) {
        guard let bone = Bone.allCases.first(where: { $0.kitName == kitName }) else { return nil }
        self = bone
    }
}
