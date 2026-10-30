import CoreGraphics
import FeatherwickCore
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import Featherwick

/// The painted part kits in the app bundle, and the loader. No kit ships now (the skeleton's path rig draws
/// every bird), so the loader is checked on a small kit these tests write to a temporary folder.
/// Serialised: the kit shelf is shared by the whole app, and `drawingNeverReadsAKit` waits on it.
@Suite(.serialized) struct PartKitTests {
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
    @MainActor @Test func grownHensShareTheHenKit() throws {
        PartKit.reload()
        let henKit: PartKit = try #require(PartKit.load(.hen), "the hen kit does not load")
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

    /// A laced or barred hen keeps the path rig while the hen kit has no map for her pattern, so her
    /// pattern still shows: her look comes from her genes.
    @MainActor @Test func patternedHensWaitForTheirPatternMap() throws {
        PartKit.reload()
        let henKit: PartKit = try #require(PartKit.load(.hen), "the hen kit does not load")
        var hen: ChickenColours = ChickenColours.sample
        hen.isGrownHen = true
        hen.pattern = nil
        #expect(PartKit.kit(for: hen) === henKit)
        hen.pattern = .lacing
        #expect(PartKit.kit(for: hen) === (henKit.lacing == nil ? nil : henKit))
        hen.pattern = .barring
        #expect(PartKit.kit(for: hen) === (henKit.barring == nil ? nil : henKit))
    }

    /// The test tools' kit override wins over the bird's own kit: a grown hen can be drawn with `hen-b`.
    /// Without it, she keeps the hen kit.
    @MainActor @Test func theKitOverrideDrawsHenB() throws {
        PartKit.reload()
        let henB: PartKit = try #require(PartKit.load(.henB), "the hen-b kit does not load")
        var hen: ChickenColours = ChickenColours.sample
        hen.use(kit: .henB)
        #expect(PartKit.kit(for: hen) === henB)
        hen.use(kit: .hen)
        #expect(PartKit.kit(for: hen) === PartKit.load(.hen))
    }

    /// hen-b pecks to the ground: she tips her body far, her throat comes down near the ground in front of
    /// her, and her upper neck stays nearly straight, so the neck reaches rather than folds under her chin.
    ///
    /// She tips further than the hen (70°) and sends her throat forward and down, so her lower neck stays
    /// within 30° of her body (#116) and her beak still reaches the ground: about 0.05 above it, where the
    /// hen's peck stops at 0.16.
    @MainActor @Test func henBPecksToTheGround() throws {
        PartKit.reload()
        let henB: PartKit = try #require(PartKit.load(.henB), "the hen-b kit does not load")
        let throat: CGPoint = try #require(henB.rig.joints[.head])
        let bottom: ChickenPose = ChickenMotion.peck(henB.rig, progress: 0.5)
        #expect(bottom[.body] >= 45)
        #expect(abs(bottom[.neckLow]) < 30)
        #expect(abs(bottom[.neckHigh]) < 30)
        let placed: CGPoint = Skeleton.place(throat, on: .head, rig: henB.rig, pose: bottom)
        #expect(placed.y < 0.15)
        #expect(placed.x > throat.x)
        #expect(try Self.beakLow(henB, pose: bottom) < 0.08)
    }

    /// The lowest point of a kit's painted beak in a pose (rig units above the ground).
    @MainActor private static func beakLow(_ kit: PartKit, pose: ChickenPose) throws -> Double {
        let beak: KitLayer = try #require(kit.layers.first { $0.id == "beak" })
        let painted: (CGPoint) -> Bool = try paint(of: [beak], in: kit)
        var low: Double = .infinity
        for x in stride(from: -0.6, through: 0.6, by: 0.005) {
            for y in stride(from: 0.0, through: 1.0, by: 0.005) where painted(CGPoint(x: x, y: y)) {
                low = min(low, Double(Skeleton.place(CGPoint(x: x, y: y), on: .head, rig: kit.rig, pose: pose).y))
            }
        }
        return low
    }

    /// The hen pecks the same way: by tipping her body, with her lower neck nearly in line with it.
    @MainActor @Test func henPecksWithHerNeckInLine() throws {
        PartKit.reload()
        let hen: PartKit = try #require(PartKit.load(.hen), "the hen kit does not load")
        let bottom: ChickenPose = ChickenMotion.peck(hen.rig, progress: 0.5)
        #expect(abs(bottom[.neckLow]) < 30)
        #expect(bottom[.body] >= 45)
    }

    /// Both hen kits bend their body, neck, head and tail as one image, and sit with the belly (the
    /// body's lowest paint, found here from the body's own pixels) on the ground.
    @MainActor @Test func henKitsBendAndSitOnTheirBelly() throws {
        PartKit.reload()
        for name in [KitName.hen, .henB] {
            let kit: PartKit = try #require(PartKit.load(name), "\(name) does not load")
            let skin: ChickenSkin = try #require(kit.skin, "\(name)")
            #expect(skin.bones.map(\.bone) == [.body, .tail, .neckLow, .neckHigh, .head], "\(name)")
            let body: KitLayer = try #require(kit.layers.first { $0.id == "body" })
            let painted: (CGPoint) -> Bool = try Self.paint(of: [body], in: kit)
            let step: Double = 0.002
            var lowest: CGPoint?
            for y in stride(from: 0.0, through: 1.0, by: step) {
                if let x = stride(from: -0.6, through: 0.6, by: step).first(where: { painted(CGPoint(x: $0, y: y)) }) {
                    lowest = CGPoint(x: x, y: y)
                    break
                }
            }
            let belly: CGPoint = try #require(lowest, "\(name) has no body paint")
            let sat: CGPoint = Skeleton.place(belly, on: body.bone, rig: kit.rig, pose: ChickenMotion.sitting(kit.rig))
            #expect(abs(sat.y) < 2 * step, "\(name): the belly sits \(sat.y) above the ground")
            #expect(belly.y > 0.05 && belly.y < kit.rig.hip.y, "\(name)")
        }
    }

    /// Every painted point of each hen kit's bent feathers lies in a kept cell of its run's mesh, so no
    /// paint is left out of the bend.
    @MainActor @Test func henKitsMeshesHoldAllTheirPaint() throws {
        PartKit.reload()
        for name in [KitName.hen, .henB] {
            let kit: PartKit = try #require(PartKit.load(name), "\(name) does not load")
            try #require(kit.skin != nil, "\(name) has no skin")
            #expect(!kit.meshes.isEmpty, "\(name)")
            var runs: [[KitLayer]] = []
            var last: Bool = false
            for layer in kit.layers {
                let skinned: Bool = kit.isSkinned(layer)
                if skinned, last { runs[runs.count - 1].append(layer) } else if skinned { runs.append([layer]) }
                last = skinned
            }
            var checked: Int = 0
            for run in runs {
                let mesh: SkinMesh = try #require(kit.meshes[run[0].id], "\(name) \(run[0].id)")
                let kept = Set(mesh.triangles.map { $0.corners[0] })
                let painted: (CGPoint) -> Bool = try Self.paint(of: run, in: kit)
                for x in stride(from: -0.6, through: 0.6, by: 0.01) {
                    for y in stride(from: 0.0, through: 1.0, by: 0.01) where painted(CGPoint(x: x, y: y)) {
                        checked += 1
                        let column = Int(((x - Double(mesh.origin.x)) / mesh.cell).rounded(.down))
                        let row = Int(((y - Double(mesh.origin.y)) / mesh.cell).rounded(.down))
                        let inside: Bool = column >= 0 && column < mesh.columns && row >= 0 && row < mesh.rows
                        #expect(
                            inside && kept.contains(row * (mesh.columns + 1) + column),
                            "\(name): paint at \(x), \(y) is outside the mesh")
                    }
                }
            }
            #expect(checked > 1000, "\(name)")
        }
    }

