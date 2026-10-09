import FeatherwickCore
import FeatherwickText
import SwiftUI

// MARK: - Farm gate: Speckle & Down (8a) and the county show

struct FarmGateSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    let open: (FarmSheet) -> Void
    @State private var tab = ShopTab.feed

    enum ShopTab: Hashable { case feed, treats, hatching, show }
    static let tabs: [(ShopTab, String)] = [
        (.feed, "Feed"), (.treats, "Treats"), (.hatching, "Hatching"), (.show, "Show"),
    ]

    var body: some View {
        let s = store.state
        SheetPage(context: "In the village") {
            HStack(spacing: Space.xs) {
                Spacer()
                CoinDisc()
                Text(s.coins.formatted()).font(Typeface.number).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            ArtPlaceholder(label: "shop front").frame(height: 130)
            Text("Speckle & Down").font(Typeface.title)
            Text("“Morning! Fresh mealworms in today, and the feed's just come off the cart.”")
                .font(Typeface.serifItalic(19)).foregroundStyle(palette.inkSoft)
            // The Show tab appears when the early game opens the show (a week before the first one).
            WordTabs(tabs: Self.tabs.filter { $0.0 != .show || s.isOpen(.shows) }, selection: $tab)
            switch tab {
            case .feed: feedItems(s)
            case .treats: treatItems(s)
            case .hatching: hatchingItems(s)
            case .show: ShowPanel()
            }
            // The market board is by the bakery, next door (MarketBoardSheet).
            if s.isOpen(.marketBoard) {
                let cards = s.marketBoard.cards.count
                Button(cards == 0 ? "Market board" : "Market board · \(cards) card\(cards == 1 ? "" : "s")") {
                    open(.marketBoard)
                }
                .buttonStyle(.textAction)
            }
            LastWords()
        }
        .presentationDetents([.large])
        .onAppear {
            // Whatever came in today has now been seen: the farm gate stops saying "new in today".
            store.sawNewStock()
            // The neighbour's show tip is waiting: open on the Show tab.
            if let tip = s.showTip, !s.showEntries.contains(where: { $0.birdID == tip.birdID }) { tab = .show }
        }
    }

    private func feedItems(_ s: GameState) -> some View {
        let r = s.rules
        return VStack(spacing: 0) {
            if s.isOpen(.premiumFeed) {
                ShopRow(
                    name: "Premium feed", detail: "\(r.premiumFeedBagSize) days. Feeds the flock and lifts laying.",
                    price: r.premiumFeedPrice, coins: s.coins,
                    closed: daylightRefusalText(.buy(.premiumFeed), in: s)
                ) { store.run(.buy(.premiumFeed)) }
            }
            Text("Basic feed is free, always.").font(Typeface.caption).foregroundStyle(palette.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, Space.s)
        }
    }

    @ViewBuilder
    private func treatItems(_ s: GameState) -> some View {
        if s.isOpen(.treats) {
            ShopRow(
                name: "Mealworms", detail: "A bag of \(s.rules.treatBagSize). One a day wins a bird's trust.",
                price: s.rules.treatBagPrice, coins: s.coins,
                closed: daylightRefusalText(.buy(.treats), in: s)
            ) { store.run(.buy(.treats)) }
        } else {
            NotYetLine(feature: .treats)
        }
    }

    private func hatchingItems(_ s: GameState) -> some View {
        let r = s.rules
        return VStack(spacing: 0) {
            if s.isOpen(.birdShop) { birdStock(s) } else { NotYetLine(feature: .birdShop) }
            if s.isOpen(.incubatorShop), s.incubatorSize < r.bigIncubatorSize {
                ShopRow(
                    name: "Incubator",
                    detail: "Holds \(r.bigIncubatorSize) eggs. They hatch in \(r.incubatorHatchDays) nights.",
                    price: r.incubatorPrice, coins: s.coins,
                    closed: daylightRefusalText(.buyIncubator, in: s)
                ) { store.run(.buyIncubator) }
            }
            if s.isOpen(.coopUpgrade), s.perches < r.maxPerches {
                ShopRow(
                    name: "More perches", detail: "Adds \(r.perchesPerUpgrade) perches (now \(s.perches)).",
                    price: r.coopUpgradePrice, coins: s.coins,
                    closed: daylightRefusalText(.upgradeCoop, in: s)
                ) { store.run(.upgradeCoop) }
            }
        }
    }

    /// Birds and eggs: the daily special, basic stock, and breeds a storyline unlocked.
    @ViewBuilder
    private func birdStock(_ s: GameState) -> some View {
        let r = s.rules
        specialRow(s)
        ShopRow(
            name: "A fertile egg", detail: "From a local flock, already candled.", price: r.fertileEggPrice,
            coins: s.coins,
            closed: daylightRefusalText(.buy(.fertileEgg), in: s)
        ) { store.run(.buy(.fertileEgg)) }
        ShopRow(
            name: "A pullet", detail: "A young hen. The breed is a surprise.", price: r.pulletPrice, coins: s.coins,
            closed: daylightRefusalText(.buy(.pullet), in: s)
        ) {
            store.run(.buy(.pullet))
        }
        ShopRow(
            name: "A cockerel", detail: "A young rooster. The breed is a surprise.", price: r.cockerelPrice,
            coins: s.coins,
            closed: daylightRefusalText(.buy(.cockerel), in: s)
        ) { store.run(.buy(.cockerel)) }
    }
}

