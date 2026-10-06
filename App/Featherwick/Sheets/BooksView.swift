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
                    BreedTile(breed: breed, colours: colours(of: breed, in: s))
                }
            }
            let crosses = s.breedBook.filter(\.isCross).map(entryText).sorted()
            if !crosses.isEmpty {
                Text("Crosses").font(Typeface.item)
                ForEach(crosses, id: \.self) { Text($0.prefix(1).uppercased() + $0.dropFirst()).font(Typeface.body) }
            }
        }
    }

    /// The distinct looks of this breed found so far.
    private func colours(of breed: BreedDefinition, in s: GameState) -> [BreedBookEntry] {
        s.breedBook.filter { !$0.isCross && $0.variety == breed.id.rawValue }
            .sorted { entryText($0) < entryText($1) }
    }
}

/// A collection tile: art, name, and a dot per colour (filled found, dashed still to find).
struct BreedTile: View {
    @Environment(\.palette) private var palette
    let breed: BreedDefinition
    let colours: [BreedBookEntry]

    var body: some View {
        let known = !colours.isEmpty
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
                HStack(spacing: Space.xs) {
                    ForEach(0..<max(breed.varieties.count, colours.count), id: \.self) { i in
                        if i < colours.count {
                            Circle().fill(Pigment.feather(colours[i].colour)).frame(width: 8, height: 8)
                                .overlay(Circle().stroke(palette.ink.opacity(0.3), lineWidth: 0.5))
                        } else {
                            UnknownDot(size: 8)
                        }
                    }
                }
            } else {
                Text("lays \(breed.eggColour.rawValue) eggs").font(Typeface.serifItalic(13, relativeTo: .footnote))
                    .foregroundStyle(palette.inkMuted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            known
                ? "\(breed.displayName), \(colours.count) of \(breed.varieties.count) colours found"
                : "Breed not found yet. Lays \(breed.eggColour.rawValue) eggs")
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
        case .olive: "Cross a blue-egg bird with a brown-egg bird."
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
            Text("Fast forward").font(Typeface.item)
            HStack(spacing: Space.m) {
                Button("1 day") { store.fullDays(1) }.buttonStyle(.secondary)
                Button("7 days") { store.fullDays(7) }.buttonStyle(.secondary)
            }
            // Runs every day up to and including the next show, then closes so the show screen opens.
<<<<<<< HEAD
            // Before the early game opens the show, it runs to the day the neighbour announces it.
            let showOpen = store.state.isOpen(.shows)
            let target = showOpen ? store.state.nextShowDay : store.state.rules.introductionDay(of: .shows)
            Button(showOpen ? "To show day (day \(target))" : "To the show news (day \(target))") {
                let days = target - store.state.day
=======
            Button("To show day (day \(store.state.nextShowDay))") {
                let days = store.state.nextShowDay - store.state.day
>>>>>>> origin/main
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
