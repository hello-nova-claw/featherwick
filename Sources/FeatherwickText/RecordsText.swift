import FeatherwickCore

// MARK: - The flock record book (Records.swift)

/// The words of the record book. The app's Records tab and the CLI's `records` share them.
public enum RecordsWords {
    public static var tab: String {
        String(
            localized: "records.tab", defaultValue: "Records", bundle: .module, comment: "Books tab: the record book.")
    }
    public static var title: String {
        String(localized: "records.title", defaultValue: "Record Book", bundle: .module, comment: "Record book title.")
    }
    public static var eggs: String {
        String(localized: "records.eggs", defaultValue: "Eggs", bundle: .module, comment: "Record book section.")
    }
    public static var ribbons: String {
        String(localized: "records.ribbons", defaultValue: "Ribbons", bundle: .module, comment: "Record book section.")
    }
    public static var flock: String {
        String(localized: "records.flock", defaultValue: "The flock", bundle: .module, comment: "Record book section.")
    }
    public static var hen: String {
        String(localized: "records.hen", defaultValue: "Hen", bundle: .module, comment: "Column heading: the hen.")
    }
    public static var bird: String {
        String(localized: "records.bird", defaultValue: "Bird", bundle: .module, comment: "Column heading: the bird.")
    }
    public static var total: String {
        String(
            localized: "records.total", defaultValue: "Total", bundle: .module,
            comment: "Column heading: eggs laid in all.")
    }
    public static var firstEgg: String {
        String(
            localized: "records.firstEgg", defaultValue: "First egg", bundle: .module,
            comment: "Column heading: the day of a hen's first egg.")
    }
    public static var first: String {
        String(
            localized: "records.first", defaultValue: "1st", bundle: .module, comment: "Column heading: first places.")
    }
    public static var second: String {
        String(
            localized: "records.second", defaultValue: "2nd", bundle: .module, comment: "Column heading: second places."
        )
    }
    public static var third: String {
        String(
            localized: "records.third", defaultValue: "3rd", bundle: .module, comment: "Column heading: third places.")
    }
    /// A visible hen who has not laid yet. Not "0": she simply has not started.
    public static var noneYet: String {
        String(
            localized: "records.noneYet", defaultValue: "none yet", bundle: .module,
            comment: "In place of a hen's egg count: she has not laid yet.")
    }
    public static var noHensYet: String {
        String(localized: "records.noHensYet", defaultValue: "No hens laying yet.", bundle: .module)
    }
    public static var noRibbonsYet: String {
        String(
            localized: "records.noRibbonsYet",
            defaultValue: "No ribbons yet. The county show gives them for 1st, 2nd and 3rd.",
            bundle: .module)
    }

    public static func recent(_ days: Int) -> String {
        String(
            localized: "records.recent", defaultValue: "Last \(days) days", bundle: .module,
            comment: "Column heading: eggs laid lately. The placeholder is a number of days.")
    }
    public static func day(_ d: Int) -> String {
        String(
            localized: "records.day", defaultValue: "day \(d)", bundle: .module,
            comment: "A day of the game, in a table cell. The placeholder is the day number.")
    }
    /// The note beside a hen who lives in Featherwick now. Her eggs still count.
    public static var rehomedNote: String {
        String(
            localized: "records.rehomed", defaultValue: "rehomed", bundle: .module,
            comment: "Beside a hen who now lives in the village.")
    }
    /// A day not reached yet in "The flock" table.
    static var notYet: String {
        String(localized: "records.notYet", defaultValue: "not yet", bundle: .module, comment: "In place of a day.")
    }
}

/// One line of the "The flock" table.
public struct FlockFactLine: Hashable, Sendable {
    public let label: String
    public let value: String
}

