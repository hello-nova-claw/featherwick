import FeatherwickCore
import FeatherwickText
import SwiftUI

/// Show day, full screen: the theme, then each class with your entries, where they placed, what they
/// won and what the judge said. Then the day's takings, and back to the farm.
struct ShowDayView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    let report: ShowReport

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                header
                if report.results.isEmpty {
                    noEntries
                } else {
                    ForEach(classes, id: \.self) { cls in
                        ShowClassSection(
                            showClass: cls, featured: cls.kind == report.theme.featured,
                            results: report.results.filter { $0.showClass == cls })
                    }
                    ShowTakings(coins: report.coinsWon, treats: report.treatsWon)
                }
                Button("Back to the farm") { store.finishShow() }.buttonStyle(.primary)
            }
            .padding(.horizontal, Space.sheetSide)
            .padding(.top, Space.s)
            .padding(.bottom, Space.sheetBottom)
        }
        .foregroundStyle(palette.ink)
        .background(palette.paper)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SheetHeader(context: "The county show, day \(report.day)") { store.finishShow() }
            ArtPlaceholder(label: "show tent").frame(height: 140)
            UnderlinedName(text: showThemeName(report.theme), font: Typeface.title, size: 38)
            Text("Featured: \(kindName(report.theme.featured).lowercased()) classes, bonus prizes")
                .font(Typeface.label).foregroundStyle(palette.inkMuted)
        }
    }

    private var noEntries: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("You didn't enter this time.").font(Typeface.epithet)
            Text("The next show is on day \(store.state.nextShowDay). Enter birds and eggs at the farm gate.")
                .font(Typeface.body).foregroundStyle(palette.inkSoft)
        }
    }

    /// Each class once, in the order the judge went round.
    private var classes: [ShowClass] {
        var seen: [ShowClass] = []
        for r in report.results where !seen.contains(r.showClass) { seen.append(r.showClass) }
        return seen
    }
}

/// One class at the show: its name and difficulty, the top three (rivals too), then each of your entries.
struct ShowClassSection: View {
    @Environment(\.palette) private var palette
    let showClass: ShowClass
    let featured: Bool
    let results: [ShowResult]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(showClass.name).font(Typeface.title2)
            Text(subtitle).font(Typeface.label).foregroundStyle(palette.inkMuted)
            if !podium.isEmpty {
                ShowPodium(showClass: showClass, podium: podium, day: results.first?.day ?? 0)
            }
            ForEach(Array(results.enumerated()), id: \.offset) { _, r in
                ShowEntryResult(result: r)
            }
        }
    }

    /// Every result in a class carries the same podium. Empty for results from older saves.
    private var podium: [PodiumPlace] { results.lazy.compactMap(\.podium).first ?? [] }

    private var subtitle: String {
        let difficulty = "\(difficultyName(showClass.kind)) class"
        return featured ? "\(difficulty) · featured, bonus prizes" : difficulty
    }
}

/// The top three in a class, whoever they belong to. Your own places have an ink frame.
struct ShowPodium: View {
    let showClass: ShowClass
    let podium: [PodiumPlace]
    let day: Int

    var body: some View {
        let owners: [String?] = podiumOwnerNames(podium)
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("The top three").font(Typeface.item)
            ForEach(Array(podium.enumerated()), id: \.offset) { i, place in
                let who: String = podiumWhoText(place, owner: owners[i], in: showClass)
                PodiumRow(place: place, who: who, showClass: showClass, day: day)
            }
        }
    }
}

/// One podium place: rosette, a small drawing, who, the score, and "Why?" for the judge's notes.
struct PodiumRow: View {
    @Environment(\.palette) private var palette
    let place: PodiumPlace
    let who: String
    let showClass: ShowClass
    let day: Int
    @State private var showsWhy = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.s) {
                RibbonMark(placing: place.placing, size: 16)
                PodiumArt(entrant: place.entrant, showClass: showClass, day: day)
                summary
                Spacer(minLength: Space.s)
                whyButton
            }
            if showsWhy { JudgeNotes(notes: place.notes) }
        }
        .padding(Space.s)
        .background { frame }
    }

    /// "Why?" opens the judge's notes under the row; "Hide" closes them.
    private var whyButton: some View {
        let label: String = showsWhy ? "Hide" : "Why?"
        let spoken: String = showsWhy ? "Hide the judge's notes" : "Why it placed: the judge's notes"
        return Button(label) { showsWhy.toggle() }
            .buttonStyle(.textAction)
            .accessibilityLabel(spoken)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(sentenceCase(who)).font(Typeface.item)
            Text("\(placingText(place.placing)), \(place.score) of 100")
                .font(Typeface.label).foregroundStyle(palette.inkMuted)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var frame: some View {
        if place.isKeeper {
            RoundedRectangle(cornerRadius: Radius.control).stroke(palette.ink, lineWidth: 1.2)
        }
    }
}

