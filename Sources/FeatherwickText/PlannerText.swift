import FeatherwickCore
import Foundation

// The words for "What might hatch" (the planner) and the carrier notes on a bird's card.
//
// Core rule 8 (no hidden-gene leaks) is why these words stay close to the enums. A line says only
// what its `Forecast` or `ProvenAllele` says, and a reason names only birds the keeper owns or has
// rehomed (`GameState.bird`). Any other bird is "a bird" or "a chick". A bird whose sex does not show
// yet gets its name, never he or she. No percentages and no decimals: ratios read "1 in 4".
//
// Every sentence shape is one whole string in the catalog (#58). Only names, breed names, colour
// words and egg words go into a sentence as values.

// MARK: - The panel

/// The panel heading or prompt. Nil when the keeper has not met the planner yet.
public func plannerPanelText(_ p: PlannerPanel, _ s: GameState) -> String? {
    switch p {
    case .hidden: nil
    case .needsHen:
        String(
            localized: "planner.needsHen", defaultValue: "Pen a hen to see what might hatch.", bundle: .module,
            comment: "Breeding pen prompt when no hen is penned.")
    case .needsRooster:
        String(
            localized: "planner.needsRooster", defaultValue: "Pen a rooster to see what might hatch.", bundle: .module,
            comment: "Breeding pen prompt when no rooster is penned.")
    case .forecast:
        String(
            localized: "planner.heading", defaultValue: "What might hatch", bundle: .module,
            comment: "Heading of the breeding pen's forecast panel.")
    }
}

/// The pen's "New" notice, shown until the keeper first opens the panel.
public func plannerNoticeText(_ s: GameState) -> String? {
    guard s.plannerKnown, !s.plannerOpened else { return nil }
    return String(
        localized: "planner.notice", defaultValue: "New: What might hatch. Tap to see what this pair could hatch.",
        bundle: .module, comment: "Notice on the breeding pen until the keeper first opens the forecast.")
}

/// What `plan` and `carries` say before the keeper has met the planner.
public func plannerNotYetText(_ s: GameState) -> String {
    String(
        localized: "planner.notYet",
        defaultValue: "Not yet. Hatch a few chicks first, and Hazel will show you a trick.",
        bundle: .module, comment: "The forecast before the keeper has met it. Hazel is the neighbour.")
}

/// The whole panel as text lines: the heading, then each penned hen's forecast with the rooster.
/// Each line ends with its reasons in brackets. For the CLI and the test tools.
public func plannerLines(_ s: GameState) -> [String] {
    let panel = Planner.panel(in: s)
    guard s.plannerKnown, let heading = plannerPanelText(panel, s) else { return [plannerNotYetText(s)] }
    guard case .forecast(let rooster, let pairs) = panel else { return [heading] }
    let roosterName = birdName(rooster, s)
    var out = [
        String(
            localized: "planner.headingWithRooster", defaultValue: "\(heading) (rooster: \(roosterName))",
            bundle: .module, comment: "The forecast heading, then the penned rooster's name. CLI and test tools.")
    ]
    for pair in pairs {
        let henName = birdName(pair.hen, s)
        out.append(
            String(
                localized: "planner.withHen", defaultValue: "With \(henName):", bundle: .module,
                comment: "Introduces one penned hen's forecast lines. The value is her name."))
        // The indent is layout, not words.
        out += pairLines(pair.lines, s, pair: (pair.hen, rooster)).map { "  " + $0 }
    }
    return out
}

/// One pair's forecast as text lines, each with its reasons in brackets. Used by `plannerLines` and
/// by the CLI's `plan <hen> <rooster>`. `pair` is the hen and rooster the lines are about.
public func pairLines(_ lines: [Forecast], _ s: GameState, pair: (hen: UUID, rooster: UUID)? = nil) -> [String] {
    let sentences = plannerSentences(lines, s, pair: pair)
    if sentences.isEmpty {
        return [
            String(
                localized: "planner.nothingYet", defaultValue: "Nothing to say about this pair yet.", bundle: .module,
                comment: "A pair's forecast when there is nothing to say.")
        ]
    }
    return sentences.map { sentence in
        guard let reasons = sentencesInOrder(sentence.reasons) else { return sentence.text }
        return String(
            localized: "planner.lineWithReasons", defaultValue: "\(sentence.text) (\(reasons))", bundle: .module,
            comment: "A forecast sentence, then the reasons for it in brackets.")
    }
}

/// One sentence of the panel and the reasons behind it.
public struct PlannerSentence: Hashable, Sendable {
    public let text: String
    /// Each distinct reason, in the order of the forecast lines.
    public let reasons: [String]
    /// The forecast lines this sentence says.
    public let lines: [Forecast]
}

/// A pair's forecast as sentences. Ratio lines one after another about the same thing (feather colour,
/// or egg colour) out of the same number join into one sentence: "About 1 in 4 black, 2 in 4 blue, 1 in 4 splash."
public func plannerSentences(
    _ lines: [Forecast], _ s: GameState, pair: (hen: UUID, rooster: UUID)? = nil
) -> [PlannerSentence] {
    var out: [PlannerSentence] = []
    var i = 0
    while i < lines.count {
        guard case .ratio(let first, _, let d, _) = lines[i], let group = ratioGroup(first) else {
            let line = lines[i]
            out.append(
                PlannerSentence(
                    text: plannerText(line, s), reasons: [plannerReasonText(line.reason, s, pair: pair)], lines: [line])
            )
            i += 1
            continue
        }
        var run: [Forecast] = [lines[i]]
        var j = i + 1
        while j < lines.count, case .ratio(let t, _, let dj, _) = lines[j], dj == d, ratioGroup(t) == group {
            run.append(lines[j])
            j += 1
        }
        var reasons: [String] = []
        for line in run {
            let r = plannerReasonText(line.reason, s, pair: pair)
            if !reasons.contains(r) { reasons.append(r) }
        }
        let text = run.count == 1 ? plannerText(run[0], s) : joinedRatios(run, group: group)
        out.append(PlannerSentence(text: text, reasons: reasons, lines: run))
        i = j
    }
    return out
}

/// Ratio lines that can share a sentence: feather colours, and egg colours.
private enum RatioGroup { case colour, eggs }

private func ratioGroup(_ t: Trait) -> RatioGroup? {
    switch t {
    case .colour: .colour
    case .eggColour: .eggs
    default: nil
    }
}

private func joinedRatios(_ run: [Forecast], group: RatioGroup) -> String {
    let parts = run.compactMap { line -> String? in
        guard case .ratio(let t, let n, let d, _) = line else { return nil }
        switch t {
        case .colour(let c): return ratioPart(n, d, colourWord(c))
        case .eggColour(let e): return ratioPart(n, d, coarseEggWord(e))
        default: return nil
        }
    }
    let list = commaList(parts)
    switch group {
    case .colour:
        return String(
            localized: "planner.ratios.colour", defaultValue: "About \(list).", bundle: .module,
            comment: "Feather colour ratios in one sentence. The value is a list like: 1 in 4 black, 2 in 4 blue.")
    case .eggs:
        return String(
            localized: "planner.ratios.eggs", defaultValue: "Hens from this pair: about \(list) eggs.",
            bundle: .module,
            comment: "Egg colour ratios in one sentence. The value is a list like: 1 in 2 blue, 1 in 2 brown.")
    }
}

/// "1 in 4 black": one part of a joined ratio sentence.
private func ratioPart(_ n: Int, _ d: Int, _ word: String) -> String {
    String(
        localized: "planner.ratioPart", defaultValue: "\(n) in \(d) \(word)", bundle: .module,
        comment:
            "One part of a ratio list: how many, out of how many, then a feather or egg colour. Example: 1 in 4 black."
    )
}

// MARK: - One forecast line

/// What a trait shows, for choosing a sentence: an egg phrase, or one of the feather traits.
private enum Shows {
    case eggs(String)
    case colour(String)
    case barred, laced, silkie
}

private func shows(_ t: Trait) -> Shows {
    switch t {
    case .colour(let c): .colour(colourWord(c))
    case .barred: .barred
    case .laced: .laced
    case .silkieFeathered: .silkie
    case .eggColour(let e): .eggs(eggsPhrase(coarseEggWord(e)))
    case .speckledEggs: .eggs(speckledEggsPhrase)
    }
}

