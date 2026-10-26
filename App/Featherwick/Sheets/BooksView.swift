import FeatherwickCore
import FeatherwickText
import SwiftUI

/// 4a / 4b: the collections. Tiles keep a fixed order, so gaps show where unfound breeds belong.
struct BooksView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @State private var tab = BookTab.breeds

    enum BookTab: Hashable { case breeds, eggs, inheritance, records, people }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                HStack {
                    // Five tabs are wider than a phone: they scroll sideways, and the close button stays put.
                    ScrollView(.horizontal, showsIndicators: false) {
                        WordTabs(
                            tabs: [
                                (.breeds, "Breeds"), (.eggs, "Eggs"), (.inheritance, inheritanceTitleText),
                                (.records, RecordsWords.tab), (.people, PeopleWords.tab),
                            ],
                            selection: $tab)
                    }
                    CloseButton()
                }
                switch tab {
                case .breeds: BreedBook()
                case .eggs: EggBook()
                case .inheritance: InheritanceBook()
                case .records: RecordBook()
                case .people: PeopleBook()
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
    /// The lore page open now. Only a breed the keeper owns a look of opens one.
    @State private var page: BreedDefinition?

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
                    let owned = colours(of: breed, in: s)
                    let tile = BreedTile(breed: breed, colours: owned, seen: seen(of: breed, in: s))
                    if owned.isEmpty {
                        tile  // unfound, or only seen at a show: stays closed
                    } else {
                        Button {
                            page = breed
                        } label: {
                            tile
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the \(breed.displayName) page")
                    }
                }
            }
            let crosses = s.breedBook.filter(\.isCross).map(entryText).sorted()
            if !crosses.isEmpty {
                Text("Crosses").font(Typeface.item)
                ForEach(crosses, id: \.self) { Text($0.prefix(1).uppercased() + $0.dropFirst()).font(Typeface.body) }
            }
            SeenAtShows(seen: s.breedBookSeenOnly)
        }
        .sheet(item: $page) { BreedPageSheet(breed: $0).environment(\.palette, palette) }
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

