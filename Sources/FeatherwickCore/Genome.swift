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

/// The full v1 genome of one bird.
public struct Genome: Hashable, Codable, Sendable {
    public var sexChromosomes: SexChromosomes
    public var feathering: AllelePair<Feathering>
    public var baseColour: AllelePair<BaseColour>
    public var blue: AllelePair<BlueDilution>
    public var lavender: AllelePair<Lavender>
    public var lacing: AllelePair<Lacing>
    public var blueShell: AllelePair<BlueShell>
    public var brownShell: AllelePair<BrownShell>
    public var speckle: AllelePair<Speckle>

    public var sex: Sex { sexChromosomes.sex }

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
