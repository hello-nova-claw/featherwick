import FeatherwickCore
import Foundation

// The words for "What might hatch" (the planner) and the carrier notes on a bird's card.
//
// Core rule 8 (no hidden-gene leaks) is why these words stay close to the enums. A line says only
// what its `Forecast` or `ProvenAllele` says, and a reason names only birds the keeper owns or has
// rehomed (`GameState.bird`). Any other bird is "a bird" or "a chick". A bird whose sex does not show
// yet gets its name, never he or she. No percentages and no decimals: ratios read "1 in 4".

// MARK: - The panel

/// The panel heading or prompt. Nil when the keeper has not met the planner yet.
public func plannerPanelText(_ p: PlannerPanel, _ s: GameState) -> String? {
    switch p {
    case .hidden: nil
    case .needsHen: "Pen a hen to see what might hatch."
    case .needsRooster: "Pen a rooster to see what might hatch."
    case .forecast: "What might hatch"
    }
}

/// The pen's "New" notice, shown until the keeper first opens the panel.
public func plannerNoticeText(_ s: GameState) -> String? {
    guard s.plannerKnown, !s.plannerOpened else { return nil }
    return "New: What might hatch. Tap to see what this pair could hatch."
}

/// What `plan` and `carries` say before the keeper has met the planner.
public func plannerNotYetText(_ s: GameState) -> String {
    "Not yet. Hatch a few chicks first, and the neighbour will show you a trick."
}

/// The whole panel as text lines: the heading, then each penned hen's forecast with the rooster.
/// Each line ends with its reasons in brackets. For the CLI and the test tools.
public func plannerLines(_ s: GameState) -> [String] {
    let panel = Planner.panel(in: s)
    guard s.plannerKnown, let heading = plannerPanelText(panel, s) else { return [plannerNotYetText(s)] }
    guard case .forecast(let rooster, let pairs) = panel else { return [heading] }
    var out = ["\(heading) (rooster: \(birdName(rooster, s)))"]
    for pair in pairs {
        out.append("With \(birdName(pair.hen, s)):")
        out += pairLines(pair.lines, s, pair: (pair.hen, rooster)).map { "  " + $0 }
    }
    return out
}

/// One pair's forecast as text lines, each with its reasons in brackets. Used by `plannerLines` and
/// by the CLI's `plan <hen> <rooster>`. `pair` is the hen and rooster the lines are about.
public func pairLines(_ lines: [Forecast], _ s: GameState, pair: (hen: UUID, rooster: UUID)? = nil) -> [String] {
    let sentences = plannerSentences(lines, s, pair: pair)
    if sentences.isEmpty { return ["Nothing to say about this pair yet."] }
    return sentences.map { $0.reasons.isEmpty ? $0.text : "\($0.text) (\($0.reasons.joined(separator: " ")))" }
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
        case .colour(let c): return "\(n) in \(d) \(c.rawValue)"
        case .eggColour(let e): return "\(n) in \(d) \(e.rawValue)"
        default: return nil
        }
    }
    switch group {
    case .colour: return "About " + parts.joined(separator: ", ") + "."
    case .eggs: return "Hens from this pair: about " + parts.joined(separator: ", ") + " eggs."
    }
}

// MARK: - One forecast line