/// One forecast line in plain words. Ratios read "about 1 in 4", never a percentage.
public func plannerText(_ f: Forecast, _ s: GameState) -> String {
    switch f {
    case .certain(let t, _):
        return certainText(shows(t))
    case .ratio(let t, let n, let d, _):
        return ratioText(shows(t), n, d)
    case .likely(let t, let r):
        // A long run of chicks that never showed it makes it unlikely. Any other reason makes it likely.
        if case .manyChicks = r { return likelyNoneText(shows(t)) }
        return likelyText(shows(t))
    case .possible(let t, let r):
        if case .unknownFamily = r { return hidingText(shows(t)) }
        return possibleText(shows(t))
    case .notPossible(let t, _):
        return notPossibleText(shows(t))
    case .sexLink(let barredAre, _):
        return barredAre == .rooster
            ? String(
                localized: "planner.sexLink.barredCockerels",
                defaultValue: "Every barred chick will be a cockerel, every plain one a pullet.", bundle: .module,
                comment: "Forecast for a sex-link pair.")
            : String(
                localized: "planner.sexLink.barredPullets",
                defaultValue: "Every barred chick will be a pullet, every plain one a cockerel.", bundle: .module,
                comment: "Forecast for a sex-link pair.")
    case .eggColours(let colours, let sure, let r):
        return eggColoursText(orList(colours.flatMap(coarseEggWords)), sure: sure, r)
    case .typeOutlook(let hen, let rooster, let r):
        return typeOutlookText(hen, rooster, r, s)
    case .kinship(let rel, _):
        return kinshipText(rel)
    case .unknownUnderWhite:
        return String(
            localized: "planner.unknownUnderWhite",
            defaultValue: "White hides what's underneath. Anything either of them carries could show.",
            bundle: .module, comment: "Forecast when a white bird hides its colour genes.")
    }
}

private func certainText(_ x: Shows) -> String {
    switch x {
    case .eggs(let eggs):
        String(
            localized: "planner.certain.eggs", defaultValue: "Every hen from this pair will lay \(eggs).",
            bundle: .module, comment: "Forecast. The value is an egg phrase, like: blue eggs.")
    case .colour(let colour):
        String(
            localized: "planner.certain.colour", defaultValue: "Every chick will be \(colour).", bundle: .module,
            comment: "Forecast. The value is a feather colour, like: lavender.")
    case .barred:
        String(localized: "planner.certain.barred", defaultValue: "Every chick will be barred.", bundle: .module)
    case .laced:
        String(localized: "planner.certain.laced", defaultValue: "Every chick will be laced.", bundle: .module)
    case .silkie:
        String(
            localized: "planner.certain.silkie", defaultValue: "Every chick will have silkie feathers.",
            bundle: .module)
    }
}

private func ratioText(_ x: Shows, _ n: Int, _ d: Int) -> String {
    switch x {
    case .eggs(let eggs):
        String(
            localized: "planner.ratio.eggs", defaultValue: "About \(n) in \(d) hens from this pair will lay \(eggs).",
            bundle: .module,
            comment:
                "Forecast: how many hens, out of how many, then an egg phrase, like: blue eggs. Never a percentage."
        )
    case .colour(let colour):
        String(
            localized: "planner.ratio.colour", defaultValue: "About \(n) in \(d) chicks will be \(colour).",
            bundle: .module,
            comment: "Forecast: how many chicks, out of how many, then a feather colour. Never a percentage.")
    case .barred:
        String(
            localized: "planner.ratio.barred", defaultValue: "About \(n) in \(d) chicks will be barred.",
            bundle: .module, comment: "Forecast: how many chicks, out of how many. Never a percentage.")
    case .laced:
        String(
            localized: "planner.ratio.laced", defaultValue: "About \(n) in \(d) chicks will be laced.",
            bundle: .module, comment: "Forecast: how many chicks, out of how many. Never a percentage.")
    case .silkie:
        String(
            localized: "planner.ratio.silkie", defaultValue: "About \(n) in \(d) chicks will have silkie feathers.",
            bundle: .module, comment: "Forecast: how many chicks, out of how many. Never a percentage.")
    }
}

private func likelyText(_ x: Shows) -> String {
    switch x {
    case .eggs(let eggs):
        String(
            localized: "planner.likely.eggs", defaultValue: "Hens from this pair will likely lay \(eggs).",
            bundle: .module, comment: "Forecast. The value is an egg phrase, like: blue eggs.")
    case .colour(let colour):
        String(
            localized: "planner.likely.colour", defaultValue: "Some chicks will likely be \(colour).",
            bundle: .module, comment: "Forecast. The value is a feather colour, like: lavender.")
    case .barred:
        String(localized: "planner.likely.barred", defaultValue: "Some chicks will likely be barred.", bundle: .module)
    case .laced:
        String(localized: "planner.likely.laced", defaultValue: "Some chicks will likely be laced.", bundle: .module)
    case .silkie:
        String(
            localized: "planner.likely.silkie", defaultValue: "Some chicks will likely have silkie feathers.",
            bundle: .module)
    }
}

/// After many chicks that never showed it.
private func likelyNoneText(_ x: Shows) -> String {
    switch x {
    case .eggs(let eggs):
        String(
            localized: "planner.likelyNone.eggs", defaultValue: "Likely no \(eggs).", bundle: .module,
            comment: "Forecast after many daughters never laid it. The value is an egg phrase, like: blue eggs.")
    case .colour(let colour):
        String(
            localized: "planner.likelyNone.colour", defaultValue: "Likely no \(colour) chicks.", bundle: .module,
            comment: "Forecast after many chicks never showed it. The value is a feather colour, like: lavender.")
    case .barred:
        String(
            localized: "planner.likelyNone.barred", defaultValue: "Likely no barred chicks.", bundle: .module,
            comment: "Forecast after many chicks never showed it.")
    case .laced:
        String(
            localized: "planner.likelyNone.laced", defaultValue: "Likely no laced chicks.", bundle: .module,
            comment: "Forecast after many chicks never showed it.")
    case .silkie:
        String(
            localized: "planner.likelyNone.silkie", defaultValue: "Likely no silkie-feathered chicks.",
            bundle: .module, comment: "Forecast after many chicks never showed it.")
    }
}

/// When no one in the family has shown it yet.
private func hidingText(_ x: Shows) -> String {
    switch x {
    case .eggs(let eggs):
        String(
            localized: "planner.hiding.eggs", defaultValue: "If one of them carries \(eggs), you'll find out.",
            bundle: .module, comment: "Forecast. The value is an egg phrase, like: blue eggs.")
    case .colour(let colour):
        String(
            localized: "planner.hiding.colour", defaultValue: "If one of them is hiding \(colour), you'll find out.",
            bundle: .module, comment: "Forecast. The value is a feather colour, like: lavender.")
    case .barred:
        String(
            localized: "planner.hiding.barred", defaultValue: "If one of them is hiding barring, you'll find out.",
            bundle: .module)
    case .laced:
        String(
            localized: "planner.hiding.laced", defaultValue: "If one of them is hiding lacing, you'll find out.",
            bundle: .module)
    case .silkie:
        String(
            localized: "planner.hiding.silkie",
            defaultValue: "If one of them is hiding silkie feathers, you'll find out.", bundle: .module)
    }
}

private func possibleText(_ x: Shows) -> String {
    switch x {
    case .eggs(let eggs):
        String(
            localized: "planner.possible.eggs", defaultValue: "Hens from this pair could lay \(eggs).",
            bundle: .module, comment: "Forecast. The value is an egg phrase, like: blue eggs.")
    case .colour(let colour):
        String(
            localized: "planner.possible.colour", defaultValue: "Some chicks could be \(colour).", bundle: .module,
            comment: "Forecast. The value is a feather colour, like: lavender.")
    case .barred:
        String(localized: "planner.possible.barred", defaultValue: "Some chicks could be barred.", bundle: .module)
    case .laced:
        String(localized: "planner.possible.laced", defaultValue: "Some chicks could be laced.", bundle: .module)
    case .silkie:
        String(
            localized: "planner.possible.silkie", defaultValue: "Some chicks could have silkie feathers.",
            bundle: .module)
    }
}

private func notPossibleText(_ x: Shows) -> String {
    switch x {
    case .eggs(let eggs):
        String(
            localized: "planner.notPossible.eggs", defaultValue: "No hens from this pair will lay \(eggs).",
            bundle: .module, comment: "Forecast. The value is an egg phrase, like: blue eggs.")
    case .colour(let colour):
        String(
            localized: "planner.notPossible.colour", defaultValue: "No \(colour) chicks from this pair.",
            bundle: .module, comment: "Forecast. The value is a feather colour, like: lavender.")
    case .barred:
        String(
            localized: "planner.notPossible.barred", defaultValue: "No barred chicks from this pair.", bundle: .module)
    case .laced:
        String(
            localized: "planner.notPossible.laced", defaultValue: "No laced chicks from this pair.", bundle: .module)
    case .silkie:
        String(
            localized: "planner.notPossible.silkie", defaultValue: "No silkie-feathered chicks from this pair.",
            bundle: .module)
    }
}

