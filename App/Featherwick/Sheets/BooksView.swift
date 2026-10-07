import FeatherwickCore
import FeatherwickText
import SwiftUI

/// 4a / 4b: the collections. Tiles keep a fixed order, so gaps show where unfound breeds belong.
struct BooksView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @State private var tab = BookTab.breeds

    enum BookTab: Hashable { case breeds, eggs }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                HStack {
                    WordTabs(tabs: [(.breeds, "Breeds"), (.eggs, "Eggs")], selection: $tab)
                    Spacer()
                    CloseButton()
                }
                switch tab {
                case .breeds: BreedBook()
                case .eggs: EggBook()
                }
            }
            .padding(.horizontal, Space.sheetSide)
            .padding(.bottom, Space.sheetBottom)
            .padding(.top, Space.s)
        }
        .foregroundStyle(palette.ink)
        .background(palette.paper)
        .presentationDetents([.large])
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(palette.paper)
    }
}

struct BreedBook: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        let s = store.state
        let breeds = BreedTable.inGame
        let found = breeds.filter { b in s.breedBook.contains { !$0.isCross && $0.variety == b.id.rawValue } }
        let colourTotal = breeds.reduce(0) { $0 + $1.varieties.count }
        let coloursFound = breeds.reduce(0) { $0 + min($1.varieties.count, colours(of: $1, in: s).count) }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: 3)
        VStack(alignment: .leading, spacing: Space.l) {
            Text("Breed Book").font(Typeface.title)
            Text("\(found.count) of \(breeds.count) breeds, \(coloursFound) of \(colourTotal) colours")
                .font(Typeface.label).foregroundStyle(palette.inkMuted)
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(breeds) { breed in
                    BreedTile(breed: breed, colours: colours(of: breed, in: s), seen: seen(of: breed, in: s))
                }
            }
            let crosses = s.breedBook.filter(\.isCross).map(entryText).sorted()
            if !crosses.isEmpty {
                Text("Crosses").font(Typeface.item)
                ForEach(crosses, id: \.self) { Text($0.prefix(1).uppercased() + $0.dropFirst()).font(Typeface.body) }
            }
            SeenAtShows(seen: s.breedBookSeenOnly)
        }
    }

    /// The distinct looks of this breed found so far.
    private func colours(of breed: BreedDefinition, in s: GameState) -> [BreedBookEntry] {
        s.breedBook.filter { !$0.isCross && $0.variety == breed.id.rawValue }
            .sorted { entryText($0) < entryText($1) }
    }

    /// Looks of this breed seen on a show podium but not owned.
    private func seen(of breed: BreedDefinition, in s: GameState) -> [BreedBookEntry] {
        s.breedBookSeenOnly.map(\.entry).filter { !$0.isCross && $0.variety == breed.id.rawValue }
            .sorted { entryText($0) < entryText($1) }
    }
}

/// Looks seen on show podiums that the keeper has never owned, each with the show it was seen at.
struct SeenAtShows: View {
    @Environment(\.palette) private var palette
    let seen: [SeenBreedBookEntry]