/// The "The flock" table, in reading order. A day not reached yet reads "not yet".
public func flockFactLines(_ f: FlockFacts) -> [FlockFactLine] {
    let day = { (d: Int?) in d.map(RecordsWords.day) ?? RecordsWords.notYet }
    return [
        FlockFactLine(
            label: String(localized: "records.birdsNow", defaultValue: "Birds now", bundle: .module),
            value: f.birdsNow.formatted()),
        FlockFactLine(
            label: String(localized: "records.hatchedHere", defaultValue: "Hatched here", bundle: .module),
            value: f.hatchedHere.formatted()),
        FlockFactLine(
            label: String(
                localized: "records.bought", defaultValue: "Bought", bundle: .module, comment: "Birds bought."),
            value: f.bought.formatted()),
        FlockFactLine(
            label: String(
                localized: "records.rehomedCount", defaultValue: "Rehomed", bundle: .module,
                comment: "Birds that went to live in the village."),
            value: f.rehomed.formatted()),
        FlockFactLine(
            label: String(
                localized: "records.retired", defaultValue: "Retired", bundle: .module,
                comment: "Hens too old to lay."),
            value: f.retired.formatted()),
        FlockFactLine(
            label: String(localized: "records.firstHatch", defaultValue: "First hatch", bundle: .module),
            value: day(f.firstHatchDay)),
        FlockFactLine(
            label: String(localized: "records.firstRibbon", defaultValue: "First ribbon", bundle: .module),
            value: day(f.firstRibbonDay)),
        FlockFactLine(
            label: String(localized: "records.daysKept", defaultValue: "Days kept", bundle: .module),
            value: f.daysKept.formatted()),
    ]
}

/// The name in a hen's row, with a note when she was rehomed.
public func eggRowName(_ row: EggRecordRow) -> String {
    guard row.rehomed else { return row.name }
    return String(
        localized: "records.rehomedName", defaultValue: "\(row.name) (\(RecordsWords.rehomedNote))", bundle: .module,
        comment: "A hen's name, then the note that she was rehomed.")
}

/// The CLI's `records`. Indents are layout, not words, so they stay out of the catalog.
public func recordsLines(_ s: GameState) -> [String] {
    let r = Records.of(s)
    var out: [String] = [cliHeading(RecordsWords.title)]
    out.append(
        String(
            localized: "records.cli.eggs", defaultValue: "Eggs (total, last \(r.windowDays) days, first egg):",
            bundle: .module, comment: "CLI heading over the egg table. The placeholder is a number of days."))
    if r.eggs.isEmpty { out.append("  " + RecordsWords.noHensYet) }
    for row in r.eggs {
        if let total = row.total, let recent = row.recent, let first = row.firstEggDay {
            out.append(
                "  "
                    + String(
                        localized: "records.cli.eggRow",
                        defaultValue: "\(eggRowName(row)) — \(total), \(recent), \(RecordsWords.day(first))",
                        bundle: .module,
                        comment: "CLI egg table row: hen's name, eggs in all, eggs lately, the day of her first egg."))
        } else {
            out.append(
                "  "
                    + String(
                        localized: "records.cli.eggRowNone",
                        defaultValue: "\(eggRowName(row)) — \(RecordsWords.noneYet)",
                        bundle: .module,
                        comment: "CLI egg table row for a hen who has not laid: her name, then none yet."
                    ))
        }
    }
    out.append(
        String(localized: "records.cli.ribbons", defaultValue: "Ribbons (1st, 2nd, 3rd):", bundle: .module))
    if r.ribbons.isEmpty { out.append("  " + RecordsWords.noRibbonsYet) }
    for row in r.ribbons {
        out.append(
            "  "
                + String(
                    localized: "records.cli.ribbonRow",
                    defaultValue: "\(row.name) — \(row.firsts), \(row.seconds), \(row.thirds)", bundle: .module,
                    comment: "CLI ribbon table row: bird's name, then its 1st, 2nd and 3rd places."))
    }
    out.append(cliHeading(RecordsWords.flock))
    for line in flockFactLines(r.flock) {
        out.append(
            "  "
                + String(
                    localized: "records.cli.fact", defaultValue: "\(line.label): \(line.value)", bundle: .module,
                    comment: "CLI flock table row: a label, then its value."))
    }
    return out
}

/// A CLI heading: the words, then a colon.
func cliHeading(_ words: String) -> String {
    String(
        localized: "cli.heading", defaultValue: "\(words):", bundle: .module,
        comment: "A heading in the text game, followed by its lines. The placeholder is the heading.")
}