/// The egg colours a pair's hens will lay, and what could still change them. Only the gene the reason
/// names as open, else nothing specific.
private func eggColoursText(_ list: String, sure: Bool, _ r: Reason) -> String {
    if sure {
        return String(
            localized: "planner.eggColours.sure", defaultValue: "Hens from this pair will lay \(list) eggs.",
            bundle: .module, comment: "Forecast. The value is egg colours, like: blue or green.")
    }
    let open: LocusID? =
        switch r {
        case .unknownFamily(let l), .manyChicks(_, _, let l): l
        default: nil
        }
    switch open {
    case BlueShell.locus:
        return String(
            localized: "planner.eggColours.unlessBlue",
            defaultValue: "Hens from this pair will lay \(list) eggs, unless one of them carries blue.",
            bundle: .module, comment: "Forecast. The value is egg colours, like: white, cream or brown.")
    case BrownShell.locus:
        return String(
            localized: "planner.eggColours.unlessBrown",
            defaultValue: "Hens from this pair will lay \(list) eggs, unless one of them carries brown.",
            bundle: .module, comment: "Forecast. The value is egg colours, like: white or cream.")
    case Speckle.locus:
        return String(
            localized: "planner.eggColours.unlessSpeckles",
            defaultValue: "Hens from this pair will lay \(list) eggs, unless one of them carries speckles.",
            bundle: .module, comment: "Forecast. The value is egg colours, like: blue or green.")
    default:
        return String(
            localized: "planner.eggColours.unlessOther",
            defaultValue: "Hens from this pair will lay \(list) eggs, unless one of them is hiding another egg colour.",
            bundle: .module, comment: "Forecast. The value is egg colours, like: brown.")
    }
}

private func kinshipText(_ r: Relatedness) -> String {
    switch r {
    case .unrelated:
        String(
            localized: "planner.kinship.unrelated", defaultValue: "They are not related.", bundle: .module,
            comment: "Forecast: how the penned pair are related.")
    case .distant:
        String(
            localized: "planner.kinship.distant", defaultValue: "They are distantly related.", bundle: .module,
            comment: "Forecast: how the penned pair are related.")
    case .cousins:
        String(
            localized: "planner.kinship.cousins", defaultValue: "They are related like cousins.", bundle: .module,
            comment: "Forecast: how the penned pair are related.")
    case .halfSiblings:
        String(
            localized: "planner.kinship.halfSiblings", defaultValue: "They are related like half-siblings.",
            bundle: .module, comment: "Forecast: how the penned pair are related.")
    case .close:
        String(
            localized: "planner.kinship.close",
            defaultValue: "They are closely related (like siblings, or parent and chick).", bundle: .module,
            comment: "Forecast: how the penned pair are related.")
    }
}

// MARK: - Words inside sentences

/// A feather colour's name inside a sentence: "lavender".
private func colourWord(_ c: FeatherColour) -> String {
    switch c {
    case .black:
        String(localized: "planner.colour.black", defaultValue: "black", bundle: .module, comment: "A feather colour.")
    case .blue:
        String(localized: "planner.colour.blue", defaultValue: "blue", bundle: .module, comment: "A feather colour.")
    case .splash:
        String(
            localized: "planner.colour.splash", defaultValue: "splash", bundle: .module, comment: "A feather colour.")
    case .lavender:
        String(
            localized: "planner.colour.lavender", defaultValue: "lavender", bundle: .module,
            comment: "A feather colour.")
    case .buff:
        String(localized: "planner.colour.buff", defaultValue: "buff", bundle: .module, comment: "A feather colour.")
    case .white:
        String(localized: "planner.colour.white", defaultValue: "white", bundle: .module, comment: "A feather colour.")
    }
}

/// An egg colour's name inside a sentence: "blue", as in "blue eggs".
private func eggWord(_ e: EggColour) -> String {
    switch e {
    case .cream:
        String(localized: "planner.egg.cream", defaultValue: "cream", bundle: .module, comment: "An egg colour.")
    case .brown:
        String(localized: "planner.egg.brown", defaultValue: "brown", bundle: .module, comment: "An egg colour.")
    case .blue:
        String(localized: "planner.egg.blue", defaultValue: "blue", bundle: .module, comment: "An egg colour.")
    case .olive:
        String(localized: "planner.egg.olive", defaultValue: "olive", bundle: .module, comment: "An egg colour.")
    case .chocolate:
        String(
            localized: "planner.egg.chocolate", defaultValue: "chocolate", bundle: .module,
            comment: "An egg colour.")
    case .green:
        String(localized: "planner.egg.green", defaultValue: "green", bundle: .module, comment: "An egg colour.")
    case .white:
        String(localized: "planner.egg.white", defaultValue: "white", bundle: .module, comment: "An egg colour.")
    }
}

/// "blue eggs": egg colours, then the word for eggs.
private func eggsPhrase(_ colours: String) -> String {
    String(
        localized: "planner.eggsPhrase", defaultValue: "\(colours) eggs", bundle: .module,
        comment: "Egg colours, then eggs. The value is one colour or a list, like: white or cream.")
}

private var speckledEggsPhrase: String {
    String(
        localized: "planner.speckledEggs", defaultValue: "speckled eggs", bundle: .module,
        comment: "Inside a forecast sentence.")
}

/// The words for a coarse egg class the planner forecasts. Coarse cream holds white too: whether a
/// cream egg is white comes from shell depth, which the planner does not forecast. Coarse brown
/// holds chocolate, and "brown" is still true of a chocolate egg, so only cream needs two words.
private func coarseEggWords(_ e: EggColour) -> [String] {
    e == .cream ? [eggWord(.white), eggWord(.cream)] : [eggWord(e)]
}

/// "white or cream", "brown".
private func coarseEggWord(_ e: EggColour) -> String { orList(coarseEggWords(e)) }

/// "cream", "cream or brown", "blue, green or olive". No Oxford comma, so not `ListFormatStyle`.
private func orList(_ words: [String]) -> String {
    guard let last = words.last else {
        return String(
            localized: "planner.eggsPlain", defaultValue: "plain", bundle: .module,
            comment: "In place of egg colours when there are none to list, as in: plain eggs.")
    }
    guard words.count > 1 else { return last }
    let head = commaList(Array(words.dropLast()))
    return String(
        localized: "planner.list.or", defaultValue: "\(head) or \(last)", bundle: .module,
        comment: "The end of a list of choices: the items before, then the last item.")
}

/// "lavender, barring and blue eggs". No Oxford comma, so not `ListFormatStyle`.
private func andList(_ words: [String]) -> String {
    guard let last = words.last else { return "" }
    guard words.count > 1 else { return last }
    let head = commaList(Array(words.dropLast()))
    return String(
        localized: "planner.list.and", defaultValue: "\(head) and \(last)", bundle: .module,
        comment: "The end of a list: the items before, then the last item.")
}

/// "a, b, c": the items of a list before its last "and" or "or".
private func commaList(_ words: [String]) -> String {
    words.dropFirst().reduce(words.first ?? "") { head, next in
        String(
            localized: "planner.list.comma", defaultValue: "\(head), \(next)", bundle: .module,
            comment: "Two items in the middle of a list: the items so far, then the next one.")
    }
}

/// Sentences one after another: "Pip is blue. Pip is barred." Nil for none.
private func sentencesInOrder(_ sentences: [String]) -> String? {
    guard let first = sentences.first else { return nil }
    return sentences.dropFirst().reduce(first) { before, next in
        String(
            localized: "planner.sentences", defaultValue: "\(before) \(next)", bundle: .module,
            comment: "Two whole sentences one after the other.")
    }
}

// MARK: - Type

/// A type band's rank, worst first: poor, fair, good, excellent.
private func bandRank(_ b: JudgeNote.Band) -> Int { JudgeNote.Band.allCases.firstIndex(of: b) ?? 0 }

/// A judge's type band inside a sentence: "good".
private func bandWord(_ b: JudgeNote.Band) -> String {
    switch b {
    case .poor:
        String(localized: "planner.band.poor", defaultValue: "poor", bundle: .module, comment: "A judge's type band.")
    case .fair:
        String(localized: "planner.band.fair", defaultValue: "fair", bundle: .module, comment: "A judge's type band.")
    case .good:
        String(localized: "planner.band.good", defaultValue: "good", bundle: .module, comment: "A judge's type band.")
    case .excellent:
        String(
            localized: "planner.band.excellent", defaultValue: "excellent", bundle: .module,
            comment: "A judge's type band.")
    }
}