    var body: some View {
        if !seen.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Seen at shows").font(Typeface.item)
                ForEach(seen, id: \.self) { row($0) }
            }
        }
    }

    private func row(_ s: SeenBreedBookEntry) -> some View {
        HStack(spacing: Space.s) {
            SeenDot(colour: s.entry.colour)
            VStack(alignment: .leading, spacing: 2) {
                Text(sentenceCase(entryText(s.entry))).font(Typeface.body)
                Text("\(seenText(s)), day \(s.day)").font(Typeface.label).foregroundStyle(palette.inkMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A colour seen at a show but not owned: a paler dab with a dashed rim.
struct SeenDot: View {
    @Environment(\.palette) private var palette
    let colour: FeatherColour
    var size: CGFloat = 8

    var body: some View {
        Circle().fill(Pigment.feather(colour).opacity(0.45)).frame(width: size, height: size)
            .overlay(Circle().stroke(palette.ink.opacity(0.5), style: Stitch.unknown))
    }
}

/// A collection tile: art, name, and a dot per colour (filled owned, pale seen at a show, dashed still to find).
struct BreedTile: View {
    @Environment(\.palette) private var palette
    let breed: BreedDefinition
    let colours: [BreedBookEntry]
    var seen: [BreedBookEntry] = []

    var body: some View {
        let known = !colours.isEmpty || !seen.isEmpty
        VStack(alignment: .leading, spacing: Space.s) {
            ZStack {
                if known {
                    ArtPlaceholder(label: "bird art")
                } else {
                    RoundedRectangle(cornerRadius: Radius.tile).stroke(palette.unknownBox, style: Stitch.unknown)
                    Text("?").font(Typeface.display(34)).foregroundStyle(palette.unknown)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            if known {
                Text(breed.displayName).font(Typeface.serif(15))
                dots
                if colours.isEmpty {
                    Text("seen at a show").font(Typeface.serifItalic(13, relativeTo: .footnote))
                        .foregroundStyle(palette.inkMuted)
                }
            } else {
                Text("lays \(breed.eggColour.rawValue) eggs").font(Typeface.serifItalic(13, relativeTo: .footnote))
                    .foregroundStyle(palette.inkMuted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(known ? knownLabel : "Breed not found yet. Lays \(breed.eggColour.rawValue) eggs")
    }

    /// Owned colours, then colours only seen at a show, then a dashed dot per colour still to find.
    private var dots: some View {
        let total: Int = max(breed.varieties.count, colours.count + seen.count)
        return HStack(spacing: Space.xs) {
            ForEach(0..<total, id: \.self) { i in
                if i < colours.count {
                    Circle().fill(Pigment.feather(colours[i].colour)).frame(width: 8, height: 8)
                        .overlay(Circle().stroke(palette.ink.opacity(0.3), lineWidth: 0.5))
                } else if i < colours.count + seen.count {
                    SeenDot(colour: seen[i - colours.count].colour)
                } else {
                    UnknownDot(size: 8)
                }
            }
        }
    }

    private var knownLabel: String {
        let found = "\(breed.displayName), \(colours.count) of \(breed.varieties.count) colours found"
        return seen.isEmpty ? found : "\(found), \(seen.count) more seen at shows"
    }
}

/// One row per egg colour, plain and speckled: filled if found, dashed if not.
struct EggBook: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        let s = store.state
        let total = EggColour.allCases.count * 2
        VStack(alignment: .leading, spacing: Space.l) {
            Text("Egg Book").font(Typeface.title)
            Text("\(s.eggBook.count) of \(total) eggs found").font(Typeface.label).foregroundStyle(palette.inkMuted)
            VStack(spacing: 0) {
                ForEach(EggColour.allCases, id: \.self) { colour in
                    let found = [false, true].filter { sp in
                        s.eggBook.contains { $0.colour == colour && $0.speckled == sp }
                    }
                    VStack(alignment: .leading, spacing: Space.s) {
                        HStack {
                            Text(colour.rawValue.capitalized).font(Typeface.item)
                            Spacer()
                            Text("\(found.count) of 2").font(Typeface.label).foregroundStyle(palette.inkMuted)
                        }
                        HStack(spacing: Space.m) {
                            ForEach([false, true], id: \.self) { speckled in
                                if found.contains(speckled) {
                                    EggMark(colour: colour, speckled: speckled, size: CGSize(width: 26, height: 33))
                                } else {
                                    EggShape().stroke(palette.unknown, style: Stitch.unknown)
                                        .frame(width: 26, height: 33)
                                }
                            }
                        }
                        if found.isEmpty {
                            Text(hint(colour)).font(Typeface.serifItalic(14, relativeTo: .footnote))
                                .foregroundStyle(palette.inkMuted)
                        }
                    }
                    .padding(.vertical, Space.m)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(colour.rawValue.capitalized) eggs, \(found.count) of 2 found")
                    StitchDivider()
                }
            }
        }
    }

    private func hint(_ colour: EggColour) -> String {
        switch colour {
        case .cream: "Silkies lay these."
        case .brown: "Orpingtons and Australorps lay these."
        case .blue: "Araucanas carry the blue-egg gene."
        case .olive: "Cross a blue-egg bird with a dark brown-egg bird."
        case .chocolate: "Breed from the darkest brown-egg hens."
        case .green: "Cross a blue-egg bird with a light brown-egg bird."
        }
    }
}

/// ≡: new game, the simulator, and the old test screens.
struct SettingsSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var difficulty = Difficulty.standard
    @State private var confirmNew = false
    @State private var testTools = false

    var body: some View {
        SheetPage(context: "Settings") {
            Text("Henhaven").font(Typeface.title)
            Button("Open test tools") { testTools = true }.buttonStyle(.secondary)
            Text("The plain lists from the test build: every action, the full log, the simulator.")
                .font(Typeface.caption).foregroundStyle(palette.inkMuted)
            StitchDivider()
            FeedbackToggles()
            StitchDivider()
            TimeOfDayPicker()
            StitchDivider()
            Text("Fast forward").font(Typeface.item)
            HStack(spacing: Space.m) {
                Button("1 day") { store.fullDays(1) }.buttonStyle(.secondary)
                Button("7 days") { store.fullDays(7) }.buttonStyle(.secondary)
            }
            // Runs every day up to and including the next show, then closes so the show screen opens.
            // Before the early game opens the show, it runs to the day the neighbour announces it.
            let showOpen = store.state.isOpen(.shows)
            let target = showOpen ? store.state.nextShowDay : store.state.rules.introductionDay(of: .shows)
            Button(showOpen ? "To show day (day \(target))" : "To the show news (day \(target))") {
                let days = target - store.state.day
                dismiss()
                store.fullDays(days)
            }
            .buttonStyle(.secondary)
            Text("Feeds, collects, sells a full carton and shuts the coop each day. Your show entries stay.")
                .font(Typeface.caption).foregroundStyle(palette.inkMuted)
            StitchDivider()
            Text("New game").font(Typeface.item)
            WordTabs(tabs: Difficulty.allCases.map { ($0, $0.rawValue.capitalized) }, selection: $difficulty)
            Button("Start a new \(difficulty.rawValue) game") { confirmNew = true }.buttonStyle(.secondary)
        }
        .presentationDetents([.medium, .large])
        .confirmationDialog("This replaces your current game.", isPresented: $confirmNew, titleVisibility: .visible) {
            Button("Start again", role: .destructive) { store.newGame(difficulty) }
        }
        .fullScreenCover(isPresented: $testTools) { TestToolsView() }
    }
}

/// For testing: see the farm by day or by night without waiting for the clock.
struct TimeOfDayPicker: View {
    @Environment(\.palette) private var palette
    @AppStorage(TimeOfDayPin.key) private var pinned: TimeOfDayPin = .clock

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Time of day").font(Typeface.item)
            WordTabs(tabs: TimeOfDayPin.allCases.map { ($0, $0.label) }, selection: $pinned)
            Text("For testing. Clock: night is 6 pm to 6 am. Day or Night stays until you set Clock again.")
                .font(Typeface.caption).foregroundStyle(palette.inkMuted)
        }
    }
}

/// Sound and haptics on or off. `Sound` and `Haptics` read the same keys.
struct FeedbackToggles: View {
    @Environment(\.palette) private var palette
    @AppStorage(FeedbackSettings.soundKey) private var soundOn = true
    @AppStorage(FeedbackSettings.hapticsKey) private var hapticsOn = true

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Toggle("Sound", isOn: $soundOn)
                .font(Typeface.body)
                .frame(minHeight: 44)
            Toggle("Haptics", isOn: $hapticsOn)
                .font(Typeface.body)
                .frame(minHeight: 44)
            Text("Sounds are quiet when the silent switch is on.")
                .font(Typeface.caption).foregroundStyle(palette.inkMuted)
        }
        .tint(palette.ink)
    }
}
