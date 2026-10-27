import FeatherwickCore
import Foundation

// The words for the inheritance page (Books ▸ Inheritance) and the CLI's `inheritance`.
//
// A rule names no bird: only looks and what hatches. Ratios read "1 black : 2 blue : 1 splash" or
// "1 in 2 barred", never a percentage.

/// The page before the first rule.
public var inheritanceEmptyText: String {
    String(
        localized: "inheritance.empty",
        defaultValue: "Set eggs from a pair in the pen and what you learn ends up here.",
        bundle: .module, comment: "Books ▸ Inheritance, before the first rule.")
}

/// The page heading (and the Books tab).
public var inheritanceTitleText: String {
    String(
        localized: "inheritance.title", defaultValue: "Inheritance", bundle: .module,
        comment: "Books tab and page heading: the rules learned from penned pairs.")
}

/// Under the heading: each rule held for a pair the keeper set eggs from, not for every bird that looks
/// the same. Two black birds can hide different genes.
public var inheritanceSubtitleText: String {
    String(
        localized: "inheritance.subtitle", defaultValue: "What your pairs have shown", bundle: .module,
        comment: "Books ▸ Inheritance, under the heading.")
}

/// One rule in plain words: "blue × blue → 1 black : 2 blue : 1 splash".
public func inheritanceText(_ rule: InheritanceRule) -> String {
    switch rule {
    case .colours(let a, let b, let shares, let d):
        return ruleText(a.rawValue, b.rawValue, colourShares(shares, d))
    case .trait(let t, let hen, let rooster, let n, let d):
        return ruleText(parentWord(t, hen, isHen: true), parentWord(t, rooster, isHen: false), outcome(t, n, d))
    case .sexLink:
        return String(
            localized: "inheritance.sexLink", defaultValue: "barred hen × plain rooster → barred chicks are cockerels",
            bundle: .module, comment: "Books ▸ Inheritance: the rule that barring shows which chicks are cockerels.")
    }
}

/// The page as text lines: the heading and subtitle, then one rule a line, or the empty note. For the CLI.
public func inheritanceLines(_ s: GameState) -> [String] {
    let rules = InheritancePage.known(in: s)
    let heading = [inheritanceTitleText, inheritanceSubtitleText]
    guard !rules.isEmpty else { return heading + ["  " + inheritanceEmptyText] }
    return heading + rules.map { "  " + inheritanceText($0) }
}

/// "hen × rooster → what hatches".
private func ruleText(_ hen: String, _ rooster: String, _ outcome: String) -> String {
    String(
        localized: "inheritance.rule", defaultValue: "\(hen) × \(rooster) → \(outcome)", bundle: .module,
        comment: """
            Books ▸ Inheritance: one rule. The placeholders are the first parent (a colour, or a hen by her look), \
            the second parent (a colour, or a rooster by his look) and what hatches.
            """)
}

/// "all lavender", "1 black : 2 blue : 1 splash", or "1 in 4 splash" when the shares do not cover
/// every chick.
private func colourShares(_ shares: [ColourShare], _ d: Int) -> String {
    if shares.count == 1, shares[0].count == d { return allColour(shares[0].colour) }
    let total = shares.reduce(0) { $0 + $1.count }
    if total == d {
        // A ratio, "1 black : 2 blue : 1 splash". The colon is notation, not words.
        return shares.map {
            String(
                localized: "inheritance.shareCount", defaultValue: "\($0.count) \($0.colour.rawValue)", bundle: .module,
                comment: "Books ▸ Inheritance: one part of a ratio. The placeholders are the share and the colour.")
        }.joined(separator: " : ")
    }
    return shares.map { someColour($0.count, d, $0.colour) }.joined(separator: ", ")
}

/// "all lavender".
private func allColour(_ c: FeatherColour) -> String {
    String(
        localized: "inheritance.allColour", defaultValue: "all \(c.rawValue)", bundle: .module,
        comment: "Books ▸ Inheritance: every chick hatches one colour. The placeholder is the colour.")
}

/// "1 in 4 splash".
private func someColour(_ n: Int, _ d: Int, _ c: FeatherColour) -> String {
    String(
        localized: "inheritance.someColour", defaultValue: "\(n) in \(d) \(c.rawValue)", bundle: .module,
        comment:
            "Books ▸ Inheritance: some chicks hatch a colour. The placeholders are the count, out of how many, and the colour."
    )
}

