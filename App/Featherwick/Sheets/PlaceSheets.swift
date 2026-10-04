import FeatherwickCore
import FeatherwickText
import SwiftUI

// MARK: - Coop (5a: today's eggs)

/// The coop: the nest boxes, the carton of today's eggs, and shutting up for the night.
struct CoopSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    let open: (FarmSheet) -> Void
    @State private var filter = EggFilter.all
    /// The eggs the player has tapped. Hatch and sell act on exactly these.
    @State private var selected: Set<UUID> = []

    enum EggFilter: Hashable { case all, fertile, clear, notCandled }

    var body: some View {
        let s = store.state
        let shown = s.carton.filter(matches)
        SheetPage(context: "From the nest boxes") {
            Text("Today's eggs").font(Typeface.title)
            if !s.nest.isEmpty {
                HStack {
                    Text("\(s.nest.count) egg\(s.nest.count == 1 ? "" : "s") in the nest boxes")
                        .font(Typeface.body)
                    Spacer()
                    Button("Collect") { store.run(.collectEggs) }.buttonStyle(.secondary).frame(width: 110)
                }
            }
            WordTabs(
                tabs: [
                    (.all, "All \(s.carton.count)"), (.fertile, "Fertile"), (.clear, "Clear"),
                    (.notCandled, "Not candled"),
                ], selection: $filter)
            Carton(eggs: shown, capacity: max(12, s.cartonCapacity), selected: $selected)
                .onChange(of: s.carton) { _, carton in selected.formIntersection(carton.map(\.id)) }
            CandlingLegend()
            StitchDivider()
            let chosen = s.carton.filter { selected.contains($0.id) }
            if chosen.count == 1 {
                eggDetail(chosen[0], s)
            } else if chosen.count > 1 {
                Text("\(chosen.count) eggs chosen. Tap an egg again to put it back.")
                    .font(Typeface.body).foregroundStyle(palette.inkMuted)
            } else {
                Text(s.carton.isEmpty ? "The carton is empty." : "Tap eggs to choose them.")
                    .font(Typeface.body).foregroundStyle(palette.inkMuted)
            }
            eggActions(s, chosen: chosen)
            Group {
                StitchDivider()
                nightActions(s)
                LastWords()
            }
        }
        .presentationDetents([.large])
    }

    private func matches(_ egg: Egg) -> Bool {
        switch filter {
        case .all: true
        case .fertile: egg.isCandled && egg.isFertile
        case .clear: egg.isCandled && !egg.isFertile
        case .notCandled: !egg.isCandled
        }
    }

    private func eggDetail(_ egg: Egg, _ s: GameState) -> some View {
        HStack(alignment: .top, spacing: Space.l) {
            EggMark(colour: egg.colour, speckled: egg.speckled, size: CGSize(width: 34, height: 44))
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("\(egg.speckled ? "Speckled " : "")\(egg.colour.rawValue.capitalized) egg")
                    .font(Typeface.serif(26, relativeTo: .title2))
                Text(eggStory(egg, s)).font(Typeface.label).foregroundStyle(palette.inkSoft)
            }
        }
    }

    private func eggStory(_ egg: Egg, _ s: GameState) -> String {
        let from = s.bird(egg.motherID)?.name ?? "a local flock"
        let state = egg.isCandled ? (egg.isFertile ? "Fertile" : "Clear") : "Not candled yet"
        let stale = s.rules.isStale(egg, onDay: s.day) ? " Stale: it sat in the nest too long." : ""
        return "From \(from). \(state).\(stale)"
    }

    @ViewBuilder
    private func eggActions(_ s: GameState, chosen: [Egg]) -> some View {
        let selling = chosen.isEmpty ? s.carton : chosen
        let total = selling.reduce(0) { $0 + s.rules.price(of: $1, onDay: s.day) }
        HStack(spacing: Space.m) {
            if let reason = hatchBlocker(s, chosen: chosen) {
                Button(reason) {}.buttonStyle(.primary).disabled(true)
            } else {
                Button("Set \(chosen.count) to hatch") {
                    store.run(.incubateEggs(chosen.map(\.id)))
                    selected.removeAll()
                }
                .buttonStyle(.primary)
            }
            Button {
                store.run(chosen.isEmpty ? .sellEggs : .sellChosenEggs(chosen.map(\.id)))
                selected.removeAll()
            } label: {
                HStack(spacing: Space.xs) {
                    Text(chosen.isEmpty ? "Sell all" : "Sell \(chosen.count)")
                    CoinDisc()
                    Text("\(total)").monospacedDigit()
                }
            }
            .buttonStyle(.secondary)
            .disabled(s.carton.isEmpty)
        }
        HStack(spacing: Space.l) {
            Button("Candle the rest") { store.run(.candle) }
            Button("Sell all but fertile") { store.run(.sellClearEggs) }
        }
        .buttonStyle(.textAction)
        .frame(maxWidth: .infinity)
    }

    /// Why the chosen eggs can't go in the incubator, or nil if they can. The engine checks again.
    private func hatchBlocker(_ s: GameState, chosen: [Egg]) -> String? {
        if !s.hasIncubator { return "No incubator yet" }
        let inside = s.incubatorClutch
        if let inside, inside.hatchDay != s.day + s.rules.incubatorHatchDays { return "Incubator is busy" }
        let space = s.incubatorSize - (inside?.eggs.count ?? 0)
        if space <= 0 { return "Incubator is full" }
        if chosen.isEmpty { return "Choose eggs to hatch" }
        if chosen.contains(where: { $0.isCandled && !$0.isFertile }) { return "Clear eggs won't hatch" }
        if chosen.count > space { return "Room for \(space) more" }
        return nil
    }

    @ViewBuilder
    private func nightActions(_ s: GameState) -> some View {
        Text("The coop").font(Typeface.item)
        Text("\(s.coop.count) of \(s.perches) perches taken · door \(s.coopDoorOpen ? "open" : "closed")")
            .font(Typeface.label).foregroundStyle(palette.inkMuted)
        HStack(spacing: Space.m) {
            Button(s.coopDoorOpen ? "Shut the door" : "Door is shut") { store.run(.closeCoop) }
                .buttonStyle(.secondary)
                .disabled(!s.coopDoorOpen)
            Button("Sleep") { store.run(.passNight) }.buttonStyle(.secondary)
        }
        Text("An open door lets the flock forage overnight, but the fox may visit.")
            .font(Typeface.caption).foregroundStyle(palette.inkMuted)
    }
}