    /// Through a whole peck, each hen kit's bent paint is drawn where the mesh puts it: the shader's lookup
    /// (`SkinMesh.sources`) finds every painted rest point at its moved place, unless `maxFolds` layers of
    /// paint already lie over it there. So no hole opens, even where the bend folds over itself at the throat.
    @MainActor @Test func henKitsLoseNoPaintInAPeck() throws {
        PartKit.reload()
        let height: Double = 240
        let ground: Double = height * Double(ChickenRigMetrics.widthRatio) / 2
        for name in [KitName.hen, .henB] {
            let kit: PartKit = try #require(PartKit.load(name), "\(name) does not load")
            let skin: ChickenSkin = try #require(kit.skin, "\(name) has no skin")
            var lost: Int = 0
            var checked: Int = 0
            for (id, mesh) in kit.meshes {
                var run: [KitLayer] = []
                for layer in kit.layers.drop(while: { $0.id != id }) {
                    guard kit.isSkinned(layer) else { break }
                    run.append(layer)
                }
                let painted: (CGPoint) -> Bool = try Self.paint(of: run, in: kit)
                // Any paint at all, as the shader counts it (`clear`), at the nearest pixels: a found point a hair
                // from its rest point can round to the pixel past a hard painted edge.
                let any: (CGPoint) -> Bool = try Self.paint(of: run, in: kit, above: 0)
                let pixel: Double = 1 / Double(PartKit.workingHeight)
                let touched: (CGPoint) -> Bool = { p in
                    [(-1.0, 0.0), (1, 0), (0, -1), (0, 1), (0, 0)].contains { dx, dy in
                        any(CGPoint(x: Double(p.x) + dx * pixel, y: Double(p.y) + dy * pixel))
                    }
                }
                for progress in [0.1, 0.2, 0.3, 0.4, 0.5] {
                    let pose: ChickenPose = ChickenMotion.peck(kit.rig, progress: progress)
                    let t: [Affine] = skin.bones.map {
                        Skeleton.transform(of: $0.bone, rig: kit.rig, pose: pose, height: height)
                    }
                    let moved: [CGPoint] = mesh.moved(transforms: t, height: height)
                    let layer: CGRect = mesh.restBounds(height: height).union(mesh.reach(moved: moved))
                        .insetBy(dx: -1, dy: -1)
                    let offset = CGPoint(x: -layer.minX, y: -layer.minY)
                    let packed = mesh.packed(moved: moved, height: height, layer: layer, offset: offset)
                    let corner: CGPoint = mesh.rest(0, height: height)
                    let grid = CGPoint(x: corner.x + offset.x, y: corner.y + offset.y)
                    // A layer point back to rig units.
                    func rig(_ q: CGPoint) -> CGPoint {
                        CGPoint(
                            x: (Double(q.x - offset.x) - ground) / height, y: (height - Double(q.y - offset.y)) / height
                        )
                    }
                    // About a point apart: a hole in a fold can be a few points across.
                    for x in stride(from: -0.6, through: 0.6, by: 0.005) {
                        for y in stride(from: 0.0, through: 1.0, by: 0.005) where painted(CGPoint(x: x, y: y)) {
                            let rest = CGPoint(x: x, y: y)
                            guard let at = mesh.place(rest, moved: moved) else {
                                lost += 1
                                continue
                            }
                            checked += 1
                            let found: [CGPoint] = mesh.sources(
                                of: CGPoint(x: at.x + offset.x, y: at.y + offset.y), packed: packed, grid: grid,
                                height: height
                            ) { touched(rig($0)) }
                            let shown: Bool = found.contains { q in
                                let r: CGPoint = rig(q)
                                return hypot(Double(r.x - rest.x), Double(r.y - rest.y)) * height < 0.5
                            }
                            // Hidden only under `maxFolds` layers that hold paint.
                            if !shown && found.count(where: { touched(rig($0)) }) < SkinMesh.maxFolds {
                                lost += 1
                            }
                        }
                    }
                }
            }
            #expect(checked > 1000, "\(name)")
            #expect(lost == 0, "\(name): \(lost) of \(checked) painted points come out clear")
        }
    }

