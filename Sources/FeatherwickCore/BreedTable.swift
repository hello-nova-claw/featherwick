// The breed table and the colour varieties.
//
// To add a breed:
//   1. Add a static id on `Breed` (lower case, the name keepers use).
//   2. Add one `BreedDefinition` to `BreedTable.all`, with status `.planned`.
//   3. When its art is ready, change the status to `.inGame`.
// The realism tests check every entry, planned ones too.
//
// To add a colour variety: add a `ColourVariety` below and list it on the breeds that come in it.
// If it needs a new gene, add the gene first (see Locus.swift).

/// A breed's id. Written to saves. Never rename one.
public struct Breed: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible
{
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { rawValue = value }
    public var description: String { rawValue }

    // In the game now
    public static let silkie: Breed = "silkie"
    public static let orpington: Breed = "orpington"
    public static let wyandotte: Breed = "wyandotte"
    public static let araucana: Breed = "araucana"
    // Planned
    public static let australorp: Breed = "australorp"
    public static let plymouthRock: Breed = "plymouth rock"
    public static let marans: Breed = "marans"
    public static let leghorn: Breed = "leghorn"

    /// Breeds in the game now, in table order. Planned breeds are not included.
    public static var allCases: [Breed] { BreedTable.inGame.map(\.id) }

    /// The neighbour's breeds: in the game, and marked as a starter.
    public static var starters: [Breed] { BreedTable.inGame.filter(\.isStarter).map(\.id) }

    /// This breed's table entry. An id that is not in the table (for example from a newer save)
    /// gets a plain placeholder entry, so the game never crashes on it.
    public var definition: BreedDefinition { BreedTable.definition(self) ?? .placeholder(self) }
}

/// Alleles to put at one gene. Table entries use this, so they cannot name a gene or allele that does not exist.
public struct GeneSetting: Hashable, Sendable {
    public let locus: LocusID
    /// Autosomal genes: the two alleles. Z-linked genes: a hen gets `first`, a rooster gets both.
    public let first: String
    public let second: String

    /// Two copies of one allele. A breed's signature genes use this, so the breed breeds true.
    public static func two<G: GeneLocus>(_ allele: G) -> GeneSetting {
        GeneSetting(locus: G.locus, first: allele.rawValue, second: allele.rawValue)
    }

    /// Two different alleles, in this order. Order matters for seeded breeding.
    public static func pair<G: GeneLocus>(_ a: G, _ b: G) -> GeneSetting {
        GeneSetting(locus: G.locus, first: a.rawValue, second: b.rawValue)
    }

    public func apply(to genome: inout Genome) {
        guard let def = Loci.definition(locus) else { return }
        switch def.inheritance {
        case .autosomal: genome.setAlleles([first, second], at: def)
        case .zLinked: genome.setAlleles(genome.sex == .hen ? [first] : [first, second], at: def)
        }
    }
}

/// A named colour a breed comes in, as a recipe of genes on top of the breed's signature.
/// The colour a bird SHOWS is always worked out from its genes (Phenotype), never from this name.
public struct ColourVariety: Hashable, Sendable, Identifiable {
    public let id: String
    public let genes: [GeneSetting]

    public init(_ id: String, _ genes: [GeneSetting]) {
        self.id = id
        self.genes = genes
    }

    public static let black = ColourVariety("black", [])
    /// Bl/bl+: real blue birds carry one copy, so blue × blue hatches black, blue and splash.
    public static let blue = ColourVariety("blue", [.pair(BlueDilution.blue, .notBlue)])
    public static let buff = ColourVariety("buff", [.two(BaseColour.buff)])
    public static let lavender = ColourVariety("lavender", [.two(Lavender.lavender)])
    public static let barred = ColourVariety("barred", [.two(Barring.barred)])
    /// I/I: two copies of dominant white, so the variety breeds true. The white hides the black
    /// underneath, which still passes on. Real White Leghorns are made this way.
    /// SIMPLIFIED: real white Silkies and white Orpingtons are mostly recessive white (c/c).
    /// The game has no recessive white gene yet, so they use dominant white too.
    public static let white = ColourVariety("white", [.two(DominantWhite.white)])

    public static let all: [ColourVariety] = [black, blue, buff, lavender, barred, white]
}

/// Everything the game knows about one breed.
public struct BreedDefinition: Sendable, Identifiable {
    public enum Status: String, Hashable, Sendable {
        /// Playable: can hatch, be sold and appear in the Breed Book.
        case inGame
        /// In the table and tested, but no bird of this breed can appear yet.
        case planned
    }

    public let id: Breed
    public let displayName: String
    public let status: Status
    /// The neighbour offers this breed as a starter chick.
    public let isStarter: Bool
    /// Genes every bird of the breed has two copies of. These make the breed breed true.
    public let signature: [GeneSetting]
    /// Colours the breed comes in. The first is the default. Starters draw from all of them.
    public let varieties: [ColourVariety]
    /// Chance per day that an adult hen goes broody.
    public let broodiness: Double
    /// Temperament: the share of calm genes in birds bred outside the player's flock, 0...1.
    public let calmness: Double
    /// Shell depth: the share of brown-depth genes, 0...1. Purebreds get exactly this share;
    /// birds bred outside the player's flock draw each gene with this chance. 0.5 is average.
    public var brownDepth: Double = 0.5
    /// Which shared art parts the breed uses, its skin colours and its size.
    public let look: BreedLook
    public let note: String

    public var isInGame: Bool { status == .inGame }

    /// True if every bird of the breed has two copies of this allele.
    public func fixes<G: GeneLocus>(_ allele: G) -> Bool { signature.contains(.two(allele)) }

