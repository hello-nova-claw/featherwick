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
            // The fertile and clear filters only mean something once the keeper can candle.
            if s.canCandle {
                WordTabs(
                    tabs: [
                        (.all, "All \(s.carton.count)"), (.fertile, "Fertile"), (.clear, "Clear"),
                        (.notCandled, "Not candled"),
                    ], selection: $filter)
            }
            Carton(
                eggs: s.canCandle ? shown : s.carton, capacity: max(12, s.cartonCapacity), canCandle: s.canCandle,
                selected: $selected
            )
            .onChange(of: s.carton) { _, carton in selected.formIntersection(carton.map(\.id)) }
            CandlingLegend(canCandle: s.canCandle)
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
                BrooderSection(open: open)
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
        let unknown = s.canCandle ? "Not candled yet" : "Fertile? You can't tell yet"
        let state = egg.isCandled ? (egg.isFertile ? "Fertile" : "Clear") : unknown
        let stale = s.rules.isStale(egg, onDay: s.day) ? " Stale: it sat in the nest too long." : ""
        return "From \(from). \(state).\(stale)"
    }

    @ViewBuilder
    private func eggActions(_ s: GameState, chosen: [Egg]) -> some View {
        let selling = chosen.isEmpty ? s.carton : chosen
        let total = selling.reduce(0) { $0 + s.rules.price(of: $1, onDay: s.day) }
        if let note = incubatorSizeNote(s, chosen: chosen) {
            Text(note).font(Typeface.caption).foregroundStyle(palette.inkMuted)
        }
        HStack(spacing: Space.m) {
            if !s.hasIncubator {
                // Nothing to set eggs in yet, so no hatch button at all.
                EmptyView()
            } else if let reason = hatchBlocker(s, chosen: chosen) {
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
        if s.canCandle {
            HStack(spacing: Space.l) {
                // Candling is one egg at a time: choose one egg that is not candled yet.
                if chosen.count == 1, !chosen[0].isCandled {
                    Button("Candle this egg") { store.run(.candleEgg(chosen[0].id)) }
                }
                Button("Sell all but fertile") { store.run(.sellClearEggs) }
            }
            .buttonStyle(.textAction)
            .frame(maxWidth: .infinity)
        }
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

    /// The neighbour's old incubator holds 1 egg. Say so when the keeper chooses more than fit.
    private func incubatorSizeNote(_ s: GameState, chosen: [Egg]) -> String? {
        guard s.hasIncubator, chosen.count > 1 else { return nil }
        let space = s.incubatorSize - (s.incubatorClutch?.eggs.count ?? 0)
        guard chosen.count > space else { return nil }
        let holds = "Your incubator holds \(s.incubatorSize) egg\(s.incubatorSize == 1 ? "" : "s")."
        guard s.incubatorSize < s.rules.bigIncubatorSize else { return holds }
        return holds + " The Farm gate sells one for \(s.rules.bigIncubatorSize) (\(s.rules.incubatorPrice) coins)."
    }

    /// A grown bird with no perch, and when the neighbour will step in.
    private func perchWaitText(_ bird: Bird, _ s: GameState) -> String {
        guard let nights = s.nightsUntilRehomed(bird.id) else { return "\(bird.name) is waiting for a perch." }
        let when = nights <= 1 ? "tomorrow" : "in \(nights) nights"
        return "\(bird.name) is waiting for a perch. Without one, the neighbour finds \(bird.name) a home \(when)."
    }

    @ViewBuilder
    private func nightActions(_ s: GameState) -> some View {
        Text("The coop").font(Typeface.item)
        Text("\(s.coop.count) of \(s.perches) perches taken · door \(s.coopDoorOpen ? "open" : "closed")")
            .font(Typeface.label).foregroundStyle(palette.inkMuted)
        if s.unnamedBirds.contains(where: { b in s.coop.contains { $0.id == b.id } }) {
            Button("Name the new birds") { open(.naming) }.buttonStyle(.primary)
        }
        ForEach(s.birdsWaitingForPerch) { bird in
            Text(perchWaitText(bird, s)).font(Typeface.body).foregroundStyle(palette.inkSoft)
        }
        // Only once the neighbour has helped build it (early game).
        if s.isOpen(.breedingPen) {
            let penned = s.pennedBirds.count
            Button(penned == 0 ? "Breeding pen" : "Breeding pen · \(penned) in") { open(.breedingPen) }
                .buttonStyle(.textAction)
        }
        HStack(spacing: Space.m) {
            Button(s.coopDoorOpen ? "Shut the door" : "Door is shut") { store.run(.closeCoop) }
                .buttonStyle(.secondary)
                .disabled(!s.coopDoorOpen)
            Button("Sleep") { store.sleep() }.buttonStyle(.secondary)
        }
        Text("An open door lets the flock forage overnight, but the fox may visit.")
            .font(Typeface.caption).foregroundStyle(palette.inkMuted)
    }
}

/// The carton: a dashed tray of cups. Filled ink dot = fertile, hollow ring = clear, no mark = not candled.
/// Before the keeper can candle, an unknown egg shows "?".
struct Carton: View {
    @Environment(\.palette) private var palette
    let eggs: [Egg]
    let capacity: Int
    let canCandle: Bool
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
                    } else if !canCandle {
                        Text("?").font(Typeface.caption).foregroundStyle(palette.ink)
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
        let state = egg.isCandled ? (egg.isFertile ? "fertile" : "clear") : (canCandle ? "not candled" : "unknown")
        return "\(egg.speckled ? "Speckled " : "")\(egg.colour.rawValue) egg, \(state)"
    }
}

struct CandlingLegend: View {
    @Environment(\.palette) private var palette
    let canCandle: Bool
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
            Text(canCandle ? "no mark: not candled yet" : "?: can't tell yet")
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

// MARK: - Brooder (in the coop)

/// The brooder, chicks with their mothers, broody hens sitting, and the incubator. Part of the coop
/// sheet: the barn has one button (Coop), so the old potting shed lives here.
struct BrooderSection: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    let open: (FarmSheet) -> Void

    var body: some View {
        let s = store.state
        VStack(alignment: .leading, spacing: Space.m) {
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
            // No incubator, no mention of one: the coop shows only what the keeper has.
            if s.hasIncubator {
                Text("Incubator").font(Typeface.item)
                Text(incubatorText(s)).font(Typeface.body).foregroundStyle(palette.inkSoft)
            }
            ForEach(s.clutches.filter { $0.henID != nil }, id: \.henID) { c in
                Text(sittingText(c, s)).font(Typeface.body).foregroundStyle(palette.inkSoft)
            }
        }
    }

    private func sittingText(_ c: Clutch, _ s: GameState) -> String {
        let hen: String = c.henID.map { birdName($0, s) } ?? "A hen"
        return "\(hen) is sitting on \(c.eggs.count) egg(s). They hatch on day \(c.hatchDay)."
    }

    private func incubatorText(_ s: GameState) -> String {
        guard let c = s.incubatorClutch else {
            let holds: String = "\(s.incubatorSize) egg\(s.incubatorSize == 1 ? "" : "s")"
            return "Empty. Holds \(holds). Set eggs from the carton above."
        }
        let warming = "\(c.eggs.count) of \(s.incubatorSize) eggs warming. They hatch on day \(c.hatchDay)."
        let space = s.incubatorSize - c.eggs.count
        let canAdd = space > 0 && c.hatchDay == s.day + s.rules.incubatorHatchDays
        return canAdd ? warming + " Room for \(space) more today." : warming
    }
}
