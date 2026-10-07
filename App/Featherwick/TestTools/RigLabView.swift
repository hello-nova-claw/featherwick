import FeatherwickCore
import SwiftUI

/// A test bench for the chicken rig: one large chicken, a slider per joint, and the three motions.
/// For checking joints and poses now, and each painted part when the real art arrives.
struct RigLabView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    /// Manual shows the sliders' pose. The others run `AnimatedChicken`.
    private enum Mode: Hashable {
        case manual, idle, walking, pecking
    }

    @State private var mode: Mode = .manual
    /// Bumped to restart an animation (another peck).
    @State private var run = 0
    @State private var facingRight = true
    @State private var chick = false
    /// Nil shows the sample colours.
    @State private var birdID: UUID?

    // The joints, in degrees, plus head turn and blink.
    @State private var bodyTilt: Double = 0
    @State private var neckSwing: Double = 0
    @State private var headTurn: Double = 0
    @State private var blink: Double = 0
    @State private var legBack: Double = 0
    @State private var legFront: Double = 0

    private let rigHeight: CGFloat = 240

    var body: some View {
        List {
            Section { stage }
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
            legBack: .degrees(legBack), legFront: .degrees(legFront))
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

    /// The chosen bird's colours, or a sample. The chick switch can force either build.
    private var colours: ChickenColours {
        var c: ChickenColours = birdColours ?? (chick ? ChickenColours.sampleChick : ChickenColours.sample)
        c.isChick = chick
        return c
    }

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
    }

    @ViewBuilder
    private var chicken: some View {
        switch mode {
        case .manual:
            ChickenRig(colours: colours, pose: pose, facingRight: facingRight, height: rigHeight)
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

    private var jointSliders: some View {
        Group {
            JointSlider(title: "body (tilt at hip)", value: $bodyTilt, range: -40...40)
            JointSlider(title: "neck (swing at shoulder)", value: $neckSwing, range: -60...80)
            JointSlider(title: "head (turn)", value: $headTurn, range: -1...1, unit: "")
            JointSlider(title: "eyelid (blink)", value: $blink, range: 0...1, unit: "")
            JointSlider(title: "leg_back (swing at hip)", value: $legBack, range: -45...45)
            JointSlider(title: "leg_front (swing at hip)", value: $legFront, range: -45...45)
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
