import CoreGraphics
import FeatherwickCore
import Foundation
import Testing

@testable import Featherwick

/// The painted part kits in the app bundle, and the loader's fallbacks. No pictures: these check the files.
@Suite struct PartKitTests {
    /// Every kit folder in the bundle: `kit.json` reads, every part in `drawOrder` has a PNG, every
    /// overlay's `on` names real parts, and every pivot and landmark lies inside the canvas.
    @Test func everyKitInTheBundleIsWhole() throws {
        let root: URL = try #require(PartKit.bundleRoot, "no Parts folder in the app bundle")
        let builds: [String] = try FileManager.default.contentsOfDirectory(atPath: root.path)
            .filter { !$0.hasPrefix(".") }
        #expect(!builds.isEmpty)
        for build in builds {
            let folder: URL = root.appendingPathComponent(build)
            let spec: KitSpec = try JSONDecoder().decode(
                KitSpec.self, from: Data(contentsOf: folder.appendingPathComponent("kit.json")))
            #expect(spec.build == build, "kit.json in \(build) says it is \(spec.build)")
            #expect(BodyShape(rawValue: build) != nil, "\(build) is not a body shape")
            let files = Set(try FileManager.default.contentsOfDirectory(atPath: folder.path))
            #expect(spec.problems(files: files) == [], "\(build)")
            for name in spec.drawOrder { #expect(files.contains("\(name).png"), "\(build): \(name).png") }
            for (name, overlay) in spec.overlays ?? [:] {
                for part in overlay.on { #expect(spec.parts[part] != nil, "\(build): \(name) on \(part)") }
            }
            for (name, part) in spec.parts {
                guard let pivot = part.pivot else { continue }
                let pixel: CGPoint = spec.canvasPixel(CGPoint(x: pivot[0], y: pivot[1]))
                #expect(pixel.x >= 0 && pixel.x <= spec.canvas[0], "\(build): pivot of \(name)")
                #expect(pixel.y >= 0 && pixel.y <= spec.canvas[1], "\(build): pivot of \(name)")
            }
        }
    }

    /// The heavy build has a kit; the light build has none yet, so the path rig draws it.
    @MainActor @Test func heavyHasAKitLightDoesNot() {
        PartKit.reload()
        let heavy: PartKit? = PartKit.load(build: .heavy)
        #expect(heavy != nil)
        #expect(PartKit.load(build: .light) == nil)
        // Downsampled once at load: the bird is `workingHeight` pixels tall, not the canvas's 1673.
        if let heavy, let body = heavy.layers.first(where: { $0.id == "body" }) {
            let birdPixels: Double = Double(body.image.height) * heavy.spec.unit / heavy.spec.canvas[1]
            #expect(abs(birdPixels - Double(PartKit.workingHeight)) < 2)
        }
    }

    /// Chicks keep the path rig, and so does a bird whose body shape has no kit.
    @MainActor @Test func chicksAndKitlessBuildsUseThePathRig() {
        var hen: ChickenColours = ChickenColours.sample
        hen.build = .heavy
        #expect(PartKit.kit(for: hen) != nil)
        var chick: ChickenColours = ChickenColours.sampleChick
        chick.build = .heavy
        #expect(PartKit.kit(for: chick) == nil)
        hen.build = .light
        #expect(PartKit.kit(for: hen) == nil)
        hen.build = nil
        #expect(PartKit.kit(for: hen) == nil)
    }

    /// A broken or missing kit gives nil, never a crash: the app falls back to the path rig.
    @Test func aBrokenKitLoadsAsNil() throws {
        let folder: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("broken-kit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(PartKit.load(build: .heavy, from: folder) == nil)  // no kit.json
        try Data("{ not json".utf8).write(to: folder.appendingPathComponent("kit.json"))
        #expect(PartKit.load(build: .heavy, from: folder) == nil)  // malformed
        let missingPart = """
            {"build": "heavy", "canvas": [100, 100], "groundPoint": [50, 90], "unit": 80,
             "parts": {"body": {}}, "drawOrder": ["body"]}
            """
        try Data(missingPart.utf8).write(to: folder.appendingPathComponent("kit.json"))
        #expect(PartKit.load(build: .heavy, from: folder) == nil)  // body.png is missing
    }

    /// The checks name what is wrong, so the log says how to fix a kit.
    @Test func problemsNameTheFault() throws {
        let root: URL = try #require(PartKit.bundleRoot)
        let folder: URL = root.appendingPathComponent("heavy")
        var spec: KitSpec = try JSONDecoder().decode(
            KitSpec.self, from: Data(contentsOf: folder.appendingPathComponent("kit.json")))
        let files = Set(try FileManager.default.contentsOfDirectory(atPath: folder.path))
        spec.overlays?["lacing"]?.on.append("wing")
        spec.parts["head"]?.pivot = [5, 5]
        let problems: [String] = spec.problems(files: files.subtracting(["beak.png"]))
        #expect(problems.contains("part beak has no beak.png"))
        #expect(problems.contains("pivot of head lies outside the canvas"))
        #expect(problems.contains("overlay lacing is on wing, which is not a part"))
    }

    /// The canvas's ground point is the rig's ground point: the frame's bottom centre.
    @Test func theGroundPointIsTheOrigin() throws {
        let root: URL = try #require(PartKit.bundleRoot)
        let spec: KitSpec = try JSONDecoder().decode(
            KitSpec.self, from: Data(contentsOf: root.appendingPathComponent("heavy/kit.json")))
        let origin: CGPoint = spec.rigPoint(pixel: CGPoint(x: spec.groundPoint[0], y: spec.groundPoint[1]))
        #expect(abs(origin.x) < 1e-9 && abs(origin.y) < 1e-9)
    }
}
