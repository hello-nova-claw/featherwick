import FeatherwickCore
import FeatherwickText
import SwiftUI

/// The five tap places on the farm. Each one opens a sheet.
enum Place: String, CaseIterable, Identifiable {
    case backFence, coop, pottingShed, yard, farmGate
    var id: String { rawValue }

    var name: String {
        switch self {
        case .backFence: "Back fence"
        case .coop: "Coop"
        case .pottingShed: "Potting shed"
        case .yard: "Yard"
        case .farmGate: "Farm gate"
        }
    }

    /// Where the label sits, as a fraction of the farm painting (just below the place it names).
    /// Measured on the backyard mockup; change these when the painting changes.
    var anchor: UnitPoint {
        switch self {
        case .backFence: UnitPoint(x: 0.5, y: 0.585)
        case .coop: UnitPoint(x: 0.2, y: 0.635)
        case .pottingShed: UnitPoint(x: 0.8, y: 0.64)
        case .yard: UnitPoint(x: 0.5, y: 0.67)
        case .farmGate: UnitPoint(x: 0.55, y: 0.835)
        }
    }
}

/// Everything that opens over the farm. One sheet at a time.
enum FarmSheet: Identifiable, Hashable {
    case place(Place)
    case bird(UUID)
    case naming
    case books
    case settings
    var id: Self { self }
}

/// The farm screen: the painted scene (a placeholder until the art exists), the HUD, the five
/// place labels, and Books and settings at the bottom.
struct FarmView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @State private var sheet: FarmSheet?

    var body: some View {
        ZStack {
            // The scene and its labels fill the whole screen, so labels line up with the painting.
            GeometryReader { geo in
                let frame = FarmScene.paintingFrame(in: geo.size)
                ZStack {
                    FarmScene()
                    ForEach(Place.allCases) { place in
                        PlaceLabel(place: place, notices: notices(for: place)) { sheet = .place(place) }
                            .position(
                                x: frame.minX + frame.width * place.anchor.x,
                                y: frame.minY + frame.height * place.anchor.y)
                    }
                }
            }
            .ignoresSafeArea()
            VStack {
                HUD()
                Spacer()
                HStack {
                    FloatingBox {
                        Button("Books") { sheet = .books }
                            .font(Typeface.display(23, relativeTo: .title2))
                            .frame(minWidth: 72, minHeight: 56)
                    }
                    Spacer()
                    FloatingBox {
                        Button {
                            sheet = .settings
                        } label: {
                            Text("≡").font(Typeface.sans(24)).frame(width: 56, height: 56)
                        }
                        .accessibilityLabel("Settings")
                    }
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xl)
            .buttonStyle(.plain)
            .foregroundStyle(palette.ink)
            ToastStack()
        }
        .sheet(item: $sheet) { which in
            content(for: which)
                .environment(\.palette, palette)
        }
        .onChange(of: store.openRequest) { _, request in
            if let request {
                sheet = request
                store.openRequest = nil
            }
        }
    }

    @ViewBuilder
    private func content(for which: FarmSheet) -> some View {
        switch which {
        case .place(.coop): CoopSheet(open: open)
        case .place(.yard): YardSheet(open: open)
        case .place(.pottingShed): PottingShedSheet(open: open)
        case .place(.farmGate): FarmGateSheet()
        case .place(.backFence): BackFenceSheet()
        case .bird(let id): BirdCardSheet(birdID: id, context: "In the flock")
        case .naming: NamingSheet()
        case .books: BooksView()
        case .settings: SettingsSheet()
        }
    }

    /// Swap the open sheet for another (a bird card from a list, the naming prompt).
    private func open(_ next: FarmSheet) {
        sheet = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            sheet = next
        }
    }

    /// What each place has waiting. The words carry the meaning; the dot only draws the eye.
    private func notices(for place: Place) -> [Notice] {
        let s = store.state
        switch place {
        case .coop:
            var n: [Notice] = []
            if !s.nest.isEmpty {
                n.append(Notice(kind: .collect, text: "\(s.nest.count) egg\(s.nest.count == 1 ? "" : "s") waiting"))
            }
            if palette.isNight && s.coopDoorOpen { n.append(Notice(kind: .decision, text: "door still open")) }
            if palette.isNight && !s.coopDoorOpen { n.append(Notice(kind: .story, text: "\(s.coop.count) asleep")) }
            return n
        case .pottingShed:
            var n: [Notice] = []
            if let bird = s.unnamedBirds.first {
                n.append(Notice(kind: .decision, text: "\(bird.revealed ? "a bird" : "a chick") needs a name"))
            }
            if let c = s.incubatorClutch, c.hatchDay <= s.day + 1 {
                n.append(Notice(kind: .collect, text: "hatching tonight"))
            }
            return n
        case .backFence:
            let news = Engine.storyAwaitingDelivery(s) != nil || s.tradeOffer != nil
            return news ? [Notice(kind: .story, text: "has news")] : []
        case .yard:
            if !s.fedToday { return [Notice(kind: .decision, text: "hungry")] }
            return s.lost.isEmpty ? [] : [Notice(kind: .story, text: "\(s.lost.count) wandered off")]
        case .farmGate:
            let until = s.nextShowDay - s.day
            return until <= 3 ? [Notice(kind: .story, text: until == 0 ? "show today" : "show in \(until) days")] : []
        }
    }
}

