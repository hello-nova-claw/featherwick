public enum FeatherColour: String, Hashable, Codable, Sendable, CaseIterable {
    // New colours go at the end, because the shop special draws its colours in this order.
    // That alone does not keep old seeds: a new variety on an in-game breed also grows the pools that
    // starters, shop birds, gifts and show rivals draw from, so every seed changes from day 0.
    case black, blue, splash, lavender, buff, white
}

public enum EggColour: String, Hashable, Codable, Sendable, CaseIterable {
    case cream, brown, blue, olive
    /// Very dark brown, like a Marans egg: brown coating with high depth.
    case chocolate
    /// Brown coating with low depth over a blue shell. Darker coating gives olive.
    case green
    /// The bare shell, with almost no tint: no blue, no brown coating and very low depth, like a Leghorn egg.
    case white
}

/// How a chick's down looks. Shows the colour genes, not the breed.
public enum ChickDown: String, Hashable, Codable, Sendable, CaseIterable {
    case black  // often with a pale belly
    case slate  // blue
    case paleGrey  // splash
    case silver  // lavender
    case yellow  // buff, and dominant white
    case darkWithHeadSpot  // barred
}

extension Phenotype {
    public var chickDown: ChickDown {
        if isBarred { return .darkWithHeadSpot }
        switch colour {
        case .black: return .black
        case .blue: return .slate
        case .splash: return .paleGrey
        case .lavender: return .silver
        case .buff, .white: return .yellow
        }
    }
}

/// What a bird looks like and lays, computed from its genome.
/// The UI and the Breed Book read this. They never read genes directly.
public struct Phenotype: Hashable, Codable, Sendable {
    public let sex: Sex
    public let isSilkieFeathered: Bool
    public let colour: FeatherColour
    public let isBarred: Bool
    public let isLaced: Bool
    /// Nil for roosters: they carry egg genes and pass them on, but do not lay.
    public let eggColour: EggColour?
    public let eggIsSpeckled: Bool

    public init(_ genome: Genome) {
        sex = genome.sex
        isSilkieFeathered = genome.feathering.isHomozygous(for: .silkie)

        // Colour order: dominant white hides everything; buff hides the black-based dilutions;
        // lavender wins over blue. A white bird still carries its other colour genes.
        if genome.dominantWhite.has(.white) {
            colour = .white
        } else if genome.baseColour.isHomozygous(for: .buff) {
            colour = .buff
        } else if genome.lavender.isHomozygous(for: .lavender) {
            colour = .lavender
        } else {
            switch genome.blue.count(of: .blue) {
            case 0: colour = .black
            case 1: colour = .blue
            default: colour = .splash
            }
        }

        // Patterns only show on the right ground colour, as in real chickens. The genes are still
        // carried and passed on, so hidden patterns can reappear in chicks.
        // Lacing needs a gold (buff) ground; barring shows only on black-based birds. Dominant white
        // hides both, so a white bird never shows (or names) a pattern it carries.
        isLaced = colour == .buff && genome.lacing.isHomozygous(for: .laced)
        isBarred = colour != .buff && colour != .white && genome.sexChromosomes.isBarred

        if sex == .hen {
            let blueShell = genome.blueShell.has(.blue)
            let brownCoat = genome.brownShell.has(.brown)
            // Depth sets how dark the brown coating is. With no coating it is the faint tint that
            // makes a shell cream, not white. An average bird (and every bird from a save made
            // before depth existed) lays cream, brown or olive, as before.
            let depth = QuantitativeTrait.brownDepth.fraction(genome)
            eggColour =
                switch (blueShell, brownCoat) {
                case (true, true): depth >= Rules.oliveShellDepth ? .olive : .green
                case (true, false): .blue
                case (false, true): depth > Rules.chocolateShellDepth ? .chocolate : .brown
                case (false, false): depth <= Rules.whiteShellDepth ? .white : .cream
                }
            eggIsSpeckled = genome.speckle.isHomozygous(for: .speckled)
        } else {
            eggColour = nil
            eggIsSpeckled = false
        }
    }

    /// One line of plain text, for the CLI and for logs.
    public var summary: String {
        var parts = [sex.rawValue, colour.rawValue]
        if isBarred { parts.append("barred") }
        if isLaced { parts.append("laced") }
        parts.append(isSilkieFeathered ? "silkie feathers" : "normal feathers")
        if let egg = eggColour {
            parts.append("lays \(eggIsSpeckled ? "speckled " : "")\(egg.rawValue) eggs")
        }
        return parts.joined(separator: " · ")
    }
}