private func typeOutlookText(_ hen: JudgeNote.Band, _ rooster: JudgeNote.Band, _ r: Reason, _ s: GameState) -> String {
    let henBand = bandWord(hen)
    let roosterBand = bandWord(rooster)
    let bands =
        if hen == rooster {
            String(
                localized: "planner.type.both", defaultValue: "Both judged \(henBand) for type.", bundle: .module,
                comment: "Forecast: both penned birds got the same type band, like: good.")
        } else if case .grades(let h, let ro) = r {
            String(
                localized: "planner.type.named",
                defaultValue: "\(birdName(h, s)) judged \(henBand) for type, \(birdName(ro, s)) \(roosterBand).",
                bundle: .module,
                comment: "Forecast: the hen's name and type band, then the rooster's name and type band."
            ).capitalizedFirst
        } else {
            String(
                localized: "planner.type.unnamed",
                defaultValue: "The hen judged \(henBand) for type, the rooster \(roosterBand).", bundle: .module,
                comment: "Forecast: the hen's type band, then the rooster's.")
        }
    let good = bandRank(.good)
    let outlook =
        if min(bandRank(hen), bandRank(rooster)) >= good {
            String(
                localized: "planner.type.bothGood", defaultValue: "Chicks should carry it.", bundle: .module,
                comment: "Forecast when both birds are judged good for type or better.")
        } else if max(bandRank(hen), bandRank(rooster)) >= good {
            String(
                localized: "planner.type.oneGood", defaultValue: "Some chicks should take after the better one.",
                bundle: .module, comment: "Forecast when one bird is judged good for type or better.")
        } else {
            String(
                localized: "planner.type.neitherGood", defaultValue: "A partner judged better for type would help.",
                bundle: .module, comment: "Forecast when neither bird is judged good for type.")
        }
    return sentencesInOrder([bands, outlook]) ?? bands
}

// MARK: - Reasons

/// Why a forecast line is true, in one or two short sentences. Names only birds the keeper has.
/// `pair` is the hen and rooster the line is about: "They" means that pair and no other.
public func plannerReasonText(_ r: Reason, _ s: GameState, pair: (hen: UUID, rooster: UUID)? = nil) -> String {
    switch r {
    case .look(let bird, let locus):
        return lookReason(bird, locus, s)
    case .breed(let bird, let breed):
        let name = known(bird, s).name
        let origin = originWords(bird, s)
        let breedName = breed.definition.displayName
        let text =
            article(breedName) == "an"
            ? String(
                localized: "planner.reason.breedAn", defaultValue: "\(name) came from \(origin) as an \(breedName).",
                bundle: .module,
                comment: "Reason: a bird's name, where it came from, then its breed (a name that takes an).")
            : String(
                localized: "planner.reason.breedA", defaultValue: "\(name) came from \(origin) as a \(breedName).",
                bundle: .module,
                comment: "Reason: a bird's name, where it came from, then its breed (a name that takes a).")
        return text.capitalizedFirst
    case .parent(let bird, let parent, let locus):
        return parentReason(bird, parent, locus, s)
    case .chick(let bird, let chick, let locus):
        return chickReason(bird, chick, locus, s, pair: pair)
    case .unknownFamily(let locus):
        let noun = locusNoun(locus)
        return String(
            localized: "planner.reason.unknownFamily", defaultValue: "No one in their family has shown \(noun) yet.",
            bundle: .module, comment: "Reason. The value is a trait, like: lavender, barring, blue eggs.")
    case .manyChicks(let bird, let count, let locus):
        let name = known(bird, s).name
        let text: String
        if isEggLocus(locus) {
            let laid = eggShort(locus)
            text =
                count == 1
                ? String(
                    localized: "planner.reason.daughters.one",
                    defaultValue: "\(name) has had \(count) daughter, and she did not lay \(laid).", bundle: .module,
                    comment: "Reason, count == 1: a bird's name, the count, then an egg trait, like: blue.")
                : String(
                    localized: "planner.reason.daughters.other",
                    defaultValue: "\(name) has had \(count) daughters and none laid \(laid).", bundle: .module,
                    comment: "Reason, count other than 1: a bird's name, the count, then an egg trait, like: blue.")
        } else {
            let noun = locusNoun(locus)
            text =
                count == 1
                ? String(
                    localized: "planner.reason.chicks.one",
                    defaultValue: "\(name) has had \(count) chick, and it did not show \(noun).", bundle: .module,
                    comment: "Reason, count == 1: a bird's name, the count, then a trait, like: lavender.")
                : String(
                    localized: "planner.reason.chicks.other",
                    defaultValue: "\(name) has had \(count) chicks and none showed \(noun).", bundle: .module,
                    comment: "Reason, count other than 1: a bird's name, the count, then a trait, like: lavender.")
        }
        return text.capitalizedFirst
    case .grades(let hen, let rooster):
        return String(
            localized: "planner.reason.grades",
            defaultValue:
                "From the judge's notes on \(birdName(hen, s)) and \(birdName(rooster, s)) at their last shows.",
            bundle: .module, comment: "Reason: the hen's name, then the rooster's.")
    case .family(let hen, let rooster):
        return String(
            localized: "planner.reason.family",
            defaultValue: "From the family trees of \(birdName(hen, s)) and \(birdName(rooster, s)).", bundle: .module,
            comment: "Reason: the hen's name, then the rooster's.")
    case .white(let bird):
        return whiteHides(known(bird, s).name)
    }
}

/// "Pip is white, and white hides what's underneath."
private func whiteHides(_ name: String) -> String {
    String(
        localized: "planner.reason.whiteHides", defaultValue: "\(name) is white, and white hides what's underneath.",
        bundle: .module, comment: "Reason. The value is a bird's name, or: a bird."
    ).capitalizedFirst
}

/// A bird as the words may name it: its name and look if the keeper has it, else "a bird" and no look.
private struct Named {
    let name: String
    let bird: Bird?
    /// He or she once the sex shows; the name before.
    var subject: Subject { bird.map { $0.revealed ? ($0.sex == .hen ? .she : .he) : .name } ?? .name }
}

/// Her or his once the sex shows; "Pip's" before.
private func possessive(_ bird: Bird) -> String {
    guard bird.revealed else { return namePossessive(bird.name) }
    return bird.sex == .hen
        ? String(localized: "planner.her", defaultValue: "her", bundle: .module, comment: "Possessive for a hen.")
        : String(localized: "planner.his", defaultValue: "his", bundle: .module, comment: "Possessive for a rooster.")
}

/// How a sentence names a bird a second time: she, he, or its name while its sex does not show.
private enum Subject { case she, he, name }

private func namePossessive(_ name: String) -> String {
    String(
        localized: "planner.namePossessive", defaultValue: "\(name)'s", bundle: .module,
        comment: "Possessive of a bird's name, for a bird whose sex does not show yet.")
}

private func known(_ id: UUID, _ s: GameState) -> Named {
    let b = s.bird(id)
    return Named(
        name: b?.name
            ?? String(
                localized: "planner.aBird", defaultValue: "a bird", bundle: .module,
                comment: "In place of the name of a bird the keeper does not have."),
        bird: b)
}

/// What the keeper saw of a bird: an owned bird today, or a family record that kept a look.
private func seenLook(_ id: UUID, _ s: GameState) -> SeenLook? {
    if let b = s.bird(id) { return SeenLook(of: b, in: s) }
    return Pedigree.record(id, in: s)?.look
}

private func originWords(_ id: UUID, _ s: GameState) -> String {
    guard let origin = s.bird(id)?.origin else {
        return String(
            localized: "planner.origin.outside", defaultValue: "outside the flock", bundle: .module,
            comment: "Where a bird came from, as in: came from outside the flock.")
    }
    switch origin {
    case Bird.neighbourOrigin:
        return String(
            localized: "planner.origin.neighbour", defaultValue: "Hazel", bundle: .module,
            comment: "Where a bird came from: the neighbour, Hazel.")
    case Bird.localFlockOrigin:
        return String(
            localized: "planner.origin.localFlock", defaultValue: "a local flock", bundle: .module,
            comment: "Where a bird came from, as in: came from a local flock.")
    case Bird.showOrigin:
        return String(
            localized: "planner.origin.show", defaultValue: "the county show", bundle: .module,
            comment: "Where a bird came from, as in: came from the county show.")
    case Bird.villageOrigin:
        return String(
            localized: "planner.origin.village", defaultValue: "a Featherwick neighbour", bundle: .module,
            comment: "Where a bird came from, as in: came from a Featherwick neighbour.")
    default: return origin
    }
}

private func isEggLocus(_ l: LocusID) -> Bool { [BlueShell.locus, BrownShell.locus, Speckle.locus].contains(l) }

/// The trait a gene shows, as a noun: "lavender", "barring", "blue eggs".
private func locusNoun(_ l: LocusID) -> String {
    switch l {
    case Lavender.locus: colourWord(.lavender)
    case BlueDilution.locus: colourWord(.blue)
    case BaseColour.locus: colourWord(.buff)
    case Lacing.locus:
        String(localized: "planner.trait.lacing", defaultValue: "lacing", bundle: .module, comment: "A trait.")
    case Barring.locus:
        String(localized: "planner.trait.barring", defaultValue: "barring", bundle: .module, comment: "A trait.")
    case Feathering.locus:
        String(
            localized: "planner.trait.silkieFeathers", defaultValue: "silkie feathers", bundle: .module,
            comment: "A trait.")
    case BlueShell.locus: eggsPhrase(eggWord(.blue))
    case BrownShell.locus: eggsPhrase(eggWord(.brown))
    case Speckle.locus: speckledEggsPhrase
    case DominantWhite.locus: colourWord(.white)
    default:
        String(localized: "planner.trait.it", defaultValue: "it", bundle: .module, comment: "A trait with no name.")
    }
}

