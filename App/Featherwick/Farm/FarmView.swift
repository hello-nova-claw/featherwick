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
}

/// The farm is four panels side by side. Swipe left or right between them.
/// Each panel is a flat colour until its painting exists.
enum FarmPanel: Int, CaseIterable, Identifiable {
    case barn, yard, farYard, shop
    var id: Int { rawValue }

    var name: String {
        switch self {
        case .barn: "Barn"
        case .yard: "Yard"
        case .farYard: "Far yard"
        case .shop: "Shop"
        }
    }

    /// The places on this panel. The barn holds the coop and nests, the incubator and the brooder.
    var places: [Place] {
        switch self {
        case .barn: [.coop, .pottingShed]
        case .yard: [.yard]
        case .farYard: [.backFence]
        case .shop: [.farmGate]
        }
    }

    /// Stand-in colour until the painting exists. Placeholder art, so it is not a palette token.
    var colour: Color {
        switch self {
        case .barn: Color(hex: 0xE2B8A6)
        case .yard: Color(hex: 0xC6D8A8)
        case .farYard: Color(hex: 0xA9C69A)
        case .shop: Color(hex: 0xEAD5A2)
        }
    }

    static func containing(_ place: Place) -> FarmPanel {
        allCases.first { $0.places.contains(place) } ?? .yard
    }
}

/// Everything that opens over the farm. One sheet at a time.
enum FarmSheet: Identifiable, Hashable {
    case place(Place)
    case bird(UUID)
    case naming
    case books
    case settings
    case neighbourNote
    case jobs
    var id: Self { self }
}

