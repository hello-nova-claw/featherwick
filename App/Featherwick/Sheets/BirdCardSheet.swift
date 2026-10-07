import FeatherwickCore
import FeatherwickText
import SwiftUI

/// 2a / 2b: one bird. Art, name, breed line, four facts, show notes, then Cuddle and Treat.
struct BirdCardSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    let birdID: UUID
    let context: String
    @State private var renaming = false
    @State private var newName = ""
    @State private var showTree = false
    @State private var enteringShow = false
    @State private var confirmRehome = false
    @State private var cuddles = 0
    @State private var treats = 0

    var body: some View {
        let s = store.state
        if let bird = s.bird(birdID), !s.rehomed.contains(where: { $0.id == birdID }) {
            SheetPage(context: context) {
                ArtPlaceholder(label: "bird art · \(bird.name)")
                    .frame(width: 200, height: 180)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.l)
                VStack(spacing: Space.s) {
                    UnderlinedName(text: bird.name)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(epithet(bird, s)).font(Typeface.epithet).foregroundStyle(palette.inkSoft)
                }
                .frame(maxWidth: .infinity)
                facts(bird, s)
                    .padding(.vertical, Space.l)
                showNotes(bird, s)
                ribbons(bird, s)
                handlingButtons(bird, s)
                moreActions(bird, s)
                LastWords()
            }
            // The farm's toasts are under this sheet: show them here too, so "Juniper liked that" is seen.
            .overlay { ToastStack() }
            .presentationDetents([.large])
            .alert("Rename \(bird.name)", isPresented: $renaming) {
                TextField("Name", text: $newName)
                Button("Save") { store.run(.rename(birdID, name: newName)) }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Rehome \(bird.name)?", isPresented: $confirmRehome, titleVisibility: .visible) {
                Button("A neighbour pays \(s.rehomeValue(of: bird)) coins", role: .destructive) {
                    store.run(.rehome(birdID))
                }
            } message: {
                Text("\(bird.name) goes to a good home in Featherwick.")
            }
            .sheet(isPresented: $showTree) { FamilyTreeSheet(birdID: birdID).environment(\.palette, palette) }
            .sheet(isPresented: $enteringShow) { EnterShowSheet(birdID: birdID).environment(\.palette, palette) }
        } else {
            SheetPage(context: context) {
                Text("This bird has a new home.").font(Typeface.epithet).padding(.vertical, Space.xxl)
            }
        }
    }

    @ViewBuilder
    private func facts(_ bird: Bird, _ s: GameState) -> some View {
        let stage = bird.stage(onDay: s.day, rules: s.rules)
        Grid(alignment: .topLeading, horizontalSpacing: Space.l, verticalSpacing: 26) {
            GridRow {
                Fact(label: "Friendliness") {
                    FriendlinessDabs(level: bird.friendliness)
                    Text(friendlinessName(bird.friendliness)).font(Typeface.body)
                }
                Fact(label: "Age") {
                    AgeDots(stage: stage)
                    Text(ageText(bird, stage, s)).font(Typeface.body)
                }
            }
            GridRow {
                Fact(label: "Feathers") {
                    if bird.revealed {
                        FeatherSwatch(colour: bird.phenotype.colour, name: colourText(bird.phenotype))
                    } else {
                        Text(downText(bird.phenotype.chickDown).capitalized).font(Typeface.body)
                    }
                }
                laysFact(bird, stage, s)
            }
        }
    }

    /// Before a show: how the bird should look on the day (the moult, a broody spell), so nothing
    /// is a surprise. After one: what the judge said, kept on the bird's card.
    @ViewBuilder
    private func showNotes(_ bird: Bird, _ s: GameState) -> some View {
        let canEnter = s.isOpen(.shows) && !Engine.eligibleClasses(for: bird, in: s).isEmpty
        let last = s.showResults.last { $0.birdID == bird.id && !($0.notes ?? []).isEmpty }
        if canEnter || last != nil {
            VStack(alignment: .leading, spacing: Space.l) {
                if canEnter {
                    Fact(label: "Next show") {
                        Text(showReadinessText(bird, s)).font(Typeface.body)
                    }
                }
                if let last {
                    Fact(label: "Judge's notes, day \(last.day)") {
                        ForEach(Array((last.notes ?? []).enumerated()), id: \.offset) { _, note in
                            Text("“\(sentenceCase(noteText(note))).”")
                                .font(Typeface.serifItalic(17)).foregroundStyle(palette.inkSoft)
                        }
                    }
                }
            }
            .padding(.bottom, Space.l)
        }
    }

    /// Every show this bird went to, newest first. Hidden until it has been to one.
    @ViewBuilder
    private func ribbons(_ bird: Bird, _ s: GameState) -> some View {
        let results = s.showResults.filter { $0.birdID == bird.id }
        if !results.isEmpty {
            Fact(label: "Ribbons") {
                ForEach(Array(results.reversed().enumerated()), id: \.offset) { _, r in
                    RibbonLine(result: r)
                }
            }
            .padding(.bottom, Space.l)
        }
    }

    @ViewBuilder
    private func laysFact(_ bird: Bird, _ stage: LifeStage, _ s: GameState) -> some View {
        if !bird.revealed {
            Fact(label: "Hen or rooster") {
                Text("Shows in ~\(max(1, s.rules.growerAge - bird.age(onDay: s.day))) days").font(Typeface.body)
            }
        } else if bird.sex == .rooster {
            Fact(label: "Hen or rooster") { Text("Rooster").font(Typeface.body) }
        } else if bird.isRetired(onDay: s.day, rules: s.rules) {
            Fact(label: "Lays") { Text("Retired, resting").font(Typeface.body) }
        } else if stage == .adult, let egg = bird.phenotype.eggColour {
            Fact(label: "Lays") { EggSwatch(colour: egg, speckled: bird.phenotype.eggIsSpeckled) }
        } else {
            Fact(label: "Lays") {
                Text("From day \(bird.hatchDay + s.rules.adultAge)").font(Typeface.body)
            }
        }
    }

    /// Cuddle and Treat. Each counts once a day per bird, so once done the button rests and says so,
    /// like "Fed for today" in the yard.
    private func handlingButtons(_ bird: Bird, _ s: GameState) -> some View {
        let cuddled = bird.wasHandled(.pet, onDay: s.day)
        let hadTreat = bird.wasHandled(.treat, onDay: s.day)
        let treatLabel = hadTreat ? "Had a treat today" : s.treats > 0 ? "Treat · \(s.treats)" : "No treats left"
        return HStack(spacing: Space.m) {
            Button(cuddled ? "Cuddled today" : "Cuddle") {
                store.run(.pet(birdID))
                cuddles += 1
            }
            .buttonStyle(.primary)
            .disabled(cuddled)
            .sensoryFeedback(.impact(weight: .light), trigger: cuddles)
            Button(treatLabel) {
                store.run(.giveTreat(birdID))
                treats += 1
            }
            .buttonStyle(.secondary)
            .disabled(hadTreat || s.treats == 0)
            .sensoryFeedback(.impact(weight: .light), trigger: treats)
        }
    }

    @ViewBuilder
    private func moreActions(_ bird: Bird, _ s: GameState) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.l) {
                Button("Rename") {
                    newName = bird.name
                    renaming = true
                }
                Button("Family tree") { showTree = true }
            }
            HStack(spacing: Space.l) {
                if bird.isBroody(onDay: s.day), s.clutch(under: birdID) == nil {
                    Button("Set eggs under her") {
                        store.run(.sit(hen: birdID, count: min(s.rules.maxClutch, max(1, s.carton.count))))
                    }
                }
                // Only once the county show has opened (early game), and only for a bird that can enter.
                if s.isOpen(.shows), !Engine.eligibleClasses(for: bird, in: s).isEmpty {
                    if s.showEntries.contains(where: { $0.birdID == birdID }) {
                        Button("Entered in the show") {}.disabled(true)
                    } else {
                        Button("Enter the show") { enteringShow = true }
                    }
                }
                // Hidden when it can't happen (the only bird, or a hen busy with eggs or chicks).
                if Engine.rehomeBlocker(birdID, in: s) == nil {
                    Button("Rehome") { confirmRehome = true }
                }
            }
        }
        .buttonStyle(.textAction)
        .frame(maxWidth: .infinity)
    }

    /// "a Buff Orpington hen", "a blue olive egger cockerel", or "breed still a mystery".
    private func epithet(_ bird: Bird, _ s: GameState) -> String {
        guard bird.revealed else { return "breed still a mystery" }
        let kind: String =
            switch (bird.stage(onDay: s.day, rules: s.rules), bird.sex) {
            case (.adult, .hen): "hen"
            case (.adult, .rooster): "rooster"
            case (_, .hen): "pullet"
            case (_, .rooster): "cockerel"
            }
        let breed = bird.isPurebred ? bird.breed.definition.displayName : bird.varietyName
        let colour = colourText(bird.phenotype).capitalized
        return "a \(colour) \(breed) \(kind)"
    }

    private func ageText(_ bird: Bird, _ stage: LifeStage, _ s: GameState) -> String {
        let days = bird.age(onDay: s.day)
        let word: String =
            switch (stage, bird.revealed ? bird.sex : nil) {
            case (.chick, _): "Chick"
            case (.grower, .hen?): "Pullet"
            case (.grower, .rooster?): "Cockerel"
            case (.grower, nil): "Growing"
            case (.adult, .hen?): "Hen"
            case (.adult, .rooster?): "Rooster"
            case (.adult, nil): "Grown"
            }
        return "\(word), \(days) day\(days == 1 ? "" : "s")"
    }
}

