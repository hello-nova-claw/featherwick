import FeatherwickCore
import SwiftUI

/// A test bench for the chicken rig: one large chicken, a slider per joint, and the three motions.
/// It shows the path rig or a painted kit (`PartKit`) on any feather colour and pattern, with the kit's
/// joints as dots: the tool for checking each new painted part.
struct RigLabView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    /// Manual shows the sliders' pose. The others run `AnimatedChicken`.
    private enum Mode: Hashable {
        case manual, idle, walking, pecking
    }

    /// The patterns a kit can paint, or none.
    private enum LabPattern: Hashable {
        case none, lacing, barring
    }

    /// The feather colours to check a part on, as the brief lists them.
    private static let tones: [Tone] = [.black, .blue, .splash, .lavender, .buff, .whiteFeather]

    @State private var mode: Mode = .manual
    /// The body shape whose painted kit the stage uses. Nil, or a shape with no kit: the path rig.
    @State private var build: KitName?
    /// Nil keeps the bird's (or the sample's) own colours.
    @State private var tone: Tone?
    @State private var pattern: LabPattern = .none
    @State private var showJoints = false
    /// Bumped by "Reload kit", so the stage reads the kit again.
    @State private var kitVersion = 0
    /// Bumped to restart an animation (another peck).
    @State private var run = 0
    @State private var facingRight = true
    @State private var chick = false
    /// Nil shows the sample colours.
    @State private var birdID: UUID?

    // Every bone's angle in degrees (in `Bone.allCases` order), plus the hip's lift, head turn, blink and sit.
    @State private var angles: [Double] = Array(repeating: 0, count: Bone.allCases.count)
    @State private var rise: Double = 0
    @State private var headTurn: Double = 0
    @State private var blink: Double = 0
    @State private var sit: Double = 0
    /// The frame rate while a motion plays: a large painted hen is the heaviest bird to draw.
    @State private var meter = FrameMeter()

    private let rigHeight: CGFloat = 240

    var body: some View {
        List {
            // The play buttons sit right under the hen, so they stay on screen with her.
            Section {
                stage
                playButtons
            }
            Section("Rig") { rigControls }
            Section("Joints") { jointSliders }
            Section("Bird") { birdControls }
        }
        .navigationTitle("Rig lab")
        .onAppear { meter.start() }
        .onDisappear { meter.stop() }
        .onChange(of: pose) { mode = .manual }
        .onChange(of: birdID) { chick = birdColours?.isChick ?? false }
    }

    /// The sliders' pose: sitting (legs folded by the solver) as far as the sit slider says, then each bone's
    /// slider on top.
    private var pose: ChickenPose {
        var p: ChickenPose = ChickenMotion.sitting(skeleton, amount: sit)
        for bone in Bone.allCases { p[bone] += angles[bone.rawValue] }
        p.rise += rise
        p.headTurn = headTurn
        p.blink = blink
        return p
    }

    /// The skeleton on the stage: the kit's, or the path rig's.
    private var skeleton: SkeletonRig { kit?.rig ?? ChickenRig.rig(isChick: colours.isChick) }

    private var birds: [Bird] {
        let s: GameState = store.state
        return s.coop + s.brooder + s.henChicks
    }

    /// The chosen bird's own colours, as the farm would draw it today.
    private var birdColours: ChickenColours? {
        guard let birdID, let bird = birds.first(where: { $0.id == birdID }) else { return nil }
        return ChickenColours(bird: bird, state: store.state)
    }

    /// The chosen bird's colours, or a sample, with the lab's colour, pattern and rig on top. The chick
    /// switch can force either build. Chicks always use the path rig.
    private var colours: ChickenColours {
        var c: ChickenColours = birdColours ?? (chick ? ChickenColours.sampleChick : ChickenColours.sample)
        c.isChick = chick
        if let tone {
            c.feathers = tone.artColour
            c.hackle = tone.artColour
            c.tail = tone.artColour
        }
        switch pattern {
        case .none:
            if tone != nil { c.pattern = nil }
        case .lacing:
            c.pattern = .lacing
            c.patternColour = Tone.black.artColour
        case .barring:
            c.pattern = .barring
            c.patternColour = Tone.white.artColour
        }
        c.use(kit: build)
        return c
    }

    /// The painted kit the stage uses, or nil for the path rig.
    private var kit: PartKit? { PartKit.kit(for: colours) }

    // MARK: - Stage

    /// The chicken on a ground line. The dot marks the ground point: the rig's bottom centre.
    private var stage: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(palette.hairline).frame(height: 1)
            chicken
            Circle().fill(palette.inkMuted).frame(width: 6, height: 6).offset(y: 3)
        }
        .frame(maxWidth: .infinity)
        .frame(height: rigHeight + Space.xxl)
        .padding(.vertical, Space.m)
        .id(kitVersion)
        .overlay(alignment: .topLeading) { FrameReadout(meter: meter) }
    }

    @ViewBuilder
    private var chicken: some View {
        switch mode {
        case .manual:
            if let kit {
                PaintedChickenRig(
                    kit: kit, colours: colours, pose: pose, facingRight: facingRight, height: rigHeight,
                    showJoints: showJoints)
            } else {
                ChickenRig(colours: colours, pose: pose, facingRight: facingRight, height: rigHeight)
            }
        case .idle:
            animated(.idle)
        case .walking:
            animated(.walking)
        case .pecking:
            animated(.pecking)
        }
    }

    private func animated(_ activity: ChickenActivity) -> some View {
        AnimatedChicken(colours: colours, height: rigHeight, facingRight: facingRight, activity: activity)
            .id(run)
    }

    // MARK: - Controls

    private var playButtons: some View {
        HStack(spacing: Space.s) {
            playButton("Walk", .walking)
            playButton("Peck", .pecking)
            playButton("Idle", .idle)
            Button("Rest") { resetJoints() }
                .buttonStyle(.bordered)
        }
    }

    private func playButton(_ title: String, _ target: Mode) -> some View {
        Button(title) {
            mode = target
            run += 1
        }
        .buttonStyle(.borderedProminent)
    }

    private var rigControls: some View {
        Group {
            Picker("Painted kit", selection: $build) {
                Text("None (path rig)").tag(KitName?.none)
                ForEach(KitName.all, id: \.self) { name in
                    Text(name.folder).tag(KitName?.some(name))
                }
            }
            Picker("Feathers", selection: $tone) {
                Text("Bird's own").tag(Tone?.none)
                ForEach(Self.tones, id: \.self) { tone in
                    Text(tone == .whiteFeather ? "white" : tone.rawValue).tag(Tone?.some(tone))
                }
            }
            Picker("Pattern", selection: $pattern) {
                Text("None").tag(LabPattern.none)
                Text("Lacing").tag(LabPattern.lacing)
                Text("Barring").tag(LabPattern.barring)
            }
            .pickerStyle(.segmented)
            Toggle("Joints (pivots and landmarks, at rest)", isOn: $showJoints)
            kitStatus
            Button("Reload kit") {
                PartKit.reload()
                kitVersion += 1
            }
        }
        .font(Typeface.body)
    }

    /// Where the kit came from, or why the path rig shows. Joints show in the manual pose only.
    @ViewBuilder
    private var kitStatus: some View {
        if let build {
            if let kit {
                Text("Kit: \(kit.folder.path)")
                    .font(Typeface.caption).foregroundStyle(palette.inkMuted)
                    .lineLimit(2).truncationMode(.head)
            } else {
                Text("No kit loaded (a chick, or no Parts/\(build.folder)/kit.json): the path rig shows.")
                    .font(Typeface.caption).foregroundStyle(palette.inkMuted)
            }
            Text(
                "Reload reads the kit again. The app bundle changes only with a build. A Debug build on the "
                    + "simulator reads App/Featherwick/Art/Parts on the Mac, so a new PNG shows at once."
            )
            .font(Typeface.caption).foregroundStyle(palette.inkMuted)
        }
    }

    private var jointSliders: some View {
        Group {
            ForEach(Bone.allCases, id: \.self) { bone in
                JointSlider(title: title(bone), value: angle(bone), range: -90...90)
                    .disabled(!skeleton.has(bone))
            }
            JointSlider(title: "hip (lift)", value: $rise, range: -0.3...0.1, unit: "")
            JointSlider(title: "head (turn)", value: $headTurn, range: -1...1, unit: "")
            JointSlider(title: "eyelid (blink)", value: $blink, range: 0...1, unit: "")
            JointSlider(title: "sit (body down, legs fold)", value: $sit, range: 0...1, unit: "")
        }
    }

    /// A bone's slider name: where it turns. A bone this rig does not have is greyed out.
    private func title(_ bone: Bone) -> String {
        let name: String
        switch bone {
        case .body: name = "body (tilt at hip)"
        case .tail: name = "tail (flick)"
        case .neckLow: name = "neck low (swing at shoulder)"
        case .neckHigh: name = "neck high (bend mid-neck)"
        case .head: name = "head (dip at throat)"
        case .thighBack: name = "thigh back (swing at hip)"
        case .shankBack: name = "shank back (bend at hock)"
        case .toesBack: name = "toes back (curl)"
        case .thighFront: name = "thigh front (swing at hip)"
        case .shankFront: name = "shank front (bend at hock)"
        case .toesFront: name = "toes front (curl)"
        }
        return skeleton.has(bone) ? name : name + " · not in this rig"
    }

    private func angle(_ bone: Bone) -> Binding<Double> {
        Binding(get: { angles[bone.rawValue] }, set: { angles[bone.rawValue] = $0 })
    }

    private var birdControls: some View {
        Group {
            Picker("Colours", selection: $birdID) {
                Text("Sample").tag(UUID?.none)
                ForEach(birds) { bird in
                    Text(bird.name).tag(UUID?.some(bird.id))
                }
            }
            Toggle("Faces right", isOn: $facingRight)
            Toggle("Chick", isOn: $chick)
        }
        .font(Typeface.body)
    }

    private func resetJoints() {
        angles = Array(repeating: 0, count: Bone.allCases.count)
        rise = 0
        headTurn = 0
        blink = 0
        sit = 0
        mode = .manual
    }
}

/// One joint's slider, with its name and value.
private struct JointSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// "°" for angles. Empty for 0–1 or -1…1 values, shown with two decimals.
    var unit: String = "°"

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Text(title).font(Typeface.label)
                Spacer()
                Text(valueText).font(Typeface.label).monospacedDigit()
            }
            Slider(value: $value, in: range)
        }
    }

    private var valueText: String {
        let digits: Int = unit.isEmpty ? 2 : 0
        return value.formatted(.number.precision(.fractionLength(digits))) + unit
    }
}