/// A parent by the trait: "barred hen", "plain rooster", "speckled-egg hen". Just "hen" or "rooster"
/// when the look does not say.
private func parentWord(_ t: Trait, _ shows: Bool?, isHen: Bool) -> String {
    guard let shows else { return isHen ? henWord : roosterWord }
    switch t {
    case .colour(let c):
        let c = c.rawValue
        switch (shows, isHen) {
        case (true, true):
            return String(
                localized: "inheritance.parent.colourHen", defaultValue: "\(c) hen", bundle: .module,
                comment: "Books ▸ Inheritance: a hen of a colour. The placeholder is the colour.")
        case (true, false):
            return String(
                localized: "inheritance.parent.colourRooster", defaultValue: "\(c) rooster", bundle: .module,
                comment: "Books ▸ Inheritance: a rooster of a colour. The placeholder is the colour.")
        case (false, true):
            return String(
                localized: "inheritance.parent.nonColourHen", defaultValue: "non-\(c) hen", bundle: .module,
                comment: "Books ▸ Inheritance: a hen not of a colour. The placeholder is the colour.")
        case (false, false):
            return String(
                localized: "inheritance.parent.nonColourRooster", defaultValue: "non-\(c) rooster", bundle: .module,
                comment: "Books ▸ Inheritance: a rooster not of a colour. The placeholder is the colour.")
        }
    case .barred:
        if shows { return isHen ? barredHen : barredRooster }
        return isHen ? plainHen : plainRooster
    case .laced:
        if shows {
            return isHen
                ? String(
                    localized: "inheritance.parent.lacedHen", defaultValue: "laced hen", bundle: .module,
                    comment: "Books ▸ Inheritance: a parent.")
                : String(
                    localized: "inheritance.parent.lacedRooster", defaultValue: "laced rooster", bundle: .module,
                    comment: "Books ▸ Inheritance: a parent.")
        }
        return isHen ? plainHen : plainRooster
    case .silkieFeathered:
        switch (shows, isHen) {
        case (true, true):
            return String(
                localized: "inheritance.parent.silkieFeatheredHen", defaultValue: "silkie-feathered hen",
                bundle: .module, comment: "Books ▸ Inheritance: a parent.")
        case (true, false):
            return String(
                localized: "inheritance.parent.silkieFeatheredRooster", defaultValue: "silkie-feathered rooster",
                bundle: .module, comment: "Books ▸ Inheritance: a parent.")
        case (false, true):
            return String(
                localized: "inheritance.parent.plainFeatheredHen", defaultValue: "plain-feathered hen",
                bundle: .module, comment: "Books ▸ Inheritance: a parent.")
        case (false, false):
            return String(
                localized: "inheritance.parent.plainFeatheredRooster", defaultValue: "plain-feathered rooster",
                bundle: .module, comment: "Books ▸ Inheritance: a parent.")
        }
    case .eggColour(let e):
        guard shows else { return isHen ? henWord : roosterWord }
        let e = e.rawValue
        return isHen
            ? String(
                localized: "inheritance.parent.eggHen", defaultValue: "\(e)-egg hen", bundle: .module,
                comment: "Books ▸ Inheritance: a hen by the eggs she lays. The placeholder is the egg colour.")
            : String(
                localized: "inheritance.parent.eggRooster", defaultValue: "\(e)-egg rooster", bundle: .module,
                comment:
                    "Books ▸ Inheritance: a rooster by the egg colour of his line. The placeholder is the egg colour.")
    case .speckledEggs:
        switch (shows, isHen) {
        case (true, true):
            return String(
                localized: "inheritance.parent.speckledEggHen", defaultValue: "speckled-egg hen", bundle: .module,
                comment: "Books ▸ Inheritance: a parent.")
        case (true, false):
            return String(
                localized: "inheritance.parent.speckledEggRooster", defaultValue: "speckled-egg rooster",
                bundle: .module, comment: "Books ▸ Inheritance: a parent.")
        case (false, true):
            return String(
                localized: "inheritance.parent.plainEggHen", defaultValue: "plain-egg hen", bundle: .module,
                comment: "Books ▸ Inheritance: a parent.")
        case (false, false):
            return String(
                localized: "inheritance.parent.plainEggRooster", defaultValue: "plain-egg rooster", bundle: .module,
                comment: "Books ▸ Inheritance: a parent.")
        }
    }
}