/// One forecast line in plain words. Ratios read "about 1 in 4", never a percentage.
public func plannerText(_ f: Forecast, _ s: GameState) -> String {
    switch f {
    case .certain(let t, _):
        if let egg = eggNoun(t) { return "Every hen from this pair will lay \(egg)." }
        return "Every chick will \(chickVerb(t))."
    case .ratio(let t, let n, let d, _):
        if let egg = eggNoun(t) { return "About \(n) in \(d) hens from this pair will lay \(egg)." }
        return "About \(n) in \(d) chicks will \(chickVerb(t))."
    case .likely(let t, let r):
        // A long run of chicks that never showed it makes it unlikely. Any other reason makes it likely.
        if case .manyChicks = r { return "Likely no \(eggNoun(t) ?? chickNoun(t))." }
        if let egg = eggNoun(t) { return "Hens from this pair will likely lay \(egg)." }
        return "Some chicks will likely \(chickVerb(t))."
    case .possible(let t, let r):
        if case .unknownFamily = r {
            if let egg = eggNoun(t) { return "If one of them carries \(egg), you'll find out." }
            return "If one of them is hiding \(hiddenNoun(t)), you'll find out."
        }
        if let egg = eggNoun(t) { return "Hens from this pair could lay \(egg)." }
        return "Some chicks could \(chickVerb(t))."
    case .notPossible(let t, _):
        if let egg = eggNoun(t) { return "No hens from this pair will lay \(egg)." }
        return "No \(chickNoun(t)) from this pair."
    case .sexLink(let barredAre, _):
        return barredAre == .rooster
            ? "Every barred chick will be a cockerel, every plain one a pullet."
            : "Every barred chick will be a pullet, every plain one a cockerel."
    case .eggColours(let colours, let sure, let r):
        let list = orList(colours.map(\.rawValue))
        guard !sure else { return "Hens from this pair will lay \(list) eggs." }
        return "Hens from this pair will lay \(list) eggs, \(unlessClause(r))."
    case .typeOutlook(let hen, let rooster, let r):
        return typeOutlookText(hen, rooster, r, s)
    case .kinship(let rel, _):
        return rel == .unrelated ? "They are not related." : "They are \(relatedText(rel))."
    case .unknownUnderWhite:
        return "White hides what's underneath. Anything either of them carries could show."
    }
}

/// The egg words for an egg trait ("blue eggs"), or nil for a feather trait.
private func eggNoun(_ t: Trait) -> String? {
    switch t {
    case .eggColour(let e): "\(e.rawValue) eggs"
    case .speckledEggs: "speckled eggs"
    default: nil
    }
}

/// "be lavender", "be barred", "have silkie feathers".
private func chickVerb(_ t: Trait) -> String {
    switch t {
    case .colour(let c): "be \(c.rawValue)"
    case .barred: "be barred"
    case .laced: "be laced"
    case .silkieFeathered: "have silkie feathers"
    case .eggColour(let e): "carry \(e.rawValue) eggs"
    case .speckledEggs: "carry speckled eggs"
    }
}

/// "lavender chicks", "barred chicks".
private func chickNoun(_ t: Trait) -> String {
    switch t {
    case .colour(let c): "\(c.rawValue) chicks"
    case .barred: "barred chicks"
    case .laced: "laced chicks"
    case .silkieFeathered: "silkie-feathered chicks"
    case .eggColour(let e): "\(e.rawValue) eggs"
    case .speckledEggs: "speckled eggs"
    }
}

/// What a bird can hide: "lavender", "barring", "silkie feathers".
private func hiddenNoun(_ t: Trait) -> String {
    switch t {
    case .colour(let c): c.rawValue
    case .barred: "barring"
    case .laced: "lacing"
    case .silkieFeathered: "silkie feathers"
    case .eggColour(let e): "\(e.rawValue) eggs"
    case .speckledEggs: "speckled eggs"
    }
}

/// "cream", "cream or brown", "blue, green or olive".
private func orList(_ words: [String]) -> String {
    guard words.count > 1 else { return words.first ?? "plain" }
    return words.dropLast().joined(separator: ", ") + " or " + words[words.count - 1]
}

/// What could still change the egg colours. Only the gene the reason names as open, else nothing specific.
private func unlessClause(_ r: Reason) -> String {
    let open: LocusID? =
        switch r {
        case .unknownFamily(let l), .manyChicks(_, _, let l): l
        default: nil
        }
    switch open {
    case BlueShell.locus: return "unless one of them carries blue"
    case BrownShell.locus: return "unless one of them carries brown"
    case Speckle.locus: return "unless one of them carries speckles"
    default: return "unless one of them is hiding another egg colour"
    }
}

/// A type band's rank, worst first: poor, fair, good, excellent.
private func bandRank(_ b: JudgeNote.Band) -> Int { JudgeNote.Band.allCases.firstIndex(of: b) ?? 0 }

