// What the game screen draws for one bird.
//
// The artist draws each art family and stage ONCE, in greyscale, with flat mask layers.
// The engine says which drawing to use, which colour token goes on each mask, which pattern
// overlays to add, and how big to draw it. The UI maps tokens to real colours.
// So a new colour or pattern needs no new drawing.
//
// The look is always worked out from the bird's genes and age, never stored, so it can't drift.

/// Which greyscale drawing to use.
public struct ArtKey: Hashable, Codable, Sendable, CustomStringConvertible {
    /// "orpington", "silkie", "mixed"… one set of drawings per family.
    public let family: String
    public let stage: ArtStage
    public var description: String { "\(family)/\(stage.rawValue)" }
}

/// One drawing per stage. Chicks look the same for both sexes.
public enum ArtStage: String, Hashable, Codable, Sendable, CaseIterable {
    case chick, pullet, cockerel, hen, rooster

    /// The mask layers this drawing must have.
    public var masks: [Mask] {
        self == .chick ? [.down, .beak, .legs] : [.body, .hackle, .tail, .comb, .beak, .legs]
    }
}

/// A flat mask layer in a drawing. The engine fills each with one colour token.
public enum Mask: String, Hashable, Codable, Sendable, CaseIterable {
    case down, body, hackle, tail, comb, beak, legs
}

/// Colour tokens. Not RGB: the art direction picks the real colours, per palette.
public enum Tone: String, Hashable, Codable, Sendable, CaseIterable {
    // Feathers and down
    case black, blue, darkBlue, splash, lavender, buff, slateDown, paleGreyDown, silverDown, yellowDown, blackDown
    // Skin
    case red, mulberry, slate, yellow, willow, white, horn
}

/// A texture drawn over the feather masks, clipped to them.
public enum Pattern: String, Hashable, Codable, Sendable, CaseIterable {
    /// A dark edge on every feather (gold laced).
    case lacing
    /// Light bars across every feather.
    case barring
    /// The white spot on the head of a barred chick.
    case headSpot
}

public struct PatternOverlay: Hashable, Codable, Sendable {
    public let pattern: Pattern
    public let tone: Tone
    public let masks: [Mask]
}

public struct Look: Hashable, Codable, Sendable {
    public let art: ArtKey
    /// One colour token for every mask in the drawing.
    public let fills: [Mask: Tone]
    public let overlays: [PatternOverlay]
    /// Draw scale. 1.0 = an adult hen of an average-size breed.
    public let scale: Double
}

/// How a breed looks beyond its feather colour: body shape (art family), comb, legs and size.
/// SIMPLIFIED: real comb type, leg colour and size are genes too. Here they belong to the breed,
/// and crosses use the "mixed" look.
public struct BreedLook: Hashable, Sendable {
    public let family: String
    public let comb: Tone
    public let legs: Tone
    /// Leg colour on buff birds, if different (buff Orpingtons have pale legs).
    public let legsOnBuff: Tone?
    /// Adult hen size. 1.0 = average.
    public let size: Double

    public init(family: String, comb: Tone = .red, legs: Tone, legsOnBuff: Tone? = nil, size: Double) {
        self.family = family
        self.comb = comb
        self.legs = legs
        self.legsOnBuff = legsOnBuff
        self.size = size
    }

    /// Crossbreeds: a plain single-combed farmyard bird.
    public static let mixed = BreedLook(family: "mixed", legs: .willow, size: 1.0)
}

extension Bird {
    public func look(onDay day: Int, rules: Rules) -> Look {
        let p = phenotype
        let stage = stage(onDay: day, rules: rules)
        let artStage: ArtStage = switch (stage, sex) {
        case (.chick, _): .chick
        case (.grower, .hen): .pullet
        case (.grower, .rooster): .cockerel
        case (.adult, .hen): .hen
        case (.adult, .rooster): .rooster
        }

        // Body shape: silkie feathering changes the whole outline, so it picks the drawing first.
        let breedLook = isPurebred ? breed.definition.look : .mixed
        let family = p.isSilkieFeathered ? BreedTable.definition(.silkie)!.look.family : breedLook.family
        let legs = (p.colour == .buff ? breedLook.legsOnBuff : nil) ?? breedLook.legs

        var fills: [Mask: Tone] = [.beak: .horn, .legs: legs]
        var overlays: [PatternOverlay] = []
        if artStage == .chick {
            fills[.down] = switch p.chickDown {
            case .black, .darkWithHeadSpot: .blackDown
            case .slate: .slateDown
            case .paleGrey: .paleGreyDown
            case .silver: .silverDown
            case .yellow: .yellowDown
            }
            if p.chickDown == .darkWithHeadSpot {
                overlays.append(PatternOverlay(pattern: .headSpot, tone: .white, masks: [.down]))
            }
        } else {
            let feathers = Self.tone(p.colour)
            fills[.body] = feathers
            // Real blue roosters have darker hackles and saddle than their body.
            fills[.hackle] = (p.colour == .blue && sex == .rooster) ? .darkBlue : feathers
            // Gold laced birds have a black tail.
            fills[.tail] = p.isLaced ? .black : feathers
            fills[.comb] = breedLook.comb
            if p.isLaced { overlays.append(PatternOverlay(pattern: .lacing, tone: .black, masks: [.body, .hackle])) }
            if p.isBarred { overlays.append(PatternOverlay(pattern: .barring, tone: .white, masks: [.body, .hackle, .tail])) }
        }

        // Size grows smoothly with age. Roosters end about 20% bigger than hens.
        let growth = min(1, max(0, Double(age(onDay: day)) / Double(rules.adultAge)))
        let sexFactor = sex == .rooster ? 1 + 0.2 * growth : 1
        let scale = breedLook.size * sexFactor * (0.3 + 0.7 * growth)

        return Look(art: ArtKey(family: family, stage: artStage), fills: fills, overlays: overlays, scale: scale)
    }

    static func tone(_ c: FeatherColour) -> Tone {
        switch c {
        case .black: .black
        case .blue: .blue
        case .splash: .splash
        case .lavender: .lavender
        case .buff: .buff
        }
    }
}

/// The drawings the artist must make: every art family the game can show, at every stage.
public enum ArtChecklist {
    public static func required(includePlanned: Bool = false) -> [ArtKey] {
        let breeds = includePlanned ? BreedTable.all : BreedTable.inGame
        var families: [String] = []
        for f in breeds.map(\.look.family) + [BreedLook.mixed.family] where !families.contains(f) { families.append(f) }
        return families.flatMap { f in ArtStage.allCases.map { ArtKey(family: f, stage: $0) } }
    }
}
