import FeatherwickCore
import FeatherwickText
import SwiftUI

// MARK: - Farm gate: Speckle & Down (8a) and the county show

struct FarmGateSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @State private var tab = ShopTab.feed

    enum ShopTab: Hashable { case feed, treats, hatching, show }

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
            WordTabs(
                tabs: [(.feed, "Feed"), (.treats, "Treats"), (.hatching, "Hatching"), (.show, "Show")],
                selection: $tab)
            switch tab {
            case .feed: feedItems(s)
            case .treats: treatItems(s)
            case .hatching: hatchingItems(s)
            case .show: ShowPanel()
            }
            LastWords()
        }
        .presentationDetents([.large])
    }

    private func feedItems(_ s: GameState) -> some View {
        let r = s.rules
        return VStack(spacing: 0) {
            ShopRow(
                name: "Premium feed", detail: "\(r.premiumFeedBagSize) days. Feeds the flock and lifts laying.",
                price: r.premiumFeedPrice, coins: s.coins
            ) { store.run(.buy(.premiumFeed)) }
            Text("Basic feed is free, always.").font(Typeface.caption).foregroundStyle(palette.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, Space.s)
        }
    }

    private func treatItems(_ s: GameState) -> some View {
        ShopRow(
            name: "Mealworms", detail: "A bag of \(s.rules.treatBagSize). One a day wins a bird's trust.",
            price: s.rules.treatBagPrice, coins: s.coins
        ) { store.run(.buy(.treats)) }
    }

    private func hatchingItems(_ s: GameState) -> some View {
        let r = s.rules
        return VStack(spacing: 0) {
            ShopRow(
                name: "A fertile egg", detail: "From a local flock, already candled.", price: r.fertileEggPrice,
                coins: s.coins
            ) { store.run(.buy(.fertileEgg)) }
            ShopRow(name: "A pullet", detail: "A young hen, breed known.", price: r.pulletPrice, coins: s.coins) {
                store.run(.buy(.pullet))
            }
            ShopRow(
                name: "A cockerel", detail: "A young rooster, breed known.", price: r.cockerelPrice, coins: s.coins
            ) { store.run(.buy(.cockerel)) }
            ForEach(s.shopBreeds.sorted { $0.rawValue < $1.rawValue }, id: \.self) { breed in
                ShopRow(
                    name: "A \(breed.definition.displayName) pullet", detail: breed.definition.note,
                    price: r.rareBreedPulletPrice, coins: s.coins
                ) { store.run(.buyBreed(breed)) }
            }
            if s.incubatorSize < r.bigIncubatorSize {
                ShopRow(
                    name: "Incubator", detail: "Holds \(r.bigIncubatorSize) eggs, hatches overnight.",
                    price: r.incubatorPrice, coins: s.coins
                ) { store.run(.buyIncubator) }
            }
            if s.perches < r.maxPerches {
                ShopRow(
                    name: "More perches", detail: "Adds \(r.perchesPerUpgrade) perches (now \(s.perches)).",
                    price: r.coopUpgradePrice, coins: s.coins
                ) { store.run(.upgradeCoop) }
            }
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
    let buy: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.m) {
                ArtPlaceholder(label: "item", radius: Radius.control).frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(Typeface.item)
                    Text(detail).font(Typeface.caption).foregroundStyle(palette.inkMuted).lineLimit(2)
                }
                Spacer(minLength: Space.s)
                PriceButton(price: price, canAfford: coins >= price, action: buy)
            }
            .frame(minHeight: 72)
            StitchDivider()
        }
    }
}

/// The county show: when it is, what is entered, and past ribbons.
struct ShowPanel: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        let s = store.state
        VStack(alignment: .leading, spacing: Space.m) {
            Text("The \(s.season.rawValue.capitalized) Show is on day \(s.nextShowDay).").font(Typeface.body)
            Text("Entry \(s.rules.showEntryFee) coins. Ribbons pay \(s.rules.showPrizeFirst), \(s.rules.showPrizeSecond) and \(s.rules.showPrizeThird).")
                .font(Typeface.label).foregroundStyle(palette.inkMuted)
            if s.showEntries.isEmpty {
                Text("Nothing entered yet. Enter a bird from its card.").font(Typeface.body)
                    .foregroundStyle(palette.inkSoft)
            } else {
                ForEach(Array(s.showEntries.enumerated()), id: \.offset) { _, e in
                    Text(entryLine(e, s)).font(Typeface.body)
                }
            }
            Button("Enter my best plate of eggs") { store.run(.enterEggs) }.buttonStyle(.secondary)
            if !s.showResults.isEmpty {
                Text("Ribbons").font(Typeface.item)
                ForEach(Array(s.showResults.suffix(6).reversed().enumerated()), id: \.offset) { _, r in
                    Text(resultLine(r)).font(Typeface.label).foregroundStyle(palette.inkSoft)
                    StitchDivider()
                }
            }
        }
    }

    private func entryLine(_ e: ShowEntry, _ s: GameState) -> String {
        if let id = e.birdID, let b = s.bird(id) { return "\(b.name), \(Engine.showClass(for: b, in: s).name) class" }
        if let first = e.eggs.first { return "A plate of \(first.speckled ? "speckled " : "")\(first.colour.rawValue) eggs" }
        return "An entry"
    }

    private func resultLine(_ r: ShowResult) -> String {
        let place = r.placing == 0 ? "no ribbon" : r.placing == 1 ? "1st" : r.placing == 2 ? "2nd" : "3rd"
        return "Day \(r.day) · \(r.entrantName), \(r.showClass.name): \(place), \(r.score) of 100"
    }
}