private func typeOutlookText(_ hen: JudgeNote.Band, _ rooster: JudgeNote.Band, _ r: Reason, _ s: GameState) -> String {
    let bands =
        if hen == rooster {
            "Both judged \(hen.rawValue) for type."
        } else if case .grades(let h, let ro) = r {
            "\(birdName(h, s).capitalizedFirst) judged \(hen.rawValue) for type, \(birdName(ro, s)) \(rooster.rawValue)."
        } else {
            "The hen judged \(hen.rawValue) for type, the rooster \(rooster.rawValue)."
        }
    let good = bandRank(.good)
    let outlook =
        if min(bandRank(hen), bandRank(rooster)) >= good {
            "Chicks should carry it."
        } else if max(bandRank(hen), bandRank(rooster)) >= good {
            "Some chicks should take after the better one."
        } else {
            "A partner judged better for type would help."
        }
    return "\(bands) \(outlook)"
}

// MARK: - Reasons

/// Why a forecast line is true, in one or two short sentences. Names only birds the keeper has.
/// `pair` is the hen and rooster the line is about: "They" means that pair and no other.
public func plannerReasonText(_ r: Reason, _ s: GameState, pair: (hen: UUID, rooster: UUID)? = nil) -> String {
    switch r {
    case .look(let bird, let locus):
        return lookReason(bird, locus, s)
    case .breed(let bird, let breed):
        return "\(known(bird, s).name.capitalizedFirst) came from \(originWords(bird, s)) as \(breedWords(breed))."
    case .parent(let bird, let parent, let locus):
        return parentReason(bird, parent, locus, s)
    case .chick(let bird, let chick, let locus):
        return chickReason(bird, chick, locus, s, pair: pair)
    case .unknownFamily(let locus):
        return "No one in their family has shown \(locusNoun(locus)) yet."
    case .manyChicks(let bird, let count, let locus):
        let name = known(bird, s).name.capitalizedFirst
        if isEggLocus(locus) {
            let laid = eggShort(locus)
            return count == 1
                ? "\(name) has had 1 daughter, and she did not lay \(laid)."
                : "\(name) has had \(count) daughters and none laid \(laid)."
        }
        return count == 1
            ? "\(name) has had 1 chick, and it did not show \(locusNoun(locus))."
            : "\(name) has had \(count) chicks and none showed \(locusNoun(locus))."
    case .grades(let hen, let rooster):
        return "From the judge's notes on \(birdName(hen, s)) and \(birdName(rooster, s)) at their last shows."
    case .family(let hen, let rooster):
        return "From the family trees of \(birdName(hen, s)) and \(birdName(rooster, s))."
    case .white(let bird):
        return "\(known(bird, s).name.capitalizedFirst) is white, and white hides what's underneath."
    }
}

/// A bird as the words may name it: its name and look if the keeper has it, else "a bird" and no look.
private struct Named {
    let name: String
    let bird: Bird?
    /// He or she once the sex shows; the name before.
    var subject: String { bird.map { $0.revealed ? ($0.sex == .hen ? "she" : "he") : $0.name } ?? "it" }
    /// Her or his once the sex shows; "Pip's" before.
    var possessive: String { bird.map { $0.revealed ? ($0.sex == .hen ? "her" : "his") : "\($0.name)'s" } ?? "its" }
}

private func known(_ id: UUID, _ s: GameState) -> Named {
    let b = s.bird(id)
    return Named(name: b?.name ?? "a bird", bird: b)
}

/// What the keeper saw of a bird: an owned bird today, or a family record that kept a look.
private func seenLook(_ id: UUID, _ s: GameState) -> SeenLook? {
    if let b = s.bird(id) { return SeenLook(of: b, in: s) }
    return Pedigree.record(id, in: s)?.look
}

private func originWords(_ id: UUID, _ s: GameState) -> String {
    guard let origin = s.bird(id)?.origin else { return "outside the flock" }
    switch origin {
    case Bird.neighbourOrigin: return "the neighbour"
    case Bird.localFlockOrigin: return "a local flock"
    case Bird.showOrigin: return "the county show"
    case Bird.villageOrigin: return "a Featherwick neighbour"
    default: return origin
    }
}

