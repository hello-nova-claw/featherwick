import FeatherwickCore

// MARK: - The flock record book (Records.swift)

/// The words of the record book. The app's Records tab and the CLI's `records` share them.
public enum RecordsWords {
    public static let tab = "Records"
    public static let title = "Record Book"
    public static let eggs = "Eggs"
    public static let ribbons = "Ribbons"
    public static let flock = "The flock"
    public static let hen = "Hen"
    public static let bird = "Bird"
    public static let total = "Total"
    public static let firstEgg = "First egg"
    public static let first = "1st"
    public static let second = "2nd"
    public static let third = "3rd"
    /// A visible hen who has not laid yet. Not "0": she simply has not started.
    public static let noneYet = "none yet"
    public static let noHensYet = "No hens laying yet."
    public static let noRibbonsYet = "No ribbons yet. The county show gives them for 1st, 2nd and 3rd."

    public static func recent(_ days: Int) -> String { "Last \(days) days" }
    public static func day(_ d: Int) -> String { "day \(d)" }
    /// The note beside a hen who lives in Featherwick now. Her eggs still count.
    public static let rehomedNote = "rehomed"
}

/// One line of the "The flock" table.
public struct FlockFactLine: Hashable, Sendable {
    public let label: String
    public let value: String
}

/// The "The flock" table, in reading order. A day not reached yet reads "not yet".
public func flockFactLines(_ f: FlockFacts) -> [FlockFactLine] {
    [
        FlockFactLine(label: "Birds now", value: "\(f.birdsNow)"),
        FlockFactLine(label: "Hatched here", value: "\(f.hatchedHere)"),
        FlockFactLine(label: "Bought", value: "\(f.bought)"),
        FlockFactLine(label: "Rehomed", value: "\(f.rehomed)"),
        FlockFactLine(label: "Retired", value: "\(f.retired)"),
        FlockFactLine(label: "First hatch", value: f.firstHatchDay.map(RecordsWords.day) ?? "not yet"),
        FlockFactLine(label: "First ribbon", value: f.firstRibbonDay.map(RecordsWords.day) ?? "not yet"),
        FlockFactLine(label: "Days kept", value: "\(f.daysKept)"),
    ]
}

/// The name in a hen's row, with a note when she was rehomed.
public func eggRowName(_ row: EggRecordRow) -> String {
    row.rehomed ? "\(row.name) (\(RecordsWords.rehomedNote))" : row.name
}

/// The CLI's `records`.
public func recordsLines(_ s: GameState) -> [String] {
    let r = Records.of(s)
    var out: [String] = ["\(RecordsWords.title):"]
    out.append("\(RecordsWords.eggs) (total, last \(r.windowDays) days, first egg):")
    if r.eggs.isEmpty { out.append("  " + RecordsWords.noHensYet) }
    for row in r.eggs {
        if let total = row.total, let recent = row.recent, let first = row.firstEggDay {
            out.append("  \(eggRowName(row)) — \(total), \(recent), \(RecordsWords.day(first))")
        } else {
            out.append("  \(eggRowName(row)) — \(RecordsWords.noneYet)")
        }
    }
    out.append("\(RecordsWords.ribbons) (1st, 2nd, 3rd):")
    if r.ribbons.isEmpty { out.append("  " + RecordsWords.noRibbonsYet) }
    for row in r.ribbons { out.append("  \(row.name) — \(row.firsts), \(row.seconds), \(row.thirds)") }
    out.append("\(RecordsWords.flock):")
    for line in flockFactLines(r.flock) { out.append("  \(line.label): \(line.value)") }
    return out
}
