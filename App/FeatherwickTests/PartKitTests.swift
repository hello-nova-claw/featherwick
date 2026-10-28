import CoreGraphics
import FeatherwickCore
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import Featherwick

/// The painted part kits in the app bundle, and the loader. No kit ships now (the skeleton's path rig draws
/// every bird), so the loader is checked on a small kit these tests write to a temporary folder.
@Suite struct PartKitTests {
    /// Every kit folder in the bundle: `kit.json` reads and has no problems, and names its own folder (the
    /// hen kit, or a body shape).
    /// No kits at all is fine: the path rig draws every bird.
    @Test func everyKitInTheBundleIsWhole() throws {
        let root: URL = try #require(PartKit.bundleRoot, "no Parts folder in the app bundle")
        let builds: [String] = try FileManager.default.contentsOfDirectory(atPath: root.path)
            .filter { !$0.hasPrefix(".") }
        for build in builds {
            let folder: URL = root.appendingPathComponent(build)
            let spec: KitSpec = try JSONDecoder().decode(
                KitSpec.self, from: Data(contentsOf: folder.appendingPathComponent("kit.json")))
            #expect(KitName.all.map(\.folder).contains(build), "\(build) is not a kit name")
            #expect(spec.build == build, "kit.json in \(build) says it is \(spec.build)")
            let files = Set(try FileManager.default.contentsOfDirectory(atPath: folder.path))
            #expect(spec.problems(files: files) == [], "\(build)")
        }
    }

    /// A whole kit loads: one layer per part, on its bone, with the right token, made smaller once to the
    /// working size. The eye's painted bounds come from its pixels.
    @Test func aKitLoadsOnItsBones() throws {
        let folder: URL = try Fixture.write()
        defer { try? FileManager.default.removeItem(at: folder) }
        let kit: PartKit = try #require(PartKit.load(build: .heavy, from: folder))
        #expect(kit.layers.map(\.id) == Fixture.order)
        #expect(kit.layers.map(\.bone) == [.thighFront, .shankFront, .body, .body, .head, .head])
        #expect(kit.layers.map(\.token) == [.feathers, .legs, .feathers, .tail, .hackle, .eye])
        #expect(kit.layers.first(where: { $0.id == "tail" })?.follow == Follow(amount: 1, root: nil))
        #expect(kit.rig.bends(.front) && !kit.rig.has(.thighBack))
        // Made smaller once at load: the bird is `workingHeight` pixels tall, not the canvas's 800.
        if let body = kit.layers.first(where: { $0.id == "body" }) {
            let birdPixels: Double = Double(body.image.height) * kit.spec.unit / kit.spec.canvas[1]
            #expect(abs(birdPixels - Double(PartKit.workingHeight)) < 2)
        }
        let eye: CGRect = try #require(kit.eyeBounds)
        #expect(abs(eye.minX - Fixture.eye.minX) < 0.01 && abs(eye.maxY - Fixture.eye.maxY) < 0.01)
    }

    /// Every grown hen shares the hen kit, whatever her body shape. A rooster (not a hen) does not use it.
    @MainActor @Test func grownHensShareTheHenKit() {
        PartKit.reload()
        guard let henKit = PartKit.load(.hen) else { return }
        var hen: ChickenColours = ChickenColours.sample
        hen.isGrownHen = true
        for shape in BodyShape.allCases {
            hen.build = shape
            #expect(PartKit.kit(for: hen) === henKit, "\(shape)")
        }
        var rooster: ChickenColours = ChickenColours.sample
        rooster.build = nil
        #expect(PartKit.kit(for: rooster) == nil)
        var chick: ChickenColours = ChickenColours.sampleChick
        chick.isGrownHen = true
        #expect(PartKit.kit(for: chick) == nil)
    }

    /// The test tools' kit override wins over the bird's own kit: a grown hen can be drawn with `hen-b`.
    /// Without it, she keeps the hen kit.
    @MainActor @Test func theKitOverrideDrawsHenB() {
        PartKit.reload()
        guard let henB = PartKit.load(.henB) else { return }
        var hen: ChickenColours = ChickenColours.sample
        hen.use(kit: .henB)
        #expect(PartKit.kit(for: hen) === henB)
        hen.use(kit: .hen)
        #expect(PartKit.kit(for: hen) === PartKit.load(.hen))
    }

    /// hen-b pecks by tipping her body, with her lower neck nearly in line with it: a neck that turns far
    /// against the body lifts its base out of her back line.
    @MainActor @Test func henBPecksWithHerNeckInLine() {
        PartKit.reload()
        guard let henB = PartKit.load(.henB) else { return }
        let bottom: ChickenPose = ChickenMotion.peck(henB.rig, progress: 0.5)
        #expect(abs(bottom[.neckLow]) < 30)
        #expect(bottom[.body] >= 45)
    }

    /// Chicks keep the path rig, and so does a bird whose body shape has no kit.
    @MainActor @Test func chicksAndKitlessBuildsUseThePathRig() {
        PartKit.reload()
        var chick: ChickenColours = ChickenColours.sampleChick
        chick.build = .heavy
        #expect(PartKit.kit(for: chick) == nil)
        var hen: ChickenColours = ChickenColours.sample
        hen.build = nil
        #expect(PartKit.kit(for: hen) == nil)
        for shape in BodyShape.allCases where PartKit.load(build: shape) == nil {
            hen.build = shape
            #expect(PartKit.kit(for: hen) == nil, "\(shape)")
        }
    }

