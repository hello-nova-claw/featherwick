import CoreGraphics
import FeatherwickCore
import Foundation
import ImageIO
import os

// A painted parts kit for one body shape: `Art/Parts/<build>/kit.json` and one PNG per part.
// See "Painted parts" in docs/design/README.md for the format.
//
// Every PNG shares one canvas. RGB is a greyscale value, alpha is coverage. On screen a part is its colour
// token times its value, clipped to its alpha: the token rule from `Look.swift`, applied to pixels.
// Joints, landmarks and draw order all come from `kit.json`. No part name or position is fixed in code.

/// `kit.json`, as written. Points are `[x, y]` arrays: rig units (x right of the ground point, y up, in bird
/// heights) for pivots and landmarks, pixels for the canvas and the ground point.
struct KitSpec: Decodable, Sendable {
    struct Part: Decodable, Sendable {
        /// The joint this part turns about, in rig units. Needed when the part `rotates`.
        var pivot: [Double]?
        /// Which pose angle turns it: one of `KitJoint.Kind`.
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
            if part.pivot == nil { found.append("\(name) rotates but has no pivot") }
        }
        if let token = part.token, KitToken(rawValue: token) == nil {
            found.append("\(name) has unknown token \(token)")
        }
        if let parent = part.ridesOn, parts[parent] == nil { found.append("\(name) rides on \(parent), not a part") }
        let links: [String] = chain(of: name)
        if let top = links.last, let above = parts[top]?.ridesOn, parts[above] != nil {
            found.append("\(name) rides on a loop of parts")
        }
        let depth: Int = links.count
        if depth > PartKit.maxDepth { found.append("\(name) is \(depth) parts deep; at most \(PartKit.maxDepth)") }
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

    /// With no token in the kit: a part that swings as a leg takes the leg token (a bird's legs follow its
    /// genes, not its feathers). Then the same split as the path rig: the tail takes the tail token, the
    /// neck and head the hackle, the rest the body feathers. These three names are the only part names
    /// the code knows, besides "eye" for the eyelid.
    static func implied(for part: String, rotates: String?) -> KitToken {
        if rotates == KitJoint.Kind.legBack.rawValue || rotates == KitJoint.Kind.legFront.rawValue { return .legs }
        switch part {
        case "tail": return .tail
        case "neck", "head": return .hackle
        default: return .feathers
        }
    }
}

/// One joint a part turns about.
struct KitJoint: Sendable {
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

    let kind: Kind?
    /// Rig units.
    let pivot: CGPoint
}

/// One part, ready to draw: its working-size image and how it moves.
struct KitLayer: Identifiable {
    let id: String
    let image: CGImage
    let token: KitToken
    let tokenScale: Double
    /// Its own joint first, then each parent's: the order nested groups would apply them.
    let joints: [KitJoint]
    let lacing: Bool
    let barring: Bool

    /// The bone this part rides: its own joint's, or the nearest joint above it. Nil: it rides no joint.
    var bone: Bone? { joints.first(where: { $0.kind != nil })?.kind?.bone }
}

private let log = Logger(subsystem: "dev.featherwick.app", category: "PartKit")

/// A loaded kit. Immutable after load, so it is safe to share.
final class PartKit: @unchecked Sendable {
    /// A painted bird is downsampled once, at load, to this many pixels tall. A yard bird is at most
    /// about 64 pt tall, so 512 px is sharp at 3x with room to spare, and far cheaper to draw than 1673 px.
    static let workingHeight: CGFloat = 512
    /// The comb size (`Look`'s comb scale) a kit's comb is painted at: an adult hen's. A grown hen shows the
    /// painted comb at full size; a pullet's grows in towards it, and a rooster's is larger.
    static let paintedCombSize: Double = 0.6
    /// A part may ride on at most this many parts, counting itself (eye on head on neck on body).
    static let maxDepth: Int = 4