/// What the shop says about stock that the early game has not brought in yet.
struct NotYetLine: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    let feature: Feature

    var body: some View {
        Text(notYetText(feature, store.state))
            .font(Typeface.caption).foregroundStyle(palette.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, Space.s)
    }
}

extension FarmGateSheet {
    /// Today's special: one named bird (breed, sex, colour). It changes every day; sometimes it is rare.
    @ViewBuilder
    fileprivate func specialRow(_ s: GameState) -> some View {
        if let special = s.todaysSpecial {
            ShopRow(
                name: "Today's special", detail: shopSpecialText(special), price: special.price, coins: s.coins,
                closed: daylightRefusalText(.buySpecial, in: s)
            ) { store.run(.buySpecial) }
        } else {
            Text("Today's special is sold. A new one comes tomorrow.")
                .font(Typeface.caption).foregroundStyle(palette.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, Space.s)
        }
    }
}

/// A 72pt shop row: item art, name and one line, and a price button.
struct ShopRow: View {
    @Environment(\.palette) private var palette
    let name: String
    let detail: String
    let price: Int
    let coins: Int
    /// Why the shop can't sell today (no daylight left for the trip), or nil. The price button disables.
    var closed: String? = nil
    let buy: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.m) {
                ArtPlaceholder(label: "item", radius: Radius.control).frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(Typeface.item)
                    Text(detail).font(Typeface.caption).foregroundStyle(palette.inkMuted).lineLimit(2)
                    if let closed {
                        Text(closed).font(Typeface.caption).foregroundStyle(palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: Space.s)
                PriceButton(price: price, canAfford: coins >= price, action: buy)
                    .disabled(closed != nil)
            }
            .frame(minHeight: 72)
            StitchDivider()
        }
    }
}

