import Foundation

// The inheritance page: what the keeper has worked out, written down.
//
// A rule is a pinned ratio, a certainty or a sex-link that "What might hatch" gave for a penned pair,
// kept once the keeper sets at least one egg from that pair. Seeing a forecast is not trying it, so
// nothing is kept from a forecast alone. A rule says only trait outcomes and the parents' looks, never
// a bird's name.
//
// Rule 8: a rule comes only from `Planner.panel` and the parents' `Visible` looks. This file never
// reads genes (`KnowledgeTests.knowledgeSourceNeverReadsGenes` checks it). The hook does not read an egg's
// father or fertility either: those are hidden until candling. A pair's eggs are the penned hen's,
// set while a grown rooster is in the pen, which the keeper can see.
// The words live in FeatherwickText (`inheritanceText`).

/// A feather colour and how many chicks in the rule's denominator show it.
public struct ColourShare: Hashable, Codable, Sendable {
    public let colour: FeatherColour
    public let count: Int

    public init(_ colour: FeatherColour, _ count: Int) {
        self.colour = colour
        self.count = count
    }
}

/// One thing the keeper has learned about inheritance. Trait outcomes and parent looks only: no birds.
public enum InheritanceRule: Hashable, Codable, Sendable {
    /// Feather colours from parents of these two colours: "blue × blue → 1 black : 2 blue : 1 splash".
    /// The colour genes are not sex-linked, so the parents are in `FeatherColour` order, not hen first.
    /// Shares are out of `denominator`, in colour order. One share with the whole denominator is "all".
    case colours(FeatherColour, FeatherColour, [ColourShare], denominator: Int)
    /// A pattern or egg trait: `numerator` in `denominator` chicks show it (all when they are equal).
    /// `hen` and `rooster` say whether each parent shows it; nil when it cannot show (a rooster's eggs,
    /// or a hen not laying yet). An egg trait counts the pair's daughters.
    case trait(Trait, hen: Bool?, rooster: Bool?, numerator: Int, denominator: Int)
    /// "Barred hen × plain rooster → barred chicks are cockerels."
    case sexLink(barredAre: Sex)
}

// `Inheritance` (Locus.swift) is how a gene passes down: autosomal or Z-linked. The page's functions
// sit on it too, so the page reads `Inheritance.known(in:)`.
extension Inheritance {
    /// The page: every rule the keeper has learned, in the order first seen.
    public static func known(in s: GameState) -> [InheritanceRule] { s.seenRules }

    /// The rules a pair's forecast pins: its certain lines, its ratios and its sex-link. Feather colour
    /// lines join into one rule. A trait whose parent look is not seen gives no rule.
    public static func rules(from lines: [Forecast], hen: Visible, rooster: Visible) -> [InheritanceRule] {
        var out: [InheritanceRule] = []
        var shares: [ColourShare] = []
        var denominator = 1
        for line in lines {
            switch line {
            case .certain(.colour(let c), _):
                shares = [ColourShare(c, 1)]
                denominator = 1
            case .ratio(.colour(let c), let n, let d, _):
                // The planner gives every colour ratio of a pair the same denominator.
                if shares.isEmpty || d == denominator {
                    shares.append(ColourShare(c, n))
                    denominator = d
                }
            case .certain(let t, _):
                if let rule = traitRule(t, 1, 1, hen, rooster) { out.append(rule) }
            case .ratio(let t, let n, let d, _):
                if let rule = traitRule(t, n, d, hen, rooster) { out.append(rule) }
            case .sexLink(let barredAre, _):
                out.append(.sexLink(barredAre: barredAre))
            default:
                break
            }
        }
        if !shares.isEmpty, let a = hen.look?.colour, let b = rooster.look?.colour {
            let order = FeatherColour.allCases
            let (first, second) = order.firstIndex(of: a)! <= order.firstIndex(of: b)! ? (a, b) : (b, a)
            let sorted = shares.sorted { order.firstIndex(of: $0.colour)! < order.firstIndex(of: $1.colour)! }
            out.insert(.colours(first, second, sorted, denominator: denominator), at: 0)
        }
        return out
    }

    /// Whether a parent's look shows the trait. Nil when the look does not say.
    static func shows(_ t: Trait, _ v: Visible) -> Bool? {
        guard let look = v.look else { return nil }
        switch t {
        case .colour(let c): return look.colour.map { $0 == c }
        case .barred: return look.isBarred
        case .laced: return look.isLaced
        case .silkieFeathered: return look.isSilkieFeathered
        case .eggColour(let e): return look.eggColour.map { $0.coarse == e }
        case .speckledEggs: return look.eggIsSpeckled
        }
    }

    static func traitRule(_ t: Trait, _ n: Int, _ d: Int, _ hen: Visible, _ rooster: Visible) -> InheritanceRule? {
        let henShows = shows(t, hen)
        let roosterShows = t.isEggTrait ? nil : shows(t, rooster)
        // A feather trait needs both looks: "barred × ? → ..." teaches nothing.
        if !t.isEggTrait, henShows == nil || roosterShows == nil { return nil }
        return .trait(t, hen: henShows, rooster: roosterShows, numerator: n, denominator: d)
    }

    /// The rules for this hen with the penned rooster, as the pen's forecast shows them now. Empty
    /// unless the planner is known, she is penned and a grown rooster is in the pen.
    public static func rules(forHen id: UUID, in s: GameState) -> [InheritanceRule] {
        guard s.penRooster != nil, s.penRoosterGrownDay == nil,
            case .forecast(let roosterID, let pairs) = Planner.panel(in: s),
            let pair = pairs.first(where: { $0.hen == id }),
            let hen = s.bird(id), let rooster = s.bird(roosterID)
        else { return [] }
        return rules(from: pair.lines, hen: Visible(bird: hen, in: s), rooster: Visible(bird: rooster, in: s))
    }

    /// Keeps the rules of every penned pair these eggs come from. Called when the keeper sets eggs.
    /// The pair is the egg's layer (a penned hen) and the grown penned rooster.
    static func recordSetting(_ eggs: [Egg], _ s: inout GameState) {
        var mothers: [UUID] = []
        for egg in eggs where s.isPenned(egg.motherID) && !mothers.contains(egg.motherID) {
            mothers.append(egg.motherID)
        }
        for mother in mothers {
            for rule in rules(forHen: mother, in: s) where !s.seenRules.contains(rule) {
                s.seenRules.append(rule)
            }
        }
    }
}