/// "1st of 8 · Orpington class, day 84, Harvest Show", with a rosette for the top three.
struct RibbonLine: View {
    let result: ShowResult

    var body: some View {
        HStack(spacing: Space.s) {
            if (1...3).contains(result.placing) {
                RibbonMark(placing: result.placing)
            }
            Text(words).font(Typeface.body)
        }
    }

    private var words: String {
        let show = result.theme.map { ", \(showThemeName($0))" } ?? ""
        return "\(placingLabel(result)) · \(result.showClass.name) class, day \(result.day)\(show)"
    }
}

/// The newest thing that happened, so a tap on Cuddle or Treat shows its result.
struct LastWords: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    var body: some View {
        if let line = store.log.last {
            Text(line.text)
                .font(Typeface.sans(14, relativeTo: .footnote))
                .foregroundStyle(line.isRejection ? Pigment.brownNotice : palette.inkSoft)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .animation(.easeOut, value: line.id)
        }
    }
}

/// The family tree, three generations, as text for now.
struct FamilyTreeSheet: View {
    @Environment(GameStore.self) private var store
    let birdID: UUID
    var body: some View {
        SheetPage(context: "Family tree") {
            Text(treeLines(birdID, store.state).joined(separator: "\n"))
                .font(.system(.footnote, design: .monospaced))
        }
        .presentationDetents([.medium, .large])
    }
}

