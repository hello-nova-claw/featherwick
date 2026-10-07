import Foundation

// What might hatch: a forecast for a penned pair, built only from what the keeper could know.
//
// The one rule: the planner reads `Visible` birds and `Knowledge`, nothing else. Where elimination
// leaves more than one possibility, the forecast says "likely", "possible" or "not possible",
// never a number. Ratios appear only when both parents are pinned at every locus that decides them.
// The words live in FeatherwickText (`plannerText`).

/// Something a chick (or a hen from this pair) can show.
public enum Trait: Hashable, Codable, Sendable {
    /// A feather colour: black, blue, splash, lavender, buff or white.
    case colour(FeatherColour)
    case barred
    case laced
    case silkieFeathered
    /// The pair's daughters will lay this egg colour.
    case eggColour(EggColour)
    case speckledEggs
}

/// Why a forecast line is true. Names only birds the keeper has seen.
public enum Reason: Hashable, Codable, Sendable {
    /// This bird's look settles it: "Pip is blue. Blue birds always carry one of each."
    case look(bird: UUID, locus: LocusID)
    /// This bird came from outside as a purebred of this breed: "Pip came from Speckle & Down as an Orpington."
    case breed(bird: UUID, Breed)
    /// A parent of this bird showed it: "Her mother laid blue eggs."
    case parent(bird: UUID, parent: UUID, locus: LocusID)
    /// The pair (or one of them) already had a chick that showed it: "They had a lavender chick, Clover."
    case chick(bird: UUID, chick: UUID, locus: LocusID)
    /// Nobody in either bird's visible family has shown it yet.
    case unknownFamily(locus: LocusID)
    /// This bird had this many chicks and none showed it. A likelihood, not a proof.
    case manyChicks(bird: UUID, count: Int, locus: LocusID)
    /// The practice judge's grades for each bird.
    case grades(hen: UUID, rooster: UUID)
    /// The family tree.
    case family(hen: UUID, rooster: UUID)
    /// This bird is white, and white hides what is underneath.
    case white(bird: UUID)
}

/// One line of the "What might hatch" panel. Enums only: no words.
public enum Forecast: Hashable, Codable, Sendable {
    /// Every chick will show this.
    case certain(Trait, Reason)
    /// About `numerator` in `denominator` chicks will show this. Only when both parents are pinned.
    case ratio(Trait, numerator: Int, denominator: Int, Reason)
    /// Likely, but not proven.
    case likely(Trait, Reason)
    /// Can happen if one of them is hiding it.
    case possible(Trait, Reason)
    /// Proven impossible by elimination.
    case notPossible(Trait, Reason)
    /// Barred chicks are all of one sex: the hen is barred and the rooster is pinned not barred.
    case sexLink(barredAre: Sex, Reason)
    /// The egg colours this pair's daughters can lay. `sure` is false when it turns on an open gene.
    case eggColours([EggColour], sure: Bool, Reason)
    /// The practice judge's type grades for the hen and the rooster.
    case typeOutlook(Grade, Grade, Reason)
    /// How closely related the pair are, in the keeper's words.
    case kinship(Relatedness, Reason)
    /// One or both are white, so anything either carries could show.
    case unknownUnderWhite(Reason)

    public var reason: Reason {
        switch self {
        case .certain(_, let r), .ratio(_, _, _, let r), .likely(_, let r), .possible(_, let r),
            .notPossible(_, let r), .sexLink(_, let r), .eggColours(_, _, let r), .typeOutlook(_, _, let r),
            .kinship(_, let r), .unknownUnderWhite(let r):
            r
        }
    }
}

/// What the breeding pen's "What might hatch" panel shows.
public enum PlannerPanel: Hashable, Sendable {
    /// The keeper has not met the planner yet (`GameState.plannerKnown` is false).
    case hidden
    /// The pen has no hen.
    case needsHen
    /// The pen has a hen but no rooster: "Pen a rooster to see what might hatch."
    case needsRooster
    /// The forecast for the penned pair.
    case forecast(hen: UUID, rooster: UUID, [Forecast])
}

public enum Planner {
    /// The forecast for one pair. Reads only `Visible` values and `Knowledge`.
    public static func forecast(hen: Visible, rooster: Visible, knowledge: Knowledge) -> [Forecast] {
        []  // Phase 2 (Planner agent) fills this in.
    }

    /// The panel for the breeding pen today.
    public static func panel(in s: GameState) -> PlannerPanel {
        .hidden  // Phase 2 (Planner agent) fills this in.
    }

    /// The carrier notes for a bird's card: hidden alleles proven present. Empty until the planner is known.
    public static func carrierNotes(for bird: UUID, in s: GameState) -> [ProvenAllele] {
        guard s.plannerKnown else { return [] }
        return Knowledge.of(s).provenHidden(bird)
    }
}
