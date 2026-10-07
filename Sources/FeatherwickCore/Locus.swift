// The gene registry.
//
// Each gene (locus) is one enum of alleles that conforms to `GeneLocus`, plus one entry in `Loci`.
// A genome stores only the loci where a bird differs from the default allele.
// So a save made before a gene existed still loads: the bird simply has the default alleles.
//
// To add a gene:
//   1. Add an allele enum in Alleles.swift that conforms to `GeneLocus`.
//   2. Add it at the END of `Loci.autosomal` or `Loci.zLinked`.
//   3. Say how it looks in Phenotype.swift.
// No save migration is needed.

/// The name of one gene in the registry and in saves. Never rename one: saves use it.
public struct LocusID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral,
    CustomStringConvertible
{
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { rawValue = value }
    public var description: String { rawValue }
}

public enum Inheritance: String, Hashable, Codable, Sendable {
    /// Two copies in every bird, one from each parent.
    case autosomal
    /// On the Z chromosome. Hens (ZW) have one copy, roosters (ZZ) two.
    case zLinked
}

/// An allele enum for one gene. Raw values are breeder notation and are written to saves.
public protocol GeneLocus: RawRepresentable, Hashable, Codable, Sendable, CaseIterable where RawValue == String {
    static var locus: LocusID { get }
    static var inheritance: Inheritance { get }
    /// The allele a bird has when the genome does not mention this gene.
    /// Use the plain, common form, so that old birds look the same after a gene is added.
    static var defaultAllele: Self { get }
}

extension GeneLocus {
    public static var inheritance: Inheritance { .autosomal }
}

/// One gene in the registry, without its Swift type. For tools, tests and save checks.
public struct LocusDefinition: Sendable, Identifiable {
    public let id: LocusID
    public let inheritance: Inheritance
    public let alleles: [String]
    public let defaultAllele: String
    public let summary: String

    public init<G: GeneLocus>(_ type: G.Type, _ summary: String) {
        id = G.locus
        inheritance = G.inheritance
        alleles = G.allCases.map(\.rawValue)
        defaultAllele = G.defaultAllele.rawValue
        self.summary = summary
    }

    /// A gene without its own allele enum. Used for the many small genes behind a quantitative trait.
    public init(
        id: LocusID, inheritance: Inheritance = .autosomal, alleles: [String], defaultAllele: String, summary: String
    ) {
        self.id = id
        self.inheritance = inheritance
        self.alleles = alleles
        self.defaultAllele = defaultAllele
        self.summary = summary
    }

    public func isValid(_ allele: String) -> Bool { alleles.contains(allele) }
}

/// Every gene in the game.
///
/// ORDER MATTERS: breeding draws random numbers in this order, so a seed always gives the same chick.
/// Add new genes at the END of a list. Then old seeds still give the same alleles for the old genes.
public enum Loci {
    public static let zLinked: [LocusDefinition] = [
        LocusDefinition(Barring.self, "Barring. Dominant, sex-linked.")
    ]

    public static let autosomal: [LocusDefinition] =
        [
            LocusDefinition(Feathering.self, "Silkie feathering. Recessive."),
            LocusDefinition(BaseColour.self, "Base colour. Black over buff."),
            LocusDefinition(BlueDilution.self, "Blue. One copy blue, two copies splash."),
            LocusDefinition(Lavender.self, "Lavender. Recessive dilution of black."),
            LocusDefinition(Lacing.self, "Lacing. Recessive; shows on buff only."),
            LocusDefinition(BlueShell.self, "Blue eggshell. Dominant."),
            LocusDefinition(BrownShell.self, "Brown shell coating. Dominant."),
            LocusDefinition(Speckle.self, "Speckled eggs. Game-only, recessive."),
        ] + QuantitativeTrait.showType.loci + QuantitativeTrait.eggShape.loci
        + QuantitativeTrait.calm.loci + QuantitativeTrait.brownDepth.loci
        + [LocusDefinition(DominantWhite.self, "Dominant white. Dominant; hides the other colour genes.")]

    public static let all: [LocusDefinition] = zLinked + autosomal

    /// The single genes with a look of their own (colour, pattern, feathering, eggs), in `all` order.
    /// Every gene that is not one of the many small genes behind a `QuantitativeTrait`. Worked out, not
    /// listed, so a new single gene appended to `Loci` is picked up by `Knowledge` at once.
    public static let mendelian: [LocusDefinition] = {
        let quantitative = Set(QuantitativeTrait.all.flatMap { $0.loci.map(\.id) })
        return all.filter { !quantitative.contains($0.id) }
    }()

    private static let byID: [LocusID: LocusDefinition] =
        Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    public static func definition(_ id: LocusID) -> LocusDefinition? { byID[id] }
}
