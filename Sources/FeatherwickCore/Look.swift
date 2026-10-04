// What the game screen draws for one bird, built from a shared kit of parts.
//
// The artist paints each part ONCE, in greyscale, with flat mask layers. Breeds share parts:
// Orpingtons and Australorps share a heavy body, most breeds share clean legs, and so on.
// The engine picks the parts, puts a colour token on each mask, adds pattern overlays, and sets
// sizes. Pullets and cockerels are the adult parts, smaller, with a smaller comb and shorter tail.
// So a new colour, pattern or breed usually needs no new art.
//
// Tip for watercolour: paint each body as a whole bird, then cut it into parts with soft,
// overlapping edges, so the joins don't show.
//
// The look is always worked out from the bird's genes and age, never stored, so it can't drift.

// MARK: - Part shapes

public enum BodyShape: String, Hashable, Codable, Sendable, CaseIterable { case heavy, medium, light, fluffy }
public enum CombShape: String, Hashable, Codable, Sendable, CaseIterable { case single, rose, pea, walnut }
public enum LegShape: String, Hashable, Codable, Sendable, CaseIterable { case clean, featheredFiveToe }
public enum HeadShape: String, Hashable, Codable, Sendable, CaseIterable { case plain, crested }
public enum TailShape: String, Hashable, Codable, Sendable, CaseIterable { case hen, rooster, fluffy }
public enum ChickShape: String, Hashable, Codable, Sendable, CaseIterable { case plain, fluffy }

/// The slots a bird is built from, in drawing order (back to front).
public enum Slot: String, Hashable, Codable, Sendable, CaseIterable {
    case tail, legs, body, head, comb, chick
}

/// One drawing in the kit: "body/heavy/hen", "comb/rose", "chick/fluffy".
public struct PartKey: Hashable, Codable, Sendable, CustomStringConvertible {
    public let slot: Slot
    public let shape: String
    /// Only bodies have separate hen and rooster drawings.
    public let sex: Sex?

    public var description: String { [slot.rawValue, shape, sex?.rawValue].compactMap { $0 }.joined(separator: "/") }

    /// The mask layers this drawing must have.
    public var masks: [Mask] {
        switch slot {
        case .tail: [.tail]
        case .legs: [.legs]
        case .body: [.body, .hackle]
        case .head: [.head, .beak]
        case .comb: [.comb]
        case .chick: [.down, .beak, .legs]
        }
    }
}

/// A flat mask layer in a part. The engine fills each with one colour token.
public enum Mask: String, Hashable, Codable, Sendable, CaseIterable {
    case down, body, hackle, tail, head, comb, beak, legs
}

/// Colour tokens. Not RGB: the art direction picks the real colours, per palette.
public enum Tone: String, Hashable, Codable, Sendable, CaseIterable {
    // Feathers and down
    case black, blue, darkBlue, splash, lavender, buff, slateDown, paleGreyDown, silverDown, yellowDown, blackDown
    // Skin
    case red, mulberry, slate, yellow, willow, white, horn
}

/// A texture drawn over feather masks, clipped to them.
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

/// One part placed on the bird.
public struct PlacedPart: Hashable, Codable, Sendable {
    public let part: PartKey
    /// A colour token for every mask in the part.
    public let fills: [Mask: Tone]
    /// Size of this part relative to the bird. Combs and tails grow in as the bird matures.
    public let scale: Double
}

public struct Look: Hashable, Codable, Sendable {
    /// For poses and animation: chick, pullet, cockerel, hen or rooster.
    public let stage: ArtStage
    /// Back to front.
    public let parts: [PlacedPart]
    public let overlays: [PatternOverlay]
    /// Whole-bird scale. 1.0 = an adult hen of an average-size breed.
    public let scale: Double

    public func part(_ slot: Slot) -> PlacedPart? { parts.first { $0.part.slot == slot } }
    public func tone(_ mask: Mask) -> Tone? { parts.lazy.compactMap { $0.fills[mask] }.first }
}

public enum ArtStage: String, Hashable, Codable, Sendable, CaseIterable {
    case chick, pullet, cockerel, hen, rooster
}

/// A breed's parts, skin colours and size.
/// SIMPLIFIED: real comb type, crest, leg feathering and size are genes too. Here they belong to
/// the breed, and crosses use the `mixed` look. Silkie feathering is a real gene: it picks the
/// fluffy body, tail and chick for any bird, crosses included.
public struct BreedLook: Hashable, Sendable {
    public let body: BodyShape
    public let comb: CombShape
    public let combTone: Tone
    public let legs: LegShape
    public let legTone: Tone
    /// Leg colour on buff birds, if different (buff Orpingtons have pale legs).
    public let legToneOnBuff: Tone?
    public let head: HeadShape
    /// Adult hen size. 1.0 = average.
    public let size: Double

    public init(
        body: BodyShape, comb: CombShape, combTone: Tone = .red, legs: LegShape = .clean,
        legTone: Tone, legToneOnBuff: Tone? = nil, head: HeadShape = .plain, size: Double
    ) {
        self.body = body
        self.comb = comb
        self.combTone = combTone
        self.legs = legs
        self.legTone = legTone
        self.legToneOnBuff = legToneOnBuff
        self.head = head
        self.size = size
    }

    /// Crossbreeds: a medium farmyard bird with a single comb.
    public static let mixed = BreedLook(body: .medium, comb: .single, legTone: .willow, size: 1.0)
}