// MARK: - Judge card (7a)

/// The judge's card for one bird: a dashed ring with the score, the grade, and the judge's notes.
struct JudgeCardSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let birdID: UUID

    var body: some View {
        let s = store.state
        if let bird = s.bird(birdID) {
            let showClass = Engine.showClass(for: bird, in: s)
            let card = Judge.judge(bird, in: showClass, state: s)
            SheetPage(context: "Practice judging, \(showClass.name.lowercased())") {
                UnderlinedName(text: bird.name, font: Typeface.display(40), size: 40)
                    .frame(maxWidth: .infinity)
                GradeRing(score: card.score)
                    .frame(maxWidth: .infinity)
                Text(gradeName(card.grade)).font(Typeface.epithet).frame(maxWidth: .infinity)
                GradeScale(grade: card.grade)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(card.notes.prefix(4).enumerated()), id: \.offset) { _, note in
                        Text("“\(noteText(note).prefix(1).uppercased() + noteText(note).dropFirst()).”")
                            .font(Typeface.serifItalic(18))
                            .padding(.vertical, Space.m)
                        StitchDivider()
                    }
                }
                Text("Mrs Hartley, judge").font(Typeface.label).foregroundStyle(palette.inkMuted)
                Button("Thank the judge") { dismiss() }.buttonStyle(.primary)
            }
            .presentationDetents([.large])
        }
    }
}

/// A 128pt dashed ink ring: the score, "of 100" underneath.
struct GradeRing: View {
    @Environment(\.palette) private var palette
    let score: Int
    var body: some View {
        ZStack {
            Circle().stroke(palette.ink, style: StrokeStyle(lineWidth: 1.3, dash: [4, 4]))
            VStack(spacing: 0) {
                Text("\(score)").font(Typeface.display(48))
                Text("of 100").font(Typeface.label).foregroundStyle(palette.inkMuted)
            }
        }
        .frame(width: 128, height: 128)
        .accessibilityElement(children: .combine)
    }
}

/// Fair · Good · Very good · Excellent. Reached steps are solid, the rest dashed.
struct GradeScale: View {
    @Environment(\.palette) private var palette
    let grade: Grade
    private let steps: [Grade] = [.fair, .good, .veryGood, .excellent]

    var body: some View {
        HStack(alignment: .top, spacing: Space.s) {
            ForEach(steps, id: \.self) { step in
                VStack(spacing: Space.xs) {
                    if step <= grade {
                        HLine().stroke(palette.ink, lineWidth: 2).frame(height: 2)
                    } else {
                        HLine().stroke(palette.unknown, style: Stitch.unknown).frame(height: 2)
                    }
                    Text(gradeName(step))
                        .font(step == grade ? Typeface.sansMedium(12, relativeTo: .caption) : Typeface.caption)
                        .foregroundStyle(step == grade ? palette.ink : palette.inkMuted)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Grade: \(gradeName(grade))")
    }
}

func gradeName(_ g: Grade) -> String {
    switch g {
    case .disqualified: "Not judged"
    case .fair: "Fair"
    case .good: "Good"
    case .veryGood: "Very good"
    case .excellent: "Excellent"
    }
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
            Text("Mabel, over the fence").font(Typeface.label).foregroundStyle(palette.inkMuted)
            Text(speech(s)).font(Typeface.speech)
            VStack(spacing: 0) {
                StitchDivider()
                if let story = Engine.storyAwaitingDelivery(s) {
                    reply("Hand over the eggs") { store.run(.deliver(story: story)) }
                }
                if s.tradeOffer != nil {
                    reply("Yes, let's trade") { store.run(.acceptTrade) }
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
            return "“My daughter's starting a flock and needs a rooster. I'd swap you a young hen for \(birdName(offer.roosterID, s)).”"
        }
        for story in Storylines.all.reversed() {
            guard let p = s.stories[story.id], !p.rewarded else { continue }
            let step = p.step < story.steps.count && p.step > 0 ? story.steps[p.step - 1].id : nil
            return storyText(story.id, step: step)
        }
        return "“Lovely morning for it. Your hens are looking well.”"
    }
}