private func breedWords(_ b: Breed) -> String {
    let name = b.definition.displayName
    return "\(article(name)) \(name)"
}

private func isEggLocus(_ l: LocusID) -> Bool { [BlueShell.locus, BrownShell.locus, Speckle.locus].contains(l) }

/// The trait a gene shows, as a noun: "lavender", "barring", "blue eggs".
private func locusNoun(_ l: LocusID) -> String {
    switch l {
    case Lavender.locus: "lavender"
    case BlueDilution.locus: "blue"
    case BaseColour.locus: "buff"
    case Lacing.locus: "lacing"
    case Barring.locus: "barring"
    case Feathering.locus: "silkie feathers"
    case BlueShell.locus: "blue eggs"
    case BrownShell.locus: "brown eggs"
    case Speckle.locus: "speckled eggs"
    case DominantWhite.locus: "white"
    default: "it"
    }
}

/// "blue", "brown", "speckled eggs": what a daughter laid.
private func eggShort(_ l: LocusID) -> String {
    switch l {
    case BlueShell.locus: "blue"
    case BrownShell.locus: "brown"
    default: locusNoun(l)
    }
}

private let blueShells: Set<EggColour> = [.blue, .green, .olive]
private let brownShells: Set<EggColour> = [.brown, .chocolate, .green, .olive]

