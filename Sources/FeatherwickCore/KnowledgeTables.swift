import Foundation

// Tables that `Knowledge` reads, built once from the game's own rules.
//
// - `GenotypeSpace`: every genotype one single gene allows, and how parents pass them on.
// - `LookTable`: `Phenotype` run in reverse. Every combination of the single genes is made, its look
//   worked out, and the genotypes that give each look are kept per gene.
// - `RecipeTable`: the breeds' public recipes (the breed standard): the genes of every colour a breed
//   is sold or given in.
//
// These tables build test birds from recipes and allele lists. They never read a real bird. So
// `Knowledge` can work on looks and families alone, and never needs a bird's genes.

/// The alleles one bird has at one single gene, without order: two for an autosomal gene or a
/// rooster's Z gene, one for a hen's Z gene. Alleles are in the locus's own order ("Bl/bl+", "lav+/lav").
public struct Genotype: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public let alleles: [String]

    /// `alleles` in any order. They are put in the order of `locus.alleles`.
    public init(_ alleles: [String], at locus: LocusDefinition) {
        let rank = { (a: String) in locus.alleles.firstIndex(of: a) ?? Int.max }
        self.alleles = alleles.sorted { (rank($0), $0) < (rank($1), $1) }
    }

    /// "Bl/bl+", or "B" for a hen's one Z copy.
    public var description: String { alleles.joined(separator: "/") }

    public func count(of allele: String) -> Int { alleles.count(where: { $0 == allele }) }
    public func has(_ allele: String) -> Bool { alleles.contains(allele) }

    public static func < (a: Genotype, b: Genotype) -> Bool { a.alleles.lexicographicallyPrecedes(b.alleles) }

    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        alleles = text.split(separator: "/").map(String.init)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }
}

/// A set of genotypes at one locus, as bits over `GenotypeSpace.genotypes`.
public typealias GenotypeMask = UInt32

/// Every genotype one single gene allows, in a fixed order, and how parents pass them on.
public struct GenotypeSpace: Sendable {
    public let locus: LocusDefinition
    /// Autosomal: every unordered pair. Z-linked: a hen's single copies first, then a rooster's pairs.
    public let genotypes: [Genotype]
    /// Genotypes a hen can have (all of them for an autosomal gene).
    public let henMask: GenotypeMask
    /// Genotypes a rooster can have (all of them for an autosomal gene).
    public let roosterMask: GenotypeMask
    /// `containing[i]`: the genotypes that hold at least one copy of `locus.alleles[i]`.
    public let containing: [GenotypeMask]
    /// `child[m * genotypes.count + f]`: the genotypes a chick of mother `m` and father `f` can have.
    /// Both sexes of chick, for a Z-linked gene. Empty if `m` is not a hen's or `f` not a rooster's.
    private let child: [GenotypeMask]
    /// `children` for every pair of sets, when the gene is small enough: `cross[mothers << n | fathers]`.
    private let cross: [GenotypeMask]
    /// `certain` for every set, when the gene is small enough.
    private let sure: [UInt32]
    /// `genotypes(in:)` for every set, when the gene is small enough.
    private let subsets: [[Genotype]]

    public var allMask: GenotypeMask { henMask | roosterMask }