/// A found breed's page: the colours found so far, its lore, and the day it was first found.
/// Words come from `breedLore` and `breedFoundText` (FeatherwickText).
struct BreedPageSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    let breed: BreedDefinition

    var body: some View {
        let s = store.state
        let found = s.breedBook.filter { !$0.isCross && $0.variety == breed.id.rawValue }
            .sorted { swatchName($0) < swatchName($1) }
        SheetPage(context: "Breed Book") {
            ArtPlaceholder(label: "bird art · \(breed.displayName)")
                .frame(width: 200, height: 180)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.l)
            VStack(spacing: Space.s) {
                Text(breed.displayName).font(Typeface.title)
                if let day = breedFoundText(breed.id, s) {
                    Text(day).font(Typeface.epithet).foregroundStyle(palette.inkSoft)
                }
            }
            .frame(maxWidth: .infinity)
            Text("\(found.count) of \(breed.varieties.count) colours found")
                .font(Typeface.label).foregroundStyle(palette.inkMuted)
            VStack(alignment: .leading, spacing: Space.s) {
                ForEach(found, id: \.self) { FeatherSwatch(colour: $0.colour, name: swatchName($0)) }
            }
            if s.dotStandardBreed == breed.id, let looks = dotStandardText(breed.id) {
                StitchDivider()
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(PeopleWords.dotHeading).font(Typeface.item)
                    Text(looks).font(Typeface.note).fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            if let lore = breedLore(breed.id) {
                StitchDivider()
                ForEach(Array(lore.sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(section.heading).font(Typeface.item)
                        Text(section.text).font(Typeface.body).fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .presentationDetents([.large])
    }

    /// The colour as a standard names it ("gold laced"). The swatch shows it next to these words.
    private func swatchName(_ e: BreedBookEntry) -> String {
        let colour = featherColourName(e.colour, barred: e.barred, laced: e.laced)
        return colour + (e.silkieFeathered && breed.id != .silkie ? ", silkie-feathered" : "")
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
        case .olive: "Cross an Araucana with a brown-egg breed. Some of the hens lay olive eggs."
        case .chocolate: "Very dark brown eggs. Rare in Featherwick."
        case .green: "Cross an Araucana with a brown-egg breed. Some of the hens lay green eggs."
        case .white: "Shells with no tint at all. Rare in Featherwick."
        }
    }
}

/// The flock record book: eggs per hen, ribbons per bird, and the flock in numbers (Core's `Records`).
/// Names in Caslon, numbers in Figtree. A hen who has not laid yet reads "none yet", not 0.
struct RecordBook: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        let r = Records.of(store.state)
        VStack(alignment: .leading, spacing: Space.l) {
            Text(RecordsWords.title).font(Typeface.title)
            eggs(r)
            ribbons(r)
            flock(r.flock)
        }
    }

    private func eggs(_ r: FlockRecords) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(RecordsWords.eggs).font(Typeface.item)
            if r.eggs.isEmpty {
                Text(RecordsWords.noHensYet).font(Typeface.note).foregroundStyle(palette.inkMuted)
            } else {
                Grid(alignment: .leading, horizontalSpacing: Space.m, verticalSpacing: Space.s) {
                    GridRow {
                        header(RecordsWords.hen)
                        header(RecordsWords.total).gridColumnAlignment(.trailing)
                        header(RecordsWords.recent(r.windowDays)).gridColumnAlignment(.trailing)
                        header(RecordsWords.firstEgg).gridColumnAlignment(.trailing)
                    }
                    ForEach(r.eggs, id: \.henID) { row in
                        GridRow {
                            Text(eggRowName(row)).font(Typeface.rowName)
                            if let total = row.total, let recent = row.recent, let first = row.firstEggDay {
                                number("\(total)")
                                number("\(recent)")
                                number(RecordsWords.day(first))
                            } else {
                                Text(RecordsWords.noneYet).font(Typeface.serifItalic(14, relativeTo: .footnote))
                                    .foregroundStyle(palette.inkMuted)
                                    .gridCellColumns(3)
                                    .gridCellAnchor(.trailing)
                            }
                        }
                    }
                }
            }
            StitchDivider()
        }
    }

    private func ribbons(_ r: FlockRecords) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(RecordsWords.ribbons).font(Typeface.item)
            if r.ribbons.isEmpty {
                Text(RecordsWords.noRibbonsYet).font(Typeface.note).foregroundStyle(palette.inkMuted)
            } else {
                Grid(alignment: .leading, horizontalSpacing: Space.m, verticalSpacing: Space.s) {
                    GridRow {
                        header(RecordsWords.bird)
                        header(RecordsWords.first).gridColumnAlignment(.trailing)
                        header(RecordsWords.second).gridColumnAlignment(.trailing)
                        header(RecordsWords.third).gridColumnAlignment(.trailing)
                    }
                    ForEach(Array(r.ribbons.enumerated()), id: \.offset) { _, row in
                        GridRow {
                            Text(row.name).font(Typeface.rowName)
                            number("\(row.firsts)")
                            number("\(row.seconds)")
                            number("\(row.thirds)")
                        }
                    }
                }
            }
            StitchDivider()
        }
    }

    private func flock(_ f: FlockFacts) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(RecordsWords.flock).font(Typeface.item)
            Grid(alignment: .leading, horizontalSpacing: Space.m, verticalSpacing: Space.s) {
                ForEach(flockFactLines(f), id: \.label) { line in
                    GridRow {
                        Text(line.label).font(Typeface.rowName)
                        number(line.value).gridColumnAlignment(.trailing)
                    }
                }
            }
        }
    }

    private func header(_ words: String) -> some View {
        Text(words).font(Typeface.label).foregroundStyle(palette.inkMuted)
    }

    private func number(_ words: String) -> some View {
        Text(words).font(Typeface.number).monospacedDigit()
    }
}