/// How a look shows a gene's trait, as a verb phrase: "is lavender", "lays blue eggs". Nil if it does not show it.
private func showsPhrase(_ look: SeenLook, _ l: LocusID) -> String? {
    let colour = look.colour ?? downColour(look.chickDown)
    switch l {
    case Lavender.locus: return colour == .lavender ? "is lavender" : nil
    case BlueDilution.locus: return colour == .blue || colour == .splash ? "is \(colour!.rawValue)" : nil
    case BaseColour.locus: return look.colour == .buff ? "is buff" : nil
    case Lacing.locus: return look.isLaced == true ? "is laced" : nil
    case Barring.locus: return look.isBarred == true || look.chickDown == .darkWithHeadSpot ? "is barred" : nil
    case Feathering.locus: return look.isSilkieFeathered ? "has silkie feathers" : nil
    case BlueShell.locus:
        return look.eggColour.map { blueShells.contains($0) ? "lays \($0.rawValue) eggs" : nil } ?? nil
    case BrownShell.locus:
        return look.eggColour.map { brownShells.contains($0) ? "lays \($0.rawValue) eggs" : nil } ?? nil
    case Speckle.locus: return look.eggIsSpeckled == true ? "lays speckled eggs" : nil
    case DominantWhite.locus: return look.colour == .white ? "is white" : nil
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
    let name = n.name.capitalizedFirst
    guard let look = seenLook(id, s), n.bird != nil else { return "\(name)'s look settles it." }
    if look.colour == .white, l != DominantWhite.locus, !isEggLocus(l), l != Feathering.locus {
        return "\(name) is white, and white hides what's underneath."
    }
    let colour = look.colour
    switch l {
    case Lavender.locus:
        if colour == .lavender { return "\(name) is lavender. Lavender birds always pass lavender on." }
        if colour == .buff { return "\(name) is buff, and buff hides lavender." }
    case BlueDilution.locus:
        switch colour {
        case .blue: return "\(name) is blue. Blue birds always carry one of each."
        case .splash: return "\(name) is splash. Splash birds always pass blue on."
        case .black: return "\(name) is black, so \(n.subject) carries no blue."
        case .lavender: return "\(name) is lavender, and lavender hides blue."
        case .buff: return "\(name) is buff, and buff hides blue."
        default: break
        }
    case BaseColour.locus:
        if colour == .buff { return "\(name) is buff. Buff birds always pass buff on." }
    case Lacing.locus:
        if look.isLaced == true { return "\(name) is laced. Laced birds always pass lacing on." }
    case Barring.locus:
        if colour == .buff { return "\(name) is buff, and buff hides barring." }
        if look.isBarred == true { return "\(name) is barred." }
        if look.isBarred == false { return "\(name) is not barred, so \(n.subject) has no barring to pass on." }
    case Feathering.locus:
        if look.isSilkieFeathered { return "\(name) has silkie feathers. Silkie birds always pass them on." }
    case BlueShell.locus:
        if let egg = look.eggColour {
            return blueShells.contains(egg)
                ? "\(name) lays \(egg.rawValue) eggs." : "\(name) lays \(egg.rawValue) eggs, so she carries no blue."
        }
    case BrownShell.locus:
        if let egg = look.eggColour {
            return brownShells.contains(egg)
                ? "\(name) lays \(egg.rawValue) eggs." : "\(name) lays \(egg.rawValue) eggs, so she carries no brown."
        }
    case Speckle.locus:
        if let speckled = look.eggIsSpeckled { return "\(name) lays \(speckled ? "speckled" : "plain") eggs." }
    case DominantWhite.locus:
        if colour == .white { return "\(name) is white." }
        if colour != nil { return "\(name) is not white, so \(n.subject) carries no white." }
    default: break
    }
    return "\(name)'s look settles it."
}

/// "Her mother laid blue eggs." / "Her mother, Clover, is lavender."
private func parentReason(_ id: UUID, _ parent: UUID, _ l: LocusID, _ s: GameState) -> String {
    let n = known(id, s)
    let bird = n.bird
    let relation = parent == bird?.motherID ? "mother" : parent == bird?.fatherID ? "father" : "parent"
    let owner = bird == nil ? "a bird's" : n.possessive
    let named = s.bird(parent).map { "\(owner) \(relation), \($0.name)," } ?? "\(owner) \(relation)"
    if let look = seenLook(parent, s), let shows = showsPhrase(look, l) {
        return "\(named) \(shows)".capitalizedFirst + "."
    }
    let who = s.bird(parent).map { "\(owner) \(relation), \($0.name)" } ?? "\(owner) \(relation)"
    return "\(locusNoun(l).capitalizedFirst) came down from \(who)."
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
            "They"
        } else if let parents, let mother = s.bird(parents.mother), let father = s.bird(parents.father) {
            "\(mother.name) and \(father.name)"
        } else {
            n.name.capitalizedFirst
        }
    guard let look = seenLook(chick, s), let shows = showsPhrase(look, l) else {
        let named = c.map { "chick, \($0.name)," } ?? "chicks"
        let lead = c == nil ? "One of \(n.name)'s chicks" : "\(n.name)'s \(named)"
        return "\(lead.capitalizedFirst) shows that \(n.name) carries \(locusNoun(l))."
    }
    let name = c.map { ", \($0.name)" } ?? ""
    if isEggLocus(l) { return "\(who) had a daughter\(name)\(name.isEmpty ? "" : ",") who \(shows)." }
    let adjective = shows.replacingOccurrences(of: "is ", with: "")
    if l == Feathering.locus { return "\(who) had a silkie-feathered chick\(name)." }
    return "\(who) had \(article(adjective)) \(adjective) chick\(name)."
}

// MARK: - Carrier notes (the bird card)

/// What a bird surely carries but does not show: "Carries lavender". Never a sexed word.
public func carrierText(_ p: ProvenAllele) -> String {
    switch (p.locus, p.allele) {
    case (Feathering.locus, Feathering.silkie.rawValue): return "Carries silkie feathers"
    case (Feathering.locus, _): return "Carries normal feathers"
    case (BaseColour.locus, BaseColour.buff.rawValue): return "Carries buff"
    case (BaseColour.locus, _): return "Carries black"
    case (BlueDilution.locus, BlueDilution.blue.rawValue): return p.copies >= 2 ? "Carries splash" : "Carries blue"
    case (BlueDilution.locus, _): return "Carries plain colour, not blue"
    case (Lavender.locus, Lavender.lavender.rawValue): return "Carries lavender"
    case (Lavender.locus, _): return "Carries plain colour, not lavender"
    case (Lacing.locus, Lacing.laced.rawValue): return "Carries lacing"
    case (Lacing.locus, _): return "Carries plain feathers, not laced"
    case (Barring.locus, Barring.barred.rawValue): return "Carries barring"
    case (Barring.locus, _): return "Carries plain feathers, not barred"
    case (BlueShell.locus, BlueShell.blue.rawValue): return "Carries blue eggs"
    case (BlueShell.locus, _): return "Carries plain eggs, not blue"
    case (BrownShell.locus, BrownShell.brown.rawValue): return "Carries brown eggs"
    case (BrownShell.locus, _): return "Carries pale eggs, not brown"
    case (Speckle.locus, Speckle.speckled.rawValue): return "Carries speckled eggs"
    case (Speckle.locus, _): return "Carries plain eggs, not speckled"
    case (DominantWhite.locus, DominantWhite.white.rawValue): return "Carries white"
    case (DominantWhite.locus, _): return "Carries colour under the white"
    default: return "Carries something it does not show"
    }
}

