/// Two alleles at one autosomal locus: one from the mother, one from the father.
///
/// Note: equality is order-sensitive, so (H, h) != (h, H).
/// Use `count(of:)` when you compare genotypes.
public struct AllelePair<Allele: Hashable & Codable & Sendable>: Hashable, Codable, Sendable {
    public var first: Allele
    public var second: Allele

    public init(_ first: Allele, _ second: Allele) {
        self.first = first
        self.second = second
    }

    public static func homozygous(_ allele: Allele) -> AllelePair {
        AllelePair(allele, allele)
    }

    public func count(of allele: Allele) -> Int {
        (first == allele ? 1 : 0) + (second == allele ? 1 : 0)
    }

    public func has(_ allele: Allele) -> Bool {
        count(of: allele) > 0
    }

    public func isHomozygous(for allele: Allele) -> Bool {
        count(of: allele) == 2
    }

    /// One allele, chosen 50/50, as passed on in an egg or sperm cell.
    func gamete<R: RandomNumberGenerator>(using rng: inout R) -> Allele {
        Bool.random(using: &rng) ? first : second
    }

    /// Mendelian cross for one locus. Mother's allele first.
    static func cross<R: RandomNumberGenerator>(
        mother: AllelePair, father: AllelePair, using rng: inout R
    ) -> AllelePair {
        AllelePair(mother.gamete(using: &rng), father.gamete(using: &rng))
    }
}

public enum Sex: String, Hashable, Codable, Sendable, CaseIterable {
    case hen
    case rooster
}

/// Sex chromosomes and the Z-linked genes on them.
///
/// Birds are the opposite of mammals: hens are ZW, roosters are ZZ.
/// The mother decides the sex of the chick.
public enum SexChromosomes: Hashable, Codable, Sendable {
    /// ZW. One copy of each Z-linked gene.
    case hen(z: Barring)
    /// ZZ. Two copies of each Z-linked gene.
    case rooster(z: AllelePair<Barring>)

    public var sex: Sex {
        switch self {
        case .hen: .hen
        case .rooster: .rooster
        }
    }

    /// SIMPLIFIED: in real roosters, two copies of barring look lighter than one.
    public var isBarred: Bool {
        switch self {
        case .hen(let z): z == .barred
        case .rooster(let zz): zz.has(.barred)
        }
    }
}

/// The genome of one bird, stored gene by gene (see `Loci`).
///
/// Only genes that differ from their default allele are stored. A gene the genome does not
/// mention has its default alleles. So adding a gene to the registry changes no existing bird,
/// and old saves load without a migration.
public struct Genome: Hashable, Codable, Sendable {
    public private(set) var sex: Sex
    /// Autosomal genes by locus name. Missing = two default alleles. Mother's allele first.
    private var autosomal: [String: AllelePair<String>]
    /// Z-linked genes by locus name: one allele for a hen, two for a rooster. Missing = default.
    private var z: [String: [String]]

    private enum CodingKeys: String, CodingKey { case sex, autosomal, z }

    /// A bird with the default allele at every gene.
    public init(sex: Sex) {
        self.sex = sex
        autosomal = [:]
        z = [:]
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sex = try c.decode(Sex.self, forKey: .sex)
        autosomal = try c.decodeIfPresent([String: AllelePair<String>].self, forKey: .autosomal) ?? [:]
        z = try c.decodeIfPresent([String: [String]].self, forKey: .z) ?? [:]
        normalise()
    }

    /// Removes default entries and bad data, so that equal birds compare equal.
    /// A known gene with an unknown allele falls back to the default. Unknown genes are kept as they are.
    private mutating func normalise() {
        for (key, pair) in autosomal {
            guard let locus = Loci.definition(LocusID(rawValue: key)) else { continue }
            let valid = locus.isValid(pair.first) && locus.isValid(pair.second)
            if !valid || pair.isHomozygous(for: locus.defaultAllele) { autosomal[key] = nil }
        }
        for (key, alleles) in z {
            guard let locus = Loci.definition(LocusID(rawValue: key)) else { continue }
            let valid = alleles.count == zCount && alleles.allSatisfy(locus.isValid)
            if !valid || alleles.allSatisfy({ $0 == locus.defaultAllele }) { z[key] = nil }
        }
    }

    /// Copies of each Z-linked gene: hens 1, roosters 2.
    private var zCount: Int { sex == .hen ? 1 : 2 }

    // MARK: Typed access

    /// The two alleles of an autosomal gene.
    public subscript<G: GeneLocus>(_ gene: G.Type) -> AllelePair<G> {
        get {
            precondition(G.inheritance == .autosomal, "\(G.locus) is Z-linked: use zAlleles")
            guard let raw = autosomal[G.locus.rawValue],
                let a = G(rawValue: raw.first), let b = G(rawValue: raw.second)
            else { return .homozygous(G.defaultAllele) }
            return AllelePair(a, b)
        }
        set {
            precondition(G.inheritance == .autosomal, "\(G.locus) is Z-linked: use setZAlleles")
            let raw = AllelePair(newValue.first.rawValue, newValue.second.rawValue)
            autosomal[G.locus.rawValue] = raw.isHomozygous(for: G.defaultAllele.rawValue) ? nil : raw
        }
    }