/// What the keeper has worked out from setting eggs from a penned pair: one row per rule, in the order
/// first seen. A dashed box says how to fill the page before the first rule.
struct InheritanceBook: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        let rules = InheritancePage.known(in: store.state)
        VStack(alignment: .leading, spacing: Space.l) {
            Text(inheritanceTitleText).font(Typeface.title)
            Text(inheritanceSubtitleText).font(Typeface.label).foregroundStyle(palette.inkMuted)
            if rules.isEmpty {
                Text(inheritanceEmptyText)
                    .font(Typeface.serifItalic(14, relativeTo: .footnote))
                    .foregroundStyle(palette.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Space.l)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.tile).stroke(palette.unknownBox, style: Stitch.unknown))
            } else {
                VStack(spacing: 0) {
                    ForEach(rules, id: \.self) { rule in
                        Text(sentenceCase(inheritanceText(rule)))
                            .font(Typeface.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, Space.m)
                        StitchDivider()
                    }
                }
            }
        }
    }
}

/// ≡: the keeper's name, debts, the old test screens, sound and haptics, the morning report and time of day
/// switches, fast forward and a new game.
struct SettingsSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var confirmNew = false
    @State private var testTools = false

    var body: some View {
        SheetPage(context: "Settings") {
            Text("Henhaven").font(Typeface.title)
            // DUMMY PR: breaks the rules on purpose. Never merge.
            Button {
                testTools = true
            } label: {
                Circle().fill(Color(red: 0.9, green: 0.1, blue: 0.1)).frame(width: 44, height: 44)
            }
            Text("You have " + String(store.state.day) + " days on the farm")
            KeeperNameField()
            DebtsSection()
            Button("Open test tools") { testTools = true }.buttonStyle(.secondary)
            Text("The plain lists from the test build: every action, the full log, the simulator.")
                .font(Typeface.caption).foregroundStyle(palette.inkMuted)
            StitchDivider()
            FeedbackToggles()
            StitchDivider()
            MorningReportToggle()
            StitchDivider()
            TimeOfDayPicker()
            StitchDivider()
            #if DEBUG || BETA
                if BetaNotes.showsInSettings {
                    BetaNotesSettings()
                    StitchDivider()
                }
            #endif
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
            Button("Start a new game") { confirmNew = true }.buttonStyle(.secondary)
        }
        .presentationDetents([.medium, .large])
        .confirmationDialog("This replaces your current game.", isPresented: $confirmNew, titleVisibility: .visible) {
            Button("Start again", role: .destructive) { store.newGame() }
        }
        .fullScreenCover(isPresented: $testTools) { TestToolsView() }
    }
}

/// For testing: see the farm by day or by night without waiting for game time.
struct TimeOfDayPicker: View {
    @Environment(\.palette) private var palette
    @AppStorage(TimeOfDayPin.key) private var pinned: TimeOfDayPin = .clock

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Time of day").font(Typeface.item)
            WordTabs(tabs: TimeOfDayPin.allCases.map { ($0, $0.label) }, selection: $pinned)
            Text("For testing. Game: day until evening, night from Sleep. Day or Night stays until you set Game again.")
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

/// Settings: "You owe", one line for each debt with a Pay button. Hidden when the keeper owes nothing.
/// No interest and no deadline: the button waits until the keeper has the coins.
struct DebtsSection: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        let s = store.state
        if !s.debts.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("You owe").font(Typeface.item)
                ForEach(s.debts) { debt in
                    HStack(spacing: Space.m) {
                        Text(debtLineText(debt)).font(Typeface.body)
                        Spacer(minLength: Space.s)
                        Button("Pay") { store.run(.payDebt(debt.id)) }
                            .buttonStyle(.secondary)
                            .disabled(s.coins < debt.coins)
                    }
                    .frame(minHeight: 44)
                }
                Text(debtsNoteText).font(Typeface.caption).foregroundStyle(palette.inkMuted)
            }
            StitchDivider()
        }
    }
}

/// Settings: the keeper's own name, as Hazel and Wren say it.
struct KeeperNameField: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @State private var name = ""

    var body: some View {
        HStack(spacing: Space.m) {
            TextField("Your name", text: $name)
                .font(Typeface.body)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit(save)
            Button("Save", action: save)
                .buttonStyle(.secondary)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || name == store.state.keeperName)
        }
        .onAppear { name = store.state.keeperName ?? "" }
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        store.run(.nameKeeper(name))
    }
}