/// A small drawing of a podium entrant: the bird from its genes, or an egg in the plate's colour.
struct PodiumArt: View {
    @Environment(GameStore.self) private var store
    let entrant: PodiumEntrant
    let showClass: ShowClass
    let day: Int

    private let height: CGFloat = 40

    var body: some View {
        art.frame(width: 48, height: height)
    }

    @ViewBuilder
    private var art: some View {
        switch entrant {
        case .rivalBird(_, let bird):
            ChickenRig(colours: rivalColours(bird), height: height)
        case .rivalPlate(_, let colour, let speckled):
            EggMark(colour: colour, speckled: speckled, size: CGSize(width: 22, height: 28))
        case .keeper(_, let birdID):
            keeperArt(birdID)
        }
    }

    /// A rival as it looked on show day. Its colours come from its genes, like any bird's.
    private func rivalColours(_ bird: Bird) -> ChickenColours {
        let look: Look = bird.look(onDay: day, rules: store.state.rules)
        return ChickenColours(look: look)
    }

    @ViewBuilder
    private func keeperArt(_ id: UUID?) -> some View {
        if let id, let bird = store.state.bird(id) {
            ChickenRig(colours: ChickenColours(bird: bird, state: store.state), height: height)
        } else if case .eggs(let colour) = showClass {
            EggMark(colour: colour, size: CGSize(width: 22, height: 28))
        } else {
            ArtPlaceholder(label: "bird").frame(width: height, height: height)
        }
    }
}

/// The judge's notes, in italic, as the judge said them.
struct JudgeNotes: View {
    @Environment(\.palette) private var palette
    let notes: [JudgeNote]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                Text("“\(sentenceCase(noteText(note))).”")
                    .font(Typeface.serifItalic(18))
                    .foregroundStyle(palette.inkSoft)
            }
        }
    }
}

/// One entry: where it placed, its score, what it won, and the judge's notes.
struct ShowEntryResult: View {
    @Environment(\.palette) private var palette
    let result: ShowResult

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            StitchDivider()
            HStack(spacing: Space.s) {
                if (1...3).contains(result.placing) {
                    RibbonMark(placing: result.placing, size: 18)
                }
                Text(result.entrantName).font(Typeface.item)
                Spacer(minLength: Space.s)
                Text("\(result.score) of 100").font(Typeface.number).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            Text(sentenceCase(placingLabel(result))).font(Typeface.body)
            if let won {
                Text(won).font(Typeface.body).foregroundStyle(palette.inkSoft)
            }
            JudgeNotes(notes: result.notes ?? [])
        }
    }

    /// "Won 30 coins and 3 treats", or nothing outside the prizes.
    private var won: String? {
        let treats = result.treats ?? 0
        guard result.prize > 0 || treats > 0 else { return nil }
        return "Won \(prizeWords(coins: result.prize, treats: treats))"
    }
}

/// The day's takings: coins and treats won across every class.
struct ShowTakings: View {
    @Environment(\.palette) private var palette
    let coins: Int
    let treats: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            StitchDivider()
            Text("Taken home").font(Typeface.item)
            if coins == 0 && treats == 0 {
                Text("No prizes this time. The judge's notes say what to work on.")
                    .font(Typeface.body).foregroundStyle(palette.inkSoft)
            } else {
                HStack(spacing: Space.l) {
                    if coins > 0 { amount(Text("\(coins) coins"), mark: CoinDisc()) }
                    if treats > 0 { amount(Text("\(treats) treats"), mark: TreatDiamond()) }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func amount(_ words: Text, mark: some View) -> some View {
        HStack(spacing: Space.xs) {
            mark
            words.font(Typeface.number).monospacedDigit()
        }
    }
}

/// "not placed" → "Not placed". Judge's notes and placings are written lower case.
func sentenceCase(_ s: String) -> String {
    s.prefix(1).uppercased() + s.dropFirst()
}
