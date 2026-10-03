// Alleles for each locus in the v1 genome.
//
// Real poultry genetics, simplified where marked. Cozy rule: no lethal genes.
// Raw values use common breeder notation where one exists.

/// Silkie feathering. Recessive: a bird needs two copies to show it.
public enum Feathering: String, Hashable, Codable, Sendable, CaseIterable {
    case normal = "H"
    case silkie = "h"
}

/// Base colour. SIMPLIFIED: real buff comes from several loci (E locus, Columbian, gold).
/// Here, black is dominant over buff.
public enum BaseColour: String, Hashable, Codable, Sendable, CaseIterable {
    case black = "E"
    case buff = "e"
}

/// Blue dilution. Incomplete dominance on a black base:
/// 0 copies = black, 1 copy = blue, 2 copies = splash.
public enum BlueDilution: String, Hashable, Codable, Sendable, CaseIterable {
    case blue = "Bl"
    case notBlue = "bl+"
}

/// Lavender (self-blue). Recessive. Dilutes black to lavender.
public enum Lavender: String, Hashable, Codable, Sendable, CaseIterable {
    case normal = "lav+"
    case lavender = "lav"
}

/// Lacing. SIMPLIFIED: real lacing needs Pattern (Pg), Columbian (Co) and Melanotic (Ml) together.
/// Here it is one recessive stand-in.
public enum Lacing: String, Hashable, Codable, Sendable, CaseIterable {
    case solid = "lc+"
    case laced = "lc"
}

/// Barring. Sex-linked (on the Z chromosome) and dominant.
/// Hens have one Z, roosters have two.
public enum Barring: String, Hashable, Codable, Sendable, CaseIterable {
    case barred = "B"
    case plain = "b+"
}

/// Blue eggshell (oocyan). Dominant: one copy gives a blue shell.
public enum BlueShell: String, Hashable, Codable, Sendable, CaseIterable {
    case blue = "O"
    case white = "o+"
}

/// Brown shell coating. SIMPLIFIED: real brown is polygenic (many genes, many shades).
/// Here it is one dominant gene. Brown coating on a blue shell gives olive.
public enum BrownShell: String, Hashable, Codable, Sendable, CaseIterable {
    case brown = "Br"
    case noCoating = "br"
}

/// Speckled eggs. GAME-ONLY gene, not a real single locus. Recessive.
public enum Speckle: String, Hashable, Codable, Sendable, CaseIterable {
    case plain = "sp+"
    case speckled = "sp"
}

// MARK: - Registry conformances
//
// Locus names are written to saves. Never rename one.
// Default alleles are the plain forms: a bird with no entry for a gene looks plain for that gene.

extension Feathering: GeneLocus {
    public static let locus: LocusID = "feathering"
    public static let defaultAllele = Feathering.normal
}

extension BaseColour: GeneLocus {
    public static let locus: LocusID = "baseColour"
    public static let defaultAllele = BaseColour.black
}

extension BlueDilution: GeneLocus {
    public static let locus: LocusID = "blue"
    public static let defaultAllele = BlueDilution.notBlue
}

extension Lavender: GeneLocus {
    public static let locus: LocusID = "lavender"
    public static let defaultAllele = Lavender.normal
}

extension Lacing: GeneLocus {
    public static let locus: LocusID = "lacing"
    public static let defaultAllele = Lacing.solid
}

extension Barring: GeneLocus {
    public static let locus: LocusID = "barring"
    public static let inheritance = Inheritance.zLinked
    public static let defaultAllele = Barring.plain
}

extension BlueShell: GeneLocus {
    public static let locus: LocusID = "blueShell"
    public static let defaultAllele = BlueShell.white
}

extension BrownShell: GeneLocus {
    public static let locus: LocusID = "brownShell"
    public static let defaultAllele = BrownShell.noCoating
}

extension Speckle: GeneLocus {
    public static let locus: LocusID = "speckle"
    public static let defaultAllele = Speckle.plain
}
