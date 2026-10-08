import FeatherwickCore
import Foundation

// The words for the inheritance page (Books ▸ Inheritance) and the CLI's `inheritance`.
//
// A rule names no bird: only looks and what hatches. Ratios read "1 black : 2 blue : 1 splash" or
// "1 in 2 barred", never a percentage.

/// The page before the first rule.
public let inheritanceEmptyText = "Set eggs from a pair in the pen and what you learn ends up here."

/// The page heading (and the Books tab).
public let inheritanceTitleText = "Inheritance"

/// Under the heading: each rule held for a pair the keeper set eggs from, not for every bird that looks
/// the same. Two black birds can hide different genes.
public let inheritanceSubtitleText = "What your pairs have shown"

/// One rule in plain words: "blue × blue → 1 black : 2 blue : 1 splash".
public func inheritanceText(_ rule: InheritanceRule) -> String {
    switch rule {
    case .colours(let a, let b, let shares, let d):
        return "\(a.rawValue) × \(b.rawValue) → \(colourShares(shares, d))"
    case .trait(let t, let hen, let rooster, let n, let d):
        let parents = "\(parentWord(t, hen, "hen")) × \(parentWord(t, rooster, "rooster"))"
        return "\(parents) → \(outcome(t, n, d))"
    case .sexLink:
        return "barred hen × plain rooster → barred chicks are cockerels"
    }
}

/// The page as text lines: the heading and subtitle, then one rule a line, or the empty note. For the CLI.
public func inheritanceLines(_ s: GameState) -> [String] {
    let rules = Inheritance.known(in: s)
    let heading = [inheritanceTitleText, inheritanceSubtitleText]
    guard !rules.isEmpty else { return heading + ["  " + inheritanceEmptyText] }
    return heading + rules.map { "  " + inheritanceText($0) }
}

/// "all lavender", "1 black : 2 blue : 1 splash", or "1 in 4 splash" when the shares do not cover
/// every chick.
private func colourShares(_ shares: [ColourShare], _ d: Int) -> String {
    if shares.count == 1, shares[0].count == d { return "all \(shares[0].colour.rawValue)" }
    let total = shares.reduce(0) { $0 + $1.count }
    if total == d { return shares.map { "\($0.count) \($0.colour.rawValue)" }.joined(separator: " : ") }
    return shares.map { "\($0.count) in \(d) \($0.colour.rawValue)" }.joined(separator: ", ")
}

/// A parent by the trait: "barred hen", "plain rooster", "speckled-egg hen". Just "hen" or "rooster"
/// when the look does not say.
private func parentWord(_ t: Trait, _ shows: Bool?, _ sex: String) -> String {
    guard let shows else { return sex }
    switch t {
    case .colour(let c): return shows ? "\(c.rawValue) \(sex)" : "non-\(c.rawValue) \(sex)"
    case .barred: return shows ? "barred \(sex)" : "plain \(sex)"
    case .laced: return shows ? "laced \(sex)" : "plain \(sex)"
    case .silkieFeathered: return shows ? "silkie-feathered \(sex)" : "plain-feathered \(sex)"
    case .eggColour(let e): return shows ? "\(e.rawValue)-egg \(sex)" : sex
    case .speckledEggs: return shows ? "speckled-egg \(sex)" : "plain-egg \(sex)"
    }
}

/// "all barred", "1 in 2 barred", "every daughter lays speckled eggs".
private func outcome(_ t: Trait, _ n: Int, _ d: Int) -> String {
    let all = n == d
    switch t {
    case .colour(let c): return all ? "all \(c.rawValue)" : "\(n) in \(d) \(c.rawValue)"
    case .barred: return all ? "all barred" : "\(n) in \(d) barred"
    case .laced: return all ? "all laced" : "\(n) in \(d) laced"
    case .silkieFeathered: return all ? "all silkie-feathered" : "\(n) in \(d) silkie-feathered"
    case .eggColour(let e):
        return all ? "every daughter lays \(e.rawValue) eggs" : "\(n) in \(d) daughters lay \(e.rawValue) eggs"
    case .speckledEggs:
        return all ? "every daughter lays speckled eggs" : "\(n) in \(d) daughters lay speckled eggs"
    }
}