/// The county show: the next show's theme and day, what is entered, birds and plates to enter, and
/// past placings. Each bird shows how it should look on the day; the judge's notes come with the results.
struct ShowPanel: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @State private var choosing: BirdChoice?

    var body: some View {
        let s = store.state
        VStack(alignment: .leading, spacing: Space.xl) {
            ShowHeading(theme: s.nextShowTheme, day: s.nextShowDay, fee: s.rules.showEntryFee)
            tip(s)
            entered(s)
            birdsToEnter(s)
            platesToEnter(s)
            pastResults(s)
            villageCalendar(s)
        }
        .sheet(item: $choosing) { choice in
            EnterShowSheet(birdID: choice.id).environment(\.palette, palette)
        }
    }

    /// The neighbour's suggestion: one bird and one class, with a button to enter it. Gone once entered.
    @ViewBuilder
    private func tip(_ s: GameState) -> some View {
        if let tip = s.showTip, let bird = s.bird(tip.birdID), !s.showEntries.contains(where: { $0.birdID == bird.id }),
            Engine.eligibleClasses(for: bird, in: s).contains(tip.showClass)
        {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Hazel thinks \(bird.name) could do well in the \(tip.showClass.name) class.")
                    .font(Typeface.note).foregroundStyle(palette.inkSoft)
                // No daylight left for the show desk: the words in place of the button.
                if let closed = daylightRefusalText(.enterShowIn(bird.id, tip.showClass), in: s) {
                    Text(closed).font(Typeface.label).foregroundStyle(palette.inkSoft)
                } else {
                    Button("Enter \(bird.name) · \(s.rules.showEntryFee) coins") {
                        store.run(.enterShowIn(bird.id, tip.showClass))
                    }
                    .buttonStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func entered(_ s: GameState) -> some View {
        if s.showEntries.isEmpty {
            Text("Nothing entered yet.").font(Typeface.body).foregroundStyle(palette.inkSoft)
        } else {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Entered").font(Typeface.item)
                ForEach(Array(s.showEntries.enumerated()), id: \.offset) { _, e in
                    Text(entryLine(e, s)).font(Typeface.body)
                    if let id = e.birdID, let bird = s.bird(id) {
                        Text(showReadinessText(bird, s)).font(Typeface.caption).foregroundStyle(palette.inkMuted)
                    }
                }
            }
        }
    }

    /// Birds that may go to the show and are not entered yet. Chicks have no class.
    @ViewBuilder
    private func birdsToEnter(_ s: GameState) -> some View {
        let enteredIDs = Set(s.showEntries.compactMap(\.birdID))
        let birds = s.birdsAtHome.filter {
            !enteredIDs.contains($0.id) && !Engine.eligibleClasses(for: $0, in: s).isEmpty
        }
        if !birds.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Enter a bird").font(Typeface.item).padding(.bottom, Space.s)
                ForEach(birds) { bird in birdRow(bird, s) }
            }
        }
    }

    private func birdRow(_ bird: Bird, _ s: GameState) -> some View {
        let classes = Engine.eligibleClasses(for: bird, in: s).map(\.name).joined(separator: " or ")
        return VStack(spacing: 0) {
            Button {
                choosing = BirdChoice(id: bird.id)
            } label: {
                HStack(spacing: Space.m) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bird.name).font(Typeface.body)
                        Text(classes).font(Typeface.caption).foregroundStyle(palette.inkMuted)
                        if !Judge.forecast(for: bird, in: s).isEmpty {
                            Text(showReadinessText(bird, s)).font(Typeface.caption).foregroundStyle(palette.inkSoft)
                        }
                    }
                    Spacer()
                    Text("→")
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            StitchDivider()
        }
    }

    /// Each matched plate the carton can make, best first. The chosen eggs go to the show.
    private func platesToEnter(_ s: GameState) -> some View {
        let plates = Judge.bestPlates(from: s.carton, state: s)
        return VStack(alignment: .leading, spacing: 0) {
            Text("Enter a plate of eggs").font(Typeface.item).padding(.bottom, Space.s)
            if plates.isEmpty {
                Text(
                    "A plate is \(ShowPoints.eggPlate) carton eggs of one colour, all speckled or all plain."
                )
                .font(Typeface.label).foregroundStyle(palette.inkMuted)
            }
            ForEach(Array(plates.enumerated()), id: \.offset) { _, plate in
                plateRow(plate.eggs, plate.card.showClass, s)
            }
        }
    }

    private func plateRow(_ eggs: [Egg], _ cls: ShowClass, _ s: GameState) -> some View {
        let speckled = eggs.first?.speckled == true
        let name = "A plate of \(speckled ? "speckled " : "")\(cls.name.lowercased())"
        let command = Command.enterEggPlate(eggs.map(\.id))
        return ShowClassRow(
            name: name, showClass: cls, state: s, closed: daylightRefusalText(command, in: s)
        ) {
            store.run(command)
        }
    }

    @ViewBuilder
    private func pastResults(_ s: GameState) -> some View {
        if !s.showResults.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Past shows").font(Typeface.item)
                ForEach(Array(s.showResults.suffix(6).reversed().enumerated()), id: \.offset) { _, r in
                    Text(resultLine(r)).font(Typeface.label).foregroundStyle(palette.inkSoft)
                    StitchDivider()
                }
            }
        }
    }

    /// The next village days, and the Hatch-along while its week is on. Nothing here asks for anything.
    private func villageCalendar(_ s: GameState) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Village calendar").font(Typeface.item)
            ForEach(villageCalendarLines(s, count: 2) + hatchAlongLines(s), id: \.self) { line in
                Text(line).font(Typeface.label).foregroundStyle(palette.inkSoft)
            }
        }
    }

    private func entryLine(_ e: ShowEntry, _ s: GameState) -> String {
        if let id = e.birdID, let b = s.bird(id) {
            let cls = e.showClass ?? Engine.showClass(for: b, in: s)
            return "\(b.name), \(cls.name) class"
        }
        if let first = e.eggs.first {
            return "A plate of \(first.speckled ? "speckled " : "")\(first.colour.rawValue) eggs"
        }
        return "An entry"
    }

    private func resultLine(_ r: ShowResult) -> String {
        "Day \(r.day) · \(r.entrantName), \(r.showClass.name): \(placingLabel(r)), \(r.score) of 100"
    }
}