    init(_ locus: LocusDefinition) {
        self.locus = locus
        let alleles = locus.alleles
        var pairs: [Genotype] = []
        for i in alleles.indices {
            for j in i..<alleles.count { pairs.append(Genotype([alleles[i], alleles[j]], at: locus)) }
        }
        switch locus.inheritance {
        case .autosomal:
            genotypes = pairs
            henMask = GenotypeMask.bits(pairs.count)
            roosterMask = henMask
        case .zLinked:
            genotypes = alleles.map { Genotype([$0], at: locus) } + pairs
            henMask = GenotypeMask.bits(alleles.count)
            roosterMask = GenotypeMask.bits(genotypes.count) & ~henMask
        }
        precondition(genotypes.count <= GenotypeMask.bitWidth, "too many genotypes at \(locus.id)")
        let genotypes = genotypes
        containing = alleles.map { a in
            genotypes.indices.reduce(0) { $0 | (genotypes[$1].has(a) ? 1 << $1 : 0) }
        }
        let index = Dictionary(uniqueKeysWithValues: genotypes.enumerated().map { ($1, $0) })
        func bit(_ alleles: [String]) -> GenotypeMask { 1 << index[Genotype(alleles, at: locus)]! }
        var child = [GenotypeMask](repeating: 0, count: genotypes.count * genotypes.count)
        for (m, mother) in genotypes.enumerated() {
            for (f, father) in genotypes.enumerated() {
                var kids: GenotypeMask = 0
                switch locus.inheritance {
                case .autosomal:
                    for a in mother.alleles { for b in father.alleles { kids |= bit([a, b]) } }
                case .zLinked:
                    // A hen has one Z, a rooster two. A daughter gets her Z from her father only;
                    // a son gets one from each parent.
                    guard mother.alleles.count == 1, father.alleles.count == 2 else { continue }
                    for b in father.alleles { kids |= bit([b]) | bit([mother.alleles[0], b]) }
                }
                child[m * genotypes.count + f] = kids
            }
        }
        self.child = child
        // Look-up tables make the elimination loops cheap. Two alleles give 3 or 5 genotypes,
        // so at most 32 sets and 1,024 pairs of sets.
        let n = genotypes.count
        let sets = n <= 12 ? 1 << n : 0
        let containing = containing
        func certain(_ mask: GenotypeMask) -> UInt32 {
            guard mask != 0 else { return 0 }
            return containing.indices.reduce(0) { mask & ~containing[$1] == 0 ? $0 | 1 << $1 : $0 }
        }
        sure = (0..<sets).map { certain(GenotypeMask($0)) }
        subsets = (0..<sets).map { GenotypeMask($0).indices.map { genotypes[$0] } }
        func slowChildren(_ mothers: GenotypeMask, _ fathers: GenotypeMask) -> GenotypeMask {
            var kids: GenotypeMask = 0
            for m in mothers.indices { for f in fathers.indices { kids |= child[m * n + f] } }
            return kids
        }
        cross =
            n <= 6
            ? (0..<(sets * sets)).map { slowChildren(GenotypeMask($0 >> n), GenotypeMask($0 & (sets - 1))) } : []
    }

    /// The alleles all genotypes in `mask` hold, as bits over `locus.alleles`. None for an empty set.
    public func certain(_ mask: GenotypeMask) -> UInt32 {
        if Int(mask) < sure.count { return sure[Int(mask)] }
        guard mask != 0 else { return 0 }
        return containing.indices.reduce(0) { mask & ~containing[$1] == 0 ? $0 | 1 << $1 : $0 }
    }

    /// The genotypes a bird of this sex can have. Nil sex: either.
    public func mask(for sex: Sex?) -> GenotypeMask {
        switch sex {
        case .hen: henMask
        case .rooster: roosterMask
        case nil: allMask
        }
    }

    /// The index of a genotype, given its alleles in any order.
    public func index(of alleles: [String]) -> Int? { genotypes.firstIndex(of: Genotype(alleles, at: locus)) }

    public func genotypes(in mask: GenotypeMask) -> [Genotype] {
        Int(mask) < subsets.count ? subsets[Int(mask)] : mask.indices.map { genotypes[$0] }
    }

    /// Every genotype a chick can have from some mother in `mothers` and some father in `fathers`.
    public func children(mothers: GenotypeMask, fathers: GenotypeMask) -> GenotypeMask {
        let n = genotypes.count
        if !cross.isEmpty { return cross[Int(mothers) << n | Int(fathers)] }
        // Bit loops, not `indices`: this runs often and must not allocate.
        var kids: GenotypeMask = 0
        var ms = mothers
        while ms != 0 {
            let row = ms.trailingZeroBitCount * n
            ms &= ms - 1
            var fs = fathers
            while fs != 0 {
                kids |= child[row + fs.trailingZeroBitCount]
                fs &= fs - 1
            }
        }
        return kids
    }