/// The farm screen: four panels to swipe between (flat colours until the art exists), the HUD,
/// the place labels and the birds on each panel, and Books, the panel dots and settings at the bottom.
struct FarmView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @State private var sheet: FarmSheet?
    /// The panel on screen. The game opens on the yard, with the barn to the left and the shop to the right.
    /// Optional because the scroll view can briefly report no page; `panel` reads that as the yard.
    @State private var scrolled: FarmPanel? = .yard
    /// The show on screen. Set from `store.showReport` once no sheet is in the way.
    @State private var showDay: ShowReport?

    var body: some View {
        ZStack {
            panels
            VStack {
                HUD()
                HStack {
                    Spacer()
                    PanelDots(selection: panel, notices: panelNotices)
                }
                Spacer()
                bottomBar
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xl)
            .buttonStyle(.plain)
            .foregroundStyle(palette.ink)
            ToastStack()
        }
        .sheet(item: $sheet, onDismiss: presentShowIfWaiting) { which in
            content(for: which)
                .environment(\.palette, palette)
        }
        .fullScreenCover(item: $showDay, onDismiss: { store.finishShow() }) { report in
            ShowDayView(report: report)
                .environment(\.palette, palette)
        }
        .onChange(of: store.openRequest) { _, request in
            if let request {
                // A sheet for a place also moves the farm to that place's panel.
                if case .place(let place) = request { scrolled = .containing(place) }
                sheet = request
                store.openRequest = nil
            }
        }
        .onChange(of: store.showReport) { _, report in showReportChanged(report) }
    }

    /// One panel per page; the pages fill the whole screen, under the HUD. A paging scroll view, not a
    /// paged TabView: a TabView drops a swipe whenever a panel redraws (a bird walking), so most swipes
    /// failed.
    private var panels: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(FarmPanel.allCases) { p in
                    FarmPanelView(panel: p) { place in
                        PlaceLabel(place: place, notices: notices(for: place)) { sheet = .place(place) }
                    }
                    // The flock, in the ground band under the place labels (see `FarmBirds.swift`).
                    .overlay { PanelBirds(panel: p) { sheet = .bird($0) } }
                    .containerRelativeFrame(.horizontal)
                    .id(p)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrolled)
        // Open on the yard (page 2 of 4) from the first frame.
        .defaultScrollAnchor(UnitPoint(x: 1.0 / 3, y: 0))
        .ignoresSafeArea()
    }

    /// The panel on screen, for the dots. Tapping a dot scrolls there.
    private var panel: Binding<FarmPanel> {
        Binding(get: { scrolled ?? .yard }, set: { scrolled = $0 })
    }

    /// Books, Today and settings. Books waits until the neighbour shows the keeper the Breed Book
    /// (the early game's `breedBook` lesson). Settings is always there.
    private var bottomBar: some View {
        HStack {
            if store.state.isOpen(.breedBook) {
                FloatingBox {
                    Button("Books") { sheet = .books }
                        .font(Typeface.display(23, relativeTo: .title2))
                        .frame(minWidth: 72, minHeight: 56)
                }
            }
            FloatingBox {
                Button {
                    sheet = .jobs
                } label: {
                    TodayButtonLabel()
                }
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

    /// Show day takes the whole screen. A place sheet closes first (one presentation at a time);
    /// settings stay open, so the test tools are not cut off, and the show waits until they close.
    private func showReportChanged(_ report: ShowReport?) {
        guard let report else {
            showDay = nil
            return
        }
        switch sheet {
        case nil: showDay = report
        case .settings?: break
        default: sheet = nil
        }
    }

    private func presentShowIfWaiting() {
        if showDay == nil, let report = store.showReport { showDay = report }
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
        case .neighbourNote: NeighbourNoteSheet()
        case .jobs: JobsSheet()
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

    /// Every notice on each panel, so the panel dots can show what waits off screen.
    private var panelNotices: [FarmPanel: [Notice]] {
        Dictionary(uniqueKeysWithValues: FarmPanel.allCases.map { p in (p, p.places.flatMap { notices(for: $0) }) })
    }

    /// What each place has waiting. The words carry the meaning; the dot only draws the eye.
    private func notices(for place: Place) -> [Notice] {
        let s = store.state
        switch place {
        case .coop:
            var n: [Notice] = []
            // The naming notice sits where the bird lives, so a bird that moved to the coop is named there.
            if let bird = s.unnamedBirds.first(where: { b in s.coop.contains { $0.id == b.id } }) {
                n.append(Notice(kind: .decision, text: "\(bird.revealed ? "a bird" : "a chick") needs a name"))
            }
            if !s.nest.isEmpty {
                n.append(Notice(kind: .collect, text: "\(s.nest.count) egg\(s.nest.count == 1 ? "" : "s") waiting"))
            }
            if palette.isNight && s.coopDoorOpen { n.append(Notice(kind: .decision, text: "door still open")) }
            if palette.isNight && !s.coopDoorOpen { n.append(Notice(kind: .story, text: "\(s.coop.count) asleep")) }
            return n
        case .pottingShed:
            var n: [Notice] = []
            if let bird = s.unnamedBirds.first(where: { b in !s.coop.contains { $0.id == b.id } }) {
                n.append(Notice(kind: .decision, text: "\(bird.revealed ? "a bird" : "a chick") needs a name"))
            }
            let waiting = s.birdsWaitingForPerch
            if !waiting.isEmpty {
                let soonest = waiting.compactMap { s.nightsUntilRehomed($0.id) }.min()
                let note = soonest.map { $0 <= 1 ? ", rehomed tomorrow" : ", \($0) nights left" } ?? ""
                n.append(
                    Notice(
                        kind: .decision, text: "\(waiting.count) need\(waiting.count == 1 ? "s" : "") a perch\(note)"))
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
            var n: [Notice] = []
            // Stock the early game brought in this morning. It goes once the keeper has looked (or bought).
            if store.hasNewStock { n.append(Notice(kind: .story, text: "new in today")) }
            guard s.isOpen(.shows) else { return n }
            if let tip = s.showTip, let bird = s.bird(tip.birdID),
                !s.showEntries.contains(where: { $0.birdID == bird.id })
            {
                n.append(Notice(kind: .decision, text: "enter \(bird.name)?"))
            }
            let until = s.nextShowDay - s.day
            if until <= 3 { n.append(Notice(kind: .story, text: until == 0 ? "show today" : "show in \(until) days")) }
            return n
        }
    }
}

/// One farm panel: its stand-in colour, a dashed box where its painting will go, and its place
/// labels. Night darkens and cools the colour, as it will the paintings.
struct FarmPanelView<PlaceButton: View>: View {
    @Environment(\.palette) private var palette
    let panel: FarmPanel
    @ViewBuilder let label: (Place) -> PlaceButton

    var body: some View {
        ZStack {
            panel.colour
                .saturation(palette.isNight ? 0.55 : 1)
                .overlay {
                    if palette.isNight {
                        Color(hex: 0x1B2233).opacity(0.62).blendMode(.multiply)
                    }
                }
                .ignoresSafeArea()
            ArtPlaceholder(label: "\(panel.name.lowercased()) scene")
                .padding(.horizontal, Space.xl)
                .padding(.vertical, 140)  // clear of the HUD and the bottom row
            VStack(spacing: Space.xl) {
                ForEach(panel.places) { label($0) }
            }
        }
    }
}

/// The panel rail: one dot per panel, top to bottom in swipe order, down the right side under the HUD.
/// Tap a dot to jump there (VoiceOver cannot swipe pages). The dot on screen is ink. A panel off screen
/// with something waiting gets a bigger dot in its notice colour with a ring, so it shows from any panel.
struct PanelDots: View {
    @Environment(\.palette) private var palette
    @Binding var selection: FarmPanel
    let notices: [FarmPanel: [Notice]]

    var body: some View {
        FloatingBox {
            VStack(spacing: 0) {
                ForEach(FarmPanel.allCases) { p in
                    Button {
                        withAnimation { selection = p }
                    } label: {
                        dot(for: p).frame(width: 44, height: 40)
                    }
                    .accessibilityLabel(([p.name] + (notices[p] ?? []).map(\.text)).joined(separator: ", "))
                    .accessibilityAddTraits(p == selection ? .isSelected : [])
                }
            }
            .padding(.vertical, Space.xs)
        }
        .padding(.top, Space.s)
    }

    @ViewBuilder
    private func dot(for p: FarmPanel) -> some View {
        if p == selection {
            Circle().fill(palette.ink).frame(width: 12, height: 12)
        } else if let kind = Notice.mostPressing(notices[p] ?? []) {
            let colour = Notice.colour(kind, in: palette)
            Circle().fill(colour).frame(width: 12, height: 12)
                .padding(4)
                .overlay(Circle().stroke(colour, lineWidth: 1.5))
        } else {
            Circle().fill(palette.unknown).frame(width: 8, height: 8)
        }
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
