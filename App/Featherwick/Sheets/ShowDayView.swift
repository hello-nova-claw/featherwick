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

/// One class at the show: its name and difficulty, then each of your entries in it.
struct ShowClassSection: View {
    @Environment(\.palette) private var palette
    let showClass: ShowClass
    let featured: Bool
    let results: [ShowResult]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(showClass.name).font(Typeface.title2)
            Text(subtitle).font(Typeface.label).foregroundStyle(palette.inkMuted)
            ForEach(Array(results.enumerated()), id: \.offset) { _, r in
                ShowEntryResult(result: r)
            }
        }
    }

    private var subtitle: String {
        let difficulty = "\(difficultyName(showClass.kind)) class"
        return featured ? "\(difficulty) · featured, bonus prizes" : difficulty
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
            notes
        }
    }

    /// "Won 30 coins and 3 treats", or nothing outside the prizes.
    private var won: String? {
        let treats = result.treats ?? 0
        guard result.prize > 0 || treats > 0 else { return nil }
        return "Won \(prizeWords(coins: result.prize, treats: treats))"
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            ForEach(Array((result.notes ?? []).enumerated()), id: \.offset) { _, note in
                Text("“\(sentenceCase(noteText(note))).”")
                    .font(Typeface.serifItalic(18))
                    .foregroundStyle(palette.inkSoft)
            }
        }
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
private func sentenceCase(_ s: String) -> String {
    s.prefix(1).uppercased() + s.dropFirst()
}