    /// The spaces of the single genes, in `Loci.mendelian` order.
    public static let all: [GenotypeSpace] = Loci.mendelian.map(GenotypeSpace.init)
}

extension GenotypeMask {
    /// The lowest `n` bits set.
    static func bits(_ n: Int) -> GenotypeMask { n >= bitWidth ? ~0 : (1 << n) - 1 }

    /// The positions of the set bits, lowest first.
    var indices: [Int] {
        var out: [Int] = []
        var rest = self
        while rest != 0 {
            out.append(rest.trailingZeroBitCount)
            rest &= rest - 1
        }
        return out
    }
}

/// `Phenotype` in reverse: which genotypes of each single gene can give a look.
///
/// Built once by making every combination of the single genes (each sex), working out each one's
/// look with `Phenotype`, and keeping, per look, the genotypes that appear at each gene. The many small
/// genes of the quantitative traits stay at their defaults: they do not change the coarse look
/// (`SeenLook.coarse`).
public enum LookTable {
    /// A look as seen on a bird of a known sex, or of a sex not known yet (nil).
    struct Key: Hashable {
        let sex: Sex?
        let look: SeenLook
    }

    struct Entry {
        var masks: [GenotypeMask]
        /// How many whole combinations give the look. Equal to the product of the per-gene counts
        /// when the look's genotypes are a product set, so the per-gene lists lose nothing.
        var combinations: Int
    }

    static let table: [Key: Entry] = build()

    /// Per single gene (in `Loci.mendelian` order), the genotypes that can show `look` on a bird of
    /// `sex` (nil: sex not known). The egg colour is compared in its coarse form. Nil for a look no
    /// combination of genes gives.
    public static func masks(for look: SeenLook, sex: Sex?) -> [GenotypeMask]? {
        table[Key(sex: sex, look: look.coarse)]?.masks
    }

    /// The same, as genotype sets.
    public static func candidates(for look: SeenLook, sex: Sex?) -> [Set<Genotype>]? {
        masks(for: look, sex: sex).map { zip(GenotypeSpace.all, $0).map { Set($0.genotypes(in: $1)) } }
    }

    /// Looks whose genotypes are not a product set: knowing the look ties two genes together, and the
    /// per-gene lists keep only the looser, per-gene part. Still sound: no genotype that can give the
    /// look is ever dropped. Yellow down is one: it is white (any colour genes) or buff (not white).
    public static var nonProductLooks: [(sex: Sex?, look: SeenLook)] {
        table.compactMap { key, entry in
            let product = entry.masks.reduce(1) { $0 * $1.nonzeroBitCount }
            return product == entry.combinations ? nil : (key.sex, key.look)
        }
    }

    /// Every look of every combination of the single genes, for one sex.
    static func looks(of sex: Sex, _ visit: ([GenotypeMask], [SeenLook]) -> Void) {
        let spaces = GenotypeSpace.all
        let options = spaces.map { $0.mask(for: sex).indices }
        var choice = [Int](repeating: 0, count: spaces.count)
        var genome = Genome(sex: sex)
        for (l, space) in spaces.enumerated() {
            genome.setAlleles(space.genotypes[options[l][0]].alleles, at: space.locus)
        }
        let levels: [LookLevel] = sex == .hen ? [.down, .feathers, .laying] : [.down, .feathers]
        while true {
            let p = Phenotype(genome)
            let bits = spaces.indices.map { GenotypeMask(1) << options[$0][choice[$0]] }
            visit(bits, levels.map { SeenLook(p, level: $0).coarse })
            // Next combination, odometer style: only the genes that change are set again.
            var l = spaces.count - 1
            while l >= 0 {
                choice[l] += 1
                if choice[l] < options[l].count { break }
                choice[l] = 0
                genome.setAlleles(spaces[l].genotypes[options[l][0]].alleles, at: spaces[l].locus)
                l -= 1
            }
            if l < 0 { return }
            genome.setAlleles(spaces[l].genotypes[options[l][choice[l]]].alleles, at: spaces[l].locus)
        }
    }

