import Foundation

// What the keeper can see of a bird.
//
// `Knowledge` (and later the planner) reads only these values. They are made here, from the bird's
// look (`Phenotype`) and from facts the keeper is told, so the code that reasons about hidden genes
// never touches a bird's genes (core rule 8: no hidden-gene leaks).

extension Bird {
    /// The origin of every chick hatched at home. Any other origin is a bird from outside the flock.
    public static let homeOrigin = "Henhaven"

    /// The bird as it goes out of the keeper's sight: its look on `day`, the last day the keeper saw
    /// it, is frozen in `lastSeenLook`. A bird already out of sight keeps the look it had.
    ///
    /// `wasAway`: the bird was already away (boarding or lost), as a rehomed boarder is. One from a save
    /// made before looks were frozen has none, and the day it left is not known, so it freezes only its
    /// down, as `SeenLook(of:in:)` shows it while away. Today's look could hold eggs the keeper never saw.
    func leavingSight(in s: GameState, onDay day: Int, wasAway: Bool = false) -> Bird {
        var b = self
        guard b.lastSeenLook == nil else { return b }
        let away = wasAway || s.boarding.contains { $0.id == id } || s.lost.contains { $0.bird.id == id }
        b.lastSeenLook =
            away ? SeenLook(phenotype, level: .down) : SeenLook(seenToday: self, onDay: day, rules: s.rules)
        return b
    }
}

/// How much of a bird's look the keeper can see.
public enum LookLevel: String, Hashable, Codable, Sendable {
    /// A chick whose sex does not show yet: its down, and fluffy (silkie) down.
    case down
    /// A grown bird (grower or older, or told by its breeder): feather colour and pattern.
    case feathers
    /// A grown hen at point of lay: her feathers and her eggs.
    case laying
}

/// The look of a bird as the keeper saw it. Nil fields were not visible.
///
/// Only visible values: no genes. A chick shows its down only (`chickDown`); a grown bird shows its
/// feathers; a laying hen shows her eggs too.
public struct SeenLook: Hashable, Codable, Sendable {
    /// The down of a chick whose sex does not show yet. Nil once the feathers show.
    public var chickDown: ChickDown?
    public var colour: FeatherColour?
    public var isBarred: Bool?
    public var isLaced: Bool?
    /// Silkie feathering shows at every age: a silkie chick is drawn with fluffy down.
    public var isSilkieFeathered: Bool
    /// A laying hen's egg colour, as she lays it.
    public var eggColour: EggColour?
    public var eggIsSpeckled: Bool?

    public init(
        chickDown: ChickDown? = nil, colour: FeatherColour? = nil, isBarred: Bool? = nil, isLaced: Bool? = nil,
        isSilkieFeathered: Bool, eggColour: EggColour? = nil, eggIsSpeckled: Bool? = nil
    ) {
        self.chickDown = chickDown
        self.colour = colour
        self.isBarred = isBarred
        self.isLaced = isLaced
        self.isSilkieFeathered = isSilkieFeathered
        self.eggColour = eggColour
        self.eggIsSpeckled = eggIsSpeckled
    }

    /// The part of a look the keeper sees at `level`. `.laying` needs a hen's look (a rooster has no egg).
    public init(_ p: Phenotype, level: LookLevel) {
        isSilkieFeathered = p.isSilkieFeathered
        switch level {
        case .down:
            chickDown = p.chickDown
        case .feathers, .laying:
            colour = p.colour
            isBarred = p.isBarred
            isLaced = p.isLaced
            if level == .laying, let egg = p.eggColour {
                eggColour = egg
                eggIsSpeckled = p.eggIsSpeckled
            }
        }
    }

    /// What the keeper has seen of `bird`. A bird at home shows today's look. A bird out of sight
    /// (rehomed, boarding or lost) keeps the look frozen when it left (`Bird.lastSeenLook`): it may
    /// grow up while away, but the keeper never sees it lay. An away bird from a save made before
    /// looks were frozen shows only its down, the safe choice: the day it left is not known.
    public init(of bird: Bird, in s: GameState) {
        let away =
            s.rehomed.contains { $0.id == bird.id } || s.boarding.contains { $0.id == bird.id }
            || s.lost.contains { $0.bird.id == bird.id }
        self.init(of: bird, in: s, away: away)
    }

    init(of bird: Bird, in s: GameState, away: Bool) {
        if let frozen = bird.lastSeenLook {
            self = frozen
        } else if away {
            self.init(bird.phenotype, level: .down)
        } else {
            self.init(seenToday: bird, onDay: s.day, rules: s.rules)
        }
    }

    /// The look of a bird in front of the keeper on `day`: its down until it is revealed, then its
    /// feathers, and a grown hen's eggs too.
    init(seenToday bird: Bird, onDay day: Int, rules: Rules) {
        let level: LookLevel =
            if !bird.revealed {
                .down
            } else if bird.sex == .hen, bird.stage(onDay: day, rules: rules) == .adult {
                .laying
            } else {
                .feathers
            }
        self.init(bird.phenotype, level: level)
    }

    public var level: LookLevel { chickDown != nil ? .down : eggColour != nil ? .laying : .feathers }

