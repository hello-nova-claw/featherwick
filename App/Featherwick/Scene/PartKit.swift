import CoreGraphics
import FeatherwickCore
import Foundation
import ImageIO
import os

// A painted parts kit: `Art/Parts/<name>/kit.json` and one PNG per part. A grown hen uses the `hen` kit;
// any other grown bird uses the kit for its body shape (`Art/Parts/heavy/`...), if there is one.
// See "Painted parts" in docs/design/README.md for the format, and `KitSpec.swift` for `kit.json`.
//
// Every PNG shares one canvas. RGB is a greyscale value, alpha is coverage. On screen a part is its colour
// token times its value, clipped to its alpha: the token rule from `Look.swift`, applied to pixels.

/// One part, ready to draw: its working-size image and how it moves.
struct KitLayer: Identifiable {
    let id: String
    let image: CGImage
    let token: KitToken
    let tokenScale: Double
    /// The bone this part rides. Nil: only the hip moves it.
    let bone: Bone?
    /// A loose part sways after its bone (`FluffFollow`). Nil: it moves with its bone exactly.
    let follow: Follow?
    let lacing: Bool
    let barring: Bool
}

private let log = Logger(subsystem: "dev.featherwick.app", category: "PartKit")

/// A loaded kit. Immutable after load, so it is safe to share.
/// Which kit a bird uses: the one every grown hen shares, or the one for a body shape.
enum KitName: Hashable, Sendable {
    case hen
    /// A second hen kit, cut from the same silhouette along other lines (`art-source/kit-fits/hen-b/`).
    /// No bird uses it yet: the test tools pick it.
    case henB
    case build(BodyShape)

    /// The kit's folder in `Art/Parts/`.
    var folder: String {
        switch self {
        case .hen: "hen"
        case .henB: "hen-b"
        case .build(let shape): shape.rawValue
        }
    }

    static let all: [KitName] = [.hen, .henB] + BodyShape.allCases.map(KitName.build)
}

final class PartKit: @unchecked Sendable {
    /// A painted bird is downsampled once, at load, to this many pixels tall. A yard bird is at most
    /// about 64 pt tall, so 512 px is sharp at 3x with room to spare, and far cheaper to draw than 1673 px.
    static let workingHeight: CGFloat = 512
    /// The comb size (`Look`'s comb scale) a kit's comb is painted at: an adult hen's. A grown hen shows the
    /// painted comb at full size; a pullet's grows in towards it, and a rooster's is larger.
    static let paintedCombSize: Double = 0.6

    let name: KitName
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
    /// The kit's skeleton: the shared bones at this kit's joint positions (`KitSpec.skeleton`). It sits
    /// with its belly (the body's lowest paint) on the ground.
    let rig: SkeletonRig
    /// The bones that bend the soft parts as one image. Nil: every part turns rigidly.
    let skin: ChickenSkin?