/// The painted farm, scaled to fill the screen. Night is the day painting, darkened and cooled.
/// Without a painting in the bundle, the striped stand-in shows instead.
struct FarmScene: View {
    @Environment(\.palette) private var palette

    /// The bundled painting: `Art/farm-day.png` (or .jpg). Portrait, about 6:13.
    static let painting: UIImage? = ["farm-day.png", "farm-day.jpg"].lazy.compactMap { UIImage(named: $0) }.first

    /// Where the painting lands on a screen of this size, after scale-to-fill. Labels use it.
    static func paintingFrame(in size: CGSize) -> CGRect {
        let aspect = painting.map { $0.size.width / $0.size.height } ?? (6.0 / 13.0)
        let scale = max(size.width / aspect, size.height)
        let drawn = CGSize(width: aspect * scale, height: scale)
        return CGRect(
            x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2, width: drawn.width,
            height: drawn.height)
    }

    var body: some View {
        if let painting = Self.painting {
            GeometryReader { geo in
                let frame = Self.paintingFrame(in: geo.size)
                Image(uiImage: painting)
                    .resizable()
                    .frame(width: frame.width, height: frame.height)
                    .saturation(palette.isNight ? 0.55 : 1)
                    .overlay {
                        if palette.isNight {
                            Color(hex: 0x1B2233).opacity(0.62).blendMode(.multiply)
                        }
                    }
                    .position(x: frame.midX, y: frame.midY)
            }
            .clipped()
            .accessibilityHidden(true)
        } else {
            FarmScenePlaceholder()
        }
    }
}

/// Stand-in for the painted farm: paper with soft diagonal stripes, as in the mocks.
struct FarmScenePlaceholder: View {
    @Environment(\.palette) private var palette
    var body: some View {
        Canvas { context, size in
            let stripe = palette.isNight ? Color.white.opacity(0.04) : Color(hex: 0xF4EEE6)
            var x: CGFloat = -size.height
            while x < size.width {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                context.stroke(p, with: .color(stripe), lineWidth: 14)
                x += 36
            }
        }
        .background(palette.isNight ? Color(hex: 0x24201E) : Color(hex: 0xFBF8F4))
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// A white box floating over the scene: radius 10 and a soft shadow.
struct FloatingBox<Content: View>: View {
    @Environment(\.palette) private var palette
    @ViewBuilder var content: Content
    var body: some View {
        content
            .background(palette.floating, in: RoundedRectangle(cornerRadius: Radius.control))
            .shadow(color: Color(hex: 0x2A2320).opacity(0.35), radius: 7, y: 4)
    }
}

/// A place name over the farm, with what is waiting there underneath.
struct PlaceLabel: View {
    @Environment(\.palette) private var palette
    let place: Place
    let notices: [Notice]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(place.name).font(Typeface.place)
                ForEach(notices, id: \.self) { NoticeLine(notice: $0) }
            }
            .foregroundStyle(palette.ink)
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.s)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .background(palette.floating, in: RoundedRectangle(cornerRadius: Radius.control))
        .shadow(color: Color(hex: 0x2A2320).opacity(0.35), radius: 7, y: 4)
        .accessibilityLabel(([place.name] + notices.map(\.text)).joined(separator: ", "))
    }
}

/// Top left: day and season. Top right: coins and treats.
struct HUD: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        let s = store.state
        HStack(alignment: .top) {
            FloatingBox {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day \(s.day)").font(Typeface.display(28, relativeTo: .title))
                    Text("\(s.season.rawValue.capitalized) · \(timeOfDay)").font(Typeface.label)
                        .foregroundStyle(palette.inkSoft)
                }
                .padding(.horizontal, Space.m)
                .padding(.vertical, Space.s)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            FloatingBox {
                HStack(spacing: Space.m) {
                    HStack(spacing: 6) {
                        CoinDisc()
                        Text(s.coins.formatted()).font(Typeface.number).monospacedDigit()
                    }
                    .frame(minHeight: 44)
                    HStack(spacing: 6) {
                        TreatDiamond()
                        Text("\(s.treats)").font(Typeface.number).monospacedDigit()
                    }
                    .frame(minHeight: 44)
                }
                .padding(.horizontal, Space.m)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(s.coins.formatted()) coins, \(s.treats) treats")
        }
        .foregroundStyle(palette.ink)
    }

    private var timeOfDay: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }
}