/// The carton: a dashed tray of cups. Filled ink dot = fertile, hollow ring = clear, no mark = not candled.
struct Carton: View {
    @Environment(\.palette) private var palette
    let eggs: [Egg]
    let capacity: Int
    @Binding var selected: Set<UUID>

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Space.s), count: 6)
        LazyVGrid(columns: columns, spacing: Space.s) {
            ForEach(0..<capacity, id: \.self) { i in
                cup(i < eggs.count ? eggs[i] : nil)
            }
        }
        .padding(Space.m)
        .overlay(RoundedRectangle(cornerRadius: Radius.tray).stroke(palette.unknownBox, style: Stitch.unknown))
    }

    private func cup(_ egg: Egg?) -> some View {
        let isSelected = egg.map { selected.contains($0.id) } ?? false
        return Button {
            guard let egg else { return }
            if isSelected {
                selected.remove(egg.id)
            } else {
                selected.insert(egg.id)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Circle().strokeBorder(palette.hairline, lineWidth: 1)
                if isSelected { Circle().strokeBorder(palette.ink, lineWidth: 1.5) }
                if let egg {
                    EggMark(colour: egg.colour, speckled: egg.speckled, size: CGSize(width: 16, height: 21))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if egg.isCandled {
                        Group {
                            if egg.isFertile {
                                Circle().fill(palette.ink)
                            } else {
                                Circle().strokeBorder(palette.ink, lineWidth: 1)
                            }
                        }
                        .frame(width: 7, height: 7)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .disabled(egg == nil)
        .accessibilityLabel(egg.map(cupLabel) ?? "Empty cup")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func cupLabel(_ egg: Egg) -> String {
        let state = egg.isCandled ? (egg.isFertile ? "fertile" : "clear") : "not candled"
        return "\(egg.speckled ? "Speckled " : "")\(egg.colour.rawValue) egg, \(state)"
    }
}

struct CandlingLegend: View {
    @Environment(\.palette) private var palette
    var body: some View {
        HStack(spacing: Space.l) {
            HStack(spacing: Space.xs) {
                Circle().fill(palette.ink).frame(width: 7, height: 7)
                Text("fertile")
            }
            HStack(spacing: Space.xs) {
                Circle().strokeBorder(palette.ink, lineWidth: 1).frame(width: 7, height: 7)
                Text("clear")
            }
            Text("no mark: not candled yet")
        }
        .font(Typeface.caption)
        .foregroundStyle(palette.inkMuted)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Yard

/// The yard: the grown flock. Feed them, and tap a bird for its card.
struct YardSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    let open: (FarmSheet) -> Void

    var body: some View {
        let s = store.state
        SheetPage(context: "In the yard") {
            Text("The flock").font(Typeface.title)
            Button(s.fedToday ? "Fed for today" : "Feed the flock") { store.run(.feed) }
                .buttonStyle(.primary)
                .disabled(s.fedToday)
            if s.premiumFeed > 0 && !s.fedPremiumToday {
                Button("Use premium feed (\(s.premiumFeed) days left)") { store.run(.feedPremium) }
                    .buttonStyle(.textAction)
            }
            BirdList(birds: s.coop, open: open)
            if !s.lost.isEmpty {
                Text("Wandered off").font(Typeface.item)
                Text(s.lost.map(\.bird.name).joined(separator: ", ") + ". They always come home.")
                    .font(Typeface.label).foregroundStyle(palette.inkMuted)
            }
            if !s.boarding.isEmpty {
                Text("Staying with the neighbour").font(Typeface.item)
                Text(s.boarding.map(\.name).joined(separator: ", ") + ". Make room so they can come home.")
                    .font(Typeface.label).foregroundStyle(palette.inkMuted)
            }
            LastWords()
        }
        .presentationDetents([.medium, .large])
    }
}

/// Rows of birds, split by dashed stitches. Tap a row for the bird card.
struct BirdList: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    let birds: [Bird]
    let open: (FarmSheet) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(birds) { bird in
                Button {
                    open(.bird(bird.id))
                } label: {
                    HStack(spacing: Space.m) {
                        BirdSwatch(bird: bird, state: store.state, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bird.name).font(Typeface.item)
                            Text(birdLabel(bird, store.state).components(separatedBy: ": ").dropFirst().joined())
                                .font(Typeface.caption).foregroundStyle(palette.inkMuted).lineLimit(1)
                        }
                        Spacer()
                        Text("→").foregroundStyle(palette.inkMuted)
                    }
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                StitchDivider()
            }
        }
    }
}

// MARK: - Potting shed

/// The potting shed: the brooder, chicks with their mothers, the incubator, and naming.
struct PottingShedSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    let open: (FarmSheet) -> Void

    var body: some View {
        let s = store.state
        SheetPage(context: "The potting shed") {
            Text("Brooder").font(Typeface.title)
            if !s.unnamedBirds.isEmpty {
                Button("Name the new \(s.unnamedBirds.count == 1 ? "bird" : "birds")") { open(.naming) }
                    .buttonStyle(.primary)
            }
            Text("\(s.brooder.count) of \(s.brooderSize) places in the brooder")
                .font(Typeface.label).foregroundStyle(palette.inkMuted)
            BirdList(birds: s.brooder, open: open)
            if !s.henChicks.isEmpty {
                Text("With their mother").font(Typeface.item)
                BirdList(birds: s.henChicks, open: open)
            }
            Text("Incubator").font(Typeface.item)
            Text(incubatorText(s)).font(Typeface.body).foregroundStyle(palette.inkSoft)
            ForEach(s.clutches.filter { $0.henID != nil }, id: \.henID) { c in
                Text("\(birdName(c.henID!, s)) is sitting on \(c.eggs.count) egg(s). They hatch on day \(c.hatchDay).")
                    .font(Typeface.body).foregroundStyle(palette.inkSoft)
            }
            LastWords()
        }
        .presentationDetents([.medium, .large])
    }

    private func incubatorText(_ s: GameState) -> String {
        guard s.hasIncubator else { return "No incubator yet. A broody hen can sit on eggs instead." }
        guard let c = s.incubatorClutch else {
            return "Empty. Holds \(s.incubatorSize) egg\(s.incubatorSize == 1 ? "" : "s"). Set eggs from the coop."
        }
        let warming = "\(c.eggs.count) of \(s.incubatorSize) eggs warming. They hatch on day \(c.hatchDay)."
        let space = s.incubatorSize - c.eggs.count
        let canAdd = space > 0 && c.hatchDay == s.day + s.rules.incubatorHatchDays
        return canAdd ? warming + " Room for \(space) more today." : warming
    }
}