    let build: BodyShape
    let spec: KitSpec
    /// Where the kit was read from: the app bundle, or the source folder in a Debug simulator build.
    let folder: URL
    /// Back to front.
    let layers: [KitLayer]
    /// Working-size overlays. `lacing` is the multiply map as painted. `barring` is white with the bar
    /// strength as alpha, so a colour multiply gives the pattern colour where the bars are.
    let lacing: CGImage?
    let barring: CGImage?
    /// The eye part's painted bounds, in rig units (origin at the bottom left): the eyelid covers this.
    let eyeBounds: CGRect?
    /// The comb part's painted bounds, in rig units: the comb grows from their bottom centre.
    let combBounds: CGRect?
    /// The kit's skeleton: the shared bones at this kit's joint positions (`skeleton(of:)`).
    let rig: SkeletonRig

    private init(
        build: BodyShape, spec: KitSpec, folder: URL, layers: [KitLayer], lacing: CGImage?, barring: CGImage?,
        eyeBounds: CGRect?, combBounds: CGRect?
    ) {
        self.rig = PartKit.skeleton(of: spec)
        self.build = build
        self.spec = spec
        self.folder = folder
        self.layers = layers
        self.lacing = lacing
        self.barring = barring
        self.eyeBounds = eyeBounds
        self.combBounds = combBounds
    }

    // MARK: - Geometry

    /// The canvas, in bird heights: an image this many heights wide sits with its ground point on the rig's.
    var canvasSize: CGSize { CGSize(width: spec.canvas[0] / spec.unit, height: spec.canvas[1] / spec.unit) }

    /// The canvas centre in rig units: where every part image is centred.
    var canvasCentre: CGPoint { spec.rigPoint(pixel: CGPoint(x: spec.canvas[0] / 2, y: spec.canvas[1] / 2)) }

    func landmark(_ name: String) -> CGPoint? {
        guard let p = spec.landmarks?[name], p.count == 2 else { return nil }
        return CGPoint(x: p[0], y: p[1])
    }

    /// The bone the eyelid rides: the eye's, or the head's when there is no eye part.
    var eyelidBone: Bone? {
        if let eye = layers.first(where: { $0.id == "eye" }) { return eye.bone }
        return rig.has(.head) ? .head : nil
    }