    private init(
        name: KitName, spec: KitSpec, folder: URL, layers: [KitLayer], lacing: CGImage?, barring: CGImage?,
        eyeBounds: CGRect?, combBounds: CGRect?, belly: Double?
    ) {
        var rig: SkeletonRig = spec.skeleton
        if let belly { rig.sitHeight = max(0, belly) }
        self.rig = rig
        self.skin = ChickenSkin(rig: rig, radii: spec.skinReaches)
        self.name = name
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

    /// The full-size image of a part, read from disk when asked. Nothing asks yet: it is for the bird card
    /// art and the share card later. Not kept: eleven 2048 px images would hold about 180 MB.
    func fullSizeImage(of part: String) -> CGImage? {
        Self.image(at: folder.appendingPathComponent("\(part).png"), maxPixel: nil)
    }

    // MARK: - Loading

    @MainActor private static var cache: [KitName: PartKit] = [:]
    /// Kits that are not there, or are broken: asked once, then remembered, so the log says it once.
    @MainActor private static var missing: Set<KitName> = []

    /// A kit by name, or nil (no kit yet, or a broken kit: then the path rig draws the bird). Read once,
    /// then cached.
    @MainActor static func load(_ name: KitName) -> PartKit? {
        if let kit = cache[name] { return kit }
        if missing.contains(name) { return nil }
        guard let root = partsRoot, let kit = load(name, from: root.appendingPathComponent(name.folder)) else {
            missing.insert(name)
            return nil
        }
        cache[name] = kit
        return kit
    }

    /// The kit for a body shape, or nil.
    @MainActor static func load(build: BodyShape) -> PartKit? { load(.build(build)) }

    /// The kit a grown bird is drawn with: a grown hen's is the hen kit, whatever her body shape; any
    /// other grown bird's is its body shape's. Chicks keep the path rig: there is no chick kit yet. Nil:
    /// the path rig draws it.
    @MainActor static func kit(for colours: ChickenColours) -> PartKit? {
        guard !colours.isChick else { return nil }
        if let name = colours.kitOverride { return load(name) }
        if colours.isGrownHen, let kit = load(.hen) { return kit }
        guard let build = colours.build else { return nil }
        return load(.build(build))
    }

    /// Reads every kit off the main thread, at launch, so the first painted bird does not stall a frame
    /// (eleven 2048 px PNGs and two pixel passes). A bird drawn before this ends loads its kit itself.
    @MainActor static func preload() async {
        guard let root = partsRoot else { return }
        for name in KitName.all where cache[name] == nil && !missing.contains(name) {
            let folder: URL = root.appendingPathComponent(name.folder)
            let kit: PartKit? = await Task.detached(priority: .utility) {
                PartKit.load(name, from: folder)
            }.value
            guard cache[name] == nil, !missing.contains(name) else { continue }
            if let kit { cache[name] = kit } else { missing.insert(name) }
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
    static func load(build: BodyShape, from folder: URL) -> PartKit? { load(.build(build), from: folder) }

    /// Reads one kit folder, for the kit `name`. See `load(build:from:)`.
    static func load(_ name: KitName, from folder: URL) -> PartKit? {
        let specURL: URL = folder.appendingPathComponent("kit.json")
        guard FileManager.default.fileExists(atPath: specURL.path) else { return nil }
        let spec: KitSpec
        do {
            spec = try JSONDecoder().decode(KitSpec.self, from: Data(contentsOf: specURL))
        } catch {
            let reason: String = String(describing: error)
            log.error("Kit \(name.folder, privacy: .public): kit.json does not read: \(reason, privacy: .public)")
            return nil
        }
        let files = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
        let problems: [String] = spec.problems(files: files)
        guard problems.isEmpty else {
            log.error("Kit \(name.folder, privacy: .public): \(problems.joined(separator: "; "), privacy: .public)")
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
            log.error("Kit \(name.folder, privacy: .public): not the canvas size: \(names, privacy: .public)")
            return nil
        }
        // The canvas's longer side, scaled so the bird is `workingHeight` pixels tall.
        let maxPixel = Int((max(spec.canvas[0], spec.canvas[1]) * workingHeight / spec.unit).rounded(.up))
        func working(_ name: String) -> CGImage? { image(at: folder.appendingPathComponent(name), maxPixel: maxPixel) }

        var layers: [KitLayer] = []
        for part in spec.drawOrder {
            guard let entry = spec.parts[part], let image = working("\(part).png") else {
                log.error("Kit \(name.folder, privacy: .public): \(part).png does not read")
                return nil
            }
            let token: KitToken =
                entry.token.flatMap(KitToken.init(rawValue:)) ?? KitToken.implied(for: part, in: spec)
            layers.append(
                KitLayer(
                    id: part, image: image, token: token, tokenScale: entry.tokenScale ?? 1,
                    bone: spec.bone(of: part), follow: spec.follow(of: part),
                    lacing: overlay("lacing", isOn: part, in: spec),
                    barring: overlay("barring", isOn: part, in: spec)))
        }
        let lacing: CGImage? = spec.overlays?["lacing"] == nil ? nil : working("lacing.png")
        let barring: CGImage? = spec.overlays?["barring"] == nil ? nil : working("barring.png").flatMap(lightMap)
        func paintedBounds(_ name: String) -> CGRect? {
            layers.first(where: { $0.id == name }).flatMap { rigBounds(of: $0.image, in: spec) }
        }
        return PartKit(
            name: name, spec: spec, folder: folder, layers: layers, lacing: lacing, barring: barring,
            eyeBounds: paintedBounds("eye"), combBounds: paintedBounds("comb"),
            belly: paintedBounds("body").map { Double($0.minY) })
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