private var henWord: String {
    String(
        localized: "inheritance.parent.hen", defaultValue: "hen", bundle: .module,
        comment: "Books ▸ Inheritance: a parent whose look does not say.")
}
private var roosterWord: String {
    String(
        localized: "inheritance.parent.rooster", defaultValue: "rooster", bundle: .module,
        comment: "Books ▸ Inheritance: a parent whose look does not say.")
}
private var barredHen: String {
    String(
        localized: "inheritance.parent.barredHen", defaultValue: "barred hen", bundle: .module,
        comment: "Books ▸ Inheritance: a parent.")
}
private var barredRooster: String {
    String(
        localized: "inheritance.parent.barredRooster", defaultValue: "barred rooster", bundle: .module,
        comment: "Books ▸ Inheritance: a parent.")
}
private var plainHen: String {
    String(
        localized: "inheritance.parent.plainHen", defaultValue: "plain hen", bundle: .module,
        comment: "Books ▸ Inheritance: a parent with no barring or lacing.")
}
private var plainRooster: String {
    String(
        localized: "inheritance.parent.plainRooster", defaultValue: "plain rooster", bundle: .module,
        comment: "Books ▸ Inheritance: a parent with no barring or lacing.")
}

/// "all barred", "1 in 2 barred", "every daughter lays speckled eggs".
private func outcome(_ t: Trait, _ n: Int, _ d: Int) -> String {
    let all = n == d
    switch t {
    case .colour(let c):
        return all ? allColour(c) : someColour(n, d, c)
    case .barred:
        return all
            ? String(
                localized: "inheritance.allBarred", defaultValue: "all barred", bundle: .module,
                comment: "Books ▸ Inheritance: what hatches.")
            : String(
                localized: "inheritance.someBarred", defaultValue: "\(n) in \(d) barred", bundle: .module,
                comment: "Books ▸ Inheritance: what hatches. The placeholders are the count and out of how many.")
    case .laced:
        return all
            ? String(
                localized: "inheritance.allLaced", defaultValue: "all laced", bundle: .module,
                comment: "Books ▸ Inheritance: what hatches.")
            : String(
                localized: "inheritance.someLaced", defaultValue: "\(n) in \(d) laced", bundle: .module,
                comment: "Books ▸ Inheritance: what hatches. The placeholders are the count and out of how many.")
    case .silkieFeathered:
        return all
            ? String(
                localized: "inheritance.allSilkieFeathered", defaultValue: "all silkie-feathered", bundle: .module,
                comment: "Books ▸ Inheritance: what hatches.")
            : String(
                localized: "inheritance.someSilkieFeathered", defaultValue: "\(n) in \(d) silkie-feathered",
                bundle: .module,
                comment: "Books ▸ Inheritance: what hatches. The placeholders are the count and out of how many.")
    case .eggColour(let e):
        let e = e.rawValue
        return all
            ? String(
                localized: "inheritance.allDaughtersLay", defaultValue: "every daughter lays \(e) eggs",
                bundle: .module,
                comment: "Books ▸ Inheritance: what the daughters lay. The placeholder is the egg colour.")
            : String(
                localized: "inheritance.someDaughtersLay", defaultValue: "\(n) in \(d) daughters lay \(e) eggs",
                bundle: .module,
                comment: """
                    Books ▸ Inheritance: what the daughters lay. The placeholders are the count, out of how many, \
                    and the egg colour.
                    """)
    case .speckledEggs:
        return all
            ? String(
                localized: "inheritance.allDaughtersLaySpeckled", defaultValue: "every daughter lays speckled eggs",
                bundle: .module, comment: "Books ▸ Inheritance: what the daughters lay.")
            : String(
                localized: "inheritance.someDaughtersLaySpeckled",
                defaultValue: "\(n) in \(d) daughters lay speckled eggs", bundle: .module,
                comment:
                    "Books ▸ Inheritance: what the daughters lay. The placeholders are the count and out of how many.")
    }
}