    /// A broken, missing or old kit gives nil, never a crash: the app falls back to the path rig. An old
    /// kit (format 1, joints by `rotates`) names no bones, so it has no body joint.
    @Test func aBrokenKitLoadsAsNil() throws {
        let folder: URL = try Fixture.write()
        defer { try? FileManager.default.removeItem(at: folder) }
        let spec: URL = folder.appendingPathComponent("kit.json")
        try Data("{ not json".utf8).write(to: spec)
        #expect(PartKit.load(build: .heavy, from: folder) == nil)  // malformed
        try FileManager.default.removeItem(at: spec)
        #expect(PartKit.load(build: .heavy, from: folder) == nil)  // no kit.json
        let old = """
            {"build": "heavy", "canvas": [1024, 1024], "groundPoint": [512, 960], "unit": 800,
             "parts": {"body": {"pivot": [0, 0.4], "rotates": "bodyTilt"}}, "drawOrder": ["body"]}
            """
        try Data(old.utf8).write(to: spec)
        #expect(PartKit.load(build: .heavy, from: folder) == nil)  // format 1
        try Fixture.json.write(to: spec)
        try FileManager.default.removeItem(at: folder.appendingPathComponent("shank.png"))
        #expect(PartKit.load(build: .heavy, from: folder) == nil)  // shank.png is missing
    }

    /// The checks name what is wrong, so the log says how to fix a kit.
    @Test func problemsNameTheFault() throws {
        var spec: KitSpec = try JSONDecoder().decode(KitSpec.self, from: Fixture.json)
        let files = Set(Fixture.order.map { "\($0).png" })
        #expect(spec.problems(files: files) == [])
        spec.overlays = ["lacing": KitSpec.Overlay(mode: "multiply", on: ["wing"])]
        spec.parts["head"]?.pivot = [5, 5]
        spec.parts["eye"]?.pivot = [0.3, 0.85]
        spec.parts["eye"]?.bone = nil
        let problems: [String] = spec.problems(files: files.subtracting(["tail.png"]))
        #expect(problems.contains("part tail has no tail.png"))
        #expect(problems.contains("pivot of head lies outside the canvas"))
        #expect(problems.contains("overlay lacing is on wing, which is not a part"))
        #expect(problems.contains("overlay lacing has no lacing.png"))
        #expect(problems.contains("eye has a pivot but no bone"))
        spec.parts["body"]?.pivot = nil
        #expect(spec.problems(files: files).contains("no part sets the joint of body"))
    }

    /// The canvas's ground point is the rig's ground point: the frame's bottom centre.
    @Test func theGroundPointIsTheOrigin() throws {
        let spec: KitSpec = try JSONDecoder().decode(KitSpec.self, from: Fixture.json)
        let origin: CGPoint = spec.rigPoint(pixel: CGPoint(x: spec.groundPoint[0], y: spec.groundPoint[1]))
        #expect(abs(origin.x) < 1e-9 && abs(origin.y) < 1e-9)
    }
}

/// A small whole kit: a one-legged bird with a drumstick, a bare shank, a loose tail and an eye. Each part
/// is a white box (value 255, full coverage) on a 1024 px canvas.
private enum Fixture {
    static let order: [String] = ["thigh", "shank", "body", "tail", "head", "eye"]
    /// The eye's box, in rig units (y up).
    static let eye = CGRect(x: 0.30, y: 0.84, width: 0.04, height: 0.03)

    static let json = Data(
        """
        {"build": "heavy", "canvas": [1024, 1024], "groundPoint": [512, 960], "unit": 800,
         "parts": {
           "thigh": {"bone": "thighFront", "pivot": [0.03, 0.40]},
           "shank": {"bone": "shankFront", "pivot": [-0.02, 0.20]},
           "body": {"bone": "body", "pivot": [0.0, 0.40]},
           "tail": {"bone": "body", "follow": {"amount": 1}},
           "head": {"bone": "head", "pivot": [0.29, 0.79]},
           "eye": {"bone": "head", "token": "eye"}},
         "drawOrder": ["thigh", "shank", "body", "tail", "head", "eye"]}
        """.utf8)

    /// Where each part's box is, in rig units.
    private static let boxes: [String: CGRect] = [
        "thigh": CGRect(x: -0.02, y: 0.22, width: 0.10, height: 0.18),
        "shank": CGRect(x: -0.03, y: 0.02, width: 0.03, height: 0.20),
        "body": CGRect(x: -0.30, y: 0.35, width: 0.60, height: 0.35),
        "tail": CGRect(x: -0.45, y: 0.55, width: 0.18, height: 0.30),
        "head": CGRect(x: 0.20, y: 0.78, width: 0.16, height: 0.14),
        "eye": eye,
    ]

    /// Writes the kit to a new temporary folder and returns it. The caller removes it.
    static func write() throws -> URL {
        let folder: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try json.write(to: folder.appendingPathComponent("kit.json"))
        for name in order {
            try png(box: boxes[name] ?? .zero, to: folder.appendingPathComponent("\(name).png"))
        }
        return folder
    }

    private static func png(box: CGRect, to url: URL) throws {
        let side: Int = 1024
        guard
            let context = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw CocoaError(.fileWriteUnknown) }
        // Rig units to the context's pixels (origin bottom left): x from the ground point, y from 64 px up.
        let rect = CGRect(
            x: 512 + box.minX * 800, y: 64 + box.minY * 800, width: box.width * 800, height: box.height * 800)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(rect)
        guard let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}