/// A bird picked from a list, for `.sheet(item:)`.
struct BirdChoice: Identifiable, Hashable {
    let id: UUID
}

/// The top of the show panel: the theme's name, the day, the fee, and which classes pay a bonus.
struct ShowHeading: View {
    @Environment(\.palette) private var palette
    let theme: ShowTheme
    let day: Int
    let fee: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(showThemeName(theme)).font(Typeface.title2)
            Text("Day \(day). Entry \(fee) coins.").font(Typeface.body)
            Text("Featured: \(kindName(theme.featured).lowercased()) classes, bonus prizes")
                .font(Typeface.label).foregroundStyle(palette.inkMuted)
            if let note = showSeasonNote(theme) {
                Text(note).font(Typeface.label).foregroundStyle(palette.inkSoft)
            }
        }
    }
}

/// One class to enter: its name, how hard it is, what 1st pays, and the entry fee as the button.
struct ShowClassRow: View {
    @Environment(\.palette) private var palette
    let name: String
    let showClass: ShowClass
    let state: GameState
    /// Why the show desk can't take an entry today (no daylight left), or nil. The price button disables.
    var closed: String? = nil
    let enter: () -> Void

    var body: some View {
        let fee = state.rules.showEntryFee
        VStack(spacing: 0) {
            HStack(spacing: Space.m) {
                details
                Spacer(minLength: Space.s)
                PriceButton(price: fee, canAfford: state.coins >= fee, action: enter)
                    .disabled(closed != nil)
            }
            .frame(minHeight: 72)
            StitchDivider()
        }
    }

