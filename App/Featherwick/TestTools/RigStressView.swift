import FeatherwickCore
import SwiftUI

/// The frame budget stage: many chickens walking at yard size, for Instruments (Animation Hitches).
/// The README's target is 10 birds walking on a yard panel at 60 fps on an iPhone 12. Birds draw on the
/// skeleton with the path rig, or with a body shape's painted kit when one exists.
///
/// View only: the birds are samples, not the flock, so nothing is saved and no command runs. Every bird
/// walks all the time, the worst case, at the yard's size and speed. They walk the way the scene's birds do
/// (a linear position animation, then a turn), so the cost is the scene's cost. A mix of plain, laced and
/// barred birds includes the extra offscreen pass a painted kit's overlays take.
struct RigStressView: View {
    @Environment(\.palette) private var palette

    @State private var count: Int = 10
    /// The body shape whose painted kit the birds use. Nil, or a shape with no kit: the path rig.
    @State private var build: KitName?
    /// Bumped to put every bird back at its start.
    @State private var run = 0

    var body: some View {
        VStack(spacing: Space.s) {
            controls
            GeometryReader { geo in
                ZStack {
                    ForEach(0..<count, id: \.self) { i in
                        StressBird(index: i, count: count, colours: colours(i), size: geo.size)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
            .id(run)
            .background(palette.paper)
        }
        .navigationTitle("\(count) walking birds")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Stepper("Birds: \(count)", value: $count, in: 1...30)
            Picker("Painted kit", selection: $build) {
                Text("None (path rig)").tag(KitName?.none)
                ForEach(KitName.all, id: \.self) { name in
                    Text(name.folder).tag(KitName?.some(name))
                }
            }
            Text(
                "To measure: Xcode ▸ Product ▸ Profile on the phone, the Animation Hitches template. Record "
                    + "20 s here with no touches. A body shape with no kit falls back to the path rig."
            )
            .font(Typeface.caption).foregroundStyle(palette.inkMuted)
        }
        .font(Typeface.body)
        .padding(.horizontal, Space.m)
        .onChange(of: count) { run += 1 }
        .onChange(of: build) { run += 1 }
    }

    /// Feather tones and patterns in turn: every third bird laced, every fourth barred.
    private static let tones: [Tone] = [.buff, .black, .blue, .splash, .lavender, .whiteFeather]

    private func colours(_ i: Int) -> ChickenColours {
        var c: ChickenColours = .sample
        let tone: Tone = Self.tones[i % Self.tones.count]
        c.feathers = tone.artColour
        c.hackle = tone.artColour
        c.tail = tone.artColour
        if i % 3 == 2 {
            c.pattern = .lacing
            c.patternColour = Tone.black.artColour
        } else if i % 4 == 3 {
            c.pattern = .barring
            c.patternColour = Tone.white.artColour
        }
        c.use(kit: build)
        return c
    }
}

/// One bird pacing its own row: across the stage, a turn, and back, for as long as the stage shows.
private struct StressBird: View {
    let index: Int
    let count: Int
    let colours: ChickenColours
    let size: CGSize

    @State private var x: CGFloat
    @State private var facingRight: Bool

    private let height: CGFloat = FarmFlock.sceneAdultHeight

    init(index: Int, count: Int, colours: ChickenColours, size: CGSize) {
        self.index = index
        self.count = count
        self.colours = colours
        self.size = size
        // Spread along the row, half facing each way, so the flock never moves in step.
        _x = State(initialValue: CGFloat((index * 37) % 100) / 100)
        _facingRight = State(initialValue: index % 2 == 0)
    }

    var body: some View {
        AnimatedChicken(colours: colours, height: height, facingRight: facingRight, activity: .walking)
            .frame(width: height * ChickenRigMetrics.widthRatio, height: height)
            .position(x: margin + x * span, y: rowY)
            .zIndex(Double(rowY))
            .task { await pace() }
    }

    private var margin: CGFloat { height * ChickenRigMetrics.widthRatio / 2 }
    private var span: CGFloat { max(1, size.width - 2 * margin) }

    /// Rows from the top of the stage to the bottom, one per bird.
    private var rowY: CGFloat {
        let top: CGFloat = height
        let rows: CGFloat = CGFloat(max(1, count - 1))
        return top + (size.height - top - height / 2) * CGFloat(index) / rows
    }

    /// Walk to the far edge at the yard's speed, turn, and repeat until the stage goes away.
    private func pace() async {
        while !Task.isCancelled {
            let target: CGFloat = facingRight ? 1 : 0
            let seconds: Double = Double(abs(target - x) * span / SceneFlock.speed)
            withAnimation(.linear(duration: seconds)) { x = target }
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch {
                return
            }
            facingRight.toggle()
        }
    }
}
