import Foundation

// What the keeper can work out about each bird's single genes, from looks and family alone.
//
// Core rule 8 (no hidden-gene leaks) is the reason this file exists. It reads only `Visible` values:
// looks, sexes and breeds once they show, origins, and parents. It never reads a bird's genes, so
// nothing it says can depend on a gene the keeper cannot see. A test checks this file for any read
// of genes, and a blind test swaps every bird's genes for others with the same look and checks the
// output does not change.
//
// Each bird starts with every genotype its gene allows. Evidence removes the ones that cannot be:
//   1. Look: `Phenotype` in reverse (`LookTable`).
//   2. Origin: a bird from outside the flock is one of its breed's recipes (`RecipeTable`).
//   3. Family up: a chick's genotype must come from some genotype of its mother and of its father.
//   4. Family down: a parent keeps a genotype only if every seen chick can come from it.
//   5. Steps 3 and 4 repeat until nothing changes.
// Hidden alleles are found by elimination only. Nothing here is a "maybe".
//
// Knowledge tracks the single (Mendelian) genes only. The quantitative traits are many small genes;
// the planner works with their visible grades instead.

/// How much the keeper knows about one bird at one gene.
public enum KnowledgeState: String, Hashable, Codable, Sendable {
    /// One genotype left.
    case pinned
    /// More than one genotype left, but at least one allele is in all of them: one copy is certain.
    case halfPinned
    /// No allele is certain.
    case open
}

/// The evidence that first made an allele certain.
public enum Evidence: Hashable, Codable, Sendable {
    /// The bird's own look.
    case look
    /// The bird came from outside the flock, so it is one of this breed's recipes.
    case origin(Breed)
    /// The bird came from outside the flock, but its breed does not show yet.
    case outsideFlock
    /// What one parent can pass on.
    case parent(UUID)
    /// What the two parents together can pass on.
    case parents(UUID, UUID)
    /// A chick the bird had.
    case child(UUID)
    /// Family evidence through a bird the keeper never saw.
    case family
}

/// An allele the keeper can be sure a bird carries, though its look does not show it.
public struct ProvenAllele: Hashable, Codable, Sendable {
    public let locus: LocusID
    public let allele: String
    /// Copies certain: 1, or 2 when every genotype left has two.
    public let copies: Int
    /// True for the gene's plain (default) allele, such as "lav+". Most notes are about the others.
    public let isDefault: Bool
    public let evidence: Evidence
}

/// What is known about one bird at one gene.
public struct LocusKnowledge: Hashable, Codable, Sendable {
    public let locus: LocusID
    /// The genotypes still possible, in `GenotypeSpace` order.
    public let candidates: [Genotype]
    public let state: KnowledgeState
}

/// What is known about one bird.
public struct BirdKnowledge: Hashable, Codable, Sendable {
    public let id: UUID
    /// One entry per single gene, in `Loci.mendelian` order.
    public let loci: [LocusKnowledge]
    /// Every allele certain but not shown by the look, plain ones too, in gene then allele order.
    public let proven: [ProvenAllele]
}

/// What the keeper can work out about every bird they know. Pure: worked out on demand from the
/// state, never stored in it.
///
/// Deterministic: birds are sorted by id and genes are in `Loci.mendelian` order, so two equal
/// states give byte-identical encodings.
public struct Knowledge: Equatable, Codable, Sendable {
    /// Every bird covered, sorted by id.
    public let birds: [BirdKnowledge]
    /// Times evidence would have emptied a bird's genotypes. The bird then kept its last set.
    /// Zero in normal play: a contradiction means the evidence was wrong, such as a hand-edited save.
    public let contradictions: Int
    private let index: [UUID: Int]