    /// The look with the egg colour in the coarse form the single genes decide (`EggColour.coarse`):
    /// chocolate is a dark brown, olive a dark green and white an untinted cream. How dark is the
    /// brown-depth trait, which `Knowledge` does not track.
    public var coarse: SeenLook {
        var c = self
        c.eggColour = eggColour?.coarse
        return c
    }
}

/// One bird as the keeper knows it: plain values only, never genes.
///
/// A bird whose sex does not show yet has `sex`, `breed` and `isPurebred` nil, and only its down as a look.
public struct Visible: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    /// Nil until the bird's sex shows (or for a record that does not say).
    public let sex: Sex?
    public let stage: LifeStage
    /// Nil until the breed shows.
    public let breed: Breed?
    public let isPurebred: Bool?
    public let origin: String
    public let motherID: UUID?
    public let fatherID: UUID?
    /// Nil for a bird the keeper never saw, such as a parent of a bought egg.
    public let look: SeenLook?
    /// The type band a show judge gave the bird at its newest show with a type note. Nil until a judge
    /// has said: never worked out from genes, so it tells the keeper only what they were shown.
    public let typeBand: JudgeNote.Band?

    public init(
        id: UUID, name: String, sex: Sex?, stage: LifeStage, breed: Breed?, isPurebred: Bool?, origin: String,
        motherID: UUID?, fatherID: UUID?, look: SeenLook?, typeBand: JudgeNote.Band? = nil
    ) {
        self.id = id
        self.name = name
        self.sex = sex
        self.stage = stage
        self.breed = breed
        self.isPurebred = isPurebred
        self.origin = origin
        self.motherID = motherID
        self.fatherID = fatherID
        self.look = look
        self.typeBand = typeBand
    }

    /// A bird the keeper has (or had, if rehomed). Sex and breed only once they show.
    public init(bird: Bird, in s: GameState) {
        self.init(
            id: bird.id, name: bird.name, sex: bird.revealed ? bird.sex : nil,
            stage: bird.stage(onDay: s.day, rules: s.rules),
            breed: bird.revealed ? bird.breed : nil, isPurebred: bird.revealed ? bird.isPurebred : nil,
            origin: bird.origin, motherID: bird.motherID, fatherID: bird.fatherID,
            look: SeenLook(of: bird, in: s), typeBand: Self.typeBand(of: bird.id, in: s))
    }

    /// The same, when the caller already knows whether the bird is out of sight.
    init(bird: Bird, in s: GameState, away: Bool) {
        self.init(
            id: bird.id, name: bird.name, sex: bird.revealed ? bird.sex : nil,
            stage: bird.stage(onDay: s.day, rules: s.rules),
            breed: bird.revealed ? bird.breed : nil, isPurebred: bird.revealed ? bird.isPurebred : nil,
            origin: bird.origin, motherID: bird.motherID, fatherID: bird.fatherID,
            look: SeenLook(of: bird, in: s, away: away), typeBand: Self.typeBand(of: bird.id, in: s))
    }

    /// A family-tree record. Its sex is known from its place in the tree (mothers are hens), unless
    /// its look is a chick's down, which hides the sex.
    public init(record r: PedigreeRecord, in s: GameState) {
        let age = s.day - r.hatchDay
        let stage: LifeStage = age >= s.rules.adultAge ? .adult : age >= s.rules.growerAge ? .grower : .chick
        let hidden = r.look?.level == .down
        self.init(
            id: r.id, name: r.name, sex: hidden ? nil : r.sex, stage: stage, breed: hidden ? nil : r.breed,
            isPurebred: hidden ? nil : r.purebred, origin: r.origin, motherID: r.motherID, fatherID: r.fatherID,
            look: r.look)
    }

    /// True for a bird bred outside the flock: no parents on record, and not hatched at home.
    /// Its genes are then one of its breed's public recipes (`RecipeTable`).
    public var isFromOutside: Bool { motherID == nil && fatherID == nil && origin != Bird.homeOrigin }

    /// The type band in the judge's notes at the bird's newest show that judged its type. Nil if no judge has.
    public static func typeBand(of bird: UUID, in s: GameState) -> JudgeNote.Band? {
        for r in s.showResults.reversed() where r.birdID == bird {
            for note in r.notes ?? [] { if case .type(let band) = note { return band } }
        }
        return nil
    }

    /// True if the keeper has seen the bird (owned or rehomed birds, and records that keep a look).
    public var isSeen: Bool { look != nil }

    /// Every bird the keeper knows: owned birds (home, lost, boarding), rehomed birds and family-tree
    /// records. Sorted by id, so the order never depends on where a bird is kept.
    /// Not included: the neighbour's starter chicks before one is chosen, and a trade offer's hen.
    public static func all(in s: GameState) -> [Visible] {
        var seen: Set<UUID> = []
        var out: [Visible] = []
        for b in s.birdsAtHome where seen.insert(b.id).inserted {
            out.append(Visible(bird: b, in: s, away: false))
        }
        for b in s.lost.map(\.bird) + s.boarding + s.rehomed where seen.insert(b.id).inserted {
            out.append(Visible(bird: b, in: s, away: true))
        }
        for r in s.pedigree.values where seen.insert(r.id).inserted {
            out.append(Visible(record: r, in: s))
        }
        return out.map { (key: $0.id.uuidString, bird: $0) }.sorted { $0.key < $1.key }.map(\.bird)
    }
}
