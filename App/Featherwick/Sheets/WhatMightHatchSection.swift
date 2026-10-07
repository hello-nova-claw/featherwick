import FeatherwickCore
import FeatherwickText
import SwiftUI

// MARK: - What might hatch (in the breeding pen)

/// The breeding pen's "What might hatch": per penned hen, what her chicks with the penned rooster could
/// show. Core's `Planner.panel` decides every line from what the keeper could know; this view only shows
/// the words, and a feather or egg mark when a line names that colour. The colour comes from the line's
/// `Trait`, never from its words. Closed until the keeper first opens it, which sends `.openPlanner`.
struct WhatMightHatchSection: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        let s = store.state
        let panel = Planner.panel(in: s)
        switch panel {
        case .hidden:
            EmptyView()
        case .needsHen, .needsRooster:
            // No notice here: "this pair" needs a pair. It shows once a hen and a rooster are penned.
            StitchDivider()
            if let line = plannerPanelText(panel, s) {
                Text(line).font(Typeface.body).foregroundStyle(palette.inkMuted)
            }
        case .forecast(let rooster, let pairs):
            StitchDivider()
            notice(s)
            if s.plannerOpened {
                heading(panel, s)
                ForEach(pairs, id: \.hen) { pair in
                    // Both are penned, so both show their sex: their names leak nothing.
                    Text("\(birdName(pair.hen, s)) & \(birdName(rooster, s))")
                        .font(Typeface.label).foregroundStyle(palette.inkMuted)
                    ForEach(Array(pair.lines.enumerated()), id: \.offset) { i, line in
                        if i > 0 { StitchDivider() }
                        WhyLine(text: plannerText(line, s), why: plannerReasonText(line.reason, s)) {
                            marks(line)
                        }
                    }
                }
            } else {
                // Unopened: the heading is the way in. Opening it is the keeper's own step, so the game
                // can stop showing the notice.
                Button {
                    store.run(.openPlanner)
                } label: {
                    HStack(spacing: Space.s) {
                        heading(panel, s)
                        Spacer(minLength: 0)
                        Text("→").font(Typeface.body).foregroundStyle(palette.inkMuted)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the forecast.")
            }
        }
    }

    /// "New: …" while the keeper has not opened the forecast yet.
    @ViewBuilder
    private func notice(_ s: GameState) -> some View {
        if let text = plannerNoticeText(s) {
            NoticeLine(notice: Notice(kind: .story, text: text))
        }
    }

    @ViewBuilder
    private func heading(_ panel: PlannerPanel, _ s: GameState) -> some View {
        if let title = plannerPanelText(panel, s) {
            Text(title).font(Typeface.item).accessibilityAddTraits(.isHeader)
        }
    }

    /// The colour a line names, as a mark beside its words: a feather for a feather colour, an egg for
    /// each egg colour. Patterns (barred, laced, speckled) and the rest name no colour, so get none.
    @ViewBuilder
    private func marks(_ line: Forecast) -> some View {
        switch line {
        case .certain(let trait, _), .ratio(let trait, _, _, _), .likely(let trait, _), .possible(let trait, _),
            .notPossible(let trait, _):
            switch trait {
            case .colour(let colour): FeatherMark(colour: colour)
            case .eggColour(let colour): EggMark(colour: colour)
            case .barred, .laced, .silkieFeathered, .speckledEggs: EmptyView()
            }
        case .eggColours(let colours, _, _):
            HStack(spacing: Space.xs) {
                ForEach(colours, id: \.self) { EggMark(colour: $0) }
            }
        case .sexLink, .typeOutlook, .kinship, .unknownUnderWhite:
            EmptyView()
        }
    }
}

// MARK: - Carrier lines (on the bird card)

/// "Carries lavender": what the keeper has proven a bird hides, each with its reason a tap away.
/// Empty, so nothing at all, until the keeper knows the planner.
struct CarrierLines: View {
    @Environment(GameStore.self) private var store
    let birdID: UUID

    var body: some View {
        let s = store.state
        let notes = Planner.carrierNotes(for: birdID, in: s)
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                ForEach(notes, id: \.self) { note in
                    WhyLine(text: carrierText(note), why: carrierReasonText(note, bird: birdID, s))
                }
            }
            .padding(.bottom, Space.l)
        }
    }
}

// MARK: - A line that says why

/// One line that opens to say why: tap shows its reason in italic under it, tap again hides it.
/// The whole line is one button, so VoiceOver reads the line, and the reason too once open.
struct WhyLine<Marks: View>: View {
    @Environment(\.palette) private var palette
    let text: String
    let why: String
    let marks: Marks
    @State private var isOpen = false

    init(text: String, why: String, @ViewBuilder marks: () -> Marks) {
        self.text = text
        self.why = why
        self.marks = marks()
    }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { isOpen.toggle() }
        } label: {
            HStack(alignment: .top, spacing: Space.s) {
                marks.accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(text).font(Typeface.body)
                    if isOpen {
                        Text(why).font(Typeface.note).foregroundStyle(palette.inkSoft)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(isOpen ? "Hides why." : "Shows why.")
    }
}

extension WhyLine where Marks == EmptyView {
    init(text: String, why: String) {
        self.init(text: text, why: why) { EmptyView() }
    }
}