    /// The shared skeleton at this kit's joints. Each part that `rotates` puts its bone's joint at its pivot;
    /// a bone with no part is missing, and parts on it ride the bone above. A one-piece leg is a stiff thigh
    /// whose foot is straight below its hip. The kit's `motion` sets its angles; `legSwing` sets the step, so a
    /// stiff leg swings that far either side.
    static func skeleton(of spec: KitSpec) -> SkeletonRig {
        var joints: [Bone: CGPoint] = [:]
        for part in spec.parts.values {
            guard let kind = part.rotates.flatMap(KitJoint.Kind.init(rawValue:)), let p = part.pivot, p.count == 2
            else { continue }
            joints[kind.bone] = CGPoint(x: p[0], y: p[1])
        }
        var feet: [Leg: CGPoint] = [:]
        for leg in Leg.allCases {
            if let hip = joints[leg.thigh] { feet[leg] = CGPoint(x: hip.x, y: 0) }
        }
        let hipHeight: Double = max(0.01, Double((joints[.body] ?? .zero).y))
        var motion = SkeletonMotion.standard(hipHeight: hipHeight)
        if let m = spec.motion {
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

    /// The full-size image of a part, read from disk when asked. Nothing asks yet: it is for the bird card
    /// art and the share card later. Not kept: eleven 2048 px images would hold about 180 MB.
    func fullSizeImage(of part: String) -> CGImage? {
        Self.image(at: folder.appendingPathComponent("\(part).png"), maxPixel: nil)
    }

    // MARK: - Loading

    @MainActor private static var cache: [BodyShape: PartKit] = [:]
    /// Builds that have no kit, or a broken one: asked once, then remembered, so the log says it once.
    @MainActor private static var missing: Set<BodyShape> = []

    /// The kit for a bird's body shape, or nil (no kit yet, or a broken kit: then the path rig draws it).
    /// Read once, then cached.
    @MainActor static func load(build: BodyShape) -> PartKit? {
        if let kit = cache[build] { return kit }
        if missing.contains(build) { return nil }
        guard let root = partsRoot, let kit = load(build: build, from: root.appendingPathComponent(build.rawValue))
        else {
            missing.insert(build)
            return nil
        }
        cache[build] = kit
        return kit
    }

    /// The kit for a grown bird with this build. Chicks keep the path rig: there is no chick kit yet.
    @MainActor static func kit(for colours: ChickenColours) -> PartKit? {
        guard !colours.isChick, let build = colours.build else { return nil }
        return load(build: build)
    }

    /// Reads every kit off the main thread, at launch, so the first painted bird does not stall a frame
    /// (eleven 2048 px PNGs and two pixel passes). A bird drawn before this ends loads its kit itself.
    @MainActor static func preload() async {
        guard let root = partsRoot else { return }
        for build in BodyShape.allCases where cache[build] == nil && !missing.contains(build) {
            let folder: URL = root.appendingPathComponent(build.rawValue)
            let kit: PartKit? = await Task.detached(priority: .utility) {
                PartKit.load(build: build, from: folder)
            }.value
            guard cache[build] == nil, !missing.contains(build) else { continue }
            if let kit { cache[build] = kit } else { missing.insert(build) }
        }
    }

    /// Forgets every kit, so the next draw reads the folders again (the rig lab's "Reload kit").
    @MainActor static func reload() {
        cache = [:]
        missing = []
    }

    /// The `Parts` folder in the app bundle (a folder reference, so each kit keeps its own folder).
    static var bundleRoot: URL? { Bundle.main.url(forResource: "Parts", withExtension: nil) }

    /// Where kits are read from. In a Debug build on the simulator, the source folder on the Mac, when it
    /// is there: a new PNG then shows after "Reload kit", with no rebuild. Everywhere else, the bundle.
    static var partsRoot: URL? {
        #if DEBUG && targetEnvironment(simulator)
            let source: URL = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Art/Parts", isDirectory: true)
            if FileManager.default.fileExists(atPath: source.path) { return source }
        #endif
        return bundleRoot
    }

    /// Reads one kit folder. Nil, with one log line, when the folder is missing or the kit is broken:
    /// art never crashes the app.
    static func load(build: BodyShape, from folder: URL) -> PartKit? {
        let specURL: URL = folder.appendingPathComponent("kit.json")
        guard FileManager.default.fileExists(atPath: specURL.path) else { return nil }
        let spec: KitSpec
        do {
            spec = try JSONDecoder().decode(KitSpec.self, from: Data(contentsOf: specURL))
        } catch {
            let reason: String = String(describing: error)
            log.error("Kit \(build.rawValue, privacy: .public): kit.json does not read: \(reason, privacy: .public)")
            return nil
        }
        let files = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
        let problems: [String] = spec.problems(files: files)
        guard problems.isEmpty else {
            log.error("Kit \(build.rawValue, privacy: .public): \(problems.joined(separator: "; "), privacy: .public)")
            return nil
        }
        // Every PNG must be the canvas size: a part of another size would be stretched onto the canvas.
        let pngs: [String] =
            spec.drawOrder.map { "\($0).png" } + (spec.overlays ?? [:]).keys.sorted().map { "\($0).png" }
        let wrongSize: [String] = pngs.filter { name in
            pixelSize(at: folder.appendingPathComponent(name)) != CGSize(width: spec.canvas[0], height: spec.canvas[1])
        }
        guard wrongSize.isEmpty else {
            let names: String = wrongSize.joined(separator: ", ")
            log.error("Kit \(build.rawValue, privacy: .public): not the canvas size: \(names, privacy: .public)")
            return nil
        }
        // The canvas's longer side, scaled so the bird is `workingHeight` pixels tall.
        let maxPixel = Int((max(spec.canvas[0], spec.canvas[1]) * workingHeight / spec.unit).rounded(.up))
        func working(_ name: String) -> CGImage? { image(at: folder.appendingPathComponent(name), maxPixel: maxPixel) }

        var layers: [KitLayer] = []
        for name in spec.drawOrder {
            guard let part = spec.parts[name], let image = working("\(name).png") else {
                log.error("Kit \(build.rawValue, privacy: .public): \(name).png does not read")
                return nil
            }
            let token: KitToken =
                part.token.flatMap(KitToken.init(rawValue:)) ?? KitToken.implied(for: name, rotates: part.rotates)
            layers.append(
                KitLayer(
                    id: name, image: image, token: token, tokenScale: part.tokenScale ?? 1,
                    joints: joints(of: name, in: spec), lacing: overlay("lacing", isOn: name, in: spec),
                    barring: overlay("barring", isOn: name, in: spec)))
        }
        let lacing: CGImage? = spec.overlays?["lacing"] == nil ? nil : working("lacing.png")
        let barring: CGImage? = spec.overlays?["barring"] == nil ? nil : working("barring.png").flatMap(lightMap)
        func paintedBounds(_ name: String) -> CGRect? {
            layers.first(where: { $0.id == name }).flatMap { rigBounds(of: $0.image, in: spec) }
        }
        return PartKit(
            build: build, spec: spec, folder: folder, layers: layers, lacing: lacing, barring: barring,
            eyeBounds: paintedBounds("eye"), combBounds: paintedBounds("comb"))
    }

    /// A working-size part's painted bounds (`alphaBounds`) in rig units, origin at the bottom left.
    private static func rigBounds(of image: CGImage, in spec: KitSpec) -> CGRect? {
        guard let bounds = alphaBounds(image) else { return nil }
        // Working pixels to canvas pixels, then to rig units (y up).
        let scale: Double = Double(image.width) / spec.canvas[0]
        let topLeft: CGPoint = spec.rigPoint(pixel: CGPoint(x: bounds.minX / scale, y: bounds.minY / scale))
        let bottomRight: CGPoint = spec.rigPoint(pixel: CGPoint(x: bounds.maxX / scale, y: bounds.maxY / scale))
        return CGRect(
            x: topLeft.x, y: bottomRight.y, width: bottomRight.x - topLeft.x, height: topLeft.y - bottomRight.y)
    }

    private static func joints(of name: String, in spec: KitSpec) -> [KitJoint] {
        spec.chain(of: name).map { link in
            let part: KitSpec.Part? = spec.parts[link]
            let pivot: CGPoint = part?.pivot.map { CGPoint(x: $0[0], y: $0[1]) } ?? .zero
            return KitJoint(kind: part?.rotates.flatMap(KitJoint.Kind.init(rawValue:)), pivot: pivot)
        }
    }

    private static func overlay(_ name: String, isOn part: String, in spec: KitSpec) -> Bool {
        spec.overlays?[name]?.on.contains(part) ?? false
    }

    /// A PNG's size in pixels, read from its header only.
    static func pixelSize(at url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return CGSize(width: width, height: height)
    }

    /// A PNG from disk. With `maxPixel`, downsampled so its longer side is at most that.
    static func image(at url: URL, maxPixel: Int?) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        guard let maxPixel else { return CGImageSourceCreateImageAtIndex(source, 0, nil) }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// The image as premultiplied RGBA bytes, and its width and height.
    private static func pixels(_ image: CGImage) -> (bytes: [UInt8], width: Int, height: Int)? {
        let width: Int = image.width
        let height: Int = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? (bytes, width, height) : nil
    }

    /// The barring map turned into a light layer: white, with alpha = value × coverage. A colour multiply on
    /// it gives the pattern colour, as strong as the painted bar: RGB 255 is a full bar, 0 changes nothing.
    private static func lightMap(_ image: CGImage) -> CGImage? {
        guard var p = pixels(image) else { return nil }
        for i in stride(from: 0, to: p.bytes.count, by: 4) {
            // Premultiplied and greyscale, so red is already value × coverage.
            let strength: UInt8 = p.bytes[i]
            p.bytes[i] = strength
            p.bytes[i + 1] = strength
            p.bytes[i + 2] = strength
            p.bytes[i + 3] = strength
        }
        let width: Int = p.width
        let height: Int = p.height
        let made: CGImage? = p.bytes.withUnsafeMutableBytes { buffer -> CGImage? in
            CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
        return made
    }

    /// The box around a part's painted pixels (alpha above about 10%), in image pixels.
    private static func alphaBounds(_ image: CGImage) -> CGRect? {
        guard let p = pixels(image) else { return nil }
        var minX: Int = p.width
        var minY: Int = p.height
        var maxX: Int = -1
        var maxY: Int = -1
        for y in 0..<p.height {
            for x in 0..<p.width where p.bytes[(y * p.width + x) * 4 + 3] > 25 {
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