    private enum CodingKeys: String, CodingKey { case birds, contradictions }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        birds = try c.decode([BirdKnowledge].self, forKey: .birds)
        contradictions = try c.decode(Int.self, forKey: .contradictions)
        index = Self.index(birds)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(birds, forKey: .birds)
        try c.encode(contradictions, forKey: .contradictions)
    }

    public static func == (a: Knowledge, b: Knowledge) -> Bool {
        a.birds == b.birds && a.contradictions == b.contradictions
    }

    private init(birds: [BirdKnowledge], contradictions: Int) {
        self.birds = birds
        self.contradictions = contradictions
        index = Self.index(birds)
    }

    private static func index(_ birds: [BirdKnowledge]) -> [UUID: Int] {
        Dictionary(birds.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - Questions

    /// What is known about one bird. Nil for a bird the keeper does not know.
    public func bird(_ id: UUID) -> BirdKnowledge? { index[id].map { birds[$0] } }

    /// The genotypes still possible for a bird at a single gene. Empty for an unknown bird or gene.
    public func candidates(_ bird: UUID, _ locus: LocusID) -> Set<Genotype> {
        Set(entry(bird, locus)?.candidates ?? [])
    }

    /// How much is known about a bird at a single gene. `.open` for an unknown bird or gene.
    public func state(_ bird: UUID, _ locus: LocusID) -> KnowledgeState { entry(bird, locus)?.state ?? .open }

    /// Alleles the bird surely carries that its look does not show, such as lavender on a black bird
    /// with a lavender parent. Only certainties, never "may carry". Plain (default) alleles only with
    /// `includeDefault`.
    public func provenHidden(_ bird: UUID, includeDefault: Bool = false) -> [ProvenAllele] {
        (self.bird(bird)?.proven ?? []).filter { includeDefault || !$0.isDefault }
    }

    private func entry(_ bird: UUID, _ locus: LocusID) -> LocusKnowledge? {
        self.bird(bird)?.loci.first { $0.locus == locus }
    }

    // MARK: - Working it out

    /// Everything the keeper can work out about the birds they know (`Visible.all(in:)`).
    public static func of(_ s: GameState) -> Knowledge { of(Visible.all(in: s)) }

    /// Everything that can be worked out from these birds alone. A parent not in the list counts as
    /// unknown: it could have any genotype.
    public static func of(_ visible: [Visible]) -> Knowledge {
        var solver = Solver(visible)
        solver.run()
        return solver.result()
    }

    /// The elimination itself. Genotype sets are bit masks over `GenotypeSpace.all[l].genotypes`.
    private struct Solver {
        let spaces = GenotypeSpace.all
        let birds: [Visible]
        let mother: [Int?]
        let father: [Int?]
        /// For each bird, its chicks as (chick, other parent, true if this bird is the mother).
        let chicks: [[(chick: Int, other: Int?, isMother: Bool)]]
        /// Genotypes still possible, `masks[b * loci + l]`.
        var masks: [GenotypeMask]
        /// What the look alone allows (with the sex), to tell a hidden allele from a shown one.
        var shown: [GenotypeMask]
        /// The evidence that first made each allele certain, `causes[(b * loci + l) * maxAlleles + a]`.
        var causes: [Evidence?]
        var contradictions = 0
        let maxAlleles: Int

        var loci: Int { spaces.count }

        init(_ visible: [Visible]) {
            var unique: [Visible] = []
            var ids: Set<UUID> = []
            // Sort on keys made once: making a uuidString in every comparison is slow.
            let keyed = visible.map { (key: $0.id.uuidString, bird: $0) }.sorted { $0.key < $1.key }
            for (_, v) in keyed where ids.insert(v.id).inserted { unique.append(v) }
            birds = unique
            let at = Dictionary(uniqueKeysWithValues: unique.enumerated().map { ($1.id, $0) })
            mother = unique.map { $0.motherID.flatMap { at[$0] } }
            father = unique.map { $0.fatherID.flatMap { at[$0] } }
            var chicks = [[(chick: Int, other: Int?, isMother: Bool)]](repeating: [], count: unique.count)
            for c in unique.indices {
                if let m = mother[c] { chicks[m].append((c, father[c], true)) }
                if let f = father[c] { chicks[f].append((c, mother[c], false)) }
            }
            self.chicks = chicks
            maxAlleles = spaces.map(\.locus.alleles.count).max() ?? 0
            masks = []
            shown = []
            causes = []
            masks.reserveCapacity(unique.count * spaces.count)
            for (b, v) in unique.enumerated() {
                // A mother is a hen and a father a rooster, whatever shows yet.
                let isMother = chicks[b].contains { $0.isMother }
                let isFather = chicks[b].contains { !$0.isMother }
                for space in spaces {
                    var m = space.mask(for: v.sex)
                    if isMother { m &= space.henMask }
                    if isFather { m &= space.roosterMask }
                    masks.append(m)
                }
            }
            causes = Array(repeating: nil, count: masks.count * maxAlleles)
            shown = masks
        }

        /// Keeps only `allowed` for bird `b` at gene `l`. Returns true if anything was removed.
        /// Evidence that would remove everything is a contradiction: it is counted and ignored.
        @discardableResult
        mutating func narrow(
            _ b: Int, _ l: Int, _ space: GenotypeSpace, to allowed: GenotypeMask, _ cause: Evidence
        ) -> Bool {
            let i = b * loci + l
            let old = masks[i]
            let new = old & allowed
            if new == old { return false }
            if new == 0 {
                contradictions += 1
                return false
            }
            masks[i] = new
            var newlySure = space.certain(new) & ~space.certain(old)
            while newlySure != 0 {
                let a = newlySure.trailingZeroBitCount
                newlySure &= newlySure - 1
                if causes[i * maxAlleles + a] == nil { causes[i * maxAlleles + a] = cause }
            }
            return true
        }

        /// A bird named as evidence, or `.family` if the keeper never saw it.
        func named(_ b: Int, _ make: (UUID) -> Evidence) -> Evidence {
            birds[b].isSeen ? make(birds[b].id) : .family
        }

        mutating func run() {
            for (b, v) in birds.enumerated() {
                // 1. Look.
                if let look = v.look, let allowed = LookTable.masks(for: look, sex: v.sex) {
                    for (l, space) in spaces.enumerated() { narrow(b, l, space, to: allowed[l], .look) }
                }
                for l in 0..<loci { shown[b * loci + l] = masks[b * loci + l] }
                // 2. Origin.
                if v.isFromOutside { applyOrigin(b, v) }
            }
            // 3–5. Family, up and down, until nothing changes. Family evidence never links two genes,
            // so each gene settles on its own.
            for (l, space) in spaces.enumerated() {
                var changed = true
                while changed {
                    changed = false
                    for c in birds.indices where hasParents(c) && !sexBlind(c, space) && up(c, l, space) {
                        changed = true
                    }
                    for p in birds.indices where !chicks[p].isEmpty && down(p, l, space) { changed = true }
                }
            }
        }

        func hasParents(_ c: Int) -> Bool { mother[c] != nil || father[c] != nil }

        /// True for a sex-linked gene of a bird whose sex does not show. Its parents are not used to
        /// narrow it: a daughter gets her one Z from her father, a son one from each parent, so what the
        /// parents allow differs by sex, and a narrower set could tell a barred chick's sex (as real
        /// keepers autosex barred chicks). Such a gene keeps what its look and origin allow, which hold
        /// both sexes' forms alike. It still counts as evidence about its parents (`down`): that check
        /// accepts either sex, so it cannot depend on the chick's.
        func sexBlind(_ c: Int, _ space: GenotypeSpace) -> Bool {
            birds[c].sex == nil && space.locus.inheritance == .zLinked
        }

        /// A bird from outside the flock is one of its breed's recipes that gives the look it shows.
        ///
        /// This uses today's recipes. A bird from an old save may have come from a recipe the game no
        /// longer has, and then its look can fit no recipe: origin evidence is skipped for that bird,
        /// rather than counted as a contradiction. Its look and family still count.
        mutating func applyOrigin(_ b: Int, _ v: Visible) {
            let level = v.look?.level
            let look = v.look?.coarse
            let fits = RecipeTable.recipes(breed: v.breed, sex: v.sex).filter { r in
                guard let level, let look else { return true }
                return r.look(at: level) == look
            }
            guard !fits.isEmpty else { return }
            let cause: Evidence = v.breed.map { .origin($0) } ?? .outsideFlock
            for (l, space) in spaces.enumerated() {
                narrow(b, l, space, to: fits.reduce(0) { $0 | $1.masks[l] }, cause)
            }
        }

        func mask(_ b: Int?, _ l: Int, or fallback: GenotypeMask) -> GenotypeMask {
            b.map { masks[$0 * loci + l] } ?? fallback
        }

        /// A chick keeps only genotypes its parents can give it.
        mutating func up(_ c: Int, _ l: Int, _ space: GenotypeSpace) -> Bool {
            let mothers = mask(mother[c], l, or: space.henMask)
            let fathers = mask(father[c], l, or: space.roosterMask)
            let allowed = space.children(mothers: mothers, fathers: fathers)
            let new = masks[c * loci + l] & allowed
            // Work out the credit only when something would change: it costs two more crosses.
            guard new != masks[c * loci + l] else { return false }
            return narrow(c, l, space, to: allowed, upCause(c, l, space, new, mother[c], father[c]))
        }

        /// Credit one parent if it alone explains the narrowing, else both.
        func upCause(
            _ c: Int, _ l: Int, _ space: GenotypeSpace, _ new: GenotypeMask, _ m: Int?, _ f: Int?
        )
            -> Evidence
        {
            let current = masks[c * loci + l]
            if let m, current & space.children(mothers: masks[m * loci + l], fathers: space.roosterMask) == new {
                return named(m, Evidence.parent)
            }
            if let f, current & space.children(mothers: space.henMask, fathers: masks[f * loci + l]) == new {
                return named(f, Evidence.parent)
            }
            if let m, let f, birds[m].isSeen, birds[f].isSeen { return .parents(birds[m].id, birds[f].id) }
            return .family
        }

        /// A parent keeps a genotype only if every chick can come from it and some genotype of the
        /// chick's other parent.
        mutating func down(_ p: Int, _ l: Int, _ space: GenotypeSpace) -> Bool {
            var changed = false
            for (c, other, isMother) in chicks[p] {
                let mine = masks[p * loci + l]
                let chick = masks[c * loci + l]
                var keep: GenotypeMask = 0
                var rest = mine
                while rest != 0 {
                    let one = GenotypeMask(1) << rest.trailingZeroBitCount
                    rest &= rest - 1
                    let kids =
                        isMother
                        ? space.children(mothers: one, fathers: mask(other, l, or: space.roosterMask))
                        : space.children(mothers: mask(other, l, or: space.henMask), fathers: one)
                    if kids & chick != 0 { keep |= one }
                }
                if keep != mine, narrow(p, l, space, to: keep, named(c, Evidence.child)) { changed = true }
            }
            return changed
        }

        func result() -> Knowledge {
            var out: [BirdKnowledge] = []
            out.reserveCapacity(birds.count)
            for (b, v) in birds.enumerated() {
                var loci: [LocusKnowledge] = []
                var proven: [ProvenAllele] = []
                for (l, space) in spaces.enumerated() {
                    let i = b * self.loci + l
                    let mask = masks[i]
                    let sure = space.certain(mask)
                    let state: KnowledgeState = mask.nonzeroBitCount == 1 ? .pinned : sure == 0 ? .open : .halfPinned
                    loci.append(
                        LocusKnowledge(locus: space.locus.id, candidates: space.genotypes(in: mask), state: state))
                    let hidden = sure & ~space.certain(shown[i])
                    for a in space.locus.alleles.indices where hidden & (1 << a) != 0 {
                        let allele = space.locus.alleles[a]
                        let copies = space.genotypes(in: mask).map { $0.count(of: allele) }.min() ?? 0
                        proven.append(
                            ProvenAllele(
                                locus: space.locus.id, allele: allele, copies: copies,
                                isDefault: allele == space.locus.defaultAllele,
                                evidence: causes[i * maxAlleles + a] ?? .family))
                    }
                }
                out.append(BirdKnowledge(id: v.id, loci: loci, proven: proven))
            }
            return Knowledge(birds: out, contradictions: contradictions)
        }
    }
}