    private var details: some View {
        let theme = state.nextShowTheme
        let first = Engine.prize(for: 1, in: showClass, theme: theme, rules: state.rules)
        let prize = prizeWords(coins: first.coins, treats: first.treats)
        return VStack(alignment: .leading, spacing: 2) {
            Text(name).font(Typeface.item)
            Text("\(difficultyName(showClass.kind)) · 1st wins \(prize)")
                .font(Typeface.caption).foregroundStyle(palette.inkMuted)
            Text(judgingText(showClass.kind)).font(Typeface.caption).foregroundStyle(palette.inkMuted)
            if showClass.kind == theme.featured {
                Text("Featured: bonus prizes").font(Typeface.caption).foregroundStyle(palette.inkSoft)
            }
            if let closed {
                Text(closed).font(Typeface.caption).foregroundStyle(palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Choosing a class for one bird. A bird may fit two (its breed class and the pet class).
struct EnterShowSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let birdID: UUID

    var body: some View {
        let s = store.state
        SheetPage(context: "\(showThemeName(s.nextShowTheme)), day \(s.nextShowDay)") {
            if let bird = s.bird(birdID) {
                Text("Enter \(bird.name)").font(Typeface.title2)
                Text("Pick a class. Harder classes have a bigger field and bigger prizes.")
                    .font(Typeface.label).foregroundStyle(palette.inkMuted)
                // How the bird should look on the day, before the fee is paid.
                Text(showReadinessText(bird, s)).font(Typeface.body)
                classRows(bird, s)
            }
            LastWords()
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func classRows(_ bird: Bird, _ s: GameState) -> some View {
        let classes = Engine.eligibleClasses(for: bird, in: s)
        if s.showEntries.contains(where: { $0.birdID == birdID }) {
            Text("\(bird.name) is entered for day \(s.nextShowDay).").font(Typeface.body)
        } else if classes.isEmpty {
            Text("Too young for the show. Chicks stay home.").font(Typeface.body).foregroundStyle(palette.inkSoft)
        } else {
            VStack(spacing: 0) {
                ForEach(classes, id: \.self) { cls in
                    ShowClassRow(
                        name: "\(cls.name) class", showClass: cls, state: s,
                        closed: daylightRefusalText(.enterShowIn(birdID, cls), in: s)
                    ) { enter(cls) }
                }
            }
        }
    }

    /// Close on success; stay open on a "no", so its reason shows in the last words.
    private func enter(_ cls: ShowClass) {
        let events = store.run(.enterShowIn(birdID, cls))
        let rejected = events.contains {
            if case .rejected = $0 { return true }
            return false
        }
        if !rejected { dismiss() }
    }
}

/// "1st of 8", "4th of 6, no ribbon", "not placed". 4th and below are real placings, but only the
/// top three take a ribbon home.
func placingLabel(_ r: ShowResult) -> String {
    switch r.placing {
    case 0: "not placed"
    case 1...3: "\(placingText(r.placing)) of \(r.fieldSize)"
    default: "\(placingText(r.placing)) of \(r.fieldSize), no ribbon"
    }
}

/// The pet class is the easy way in; breed classes are judged hardest, against the biggest field.
func difficultyName(_ kind: ShowKind) -> String {
    switch kind {
    case .pet: "Easy"
    case .eggs: "Medium"
    case .breed: "Hard"
    }
}

func kindName(_ kind: ShowKind) -> String {
    switch kind {
    case .pet: "Pet"
    case .eggs: "Egg"
    case .breed: "Breed"
    }
}

/// "30 coins", "8 coins and 3 treats", "no prize".
func prizeWords(coins: Int, treats: Int) -> String {
    var parts: [String] = []
    if coins > 0 { parts.append("\(coins) coin\(coins == 1 ? "" : "s")") }
    if treats > 0 { parts.append("\(treats) treat\(treats == 1 ? "" : "s")") }
    return parts.isEmpty ? "no prize" : parts.joined(separator: " and ")
}

// MARK: - Back fence (6a)

/// A neighbour over the fence. What they say comes from the storylines; replies are full-width rows.
struct BackFenceSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let s = store.state
        VStack(alignment: .leading, spacing: Space.l) {
            HStack(alignment: .top) {
                ArtPlaceholder(label: "portrait", radius: 36)
                    .frame(width: 72, height: 72)
                    .background(palette.paper, in: Circle())
                    .offset(y: -36)
                    .padding(.bottom, -36)
                Spacer()
                CloseButton()
            }
            Text("\(People.neighbour), over the fence").font(Typeface.label).foregroundStyle(palette.inkMuted)
            Text(speech(s)).font(Typeface.speech)
            VStack(spacing: 0) {
                StitchDivider()
                // Hazel's asks first, then the village's: Hazel passes on what the others are asking.
                // Books ▸ People offers the same rows.
                ForEach(Engine.storiesAwaitingDelivery(s)) { story in
                    let who = story.person == .hazel ? "" : " (\(People.name(story.person)))"
                    reply(PeopleWords.handOver + who) { store.run(.deliver(story: story.id)) }
                }
                ForEach(s.pendingChoices, id: \.story) { choice in
                    ForEach(choice.options, id: \.self) { option in
                        let words = sentenceCase(choiceText(story: choice.story, option: option))
                        reply("\(People.name(choice.person)): \(words)") {
                            store.run(.choose(story: choice.story, option: option))
                        }
                    }
                }
                if s.tradeOffer != nil {
                    reply("Yes, let's trade") { store.run(.acceptTrade) }
                }
                if s.hatchAlongRefusal() == nil {
                    reply("Bring an egg for the Hatch-along") { store.run(.giveHatchAlongEgg(nil)) }
                }
                reply("Bye for now") { dismiss() }
            }
            LastWords()
        }
        .padding(.horizontal, Space.sheetSide)
        .padding(.bottom, Space.sheetBottom)
        .foregroundStyle(palette.ink)
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(palette.paper)
    }

    private func reply(_ text: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack {
                    Text(text).font(Typeface.body)
                    Spacer()
                    Text("→")
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            StitchDivider()
        }
    }

    /// The newest storyline line, or a quiet hello when nothing is happening.
    private func speech(_ s: GameState) -> String {
        if let offer = s.tradeOffer {
            return
                "“My daughter's starting a flock and needs a rooster. I'd swap you a young hen for \(birdName(offer.roosterID, s)).”"
        }
        // Hazel away (Marigold's week), or a choice waiting for a perch or a busy hen: its own words.
        if let words = hazelFenceText(s) { return words }
        for story in Storylines.all.reversed() where story.person == .hazel {
            guard let p = s.stories[story.id], !p.rewarded, !story.steps.isEmpty else { continue }
            // The words of the step the story is on: `storyStep` names the step it moves to. The story's
            // opening words before its first step is done, and its last step's once every step is.
            let step = p.step == 0 ? nil : story.steps[min(p.step, story.steps.count - 1)].id
            return storyText(story.id, step: step)
        }
        return "“Lovely morning for it. Your hens are looking well.”"
    }
}
