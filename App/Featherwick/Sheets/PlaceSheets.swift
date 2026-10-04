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
    @State private var selected: UUID?

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
            CandlingLegend()
            StitchDivider()
            if let egg = s.carton.first(where: { $0.id == selected }) {
                eggDetail(egg, s)
            } else {
                Text(s.carton.isEmpty ? "The carton is empty." : "Tap an egg to look at it.")
                    .font(Typeface.body).foregroundStyle(palette.inkMuted)
            }
            eggActions(s)
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
    private func eggActions(_ s: GameState) -> some View {
        let fertile = s.carton.count(where: { $0.isCandled && $0.isFertile })
        let total = s.carton.reduce(0) { $0 + s.rules.price(of: $1, onDay: s.day) }
        HStack(spacing: Space.m) {
            if fertile > 0, s.hasIncubator, s.incubatorClutch == nil {
                Button("Set to hatch") { store.run(.incubate(count: 1)) }.buttonStyle(.primary)
            } else {
                Button(hatchReason(s, fertile: fertile)) {}.buttonStyle(.primary).disabled(true)
            }
            Button {
                store.run(.sellEggs)
            } label: {
                HStack(spacing: Space.xs) {
                    Text("Sell all")
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

    private func hatchReason(_ s: GameState, fertile: Int) -> String {
        if !s.hasIncubator { return "No incubator yet" }
        if s.incubatorClutch != nil { return "Incubator is full" }
        return fertile == 0 ? "No fertile eggs" : "Set to hatch"
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
    @Binding var selected: UUID?

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
        let isSelected = egg != nil && egg?.id == selected
        return Button {
            selected = egg?.id
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
        return "\(c.eggs.count) egg\(c.eggs.count == 1 ? "" : "s") warming. They hatch on day \(c.hatchDay)."
    }
}
