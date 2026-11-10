import FeatherwickCore
import FeatherwickText
import SwiftUI

/// The tap places on the farm. Each one opens a sheet. The potting shed is on no panel now: the coop
/// sheet holds it, so a request for it opens the coop.
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
/// The Yard and the Far yard draw a 2.5D scene (`Scene/FarmScene.swift`); the others are a flat colour until
/// their painting exists.
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
        case .barn: [.coop]
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
    /// The breeding pen, opened from the coop sheet.
    case breedingPen
    /// The market board by the bakery, opened from the farm gate sheet.
    case marketBoard
    #if DEBUG || BETA
        /// A TestFlight question (`Beta/`). Never in an App Store build.
        case betaPrompt(BetaMoment)
    #endif
    case morningReport
    /// Day 1: Hazel shows the keeper round the farm, one place at a time.
    case tour
    var id: Self { self }
}

/// The farm screen: four panels to swipe between (the 2.5D yard scenes and flat colours), the HUD, the panel
/// rail down the right side, the birds on each panel, and the bottom row (Books, Today, the panel's place,
/// Rest or Sleep, settings).
struct FarmView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sheet: FarmSheet?
    /// The panel on screen. The game opens on the yard, with the barn to the left and the shop to the right.
    /// Optional because the scroll view can briefly report no page; `panel` reads that as the yard.
    @State private var scrolled: FarmPanel? = .yard
    /// The show on screen. Set from `store.showReport` once no sheet is in the way.
    @State private var showDay: ShowReport?
    /// The sheet `open` is about to show after the current one closes. A beta question must not slip in between.
    @State private var swapping: FarmSheet?
    /// A sheet asked for while a beta question was open. It opens when the question closes.
    @State private var afterBeta: FarmSheet?
    /// The sheet on screen, kept after it closes so `sheetClosed` knows which one it was.
    @State private var shownSheet: FarmSheet?

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
            // A rest and nightfall cannot be skipped: the farm takes no taps until they are over.
            if store.restSeconds != nil || store.asleep {
                RestScene(line: store.restLine)
            }
            ToastStack()
        }
        .sheet(item: $sheet, onDismiss: sheetClosed) { which in
            content(for: which)
                .environment(\.palette, palette)
        }
        .fullScreenCover(
            item: $showDay,
            onDismiss: {
                store.finishShow()
                presentNeighbourNoteIfWaiting()
            }
        ) { report in
            ShowDayView(report: report)
                .environment(\.palette, palette)
        }
        .onChange(of: store.openRequest) { _, request in openRequested(request) }
        // A request made before the farm was on screen (the day-1 tour, set as the starter screen closes).
        .onAppear { openRequested(store.openRequest) }
        .onChange(of: sheet) { _, new in if let new { shownSheet = new } }
        .onChange(of: store.showReport) { _, report in showReportChanged(report) }
        // A show night: the show opens once the keeper is back from the morning report.
        .onChange(of: store.morningReport) { _, report in
            if report == nil, sheet == nil { presentShowIfWaiting() }
        }
    }

    /// One panel per page; the pages fill the whole screen, under the HUD. A paging scroll view, not a
    /// paged TabView: a TabView drops a swipe whenever a panel redraws (a bird walking), so most swipes
    /// failed.
    private var panels: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(FarmPanel.allCases) { p in
                    FarmPanelView(panel: p, openBird: { sheet = .bird($0) })
                        // The Barn's birds, in the ground band (see `FarmBirds.swift`).
                        // The yards draw theirs inside the scene, so they sort against the trees.
                        .overlay {
                            if !SceneArt.hasScene(p) { PanelBirds(panel: p) { sheet = .bird($0) } }
                        }
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

    /// Books, Today, the place of the panel on screen, Rest or Sleep, and settings. Books waits until the
    /// neighbour shows the keeper the Breed Book (the early game's `breedBook` lesson). Rest and Sleep wait
    /// for the daylight lesson; before it, Sleep is in the Coop sheet. Settings is always there.
    private var bottomBar: some View {
        HStack(alignment: .bottom) {
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
            panelPlaces
            Spacer()
            if store.state.isOpen(.daylight) { restOrSleep }
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

    /// "Rest a while" until the last slot of daylight is spent, then "Sleep", in the same place.
    private var restOrSleep: some View {
        let bedtime = store.state.slotsLeft == 0
        return FloatingBox {
            Button(bedtime ? "Sleep" : "Rest a while") {
                Task {
                    if bedtime {
                        await store.goToBed(reduceMotion: reduceMotion)
                    } else {
                        await store.restAWhile(reduceMotion: reduceMotion)
                    }
                }
            }
            .font(Typeface.action)
            .padding(.horizontal, Space.l)
            .frame(minHeight: 56)
        }
    }

    /// The place button of the panel on screen (Coop, Yard, Back fence, Farm gate) sits in the bottom
    /// row, so it never covers the scene. It changes as the keeper swipes.
    private var panelPlaces: some View {
        ForEach(panel.wrappedValue.places) { place in
            PlaceLabel(place: place, notices: notices(for: place)) { sheet = .place(place) }
        }
    }

    /// Show day takes the whole screen. A place sheet closes first (one presentation at a time);
    /// settings stay open, so the test tools are not cut off, and the show waits until they close.
    /// The morning report comes first: the show waits until the keeper is back from it.
    private func showReportChanged(_ report: ShowReport?) {
        guard let report else {
            showDay = nil
            return
        }
        if store.morningReport != nil { return }
        switch sheet {
        case nil: showDay = report
        case .settings?: break
        default: sheet = nil
        }
    }

    private func presentShowIfWaiting() {
        guard showDay == nil, store.morningReport == nil, let report = store.showReport else { return }
        showDay = report
    }

    /// Opens what the store asked for, unless a beta question must not be pushed aside.
    private func openRequested(_ request: FarmSheet?) {
        if let request {
            #if DEBUG || BETA
                // A beta question never pushes a sheet aside: it waits until that sheet closes.
                if case .betaPrompt = request, sheet != nil || swapping != nil {
                    store.openRequest = nil
                    return
                }
                // Nothing pushes a beta question aside either: the request waits until it closes.
                if case .betaPrompt? = sheet {
                    afterBeta = request
                    store.openRequest = nil
                    return
                }
            #endif
            // A sheet for a place also moves the farm to that place's panel.
            if case .place(let place) = request { scrolled = .containing(place) }
            sheet = request
            store.openRequest = nil
        }
    }

    /// The neighbour's note from the night, once the morning report (and any show) is closed.
    private func presentNeighbourNoteIfWaiting() {
        guard showDay == nil, sheet == nil, swapping == nil, store.morningReport == nil, !store.neighbourNotes.isEmpty
        else { return }
        sheet = .neighbourNote
    }

    /// A sheet closed: the show goes first, then the neighbour's note, then any beta question that waited
    /// for a quiet farm.
    private func sheetClosed() {
        // A new sheet replaced this one (`sheet = request` while it was open), and the new one is on
        // screen now. `shownSheet` is already the new one: reading it here would mark the neighbour's
        // note as read while it shows, and the note would open empty.
        guard sheet == nil else { return }
        let closed = shownSheet
        shownSheet = nil
        // Read, even if swiped away: so the note does not open again at once.
        if closed == .neighbourNote { store.readNeighbourNotes() }
        presentShowIfWaiting()
        presentNeighbourNoteIfWaiting()
        if sheet != nil { return }
        #if DEBUG || BETA
            guard showDay == nil, sheet == nil, swapping == nil, store.morningReport == nil else { return }
            if let next = afterBeta {
                afterBeta = nil
                if case .place(let place) = next { scrolled = .containing(place) }
                sheet = next
                return
            }
            store.offerBetaPrompt()
        #endif
    }

    @ViewBuilder
    private func content(for which: FarmSheet) -> some View {
        switch which {
        case .place(.coop): CoopSheet(open: open)
        case .place(.yard): YardSheet(open: open)
        // The old potting shed is part of the coop sheet now (`BrooderSection`).
        case .place(.pottingShed): CoopSheet(open: open)
        case .place(.farmGate): FarmGateSheet(open: open)
        case .place(.backFence): BackFenceSheet()
        case .bird(let id): BirdCardSheet(birdID: id, context: "In the flock")
        case .naming: NamingSheet()
        case .books: BooksView()
        case .settings: SettingsSheet()
        case .neighbourNote: NeighbourNoteSheet()
        case .jobs: JobsSheet()
        case .breedingPen: BreedingPenSheet(open: open)
        case .marketBoard: MarketBoardSheet(open: open)
        #if DEBUG || BETA
            case .betaPrompt(let moment): BetaPromptSheet(moment: moment)
        #endif
        case .morningReport: MorningReportSheet()
        case .tour: TourSheet(show: { scrolled = .containing($0) })
        }
    }

    /// Swap the open sheet for another (a bird card from a list, the naming prompt).
    private func open(_ next: FarmSheet) {
        swapping = next
        sheet = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            sheet = next
            swapping = nil
        }
    }

    /// Every notice on each panel, so the panel dots can show what waits off screen.
    private var panelNotices: [FarmPanel: [Notice]] {
        Dictionary(uniqueKeysWithValues: FarmPanel.allCases.map { p in (p, p.places.flatMap { notices(for: $0) }) })
    }

    /// Birds in the brooder waiting for a free perch, and how soon one is rehomed.
    private func perchNotice(_ s: GameState) -> Notice? {
        let waiting = s.birdsWaitingForPerch
        guard !waiting.isEmpty else { return nil }
        let soonest = waiting.compactMap { s.nightsUntilRehomed($0.id) }.min()
        let note = soonest.map { $0 <= 1 ? ", rehomed tomorrow" : ", \($0) nights left" } ?? ""
        return Notice(kind: .decision, text: "\(waiting.count) need\(waiting.count == 1 ? "s" : "") a perch\(note)")
    }

    /// What each place has waiting. The words carry the meaning; the dot only draws the eye.
    private func notices(for place: Place) -> [Notice] {
        let s = store.state
        switch place {
        case .coop:
            // The coop holds the brooder and the incubator too (the old potting shed).
            var n: [Notice] = []
            if let bird = s.unnamedBirds.first {
                n.append(Notice(kind: .decision, text: "\(bird.revealed ? "a bird" : "a chick") needs a name"))
            }
            if !s.nest.isEmpty {
                n.append(Notice(kind: .collect, text: "\(s.nest.count) egg\(s.nest.count == 1 ? "" : "s") waiting"))
            }
            if let perch = perchNotice(s) { n.append(perch) }
            if let c = s.incubatorClutch, c.hatchDay <= s.day + 1 {
                n.append(Notice(kind: .collect, text: "hatching tonight"))
            }
            // Bedtime counts as night here too, so the open door is noticed before Sleep.
            let night = palette.isNight || (s.isOpen(.daylight) && s.slotsLeft == 0)
            if night && s.coopDoorOpen { n.append(Notice(kind: .decision, text: "door still open")) }
            if night && !s.coopDoorOpen { n.append(Notice(kind: .story, text: "\(s.coop.count) asleep")) }
            return n
        case .pottingShed:
            // Not on the farm any more: its notices show under the coop.
            return []
        case .backFence:
            // Hazel takes the Hatch-along eggs, so the week is news at the fence too.
            let news =
                Engine.storyAwaitingDelivery(s) != nil || s.tradeOffer != nil || !s.pendingChoices.isEmpty
                || s.hatchAlongRefusal() == nil
            return news ? [Notice(kind: .story, text: "has news")] : []
        case .yard:
            if !s.fedToday { return [Notice(kind: .decision, text: "hungry")] }
            return s.lost.isEmpty ? [] : [Notice(kind: .story, text: "\(s.lost.count) wandered off")]
        case .farmGate:
            var n: [Notice] = []
            // Stock the early game brought in this morning. It goes once the keeper has looked (or bought).
            if store.hasNewStock { n.append(Notice(kind: .story, text: "new in today")) }
            // A village day this week, today, or the Hatch-along week with an egg to bring.
            if let village = villageNotice(s) { n.append(Notice(kind: .story, text: village)) }
            if s.marketBoard.keeperCard?.buyerHere(onDay: s.day) == true {
                n.append(Notice(kind: .decision, text: "a buyer is here"))
            } else if s.isOpen(.marketBoard), s.marketBoard.cards.contains(where: s.canFill) {
                n.append(Notice(kind: .collect, text: "a card you can fill"))
            }
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

/// One farm panel (its place button is in the bottom row, `FarmView.panelPlaces`). The Yard and the Far yard
/// draw the 2.5D scene with the coop birds in it (`YardScene`). The others show a stand-in colour and a
/// dashed box where the painting will go.
/// Night darkens and cools both.
struct FarmPanelView: View {
    @Environment(\.palette) private var palette
    let panel: FarmPanel
    /// Opens a bird's card when a bird in the scene is tapped.
    let openBird: (UUID) -> Void

    var body: some View {
        ZStack {
            if SceneArt.hasScene(panel) {
                YardScene(panel: panel, open: openBird)
            } else {
                standIn
            }
        }
    }

    /// A flat colour and a dashed box, until the panel's scene exists.
    private var standIn: some View {
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
                        dot(for: p).frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(([p.name] + (notices[p] ?? []).map(\.text)).joined(separator: ", "))
                    .accessibilityAddTraits(p == selection ? .isSelected : [])
                    .accessibilityIdentifier("rail.dot")
                }
            }
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

/// A box floating over the scene (white by day, dark by night): radius 10 and a soft shadow. A button in it
/// takes taps over the whole box, not only on its word or mark.
struct FloatingBox<Content: View>: View {
    @Environment(\.palette) private var palette
    @ViewBuilder var content: Content
    var body: some View {
        content
            .contentShape(RoundedRectangle(cornerRadius: Radius.control))
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
            .contentShape(Rectangle())
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
    /// The sun was tapped: the time of day shows in words under it.
    @State private var showsTime = false

    var body: some View {
        let s = store.state
        HStack(alignment: .top) {
            FloatingBox {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day \(s.day)").font(Typeface.display(28, relativeTo: .title))
                    Text(timeOfDay.map { "\(s.season.rawValue.capitalized) · \($0)" } ?? s.season.rawValue.capitalized)
                        .font(Typeface.label)
                        .foregroundStyle(palette.inkSoft)
                    if s.isOpen(.daylight) { sun(s) }
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

    /// Game time, not the device clock. Before the daylight lesson the day has no time of day.
    private var timeOfDay: String? {
        if store.asleep { return "night" }
        let s = store.state
        return s.isOpen(.daylight) ? s.timeOfDay.rawValue : nil
    }

    /// The sun on its track. Tap for the time of day and how many errands still fit.
    private func sun(_ s: GameState) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Button {
                showsTime.toggle()
            } label: {
                SunTrack(slots: s.slotsToday(rules: s.rules), used: s.slotsUsed, slide: store.restSeconds ?? 0.3)
                    .padding(.vertical, Space.s)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(timeOfDayText(s))
            if showsTime {
                Text(timeOfDayText(s)).font(Typeface.label).foregroundStyle(palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Over the farm while a rest plays (or night falls): what the keeper did with the time, and a cover
/// that takes every tap, so the scene cannot be skipped.
struct RestScene: View {
    @Environment(\.palette) private var palette
    let line: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear.contentShape(Rectangle()).ignoresSafeArea()
            if let line {
                FloatingBox {
                    Text(line).font(Typeface.speech).foregroundStyle(palette.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Space.l)
                        .padding(.vertical, Space.m)
                }
                .padding(.horizontal, Space.xl)
                .padding(.bottom, 140)  // over the bottom row, clear of the buttons
                .transition(.opacity)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