    /// The alleles of a Z-linked gene: one for a hen, two for a rooster.
    public func zAlleles<G: GeneLocus>(_ gene: G.Type) -> [G] {
        precondition(G.inheritance == .zLinked, "\(G.locus) is autosomal: use the subscript")
        let parsed = (z[G.locus.rawValue] ?? []).compactMap(G.init(rawValue:))
        return parsed.count == zCount ? parsed : Array(repeating: G.defaultAllele, count: zCount)
    }

    /// Sets a Z-linked gene. Give one allele for a hen, two for a rooster.
    public mutating func setZAlleles<G: GeneLocus>(_ alleles: [G]) {
        precondition(G.inheritance == .zLinked, "\(G.locus) is autosomal: use the subscript")
        precondition(alleles.count == zCount, "a \(sex) has \(zCount) Z copies")
        z[G.locus.rawValue] = alleles.allSatisfy { $0 == G.defaultAllele } ? nil : alleles.map(\.rawValue)
    }

    // MARK: Untyped access, by registry entry (breeding, breed tables, tools)

    /// The alleles at one locus as breeder notation: two for autosomal genes, one or two for Z-linked.
    public func alleles(at locus: LocusDefinition) -> [String] {
        switch locus.inheritance {
        case .autosomal:
            let p = autosomal[locus.id.rawValue] ?? .homozygous(locus.defaultAllele)
            return [p.first, p.second]
        case .zLinked:
            let raw = z[locus.id.rawValue] ?? []
            return raw.count == zCount ? raw : Array(repeating: locus.defaultAllele, count: zCount)
        }
    }

    /// Sets the alleles at one locus. Invalid input is ignored, so a bad table entry cannot make a bad bird.
    public mutating func setAlleles(_ alleles: [String], at locus: LocusDefinition) {
        guard alleles.allSatisfy(locus.isValid) else { return }
        let key = locus.id.rawValue
        let isDefault = alleles.allSatisfy { $0 == locus.defaultAllele }
        switch locus.inheritance {
        case .autosomal:
            guard alleles.count == 2 else { return }
            autosomal[key] = isDefault ? nil : AllelePair(alleles[0], alleles[1])
        case .zLinked:
            guard alleles.count == zCount else { return }
            z[key] = isDefault ? nil : alleles
        }
    }

    /// Changes sex. Z-linked genes keep their first copy (a new rooster gets two of it).
    private mutating func changeSex(to newSex: Sex) {
        guard newSex != sex else { return }
        let firstCopies = z.compactMapValues(\.first)
        sex = newSex
        z = firstCopies.mapValues { Array(repeating: $0, count: zCount) }
        normalise()
    }

    // MARK: Named genes (short forms for the genes the game uses now)

    public var feathering: AllelePair<Feathering> {
        get { self[Feathering.self] }
        set { self[Feathering.self] = newValue }
    }
    public var baseColour: AllelePair<BaseColour> {
        get { self[BaseColour.self] }
        set { self[BaseColour.self] = newValue }
    }
    public var blue: AllelePair<BlueDilution> {
        get { self[BlueDilution.self] }
        set { self[BlueDilution.self] = newValue }
    }
    public var lavender: AllelePair<Lavender> {
        get { self[Lavender.self] }
        set { self[Lavender.self] = newValue }
    }
    public var lacing: AllelePair<Lacing> {
        get { self[Lacing.self] }
        set { self[Lacing.self] = newValue }
    }
    public var blueShell: AllelePair<BlueShell> {
        get { self[BlueShell.self] }
        set { self[BlueShell.self] = newValue }
    }
    public var brownShell: AllelePair<BrownShell> {
        get { self[BrownShell.self] }
        set { self[BrownShell.self] = newValue }
    }
    public var speckle: AllelePair<Speckle> {
        get { self[Speckle.self] }
        set { self[Speckle.self] = newValue }
    }

    public var dominantWhite: AllelePair<DominantWhite> {
        get { self[DominantWhite.self] }
        set { self[DominantWhite.self] = newValue }
    }

    /// Sex and barring together. Setting it can change the sex.
    public var sexChromosomes: SexChromosomes {
        get {
            let b = zAlleles(Barring.self)
            return sex == .hen ? .hen(z: b[0]) : .rooster(z: AllelePair(b[0], b[1]))
        }
        set {
            changeSex(to: newValue.sex)
            switch newValue {
            case .hen(let b): setZAlleles([b])
            case .rooster(let bb): setZAlleles([bb.first, bb.second])
            }
        }
    }

    /// Every current gene given explicitly.
    public init(
        sexChromosomes: SexChromosomes,
        feathering: AllelePair<Feathering>,
        baseColour: AllelePair<BaseColour>,
        blue: AllelePair<BlueDilution>,
        lavender: AllelePair<Lavender>,
        lacing: AllelePair<Lacing>,
        blueShell: AllelePair<BlueShell>,
        brownShell: AllelePair<BrownShell>,
        speckle: AllelePair<Speckle>
    ) {
        self.init(sex: sexChromosomes.sex)
        self.sexChromosomes = sexChromosomes
        self.feathering = feathering
        self.baseColour = baseColour
        self.blue = blue
        self.lavender = lavender
        self.lacing = lacing
        self.blueShell = blueShell
        self.brownShell = brownShell
        self.speckle = speckle
    }
}