    /// The egg colour a purebred hen lays. Worked out from the genes, not typed in.
    public var eggColour: EggColour { Phenotype(id.purebred(.hen)).eggColour ?? .cream }

    static func placeholder(_ id: Breed) -> BreedDefinition {
        BreedDefinition(
            id: id, displayName: id.rawValue.capitalized, status: .planned, isStarter: false,
            signature: [], varieties: [.black], broodiness: 0.2, calmness: 0.5,
            look: .mixed,
            note: "Not in this version of the game.")
    }
}

public enum BreedTable {
    /// ORDER MATTERS for in-game breeds: starters and shop birds are drawn in this order.
    /// Add new breeds at the END.
    public static let all: [BreedDefinition] = [
        BreedDefinition(
            id: .silkie, displayName: "Silkie", status: .inGame, isStarter: false,
            signature: [.two(Feathering.silkie)],
            varieties: [.black, .blue, .buff, .lavender, .white], broodiness: 0.6, calmness: 0.75, brownDepth: 0.2,
            look: BreedLook(
                body: .fluffy, comb: .walnut, combTone: .mulberry, legs: .featheredFiveToe, legTone: .slate,
                head: .crested, size: 0.7),
            note: "Fluffy, gentle, famously broody. Cream eggs."),
        BreedDefinition(
            id: .orpington, displayName: "Orpington", status: .inGame, isStarter: true,
            signature: [.two(BrownShell.brown)],
            varieties: [.black, .blue, .buff, .lavender, .white], broodiness: 0.3, calmness: 0.7,
            look: BreedLook(body: .heavy, comb: .single, legTone: .slate, legToneOnBuff: .white, size: 1.2),
            note: "Big, soft and calm. Brown eggs."),
        BreedDefinition(
            id: .wyandotte, displayName: "Wyandotte", status: .inGame, isStarter: true,
            signature: [.two(Lacing.laced), .two(BrownShell.brown)],
            varieties: [.black, .blue, .buff, .lavender], broodiness: 0.15, calmness: 0.55,
            look: BreedLook(body: .medium, comb: .rose, legTone: .yellow, size: 1.0),
            note: "Carries lacing; it shows on gold (buff) birds. Brown eggs."),
        BreedDefinition(
            id: .araucana, displayName: "Araucana", status: .inGame, isStarter: true,
            signature: [.two(BlueShell.blue)],
            varieties: [.black, .blue, .buff, .lavender], broodiness: 0.2, calmness: 0.4, brownDepth: 0.2,
            look: BreedLook(body: .light, comb: .pea, legTone: .willow, size: 0.85),
            note: "Lays blue eggs. Crossed with brown-egg breeds, makes olive eggers."),
        BreedDefinition(
            id: .australorp, displayName: "Australorp", status: .inGame, isStarter: false,
            signature: [.two(BrownShell.brown)],
            varieties: [.black, .blue], broodiness: 0.25, calmness: 0.65,
            look: BreedLook(body: .heavy, comb: .single, legTone: .slate, size: 1.1),
            note: "Australian. Black with a green sheen, a famous layer. Brown eggs. "
                + "Not a starter: comes to Featherwick through the heritage-breed storyline."),
        BreedDefinition(
            id: .plymouthRock, displayName: "Plymouth Rock", status: .planned, isStarter: false,
            signature: [.two(BrownShell.brown)],
            varieties: [.barred, .buff], broodiness: 0.2, calmness: 0.6,
            look: BreedLook(body: .medium, comb: .single, legTone: .yellow, size: 1.1),
            note: "The Barred Rock. Black-and-white barring. Brown eggs."),
        BreedDefinition(
            id: .marans, displayName: "Marans", status: .planned, isStarter: false,
            signature: [.two(BrownShell.brown)],
            varieties: [.black], broodiness: 0.2, calmness: 0.6, brownDepth: 0.9,
            look: BreedLook(body: .heavy, comb: .single, legTone: .slate, size: 1.1),
            note: "French. Famous for very dark chocolate eggs. Crossed with blue-egg breeds, "
                + "makes the darkest olive eggers."),
        // Real White Leghorns: dominant white (I/I) over extended black (E, the default), single comb,
        // clean yellow legs, small and flighty, rarely broody. They lay white eggs: no blue or brown
        // shell genes, and no shell depth (at or below `Rules.whiteShellDepth`).
        BreedDefinition(
            id: .leghorn, displayName: "Leghorn", status: .planned, isStarter: false,
            signature: [],
            varieties: [.white], broodiness: 0.05, calmness: 0.3, brownDepth: 0,
            look: BreedLook(body: .light, comb: .single, legTone: .yellow, size: 0.8),
            note: "Italian. White, light and lively. A famous layer of white eggs."),
    ]

    public static var inGame: [BreedDefinition] { all.filter(\.isInGame) }

    public static func definition(_ id: Breed) -> BreedDefinition? { all.first { $0.id == id } }
}

extension Breed {
    /// A true-breeding bird of this breed: default genes, then the breed's signature and shell depth,
    /// then the variety.
    public func purebred(_ sex: Sex, variety: ColourVariety? = nil, barred: Bool = false) -> Genome {
        let def = definition
        var genome = Genome(sex: sex)
        for gene in def.signature { gene.apply(to: &genome) }
        QuantitativeTrait.brownDepth.setShare(def.brownDepth, in: &genome)
        for gene in (variety ?? def.varieties.first ?? .black).genes { gene.apply(to: &genome) }
        if barred { GeneSetting.two(Barring.barred).apply(to: &genome) }
        return genome
    }

    /// The same, for the four colours the neighbour's starters come in.
    public func purebred(_ sex: Sex, colour: StarterColour, barred: Bool = false) -> Genome {
        purebred(sex, variety: colour.variety, barred: barred)
    }
}