extension Bird {
    public func look(onDay day: Int, rules: Rules) -> Look {
        let p = phenotype
        let fluffy = p.isSilkieFeathered
        let bl = isPurebred ? breed.definition.look : .mixed
        let growth = min(1, max(0, Double(age(onDay: day)) / Double(rules.adultAge)))
        let stage: ArtStage =
            switch (self.stage(onDay: day, rules: rules), sex) {
            case (.chick, _): .chick
            case (.grower, .hen): .pullet
            case (.grower, .rooster): .cockerel
            case (.adult, .hen): .hen
            case (.adult, .rooster): .rooster
            }
        let legTone = (p.colour == .buff ? bl.legToneOnBuff : nil) ?? bl.legTone
        // Size grows smoothly with age. Roosters end about 20% bigger than hens.
        let scale = bl.size * (sex == .rooster ? 1 + 0.2 * growth : 1) * (0.3 + 0.7 * growth)

        if stage == .chick {
            let down: Tone =
                switch p.chickDown {
                case .black, .darkWithHeadSpot: .blackDown
                case .slate: .slateDown
                case .paleGrey: .paleGreyDown
                case .silver: .silverDown
                case .yellow: .yellowDown
                }
            let chick = PlacedPart(
                part: PartKey(slot: .chick, shape: (fluffy ? ChickShape.fluffy : .plain).rawValue, sex: nil),
                fills: [.down: down, .beak: .horn, .legs: legTone], scale: 1)
            let spot =
                p.chickDown == .darkWithHeadSpot
                ? [PatternOverlay(pattern: .headSpot, tone: .white, masks: [.down])] : []
            return Look(stage: stage, parts: [chick], overlays: spot, scale: scale)
        }

        let feathers = Self.tone(p.colour)
        // Real blue roosters have darker hackles than their body. Gold laced birds have a black tail.
        let hackle: Tone = (p.colour == .blue && sex == .rooster) ? .darkBlue : feathers
        let tailTone: Tone = p.isLaced ? .black : feathers
        let tail: TailShape = fluffy ? .fluffy : (sex == .rooster ? .rooster : .hen)
        // Combs and tails grow in as the bird matures. A hen's comb is the same drawing, smaller.
        let combSize = (sex == .rooster ? 1.0 : 0.6) * (0.2 + 0.8 * growth)
        let tailSize = 0.4 + 0.6 * growth

        let parts = [
            PlacedPart(
                part: PartKey(slot: .tail, shape: tail.rawValue, sex: nil), fills: [.tail: tailTone], scale: tailSize),
            PlacedPart(
                part: PartKey(slot: .legs, shape: bl.legs.rawValue, sex: nil), fills: [.legs: legTone], scale: 1),
            PlacedPart(
                part: PartKey(slot: .body, shape: (fluffy ? BodyShape.fluffy : bl.body).rawValue, sex: sex),
                fills: [.body: feathers, .hackle: hackle], scale: 1),
            PlacedPart(
                part: PartKey(slot: .head, shape: bl.head.rawValue, sex: nil), fills: [.head: hackle, .beak: .horn],
                scale: 1),
            PlacedPart(
                part: PartKey(slot: .comb, shape: bl.comb.rawValue, sex: nil), fills: [.comb: bl.combTone],
                scale: combSize),
        ]
        var overlays: [PatternOverlay] = []
        if p.isLaced { overlays.append(PatternOverlay(pattern: .lacing, tone: .black, masks: [.body, .hackle])) }
        if p.isBarred {
            overlays.append(PatternOverlay(pattern: .barring, tone: .white, masks: [.body, .hackle, .tail, .head]))
        }
        return Look(stage: stage, parts: parts, overlays: overlays, scale: scale)
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

/// The parts the artist must paint: every part any bird in the game can use.
public enum ArtChecklist {
    public static func required(includePlanned: Bool = false) -> [PartKey] {
        let defs = includePlanned ? BreedTable.all : BreedTable.inGame
        let looks = defs.map(\.look) + [BreedLook.mixed]
        // Silkie feathering can turn up in crosses once Silkies are in the game.
        let anyFluffy = defs.contains { $0.fixes(Feathering.silkie) }
        var keys: [PartKey] = []
        func add(_ slot: Slot, _ shape: String, _ sex: Sex? = nil) {
            let key = PartKey(slot: slot, shape: shape, sex: sex)
            if !keys.contains(key) { keys.append(key) }
        }
        for shape in BodyShape.allCases
        where looks.contains(where: { $0.body == shape }) || (shape == .fluffy && anyFluffy) {
            for sex in Sex.allCases { add(.body, shape.rawValue, sex) }
        }
        for shape in CombShape.allCases where looks.contains(where: { $0.comb == shape }) { add(.comb, shape.rawValue) }
        for shape in LegShape.allCases where looks.contains(where: { $0.legs == shape }) { add(.legs, shape.rawValue) }
        for shape in HeadShape.allCases where looks.contains(where: { $0.head == shape }) { add(.head, shape.rawValue) }
        add(.tail, TailShape.hen.rawValue)
        add(.tail, TailShape.rooster.rawValue)
        if anyFluffy { add(.tail, TailShape.fluffy.rawValue) }
        add(.chick, ChickShape.plain.rawValue)
        if anyFluffy { add(.chick, ChickShape.fluffy.rawValue) }
        return keys
    }
}