/// "blue", "brown", "speckled eggs": what a daughter laid.
private func eggShort(_ l: LocusID) -> String {
    switch l {
    case BlueShell.locus: eggWord(.blue)
    case BrownShell.locus: eggWord(.brown)
    default: locusNoun(l)
    }
}

private let blueShells: Set<EggColour> = [.blue, .green, .olive]
private let brownShells: Set<EggColour> = [.brown, .chocolate, .green, .olive]

/// How a look shows a gene's trait. Nil if it does not show it.
private enum Shown {
    case colour(FeatherColour)
    case laced, barred, silkie, speckled
    case lays(EggColour)
}

private func shown(_ look: SeenLook, _ l: LocusID) -> Shown? {
    let colour = look.colour ?? downColour(look.chickDown)
    switch l {
    case Lavender.locus: return colour == .lavender ? .colour(.lavender) : nil
    case BlueDilution.locus: return colour == .blue || colour == .splash ? colour.map(Shown.colour) : nil
    case BaseColour.locus: return look.colour == .buff ? .colour(.buff) : nil
    case Lacing.locus: return look.isLaced == true ? .laced : nil
    case Barring.locus: return look.isBarred == true || look.chickDown == .darkWithHeadSpot ? .barred : nil
    case Feathering.locus: return look.isSilkieFeathered ? .silkie : nil
    case BlueShell.locus:
        return look.eggColour.flatMap { blueShells.contains($0) ? .lays($0) : nil }
    case BrownShell.locus:
        return look.eggColour.flatMap { brownShells.contains($0) ? .lays($0) : nil }
    case Speckle.locus: return look.eggIsSpeckled == true ? .speckled : nil
    case DominantWhite.locus: return look.colour == .white ? .colour(.white) : nil
    default: return nil
    }
}

/// The colour a chick's down shows for sure. Yellow down is buff or white, so it says nothing.
private func downColour(_ d: ChickDown?) -> FeatherColour? {
    switch d {
    case .black: .black
    case .slate: .blue
    case .paleGrey: .splash
    case .silver: .lavender
    default: nil
    }
}

/// "Pip is blue. Blue birds always carry one of each."
private func lookReason(_ id: UUID, _ l: LocusID, _ s: GameState) -> String {
    let n = known(id, s)
    guard let look = seenLook(id, s), n.bird != nil else { return lookSettlesIt(n.name) }
    if look.colour == .white, l != DominantWhite.locus, !isEggLocus(l), l != Feathering.locus {
        return whiteHides(n.name)
    }
    return (lookSentence(n, look, l) ?? lookSettlesIt(n.name)).capitalizedFirst
}

private func lookSettlesIt(_ name: String) -> String {
    String(
        localized: "planner.reason.lookSettles", defaultValue: "\(name)'s look settles it.", bundle: .module,
        comment: "Reason. The value is a bird's name, or: a bird."
    ).capitalizedFirst
}

/// The sentence for what a bird's look shows at one gene, or nil to fall back on "its look settles it".
private func lookSentence(_ n: Named, _ look: SeenLook, _ l: LocusID) -> String? {
    let name = n.name
    let colour = look.colour
    switch l {
    case Lavender.locus:
        if colour == .lavender {
            return String(
                localized: "planner.look.lavender",
                defaultValue: "\(name) is lavender. Lavender birds always pass lavender on.", bundle: .module,
                comment: "Reason. The value is a bird's name.")
        }
        if colour == .buff {
            return String(
                localized: "planner.look.buffHidesLavender", defaultValue: "\(name) is buff, and buff hides lavender.",
                bundle: .module, comment: "Reason. The value is a bird's name.")
        }
    case BlueDilution.locus:
        switch colour {
        case .blue:
            return String(
                localized: "planner.look.blue",
                defaultValue: "\(name) is blue. Blue birds always carry one of each.", bundle: .module,
                comment: "Reason. The value is a bird's name.")
        case .splash:
            return String(
                localized: "planner.look.splash", defaultValue: "\(name) is splash. Splash birds always pass blue on.",
                bundle: .module, comment: "Reason. The value is a bird's name.")
        case .black:
            switch n.subject {
            case .she:
                return String(
                    localized: "planner.look.blackNoBlue.she",
                    defaultValue: "\(name) is black, so she carries no blue.",
                    bundle: .module, comment: "Reason about a hen. The value is her name.")
            case .he:
                return String(
                    localized: "planner.look.blackNoBlue.he", defaultValue: "\(name) is black, so he carries no blue.",
                    bundle: .module, comment: "Reason about a rooster. The value is his name.")
            case .name:
                return String(
                    localized: "planner.look.blackNoBlue.name",
                    defaultValue: "\(name) is black, so \(name) carries no blue.", bundle: .module,
                    comment: "Reason about a bird whose sex does not show yet. Both values are its name.")
            }
        case .lavender:
            return String(
                localized: "planner.look.lavenderHidesBlue",
                defaultValue: "\(name) is lavender, and lavender hides blue.",
                bundle: .module, comment: "Reason. The value is a bird's name.")
        case .buff:
            return String(
                localized: "planner.look.buffHidesBlue", defaultValue: "\(name) is buff, and buff hides blue.",
                bundle: .module, comment: "Reason. The value is a bird's name.")
        default: break
        }
    case BaseColour.locus:
        if colour == .buff {
            return String(
                localized: "planner.look.buff", defaultValue: "\(name) is buff. Buff birds always pass buff on.",
                bundle: .module, comment: "Reason. The value is a bird's name.")
        }
    case Lacing.locus:
        if look.isLaced == true {
            return String(
                localized: "planner.look.laced", defaultValue: "\(name) is laced. Laced birds always pass lacing on.",
                bundle: .module, comment: "Reason. The value is a bird's name.")
        }
    case Barring.locus:
        if colour == .buff {
            return String(
                localized: "planner.look.buffHidesBarring", defaultValue: "\(name) is buff, and buff hides barring.",
                bundle: .module, comment: "Reason. The value is a bird's name.")
        }
        if look.isBarred == true {
            return String(
                localized: "planner.look.barred", defaultValue: "\(name) is barred.", bundle: .module,
                comment: "Reason. The value is a bird's name.")
        }
        if look.isBarred == false {
            switch n.subject {
            case .she:
                return String(
                    localized: "planner.look.notBarred.she",
                    defaultValue: "\(name) is not barred, so she has no barring to pass on.", bundle: .module,
                    comment: "Reason about a hen. The value is her name.")
            case .he:
                return String(
                    localized: "planner.look.notBarred.he",
                    defaultValue: "\(name) is not barred, so he has no barring to pass on.", bundle: .module,
                    comment: "Reason about a rooster. The value is his name.")
            case .name:
                return String(
                    localized: "planner.look.notBarred.name",
                    defaultValue: "\(name) is not barred, so \(name) has no barring to pass on.", bundle: .module,
                    comment: "Reason about a bird whose sex does not show yet. Both values are its name.")
            }
        }
    case Feathering.locus:
        if look.isSilkieFeathered {
            return String(
                localized: "planner.look.silkie",
                defaultValue: "\(name) has silkie feathers. Silkie birds always pass them on.", bundle: .module,
                comment: "Reason. The value is a bird's name.")
        }
    case BlueShell.locus:
        if let egg = look.eggColour {
            let word = eggWord(egg)
            return blueShells.contains(egg)
                ? laysText(name, word)
                : String(
                    localized: "planner.look.laysNoBlue",
                    defaultValue: "\(name) lays \(word) eggs, so she carries no blue.",
                    bundle: .module, comment: "Reason about a hen: her name, then an egg colour, like: brown.")
        }
    case BrownShell.locus:
        if let egg = look.eggColour {
            let word = eggWord(egg)
            return brownShells.contains(egg)
                ? laysText(name, word)
                : String(
                    localized: "planner.look.laysNoBrown",
                    defaultValue: "\(name) lays \(word) eggs, so she carries no brown.", bundle: .module,
                    comment: "Reason about a hen: her name, then an egg colour, like: blue.")
        }
    case Speckle.locus:
        if let speckled = look.eggIsSpeckled {
            return speckled
                ? String(
                    localized: "planner.look.laysSpeckled", defaultValue: "\(name) lays speckled eggs.",
                    bundle: .module, comment: "Reason. The value is a hen's name.")
                : String(
                    localized: "planner.look.laysPlain", defaultValue: "\(name) lays plain eggs.", bundle: .module,
                    comment: "Reason. The value is a hen's name.")
        }
    case DominantWhite.locus:
        if colour == .white {
            return String(
                localized: "planner.look.white", defaultValue: "\(name) is white.", bundle: .module,
                comment: "Reason. The value is a bird's name.")
        }
        if colour != nil {
            switch n.subject {
            case .she:
                return String(
                    localized: "planner.look.notWhite.she",
                    defaultValue: "\(name) is not white, so she carries no white.",
                    bundle: .module, comment: "Reason about a hen. The value is her name.")
            case .he:
                return String(
                    localized: "planner.look.notWhite.he",
                    defaultValue: "\(name) is not white, so he carries no white.",
                    bundle: .module, comment: "Reason about a rooster. The value is his name.")
            case .name:
                return String(
                    localized: "planner.look.notWhite.name",
                    defaultValue: "\(name) is not white, so \(name) carries no white.", bundle: .module,
                    comment: "Reason about a bird whose sex does not show yet. Both values are its name.")
            }
        }
    default: break
    }
    return nil
}

