import Foundation

// Family trees and inbreeding.
//
// Every bird keeps its mother's and father's IDs. Birds the player owned (rehomed ones too) stay
// in the game state, so their trees never break. Birds the player never owned, such as the
// parents of a bought fertile egg, are kept as small pedigree records.
//
// Inbreeding uses Wright's coefficient, as real breeders do: the chance that a chick gets two
// copies of the same ancestor's gene. Brother × sister = 0.25. Unrelated parents = 0.
// Cozy rule: inbreeding never kills or blocks a hatch. The coefficient is recorded at hatch, but the
// player never sees it, and it has no effect unless `Rules.inbreedingMatters` is on (off by default).
// When on, it lightly lowers laying and show condition.

/// What the family tree needs to know about one bird.
public struct PedigreeRecord: Hashable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let breed: Breed
    public let sex: Sex
    public let purebred: Bool
    public let motherID: UUID?
    public let fatherID: UUID?
    public let origin: String
    public let hatchDay: Int
    /// What the keeper saw of this bird, if they ever saw it. Nil for a bird nobody showed them,
    /// such as a parent of a bought egg, and for every record in a save made before looks were kept.
    /// `Knowledge` reads nil as "look unknown": breed evidence only.
    public let look: SeenLook?

    /// A record of a bird. Give `look` only for a bird the keeper has seen (`SeenLook(of:in:)`).
    /// Without it the record says nothing about the bird's look.
    public init(_ b: Bird, look: SeenLook? = nil) {
        id = b.id
        name = b.name
        breed = b.breed
        sex = b.sex
        purebred = b.isPurebred
        motherID = b.motherID
        fatherID = b.fatherID
        origin = b.origin
        hatchDay = b.hatchDay
        self.look = look
    }

    /// "orpington hen", "cross rooster".
    public var kind: String {
        "\(purebred ? breed.rawValue : "cross") \(sex.rawValue)"
    }
}

/// How closely related two birds are, as a keeper would say it.
public enum Relatedness: String, Hashable, Codable, Sendable, CaseOrdered {
    case unrelated, distant, cousins, halfSiblings, close

    /// From the kinship coefficient (= the inbreeding a chick of the two would have).
    public init(kinship k: Double) {
        self = k >= 0.25 ? .close : k >= 0.125 ? .halfSiblings : k >= 0.0625 ? .cousins : k > 0 ? .distant : .unrelated
    }
}

/// A family tree, mother and father first.
public struct FamilyTree: Hashable, Sendable {
    public let record: PedigreeRecord
    public let mother: Indirect?
    public let father: Indirect?

    /// Box for the recursive tree.
    public final class Indirect: Hashable, Sendable {
        public let tree: FamilyTree
        init(_ tree: FamilyTree) { self.tree = tree }
        public static func == (a: Indirect, b: Indirect) -> Bool { a.tree == b.tree }
        public func hash(into h: inout Hasher) { h.combine(tree) }
    }
}

public enum Pedigree {
    /// How many generations back the kinship sum looks. Older links add almost nothing.
    public static let maxGenerations = 16

    /// Any bird the game knows about: owned, lost, boarding, rehomed, or an outside parent.
    public static func record(_ id: UUID?, in s: GameState) -> PedigreeRecord? {
        guard let id else { return nil }
        return s.bird(id).map { PedigreeRecord($0) } ?? s.pedigree[id]
    }

    /// Wright's kinship coefficient between two birds: the inbreeding their chick would have.
    public static func kinship(_ a: UUID?, _ b: UUID?, in s: GameState) -> Double {
        var memo: [BirdPair: Double] = [:]
        return kinship(a, b, s, &memo, depth: 0)
    }

    /// Memo key for kinship: two birds, in a fixed order, since kinship(a, b) == kinship(b, a).
    private struct BirdPair: Hashable {
        let first: UUID, second: UUID
        init(_ a: UUID, _ b: UUID) {
            let ordered = a.uuidString < b.uuidString
            first = ordered ? a : b
            second = ordered ? b : a
        }
    }

    private static func kinship(
        _ a: UUID?, _ b: UUID?, _ s: GameState, _ memo: inout [BirdPair: Double], depth: Int
    ) -> Double {
        guard let a, let b, depth < maxGenerations * 2,
            let ra = record(a, in: s), let rb = record(b, in: s)
        else { return 0 }
        let key = BirdPair(a, b)
        if let known = memo[key] { return known }
        let value: Double
        if a == b {
            // A bird with itself: 1/2 × (1 + its own inbreeding).
            value = 0.5 * (1 + kinship(ra.motherID, ra.fatherID, s, &memo, depth: depth + 1))
        } else {
            // Go up from the younger bird: it cannot be an ancestor of the older one.
            let (young, other) = (ra.hatchDay, a.uuidString) >= (rb.hatchDay, b.uuidString) ? (ra, b) : (rb, a)
            value =
                0.5
                * (kinship(young.motherID, other, s, &memo, depth: depth + 1)
                    + kinship(young.fatherID, other, s, &memo, depth: depth + 1))
        }
        memo[key] = value
        return value
    }

    /// The inbreeding of a bird: the kinship of its parents.
    public static func inbreeding(of id: UUID, in s: GameState) -> Double {
        guard let r = record(id, in: s) else { return 0 }
        return kinship(r.motherID, r.fatherID, in: s)
    }

    public static func relatedness(_ a: UUID, _ b: UUID, in s: GameState) -> Relatedness {
        Relatedness(kinship: kinship(a, b, in: s))
    }

    /// The tree back `generations` steps. Unknown parents are nil.
    public static func tree(of id: UUID, generations: Int = 3, in s: GameState) -> FamilyTree? {
        guard let r = record(id, in: s) else { return nil }
        func branch(_ parent: UUID?) -> FamilyTree.Indirect? {
            guard generations > 1, let parent, let t = tree(of: parent, generations: generations - 1, in: s) else {
                return nil
            }
            return FamilyTree.Indirect(t)
        }
        return FamilyTree(record: r, mother: branch(r.motherID), father: branch(r.fatherID))
    }

    /// Every known chick of this bird, oldest first.
    public static func offspring(of id: UUID, in s: GameState) -> [PedigreeRecord] {
        let known =
            (s.birdsAtHome + s.lost.map(\.bird) + s.boarding + s.rehomed).map { PedigreeRecord($0) }
            + Array(s.pedigree.values)
        var seen: Set<UUID> = []
        return known.filter { ($0.motherID == id || $0.fatherID == id) && seen.insert($0.id).inserted }
            .sorted { ($0.hatchDay, $0.name) < ($1.hatchDay, $1.name) }
    }
}
