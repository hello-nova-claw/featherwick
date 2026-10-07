import Foundation

// Hatch-day "why" note.
//
// When a chick hatches looking like neither parent, the neighbour says why, in one line. The engine
// picks the reason from genes and looks; the words live in FeatherwickText.
//
// No hidden-gene leaks (core rule 8): the note compares only what the keeper can see. That is the
// chick's down and the parents' grown looks, each as the down it maps to (`Phenotype.chickDown`).
// Buff and white both give yellow down, and barred down hides the colour under it. So a buff chick
// from white parents, or a barred chick's colour, never gets a note before the keeper can see it.
// The note never names or hints at the chick's sex.

/// Why a chick looks like neither parent. The engine picks the single most specific one.
public enum HatchReason: Hashable, Codable, Sendable {
    /// A recessive look (lavender, buff) that neither parent shows: each parent carried one hidden copy.
    case recessiveFromBothParents(LocusID)
    /// Blue is one copy of the blue gene. Blue x blue throws black, blue and splash; black x splash gives blue.
    case blueSplitsThreeWays
    /// A white parent: dominant white hides every other colour gene, and it passed one on.
    case whiteHidIt
}

extension HatchReason {
    /// The reason a chick looks like neither parent, or nil if it looks like one of them or no
    /// reason fits. Pure: no randomness, so the hatching step draws exactly as before.
    ///
    /// Priority, most specific first:
    /// 1. `whiteHidIt`: a parent is white. White hides every other colour, so no other reason can be
    ///    read from that parent's look.
    /// 2. `recessiveFromBothParents(lavender)`, then `(baseColour)` for buff: the chick shows a
    ///    recessive colour that neither parent shows.
    /// 3. `blueSplitsThreeWays`: chick and both parents are black, blue or splash.
    /// Reasons 2 and 3 need an unbarred chick, because barred down hides the colour.
    /// No reason for a plain chick from two barred parents: a barred hen gives every son her barring,
    /// so such a chick is always a pullet, and a note would tell its sex before the grower stage.
    public static func forChick(_ chick: Phenotype, mother: Phenotype, father: Phenotype) -> HatchReason? {
        let parents = [mother, father]
        guard parents.allSatisfy({ $0.chickDown != chick.chickDown }) else { return nil }
        if parents.contains(where: { $0.colour == .white }) { return .whiteHidIt }
        if !chick.isBarred {
            if chick.colour == .lavender, !parents.contains(where: { $0.colour == .lavender }) {
                return .recessiveFromBothParents(Lavender.locus)
            }
            if chick.colour == .buff, !parents.contains(where: { $0.colour == .buff }) {
                return .recessiveFromBothParents(BaseColour.locus)
            }
            let blueFamily: Set<FeatherColour> = [.black, .blue, .splash]
            if blueFamily.contains(chick.colour), parents.allSatisfy({ blueFamily.contains($0.colour) }),
                parents.allSatisfy({ $0.colour != chick.colour })
            {
                return .blueSplitsThreeWays
            }
        }
        return nil
    }
}

extension Engine {
    /// The hatch-day note for one chick, if its parents are birds the keeper owns and has seen grown.
    static func hatchSurprise(_ chick: Bird, _ s: GameState) -> GameEvent? {
        guard let motherID = chick.motherID, let fatherID = chick.fatherID,
            let mother = s.ownedBirds.first(where: { $0.id == motherID }),
            let father = s.ownedBirds.first(where: { $0.id == fatherID }),
            mother.revealed, father.revealed,
            let reason = HatchReason.forChick(chick.phenotype, mother: mother.phenotype, father: father.phenotype)
        else { return nil }
        return .hatchSurprise(chick: chick.id, reason: reason)
    }
}