/// "Clover lays blue eggs."
private func laysText(_ name: String, _ egg: String) -> String {
    String(
        localized: "planner.look.lays", defaultValue: "\(name) lays \(egg) eggs.", bundle: .module,
        comment: "Reason: a hen's name, then an egg colour, like: blue.")
}

/// "her mother", "Pip's father", "a bird's parent".
private func kinWords(_ owner: String, _ relation: Relation) -> String {
    switch relation {
    case .mother:
        String(
            localized: "planner.kin.mother", defaultValue: "\(owner) mother", bundle: .module,
            comment: "A bird's mother. The value is a possessive: her, his, Pip's, a bird's, this bird's.")
    case .father:
        String(
            localized: "planner.kin.father", defaultValue: "\(owner) father", bundle: .module,
            comment: "A bird's father. The value is a possessive: her, his, Pip's, a bird's, this bird's.")
    case .parent:
        String(
            localized: "planner.kin.parent", defaultValue: "\(owner) parent", bundle: .module,
            comment: "A bird's parent. The value is a possessive: her, his, Pip's, a bird's, this bird's.")
    }
}

private enum Relation { case mother, father, parent }

private func relation(of parent: UUID, to bird: Bird?) -> Relation {
    parent == bird?.motherID ? .mother : parent == bird?.fatherID ? .father : .parent
}

/// "Her mother laid blue eggs." / "Her mother, Clover, is lavender."
private func parentReason(_ id: UUID, _ parent: UUID, _ l: LocusID, _ s: GameState) -> String {
    let n = known(id, s)
    let owner =
        n.bird.map(possessive)
        ?? String(
            localized: "planner.aBirdPossessive", defaultValue: "a bird's", bundle: .module,
            comment: "Possessive of a bird the keeper does not have, as in: a bird's mother.")
    let kin = kinWords(owner, relation(of: parent, to: n.bird))
    let parentName = s.bird(parent)?.name
    if let look = seenLook(parent, s), let shows = shown(look, l) {
        let text = parentName.map { parentShowsNamed(kin, $0, shows) } ?? parentShows(kin, shows)
        return text.capitalizedFirst
    }
    let noun = locusNoun(l)
    let text =
        parentName.map { name in
            String(
                localized: "planner.parent.cameDownNamed", defaultValue: "\(noun) came down from \(kin), \(name).",
                bundle: .module,
                comment: "Reason: a trait, like: lavender; a bird's mother, father or parent; then that parent's name.")
        }
        ?? String(
            localized: "planner.parent.cameDown", defaultValue: "\(noun) came down from \(kin).", bundle: .module,
            comment: "Reason: a trait, like: lavender; then a bird's mother, father or parent.")
    return text.capitalizedFirst
}

/// "Her mother is lavender."
private func parentShows(_ kin: String, _ shows: Shown) -> String {
    switch shows {
    case .colour(let c):
        let colour = colourWord(c)
        return String(
            localized: "planner.parent.isColour", defaultValue: "\(kin) is \(colour).", bundle: .module,
            comment: "Reason: a bird's mother, father or parent, then a feather colour, like: lavender.")
    case .laced:
        return String(
            localized: "planner.parent.isLaced", defaultValue: "\(kin) is laced.", bundle: .module,
            comment: "Reason. The value is a bird's mother, father or parent, like: her mother.")
    case .barred:
        return String(
            localized: "planner.parent.isBarred", defaultValue: "\(kin) is barred.", bundle: .module,
            comment: "Reason. The value is a bird's mother, father or parent, like: her mother.")
    case .silkie:
        return String(
            localized: "planner.parent.silkie", defaultValue: "\(kin) has silkie feathers.", bundle: .module,
            comment: "Reason. The value is a bird's mother, father or parent, like: her mother.")
    case .lays(let e):
        let egg = eggWord(e)
        return String(
            localized: "planner.parent.lays", defaultValue: "\(kin) lays \(egg) eggs.", bundle: .module,
            comment: "Reason: a bird's mother or parent, then an egg colour, like: blue.")
    case .speckled:
        return String(
            localized: "planner.parent.laysSpeckled", defaultValue: "\(kin) lays speckled eggs.", bundle: .module,
            comment: "Reason. The value is a bird's mother or parent, like: her mother.")
    }
}

/// "Her mother, Clover, is lavender."
private func parentShowsNamed(_ kin: String, _ name: String, _ shows: Shown) -> String {
    switch shows {
    case .colour(let c):
        let colour = colourWord(c)
        return String(
            localized: "planner.parent.isColourNamed", defaultValue: "\(kin), \(name), is \(colour).", bundle: .module,
            comment: "Reason: a bird's mother, father or parent; that parent's name; then a feather colour.")
    case .laced:
        return String(
            localized: "planner.parent.isLacedNamed", defaultValue: "\(kin), \(name), is laced.", bundle: .module,
            comment: "Reason: a bird's mother, father or parent, then that parent's name.")
    case .barred:
        return String(
            localized: "planner.parent.isBarredNamed", defaultValue: "\(kin), \(name), is barred.", bundle: .module,
            comment: "Reason: a bird's mother, father or parent, then that parent's name.")
    case .silkie:
        return String(
            localized: "planner.parent.silkieNamed", defaultValue: "\(kin), \(name), has silkie feathers.",
            bundle: .module, comment: "Reason: a bird's mother, father or parent, then that parent's name.")
    case .lays(let e):
        let egg = eggWord(e)
        return String(
            localized: "planner.parent.laysNamed", defaultValue: "\(kin), \(name), lays \(egg) eggs.",
            bundle: .module,
            comment: "Reason: a bird's mother or parent; that parent's name; then an egg colour, like: blue.")
    case .speckled:
        return String(
            localized: "planner.parent.laysSpeckledNamed", defaultValue: "\(kin), \(name), lays speckled eggs.",
            bundle: .module, comment: "Reason: a bird's mother or parent, then that parent's name.")
    }
}

/// "They had a lavender chick, Clover." "They" only for the pair the line is about; another pair is named.
private func chickReason(
    _ id: UUID, _ chick: UUID, _ l: LocusID, _ s: GameState, pair: (hen: UUID, rooster: UUID)?
) -> String {
    let n = known(id, s)
    let c = s.bird(chick)
    let parents = c.flatMap { b in b.motherID.flatMap { m in b.fatherID.map { (mother: m, father: $0) } } }
    let who: String =
        if let parents, let pair, parents.mother == pair.hen, parents.father == pair.rooster {
            String(
                localized: "planner.chick.they", defaultValue: "They", bundle: .module,
                comment: "The penned pair, at the start of a sentence, as in: They had a lavender chick.")
        } else if let parents, let mother = s.bird(parents.mother), let father = s.bird(parents.father) {
            String(
                localized: "planner.chick.parents", defaultValue: "\(mother.name) and \(father.name)",
                bundle: .module,
                comment: "A chick's mother's name, then its father's, as in: Clover and Bramble had a lavender chick.")
        } else {
            n.name.capitalizedFirst
        }
    let name = n.name
    guard let look = seenLook(chick, s), let shows = shown(look, l) else {
        let noun = locusNoun(l)
        let text =
            c.map { chick in
                String(
                    localized: "planner.chick.showsCarrierNamed",
                    defaultValue: "\(name)'s chick, \(chick.name), shows that \(name) carries \(noun).",
                    bundle: .module,
                    comment:
                        "Reason: a bird's name, its chick's name, the bird's name again, then a trait, like: lavender."
                )
            }
            ?? String(
                localized: "planner.chick.showsCarrier",
                defaultValue: "One of \(name)'s chicks shows that \(name) carries \(noun).", bundle: .module,
                comment: "Reason: a bird's name (twice), then a trait, like: lavender.")
        return text.capitalizedFirst
    }
    if let chickName = c?.name {
        return chickShowsNamed(who, chickName, shows)
    }
    return chickShows(who, shows)
}