/// How the keeper can be sure, from the note's evidence. A bird whose sex does not show yet is named,
/// never he or she.
public func carrierReasonText(_ p: ProvenAllele, bird: UUID, _ s: GameState) -> String {
    let n = known(bird, s)
    let b = n.bird
    let name = n.bird == nil ? "this bird" : n.name
    let possessive = b == nil ? "this bird's" : n.possessive
    func named(_ id: UUID) -> String? { s.bird(id)?.name }
    let text: String
    switch p.evidence {
    case .look:
        text = "\(possessive) own look shows it."
    case .origin(let breed):
        text =
            "\(name) came from \(originWords(bird, s)) as \(breedWords(breed)), and every one with that look carries it."
    case .outsideFlock:
        text = "\(name) came from \(originWords(bird, s)), and every bird from there with that look carries it."
    case .parent(let parent):
        let relation = parent == b?.motherID ? "mother" : parent == b?.fatherID ? "father" : "parent"
        text = "It came from \(possessive) \(relation)" + (named(parent).map { ", \($0)." } ?? ".")
    case .parents(let mother, let father):
        if let m = named(mother), let f = named(father) {
            text = "It came from \(possessive) parents, \(m) and \(f)."
        } else {
            text = "It came from \(possessive) parents."
        }
    case .child(let chick):
        text = named(chick).map { "\(possessive) chick \($0) proves it." } ?? "One of \(possessive) chicks proves it."
    case .family:
        text = "\(possessive) family tree proves it."
    }
    return text.capitalizedFirst
}

/// The carrier notes for a bird's card, each with its reason. Empty before the keeper meets the planner.
public func carrierLines(_ bird: UUID, _ s: GameState) -> [String] {
    Planner.carrierNotes(for: bird, in: s).map { "\(carrierText($0)). \(carrierReasonText($0, bird: bird, s))" }
}

/// A bird's carrier notes in a few words, for the family tree: "carries lavender and blue eggs". Nil for none.
public func carrierShortText(_ notes: [ProvenAllele]) -> String? {
    let items = notes.map { carrierText($0).replacingOccurrences(of: "Carries ", with: "") }
    guard let last = items.last else { return nil }
    let list = items.count == 1 ? last : items.dropLast().joined(separator: ", ") + " and " + last
    return "carries \(list)"
}

/// What `carries <name>` says when nothing hidden is certain yet.
public func carrierNoneText(_ bird: UUID, _ s: GameState) -> String {
    "Nothing hidden you can be sure of yet. Watch \(birdName(bird, s))'s chicks."
}

/// Why two birds cannot be planned as a pair, or nil if they can: a revealed hen and a revealed rooster.
/// Says only that a sex does not show yet, never which it is.
public func plannerPairProblemText(hen: Bird, rooster: Bird) -> String? {
    for b in [hen, rooster] where !b.revealed { return "\(b.name) is too young to tell yet." }
    if hen.sex != .hen { return "\(hen.name) is not a hen. Use: plan <hen> <rooster>" }
    if rooster.sex != .rooster { return "\(rooster.name) is not a rooster. Use: plan <hen> <rooster>" }
    return nil
}

extension String {
    /// The string with its first letter in capitals: "her mother" → "Her mother".
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