    private static func build() -> [Key: Entry] {
        var table: [Key: Entry] = [:]
        func add(_ key: Key, _ bits: [GenotypeMask]) {
            if var e = table[key] {
                for i in bits.indices { e.masks[i] |= bits[i] }
                e.combinations += 1
                table[key] = e
            } else {
                table[key] = Entry(masks: bits, combinations: 1)
            }
        }
        for sex in Sex.allCases {
            looks(of: sex) { bits, seen in
                for look in seen {
                    add(Key(sex: sex, look: look), bits)
                    add(Key(sex: nil, look: look), bits)
                }
            }
        }
        return table
    }
}

/// One public recipe: a purebred of one breed, sex and colour, as the breed standard describes it.
public struct Recipe: Hashable, Sendable {
    public let breed: Breed
    public let sex: Sex
    public let variety: String
    public let barred: Bool
    /// Per single gene (in `Loci.mendelian` order), the one genotype the recipe gives.
    public let genotypes: [Genotype]
    /// The same, as one bit per gene.
    public let masks: [GenotypeMask]
    /// The coarse look at each level. No laying look for a rooster.
    let down: SeenLook
    let feathers: SeenLook
    let laying: SeenLook?

    /// What a keeper would see of this recipe at `level`. Nil for `.laying` on a rooster.
    public func look(at level: LookLevel) -> SeenLook? {
        switch level {
        case .down: down
        case .feathers: feathers
        case .laying: laying
        }
    }
}

/// The breeds' public recipes: what a bird from outside the flock can be.
///
/// Every bird bred outside the flock (a starter, a shop bird, a gift, a parent of a bought egg) is a
/// purebred made from one of these. For each breed and sex: every colour variety of the breed, and
/// every colour the shop's daily special can name on it, each with and without barring.
public enum RecipeTable {
    public static let all: [Recipe] = BreedTable.all.flatMap { def in
        let specials = FeatherColour.allCases.map { ShopSpecial.variety(for: $0, on: def.id) }
        var varieties: [ColourVariety] = []
        for v in def.varieties + specials where !varieties.contains(v) { varieties.append(v) }
        return Sex.allCases.flatMap { sex in
            varieties.flatMap { variety in
                [false, true].map { barred in recipe(def.id, sex, variety, barred: barred) }
            }
        }
    }

    /// The recipes for a breed and sex. Nil breed or sex: any.
    public static func recipes(breed: Breed?, sex: Sex?) -> [Recipe] {
        if let breed, let sex { return byBreedAndSex[BreedAndSex(breed: breed, sex: sex)] ?? [] }
        return all.filter { (breed == nil || $0.breed == breed) && (sex == nil || $0.sex == sex) }
    }

    private struct BreedAndSex: Hashable {
        let breed: Breed
        let sex: Sex
    }

    private static let byBreedAndSex = Dictionary(grouping: all) { BreedAndSex(breed: $0.breed, sex: $0.sex) }

    private static func recipe(_ breed: Breed, _ sex: Sex, _ variety: ColourVariety, barred: Bool) -> Recipe {
        let made = breed.purebred(sex, variety: variety, barred: barred)
        let p = Phenotype(made)
        let genotypes = GenotypeSpace.all.map { Genotype(made.alleles(at: $0.locus), at: $0.locus) }
        let masks = zip(GenotypeSpace.all, genotypes).map { space, g in
            GenotypeMask(1) << space.genotypes.firstIndex(of: g)!
        }
        return Recipe(
            breed: breed, sex: sex, variety: variety.id, barred: barred, genotypes: genotypes, masks: masks,
            down: SeenLook(p, level: .down).coarse, feathers: SeenLook(p, level: .feathers).coarse,
            laying: sex == .hen ? SeenLook(p, level: .laying).coarse : nil)
    }
}