/// "They had a lavender chick." The chick has no name the keeper knows.
private func chickShows(_ who: String, _ shows: Shown) -> String {
    switch shows {
    case .lays(let e):
        let egg = eggWord(e)
        return String(
            localized: "planner.chick.daughterLays", defaultValue: "\(who) had a daughter who lays \(egg) eggs.",
            bundle: .module,
            comment: "Reason: They, or a bird's name, or two names; then an egg colour, like: blue.")
    case .speckled:
        return String(
            localized: "planner.chick.daughterSpeckled", defaultValue: "\(who) had a daughter who lays speckled eggs.",
            bundle: .module, comment: "Reason. The value is They, or a bird's name, or two names.")
    case .silkie:
        return String(
            localized: "planner.chick.silkie", defaultValue: "\(who) had a silkie-feathered chick.", bundle: .module,
            comment: "Reason. The value is They, or a bird's name, or two names.")
    case .colour(let c):
        let colour = colourWord(c)
        return article(c.rawValue) == "an"
            ? String(
                localized: "planner.chick.colourAn", defaultValue: "\(who) had an \(colour) chick.", bundle: .module,
                comment: "Reason: They, or a bird's name, or two names; then a feather colour that takes an.")
            : String(
                localized: "planner.chick.colour", defaultValue: "\(who) had a \(colour) chick.", bundle: .module,
                comment: "Reason: They, or a bird's name, or two names; then a feather colour, like: lavender.")
    case .laced:
        return String(
            localized: "planner.chick.laced", defaultValue: "\(who) had a laced chick.", bundle: .module,
            comment: "Reason. The value is They, or a bird's name, or two names.")
    case .barred:
        return String(
            localized: "planner.chick.barred", defaultValue: "\(who) had a barred chick.", bundle: .module,
            comment: "Reason. The value is They, or a bird's name, or two names.")
    }
}

/// "They had a lavender chick, Fern."
private func chickShowsNamed(_ who: String, _ name: String, _ shows: Shown) -> String {
    switch shows {
    case .lays(let e):
        let egg = eggWord(e)
        return String(
            localized: "planner.chick.daughterLaysNamed",
            defaultValue: "\(who) had a daughter, \(name), who lays \(egg) eggs.", bundle: .module,
            comment: "Reason: They, or a bird's name, or two names; the daughter's name; then an egg colour.")
    case .speckled:
        return String(
            localized: "planner.chick.daughterSpeckledNamed",
            defaultValue: "\(who) had a daughter, \(name), who lays speckled eggs.", bundle: .module,
            comment: "Reason: They, or a bird's name, or two names; then the daughter's name.")
    case .silkie:
        return String(
            localized: "planner.chick.silkieNamed", defaultValue: "\(who) had a silkie-feathered chick, \(name).",
            bundle: .module, comment: "Reason: They, or a bird's name, or two names; then the chick's name.")
    case .colour(let c):
        let colour = colourWord(c)
        return article(c.rawValue) == "an"
            ? String(
                localized: "planner.chick.colourAnNamed", defaultValue: "\(who) had an \(colour) chick, \(name).",
                bundle: .module,
                comment:
                    "Reason: They, or a bird's name, or two names; a feather colour that takes an; the chick's name."
            )
            : String(
                localized: "planner.chick.colourNamed", defaultValue: "\(who) had a \(colour) chick, \(name).",
                bundle: .module,
                comment: "Reason: They, or a bird's name, or two names; a feather colour; then the chick's name.")
    case .laced:
        return String(
            localized: "planner.chick.lacedNamed", defaultValue: "\(who) had a laced chick, \(name).", bundle: .module,
            comment: "Reason: They, or a bird's name, or two names; then the chick's name.")
    case .barred:
        return String(
            localized: "planner.chick.barredNamed", defaultValue: "\(who) had a barred chick, \(name).",
            bundle: .module, comment: "Reason: They, or a bird's name, or two names; then the chick's name.")
    }
}

// MARK: - Carrier notes (the bird card)

/// One carrier note, before it has words.
private enum CarrierNote {
    case silkie, normalFeathers, buff, black, splash, blue, notBlue, lavender, notLavender, lacing, notLaced
    case barring, notBarred, blueEggs, notBlueEggs, brownEggs, notBrownEggs, speckled, notSpeckled
    case white, notWhite, unknown

    init(_ p: ProvenAllele) {
        self =
            switch (p.locus, p.allele) {
            case (Feathering.locus, Feathering.silkie.rawValue): .silkie
            case (Feathering.locus, _): .normalFeathers
            case (BaseColour.locus, BaseColour.buff.rawValue): .buff
            case (BaseColour.locus, _): .black
            case (BlueDilution.locus, BlueDilution.blue.rawValue): p.copies >= 2 ? .splash : .blue
            case (BlueDilution.locus, _): .notBlue
            case (Lavender.locus, Lavender.lavender.rawValue): .lavender
            case (Lavender.locus, _): .notLavender
            case (Lacing.locus, Lacing.laced.rawValue): .lacing
            case (Lacing.locus, _): .notLaced
            case (Barring.locus, Barring.barred.rawValue): .barring
            case (Barring.locus, _): .notBarred
            case (BlueShell.locus, BlueShell.blue.rawValue): .blueEggs
            case (BlueShell.locus, _): .notBlueEggs
            case (BrownShell.locus, BrownShell.brown.rawValue): .brownEggs
            case (BrownShell.locus, _): .notBrownEggs
            case (Speckle.locus, Speckle.speckled.rawValue): .speckled
            case (Speckle.locus, _): .notSpeckled
            case (DominantWhite.locus, DominantWhite.white.rawValue): .white
            case (DominantWhite.locus, _): .notWhite
            default: .unknown
            }
    }
}

/// What a bird surely carries but does not show: "Carries lavender". Never a sexed word.
public func carrierText(_ p: ProvenAllele) -> String {
    switch CarrierNote(p) {
    case .silkie:
        String(localized: "planner.carries.silkie", defaultValue: "Carries silkie feathers", bundle: .module)
    case .normalFeathers:
        String(localized: "planner.carries.normalFeathers", defaultValue: "Carries normal feathers", bundle: .module)
    case .buff: String(localized: "planner.carries.buff", defaultValue: "Carries buff", bundle: .module)
    case .black: String(localized: "planner.carries.black", defaultValue: "Carries black", bundle: .module)
    case .splash: String(localized: "planner.carries.splash", defaultValue: "Carries splash", bundle: .module)
    case .blue: String(localized: "planner.carries.blue", defaultValue: "Carries blue", bundle: .module)
    case .notBlue:
        String(localized: "planner.carries.notBlue", defaultValue: "Carries plain colour, not blue", bundle: .module)
    case .lavender: String(localized: "planner.carries.lavender", defaultValue: "Carries lavender", bundle: .module)
    case .notLavender:
        String(
            localized: "planner.carries.notLavender", defaultValue: "Carries plain colour, not lavender",
            bundle: .module)
    case .lacing: String(localized: "planner.carries.lacing", defaultValue: "Carries lacing", bundle: .module)
    case .notLaced:
        String(
            localized: "planner.carries.notLaced", defaultValue: "Carries plain feathers, not laced", bundle: .module)
    case .barring: String(localized: "planner.carries.barring", defaultValue: "Carries barring", bundle: .module)
    case .notBarred:
        String(
            localized: "planner.carries.notBarred", defaultValue: "Carries plain feathers, not barred",
            bundle: .module)
    case .blueEggs:
        String(localized: "planner.carries.blueEggs", defaultValue: "Carries blue eggs", bundle: .module)
    case .notBlueEggs:
        String(
            localized: "planner.carries.notBlueEggs", defaultValue: "Carries plain eggs, not blue", bundle: .module)
    case .brownEggs:
        String(localized: "planner.carries.brownEggs", defaultValue: "Carries brown eggs", bundle: .module)
    case .notBrownEggs:
        String(
            localized: "planner.carries.notBrownEggs", defaultValue: "Carries pale eggs, not brown", bundle: .module)
    case .speckled:
        String(localized: "planner.carries.speckled", defaultValue: "Carries speckled eggs", bundle: .module)
    case .notSpeckled:
        String(
            localized: "planner.carries.notSpeckled", defaultValue: "Carries plain eggs, not speckled",
            bundle: .module)
    case .white: String(localized: "planner.carries.white", defaultValue: "Carries white", bundle: .module)
    case .notWhite:
        String(
            localized: "planner.carries.notWhite", defaultValue: "Carries colour under the white", bundle: .module)
    case .unknown:
        String(
            localized: "planner.carries.unknown", defaultValue: "Carries something it does not show",
            bundle: .module)
    }
}

