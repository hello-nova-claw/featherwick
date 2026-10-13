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

    /// Which rig draws the bird. Painted falls back to the path rig when the kit does not load.
    private enum Rig: Hashable {
        case path, painted
    }

    /// The patterns a kit can paint, or none.
    private enum LabPattern: Hashable {
        case none, lacing, barring
    }

    /// The feather colours to check a part on, as the brief lists them.
    private static let tones: [Tone] = [.black, .blue, .splash, .lavender, .buff, .whiteFeather]

    @State private var mode: Mode = .manual
    @State private var rig: Rig = .painted
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

    // The joints, in degrees, plus head turn, blink and sit.
    @State private var bodyTilt: Double = 0
    @State private var neckSwing: Double = 0
    @State private var headTurn: Double = 0
    @State private var blink: Double = 0
    @State private var legBack: Double = 0
    @State private var legFront: Double = 0
    @State private var sit: Double = 0

    private let rigHeight: CGFloat = 240

    var body: some View {
        List {
            Section { stage }
            Section("Rig") { rigControls }
            Section("Play") { playButtons }
            Section("Joints") { jointSliders }
            Section("Bird") { birdControls }
        }
        .navigationTitle("Rig lab")
        .onChange(of: pose) { mode = .manual }
        .onChange(of: birdID) { chick = birdColours?.isChick ?? false }
    }

    private var pose: ChickenPose {
        ChickenPose(
            bodyTilt: .degrees(bodyTilt), neckSwing: .degrees(neckSwing), headTurn: headTurn, blink: blink,
            legBack: .degrees(legBack), legFront: .degrees(legFront), sit: sit)
    }

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
        c.build = rig == .painted ? .heavy : nil
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
            Picker("Rig", selection: $rig) {
                Text("Path rig").tag(Rig.path)
                Text("Painted (heavy)").tag(Rig.painted)
            }
            .pickerStyle(.segmented)
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
        if rig == .painted {
            if let kit {
                Text("Kit: \(kit.folder.path)")
                    .font(Typeface.caption).foregroundStyle(palette.inkMuted)
                    .lineLimit(2).truncationMode(.head)
            } else {
                Text("No kit loaded (a chick, or no Parts/heavy/kit.json): the path rig shows.")
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
            JointSlider(title: "body (tilt at hip)", value: $bodyTilt, range: -40...40)
            // A painted kit whose neck rides on the body dips the head at the throat with this instead.
            JointSlider(title: "neck (swing at shoulder; head dip on heavy)", value: $neckSwing, range: -60...80)
            JointSlider(title: "head (turn)", value: $headTurn, range: -1...1, unit: "")
            JointSlider(title: "eyelid (blink)", value: $blink, range: 0...1, unit: "")
            JointSlider(title: "leg_back (swing at hip)", value: $legBack, range: -45...45)
            JointSlider(title: "leg_front (swing at hip)", value: $legFront, range: -45...45)
            JointSlider(title: "sit (body down, legs fold)", value: $sit, range: 0...1, unit: "")
        }
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
        bodyTilt = 0
        neckSwing = 0
        headTurn = 0
        blink = 0
        legBack = 0
        legFront = 0
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
