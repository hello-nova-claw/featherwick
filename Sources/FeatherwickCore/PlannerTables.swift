import Foundation

// Tables that the planner reads, built once from the game's own rules.
//
// `ChickLookTable`: for every combination of a few single genes, the traits a chick with those genes
// shows (`Trait.planned`). Built by making test birds and asking `Phenotype`, like `LookTable`, so the
// planner follows the real look rules (white hides everything, buff hides blue and barring, lacing
// shows only on buff) without a copy of them. These tables never read a real bird.

extension Trait {
    /// True if a bird with this look shows the trait. Egg traits are a hen's: a rooster shows none.
    /// Egg colours are compared in their coarse form (`EggColour.coarse`).
    public func isShown(by p: Phenotype) -> Bool {
        switch self {
        case .colour(let c): p.colour == c
        case .barred: p.isBarred
        case .laced: p.isLaced
        case .silkieFeathered: p.isSilkieFeathered
        case .eggColour(let c): p.eggColour?.coarse == c
        case .speckledEggs: p.eggColour != nil && p.eggIsSpeckled
        }
    }
}

extension EggColour {
    /// The colour the single genes decide: chocolate is a dark brown, olive a dark green and white
    /// an untinted cream. How dark is the brown-depth trait, which the planner does not forecast.
    public var coarse: EggColour {
        switch self {
        case .chocolate: .brown
        case .olive: .green
        case .white: .cream
        default: self
        }
    }
}

/// The traits a chick shows, for every combination of genotypes at a few single genes.
struct ChickLookTable: Sendable {
    /// Positions in `GenotypeSpace.all` of the genes the table covers.
    let loci: [Int]
    /// The step of each gene in `entries`: the entry of a combination is at Σ genotype index × stride.
    let strides: [Int]
    /// The traits shown, as bits over `Trait.planned`.
    let entries: [UInt16]

    /// The genes of a daughter's eggs. Every other single gene is a feather gene.
    static let eggGenes: [LocusID] = [BlueShell.locus, BrownShell.locus, Speckle.locus]

    /// Feather colour and pattern, both sexes: every single gene but the egg genes, so a gene appended
    /// to `Loci` is in the table at once. The barring genotype says the sex: one allele is a hen.
    static let plumage = ChickLookTable(
        Loci.mendelian.map(\.id).filter { !eggGenes.contains($0) }, hen: false, traits: Trait.plumageBits)
    /// The eggs a daughter lays.
    static let eggs = ChickLookTable(eggGenes, hen: true, traits: Trait.eggBits)

    /// The traits (bits over `Trait.planned`) the table answers for.
    let traits: UInt16

    /// Builds the table for these genes. Every other gene stays at its default allele: the traits in
    /// `traits` depend only on the genes listed.
    private init(_ ids: [LocusID], hen: Bool, traits: UInt16) {
        self.traits = traits
        let spaces = GenotypeSpace.all
        loci = ids.map { id in spaces.firstIndex { $0.locus.id == id }! }
        var strides = [Int](repeating: 1, count: loci.count)
        for i in stride(from: loci.count - 2, through: 0, by: -1) {
            strides[i] = strides[i + 1] * spaces[loci[i + 1]].genotypes.count
        }
        self.strides = strides
        let total = strides[0] * spaces[loci[0]].genotypes.count
        let loci = loci
        let planned = Trait.planned
        entries = (0..<total).map { index in
            let genotypes = loci.indices.map { i in
                spaces[loci[i]].genotypes[(index / strides[i]) % spaces[loci[i]].genotypes.count]
            }
            // A one-allele Z genotype is a hen's.
            let isHen =
                hen
                || zip(loci, genotypes).contains { spaces[$0].locus.inheritance == .zLinked && $1.alleles.count == 1 }
            var bird = Genome(sex: isHen ? .hen : .rooster)
            for (l, g) in zip(loci, genotypes) {
                let space = spaces[l]
                // A hen's Z gene has one allele; a combination that gives a rooster's pair to a hen
                // (or the other way) cannot happen and shows nothing.
                if space.locus.inheritance == .zLinked, (g.alleles.count == 1) != isHen { return 0 }
                bird.setAlleles(g.alleles, at: space.locus)
            }
            let p = Phenotype(bird)
            var bits: UInt16 = 0
            for (i, trait) in planned.enumerated() where trait.isShown(by: p) { bits |= 1 << i }
            return bits & traits
        }
    }
}