/// What a carrier note says it carries, for a short list: "lavender", "plain eggs, not blue".
private func carrierShortWords(_ p: ProvenAllele) -> String {
    switch CarrierNote(p) {
    case .silkie:
        String(
            localized: "planner.carriesShort.silkie", defaultValue: "silkie feathers", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .normalFeathers:
        String(
            localized: "planner.carriesShort.normalFeathers", defaultValue: "normal feathers", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .buff:
        String(
            localized: "planner.carriesShort.buff", defaultValue: "buff", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .black:
        String(
            localized: "planner.carriesShort.black", defaultValue: "black", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .splash:
        String(
            localized: "planner.carriesShort.splash", defaultValue: "splash", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .blue:
        String(
            localized: "planner.carriesShort.blue", defaultValue: "blue", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .notBlue:
        String(
            localized: "planner.carriesShort.notBlue", defaultValue: "plain colour, not blue", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .lavender:
        String(
            localized: "planner.carriesShort.lavender", defaultValue: "lavender", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .notLavender:
        String(
            localized: "planner.carriesShort.notLavender", defaultValue: "plain colour, not lavender",
            bundle: .module, comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .lacing:
        String(
            localized: "planner.carriesShort.lacing", defaultValue: "lacing", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .notLaced:
        String(
            localized: "planner.carriesShort.notLaced", defaultValue: "plain feathers, not laced", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .barring:
        String(
            localized: "planner.carriesShort.barring", defaultValue: "barring", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .notBarred:
        String(
            localized: "planner.carriesShort.notBarred", defaultValue: "plain feathers, not barred",
            bundle: .module, comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .blueEggs:
        String(
            localized: "planner.carriesShort.blueEggs", defaultValue: "blue eggs", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .notBlueEggs:
        String(
            localized: "planner.carriesShort.notBlueEggs", defaultValue: "plain eggs, not blue", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .brownEggs:
        String(
            localized: "planner.carriesShort.brownEggs", defaultValue: "brown eggs", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .notBrownEggs:
        String(
            localized: "planner.carriesShort.notBrownEggs", defaultValue: "pale eggs, not brown", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .speckled:
        String(
            localized: "planner.carriesShort.speckled", defaultValue: "speckled eggs", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .notSpeckled:
        String(
            localized: "planner.carriesShort.notSpeckled", defaultValue: "plain eggs, not speckled",
            bundle: .module, comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .white:
        String(
            localized: "planner.carriesShort.white", defaultValue: "white", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .notWhite:
        String(
            localized: "planner.carriesShort.notWhite", defaultValue: "colour under the white", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    case .unknown:
        String(
            localized: "planner.carriesShort.unknown", defaultValue: "something it does not show", bundle: .module,
            comment: "One item in a short carrier list, as in: carries lavender and barring.")
    }
}

/// How the keeper can be sure, from the note's evidence. A bird whose sex does not show yet is named,
/// never he or she.
public func carrierReasonText(_ p: ProvenAllele, bird: UUID, _ s: GameState) -> String {
    let n = known(bird, s)
    let b = n.bird
    let name =
        b?.name
        ?? String(
            localized: "planner.thisBird", defaultValue: "this bird", bundle: .module,
            comment: "A bird on its own card when the keeper no longer has it.")
    let owner =
        b.map(possessive)
        ?? String(
            localized: "planner.thisBirdPossessive", defaultValue: "this bird's", bundle: .module,
            comment: "Possessive of a bird on its own card when the keeper no longer has it.")
    func named(_ id: UUID) -> String? { s.bird(id)?.name }
    let text: String
    switch p.evidence {
    case .look:
        text = String(
            localized: "planner.proof.look", defaultValue: "\(owner) own look shows it.", bundle: .module,
            comment: "Carrier note proof. The value is a possessive: her, his, Pip's, this bird's.")
    case .origin(let breed):
        let origin = originWords(bird, s)
        let breedName = breed.definition.displayName
        text =
            article(breedName) == "an"
            ? String(
                localized: "planner.proof.originAn",
                defaultValue:
                    "\(name) came from \(origin) as an \(breedName), and every one with that look carries it.",
                bundle: .module,
                comment: "Carrier note proof: a bird's name, where it came from, then its breed (a name that takes an)."
            )
            : String(
                localized: "planner.proof.originA",
                defaultValue: "\(name) came from \(origin) as a \(breedName), and every one with that look carries it.",
                bundle: .module,
                comment: "Carrier note proof: a bird's name, where it came from, then its breed (a name that takes a).")
    case .outsideFlock:
        let origin = originWords(bird, s)
        text = String(
            localized: "planner.proof.outsideFlock",
            defaultValue: "\(name) came from \(origin), and every bird from there with that look carries it.",
            bundle: .module, comment: "Carrier note proof: a bird's name, then where it came from.")
    case .parent(let parent):
        let kin = kinWords(owner, relation(of: parent, to: b))
        text =
            named(parent).map { parentName in
                String(
                    localized: "planner.proof.parentNamed", defaultValue: "It came from \(kin), \(parentName).",
                    bundle: .module,
                    comment: "Carrier note proof: a bird's mother, father or parent, then that parent's name.")
            }
            ?? String(
                localized: "planner.proof.parent", defaultValue: "It came from \(kin).", bundle: .module,
                comment: "Carrier note proof. The value is a bird's mother, father or parent, like: her mother.")
    case .parents(let mother, let father):
        if let m = named(mother), let f = named(father) {
            text = String(
                localized: "planner.proof.parentsNamed", defaultValue: "It came from \(owner) parents, \(m) and \(f).",
                bundle: .module,
                comment:
                    "Carrier note proof: a possessive (her, his, Pip's, this bird's), the mother's name, the father's.")
        } else {
            text = String(
                localized: "planner.proof.parents", defaultValue: "It came from \(owner) parents.",
                bundle: .module, comment: "Carrier note proof. The value is a possessive: her, his, Pip's, this bird's."
            )
        }
    case .child(let chick):
        text =
            named(chick).map { chickName in
                String(
                    localized: "planner.proof.childNamed", defaultValue: "\(owner) chick \(chickName) proves it.",
                    bundle: .module,
                    comment: "Carrier note proof: a possessive (her, his, Pip's, this bird's), then the chick's name.")
            }
            ?? String(
                localized: "planner.proof.child", defaultValue: "One of \(owner) chicks proves it.",
                bundle: .module, comment: "Carrier note proof. The value is a possessive: her, his, Pip's, this bird's."
            )
    case .family:
        text = String(
            localized: "planner.proof.family", defaultValue: "\(owner) family tree proves it.", bundle: .module,
            comment: "Carrier note proof. The value is a possessive: her, his, Pip's, this bird's.")
    }
    return text.capitalizedFirst
}

/// The carrier notes for a bird's card, each with its reason. Empty before the keeper meets the planner.
public func carrierLines(_ bird: UUID, _ s: GameState) -> [String] {
    Planner.carrierNotes(for: bird, in: s).map { p in
        let note = carrierText(p)
        let reason = carrierReasonText(p, bird: bird, s)
        return String(
            localized: "planner.carrierLine", defaultValue: "\(note). \(reason)", bundle: .module,
            comment: "A carrier note, like: Carries lavender; then how the keeper can be sure.")
    }
}

/// A bird's carrier notes in a few words, for the family tree: "carries lavender and blue eggs". Nil for none.
public func carrierShortText(_ notes: [ProvenAllele]) -> String? {
    guard !notes.isEmpty else { return nil }
    let list = andList(notes.map(carrierShortWords))
    return String(
        localized: "planner.carriesShort", defaultValue: "carries \(list)", bundle: .module,
        comment: "A bird's carrier notes in the family tree. The value is a list, like: lavender and blue eggs.")
}

/// What `carries <name>` says when nothing hidden is certain yet.
public func carrierNoneText(_ bird: UUID, _ s: GameState) -> String {
    let name = birdName(bird, s)
    return String(
        localized: "planner.carriesNone",
        defaultValue: "Nothing hidden you can be sure of yet. Watch \(name)'s chicks.",
        bundle: .module, comment: "When a bird has no carrier notes yet. The value is its name.")
}

/// Why two birds cannot be planned as a pair, or nil if they can: a revealed hen and a revealed rooster.
/// Says only that a sex does not show yet, never which it is.
public func plannerPairProblemText(hen: Bird, rooster: Bird) -> String? {
    for b in [hen, rooster] where !b.revealed {
        return String(
            localized: "planner.pair.tooYoung", defaultValue: "\(b.name) is too young to tell yet.", bundle: .module,
            comment: "CLI plan: a bird whose sex does not show yet. The value is its name.")
    }
    if hen.sex != .hen {
        return String(
            localized: "planner.pair.notHen", defaultValue: "\(hen.name) is not a hen. Use: plan <hen> <rooster>",
            bundle: .module, comment: "CLI plan. The value is a bird's name. Keep the command word plan as it is.")
    }
    if rooster.sex != .rooster {
        return String(
            localized: "planner.pair.notRooster",
            defaultValue: "\(rooster.name) is not a rooster. Use: plan <hen> <rooster>", bundle: .module,
            comment: "CLI plan. The value is a bird's name. Keep the command word plan as it is.")
    }
    return nil
}

extension String {
    /// The string with its first letter in capitals: "her mother" → "Her mother".
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
