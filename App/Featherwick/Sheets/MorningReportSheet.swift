import FeatherwickCore
import FeatherwickText
import SwiftUI

// MARK: - Morning report: what happened overnight

/// The player's "Morning report" switch (Settings). On until the player turns it off.
enum MorningReportSetting {
    static let key = "morningReportOn"
    static var isOn: Bool { FeedbackSettings.isOn(key) }
}

/// What happened overnight, shown once each morning after Sleep, before the farm. One section per group
/// from `MorningReport`, in the night's own words (`eventText`). Empty groups are hidden. The night's toasts
/// are held back while this is the page that tells it.
struct MorningReportSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let s = store.state
        SheetPage(context: "Overnight") {
            if let report = store.morningReport {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Day \(report.day)").font(Typeface.title)
                    Text("\(report.season.rawValue.capitalized) morning").font(Typeface.label)
                        .foregroundStyle(palette.inkMuted)
                }
                .accessibilityElement(children: .combine)
                ForEach(report.shownGroups, id: \.self) { group in
                    let lines = Self.lines(report.events(in: group), s)
                    if !lines.isEmpty {
                        if group == .morning {
                            // The quiet night and the turn of the season sit under the day, with no heading.
                            ReportLines(lines: lines)
                        } else {
                            StitchDivider()
                            ReportSection(
                                title: Self.title(group), count: Self.count(group, report.events(in: group)),
                                lines: lines)
                        }
                    }
                }
            }
            Button("Back to the farm") {
                store.finishMorningReport()
                dismiss()
            }
            .buttonStyle(.primary)
            .padding(.top, Space.s)
        }
        .presentationDetents([.large])
        .onDisappear { store.finishMorningReport() }
    }

    /// The words for a group's events. The day line is left out: the title already says the day.
    private static func lines(_ events: [GameEvent], _ s: GameState) -> [String] {
        events.compactMap { event in
            if case .dayStarted = event { return nil }
            let words = eventText(event, s)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return words.isEmpty ? nil : words
        }
    }

    private static func title(_ group: MorningReport.Group) -> String {
        switch group {
        case .morning: ""
        case .hatched: "Hatched"
        case .fox: "The fox"
        case .cameHome: "Came home"
        case .neighbour: "From Hazel"
        case .newStock: "New at Speckle & Down"
        case .shows: "The county show"
        case .jobs: "Today's jobs"
        case .seasonGoal: "Goals"
        case .eggs: "In the nest boxes"
        case .other: "Around the flock"
        }
    }

    /// A count beside a heading, where one number says it best: chicks hatched, birds scared or home, eggs laid.
    private static func count(_ group: MorningReport.Group, _ events: [GameEvent]) -> Int? {
        var n = 0
        for event in events {
            switch (group, event) {
            case (.hatched, .chicksHatched(let ids, _)): n += ids.count
            case (.fox, .foxVisited(let ids)): n += ids.count
            case (.cameHome, .birdReturned), (.cameHome, .cameHomeFromBoarding): n += 1
            case (.eggs, .eggLaid): n += 1
            default: break
            }
        }
        return n > 0 ? n : nil
    }
}

/// One group: a Caslon heading, a Figtree count, and the night's words.
private struct ReportSection: View {
    @Environment(\.palette) private var palette
    let title: String
    let count: Int?
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(Typeface.place)
                Spacer(minLength: Space.s)
                if let count {
                    Text("\(count)").font(Typeface.number).monospacedDigit().foregroundStyle(palette.inkSoft)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ReportLines(lines: lines)
        }
    }
}

private struct ReportLines: View {
    @Environment(\.palette) private var palette
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line).font(Typeface.body).foregroundStyle(palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The "Morning report" switch in Settings. `MorningReportSetting` reads the same key.
struct MorningReportToggle: View {
    @Environment(\.palette) private var palette
    @AppStorage(MorningReportSetting.key) private var isOn = true

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Toggle("Morning report", isOn: $isOn)
                .font(Typeface.body)
                .frame(minHeight: 44)
            Text("After Sleep, a page of what happened overnight.")
                .font(Typeface.caption).foregroundStyle(palette.inkMuted)
        }
        .tint(palette.ink)
    }
}