/// 3a: name a new bird. The suggestion is ready; "Try another" picks the next free name.
struct NamingSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var forBird: UUID?
    @State private var tries = 0

    var body: some View {
        let s = store.state
        if let bird = s.unnamedBirds.first {
            SheetPage(context: namingContext(bird, s)) {
                ArtPlaceholder(label: "chick art")
                    .frame(width: 140, height: 110)
                    .frame(maxWidth: .infinity)
                Text(question(bird)).font(Typeface.title2)
                TextField("", text: $name)
                    .font(Typeface.serif(30, relativeTo: .title))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .background(alignment: .bottom) {
                        HLine().stroke(palette.ink.opacity(0.5), style: Stitch.underline).frame(height: 2)
                            .offset(y: 4)
                    }
                HStack(spacing: Space.xs) {
                    Text("A suggestion.").font(Typeface.label).foregroundStyle(palette.inkMuted)
                    Button("Try another") {
                        tries += 1
                        name = NameBook.suggestion(for: bird, in: s, skipping: tries)
                    }
                    .buttonStyle(.textAction)
                }
                Button("Name \(pronoun(bird)) \(trimmed.isEmpty ? "…" : trimmed)") {
                    store.run(.rename(bird.id, name: trimmed))
                }
                .buttonStyle(.primary)
                .disabled(trimmed.isEmpty)
                Button("Later") { dismiss() }
                    .buttonStyle(.textAction)
                    .frame(maxWidth: .infinity)
                LastWords()
            }
            .presentationDetents([.large])
            .onAppear { prepare(bird, s) }
            .onChange(of: bird.id) { _, _ in prepare(bird, s) }
        } else {
            SheetPage(context: "Potting shed") {
                Text("Everyone has a name.").font(Typeface.epithet).padding(.vertical, Space.xl)
            }
            .presentationDetents([.medium])
        }
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    private func prepare(_ bird: Bird, _ s: GameState) {
        guard forBird != bird.id else { return }
        forBird = bird.id
        tries = 0
        name = NameBook.suggestion(for: bird, in: s)
    }

    /// Where the bird is now. A bird left unnamed for a while may already be in the coop.
    private func namingContext(_ bird: Bird, _ s: GameState) -> String {
        if s.coop.contains(where: { $0.id == bird.id }) { return "In the coop" }
        if s.henChicks.contains(where: { $0.id == bird.id }) { return "With a broody hen" }
        return bird.revealed ? "New to the flock" : "Just hatched in the brooder"
    }

    /// No sex until the player can see it: an unrevealed chick is "this chick".
    private func question(_ bird: Bird) -> String {
        bird.revealed ? "What shall we call \(bird.sex == .hen ? "her" : "him")?" : "What shall we call this chick?"
    }

    private func pronoun(_ bird: Bird) -> String {
        bird.revealed ? (bird.sex == .hen ? "her" : "him") : "it"
    }
}

/// Toasts under the HUD: one sentence and at most one action. They leave after 4 seconds.
struct ToastStack: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Space.s) {
            ForEach(store.toasts) { toast in
                HStack(spacing: Space.m) {
                    EggShape().fill(palette.toastText.opacity(0.15)).frame(width: 12, height: 15)
                    Text(toast.text).font(Typeface.sans(15)).foregroundStyle(palette.toastText)
                    Spacer(minLength: 0)
                    if let action = toast.action {
                        Button(action) {
                            store.openRequest = toast.opens
                            store.dismissToast(toast.id)
                        }
                        .font(Typeface.action)
                        .foregroundStyle(palette.toastText)
                        .frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, Space.l)
                .background(palette.toast, in: RoundedRectangle(cornerRadius: Radius.control))
                .shadow(
                    color: Color.black.opacity(palette.isNight ? 0.8 : 0.35), radius: palette.isNight ? 20 : 7, y: 4
                )
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(voiceOver ? 10 : 4))
                    withAnimation(.easeOut(duration: 0.25)) { store.dismissToast(toast.id) }
                }
            }
            Spacer()
        }
        .padding(.top, 76)
        .padding(.horizontal, Space.l)
        .animation(.easeOut(duration: 0.25), value: store.toasts)
    }
}