    /// Whether any of `layers` has paint at a rig point (alpha above a tenth, or above `above` of 255).
    private static func paint(of layers: [KitLayer], in kit: PartKit, above: UInt8 = 25) throws -> (CGPoint) -> Bool {
        let first: CGImage = try #require(layers.first?.image)
        let w: Int = first.width
        let h: Int = first.height
        var alpha = [UInt8](repeating: 0, count: w * h)
        // The context keeps the pointer it is given, so it is used only inside the buffer's scope.
        try alpha.withUnsafeMutableBytes { buffer in
            let context: CGContext = try #require(
                CGContext(
                    data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue))
            for layer in layers { context.draw(layer.image, in: CGRect(x: 0, y: 0, width: w, height: h)) }
        }
        let scale: Double = Double(w) / kit.spec.canvas[0]
        let unit: Double = kit.spec.unit
        let ground = CGPoint(x: kit.spec.groundPoint[0], y: kit.spec.groundPoint[1])
        let snapshot: [UInt8] = alpha
        return { p in
            // Rig units to canvas pixels (y down), then to working pixels. The context's rows run top down.
            let px = Int(((Double(ground.x) + Double(p.x) * unit) * scale).rounded())
            let py = Int(((Double(ground.y) - Double(p.y) * unit) * scale).rounded())
            guard px >= 0, px < w, py >= 0, py < h else { return false }
            return snapshot[py * w + px] > above
        }
    }

    /// Launch reads only the kits a bird can draw. `hen-b` is for the test tools, so it loads when picked.
    @Test func launchPreloadsOnlyTheKitsBirdsUse() {
        #expect(!KitName.preloaded.contains(.henB))
        #expect(KitName.preloaded == KitName.all.filter { $0 != .henB })
    }

    /// Drawing never reads a kit: a hen drawn before the hen kit is read gets the path rig, and the kit is
    /// read off the main thread. Once it is in, she gets it.
    @MainActor @Test func drawingNeverReadsAKit() async throws {
        PartKit.reload()
        var hen: ChickenColours = ChickenColours.sample
        hen.isGrownHen = true
        #expect(PartKit.kit(for: hen) == nil)
        await PartKit.preload()
        let henKit: PartKit = try #require(PartKit.kit(for: hen), "the hen kit does not load")
        #expect(henKit.name == .hen)
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
        spec.skin = [
            "wing": .init(radius: 0.1, width: 0.1), "body": .init(radius: 0.1, width: 0.1),
            "neckLow": .init(radius: 0.1, width: 0.1), "tail": .init(radius: 0, width: 0.1),
            "shankBack": .init(radius: 0.1, width: 0.1),
        ]
        let skinProblems: [String] = spec.problems(files: files)
        #expect(skinProblems.contains("skin names unknown bone wing"))
        #expect(skinProblems.contains("skin names body, which is always its root"))
        #expect(skinProblems.contains("skin names neckLow, which has no joint"))
        #expect(skinProblems.contains("skin radius of tail is not above 0"))
        #expect(skinProblems.contains("skin names shankBack, but legs stay rigid"))
        spec.skin = nil
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
