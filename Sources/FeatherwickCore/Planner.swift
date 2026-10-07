import Foundation

// What might hatch: a forecast for a penned pair, built only from what the keeper could know.
//
// The one rule: the planner reads `Visible` birds and `Knowledge`, nothing else. Where elimination
// leaves more than one possibility, the forecast says "likely", "possible" or "not possible",
// never a number. Ratios appear only when no open gene can change the share: every gene that decides
// it is pinned in both parents, or provably cannot change it (white, buff or lavender hides it).
// Egg colours never get certain, ratio, possible or not-possible lines: the egg-colours line covers
// them (and "likely no blue eggs").
// The words live in FeatherwickText (`plannerText`).

/// Something a chick (or a hen from this pair) can show.
public enum Trait: Hashable, Codable, Sendable {
    /// A feather colour: black, blue, splash, lavender, buff or white.
    case colour(FeatherColour)
    case barred
    case laced
    case silkieFeathered
    /// The pair's daughters will lay this egg colour.
    case eggColour(EggColour)
    case speckledEggs
}

/// Why a forecast line is true. Names only birds the keeper has seen.
public enum Reason: Hashable, Codable, Sendable {
    /// This bird's look settles it: "Pip is blue. Blue birds always carry one of each."
    case look(bird: UUID, locus: LocusID)
    /// This bird came from outside as a purebred of this breed: "Pip came from Speckle & Down as an Orpington."
    case breed(bird: UUID, Breed)
    /// A parent of this bird showed it: "Her mother laid blue eggs."
    case parent(bird: UUID, parent: UUID, locus: LocusID)
    /// The pair (or one of them) already had a chick that showed it: "They had a lavender chick, Clover."
    case chick(bird: UUID, chick: UUID, locus: LocusID)
    /// Nobody in either bird's visible family has shown it yet.
    case unknownFamily(locus: LocusID)
    /// This bird had this many chicks and none showed it. A likelihood, not a proof.
    case manyChicks(bird: UUID, count: Int, locus: LocusID)
    /// The type bands a show judge gave each bird, at its newest show.
    case grades(hen: UUID, rooster: UUID)
    /// The family tree.
    case family(hen: UUID, rooster: UUID)
    /// This bird is white, and white hides what is underneath.
    case white(bird: UUID)
}

/// One line of the "What might hatch" panel. Enums only: no words.
public enum Forecast: Hashable, Codable, Sendable {
    /// Every chick will show this.
    case certain(Trait, Reason)
    /// About `numerator` in `denominator` chicks will show this. Only when both parents are pinned.
    case ratio(Trait, numerator: Int, denominator: Int, Reason)
    /// Likely, but not proven. With `.manyChicks` (the only reason the planner gives it): likely NOT
    /// this trait, "Likely no blue eggs", because a parent that may hide the gene has had many seen
    /// chicks (laying daughters, for an egg trait) and none showed it.
    case likely(Trait, Reason)
    /// Can happen if one of them is hiding it.
    case possible(Trait, Reason)
    /// Proven impossible by elimination.
    case notPossible(Trait, Reason)
    /// Barred chicks are all of one sex: the hen is barred and the rooster is pinned not barred.
    case sexLink(barredAre: Sex, Reason)
    /// The egg colours this pair's daughters can lay. `sure` is false when it turns on an open gene.
    case eggColours([EggColour], sure: Bool, Reason)
    /// The type bands a show judge gave the hen and the rooster (`Visible.typeBand`).
    case typeOutlook(JudgeNote.Band, JudgeNote.Band, Reason)
    /// How closely related the pair are, in the keeper's words.
    case kinship(Relatedness, Reason)
    /// One or both are white, so anything either carries could show.
    case unknownUnderWhite(Reason)

    public var reason: Reason {
        switch self {
        case .certain(_, let r), .ratio(_, _, _, let r), .likely(_, let r), .possible(_, let r),
            .notPossible(_, let r), .sexLink(_, let r), .eggColours(_, _, let r), .typeOutlook(_, _, let r),
            .kinship(_, let r), .unknownUnderWhite(let r):
            r
        }
    }
}

/// What the breeding pen's "What might hatch" panel shows.
public enum PlannerPanel: Hashable, Sendable {
    /// The keeper has not met the planner yet (`GameState.plannerKnown` is false).
    case hidden
    /// The pen has no hen.
    case needsHen
    /// The pen has a hen but no rooster: "Pen a rooster to see what might hatch."
    case needsRooster
    /// The forecast for each penned hen with the penned rooster, hens in pen order.
    case forecast(rooster: UUID, [PairForecast])
}

/// The forecast for one hen with the penned rooster.
public struct PairForecast: Hashable, Sendable {
    public let hen: UUID
    public let lines: [Forecast]

    public init(hen: UUID, lines: [Forecast]) {
        self.hen = hen
        self.lines = lines
    }
}

public enum Planner {
    /// The forecast for one pair. Reads only `Visible` values and `Knowledge`.
    ///
    /// - `family`: every bird the keeper knows (`Visible.all(in:)`). It names the traits the pair's
    ///   seen relatives showed, and counts each parent's seen chicks for "likely" lines. Without it the
    ///   forecast still holds, with no "likely" lines.
    /// - `kinship`: how related the pair are (`Pedigree.relatedness`). A line only when they are related.
    ///
    /// Lines come in this order: certain, ratio, sex-link, egg colours, likely, possible, not possible,
    /// type, kinship, white caveat. Within a group, in `Trait.planned` order.
    public static func forecast(
        hen: Visible, rooster: Visible, knowledge: Knowledge, family: [Visible] = [], kinship: Relatedness? = nil,
        rules: Rules = .standard
    ) -> [Forecast] {
        var work = PairWork(hen: hen, rooster: rooster, knowledge: knowledge, family: family, rules: rules)
        return work.lines(kinship: kinship)
    }

    /// The panel for the breeding pen today.
    public static func panel(in s: GameState) -> PlannerPanel {
        guard s.plannerKnown else { return .hidden }
        let hens = s.pennedHens
        let inPenOrder = s.pen.compactMap { id in hens.first { $0.id == id } }
        guard !inPenOrder.isEmpty else { return .needsHen }
        guard let rooster = s.penRooster else { return .needsRooster }
        let family = Visible.all(in: s)
        let knowledge = Knowledge.of(family)
        let roosterSeen = Visible(bird: rooster, in: s)
        let pairs = inPenOrder.map { hen in
            PairForecast(
                hen: hen.id,
                lines: forecast(
                    hen: Visible(bird: hen, in: s), rooster: roosterSeen, knowledge: knowledge, family: family,
                    kinship: Pedigree.relatedness(hen.id, rooster.id, in: s), rules: s.rules))
        }
        return .forecast(rooster: rooster.id, pairs)
    }

    /// The carrier notes for a bird's card: hidden alleles proven present. Empty until the planner is known.
    public static func carrierNotes(for bird: UUID, in s: GameState) -> [ProvenAllele] {
        guard s.plannerKnown else { return [] }
        return Knowledge.of(s).provenHidden(bird)
    }
}

// MARK: - Traits

extension Trait {
    /// Every trait the planner forecasts, in the order its lines are listed. Egg colours are coarse
    /// (cream, brown, blue, green): how dark a brown or green egg is comes from many small genes.
    public static let planned: [Trait] =
        FeatherColour.allCases.map { .colour($0) } + [.barred, .laced, .silkieFeathered]
        + [EggColour.cream, .brown, .blue, .green].map { .eggColour($0) } + [.speckledEggs]

    /// Bits over `planned` of the feather traits and of the egg traits.
    static let plumageBits: UInt16 = 0b1_1111_1111
    static let eggBits: UInt16 = 0b11_1110_0000_0000
    static let eggColourBits: UInt16 = 0b1_1110_0000_0000
    /// The looks keepers most often breed for. Their "not possible" and "possible" lines are always
    /// worth saying; other traits only when the pair or its seen family showed them.
    static let commonBits: UInt16 = bits(notPossiblePriority)
    /// The order "not possible" lines are picked in, after the traits the family showed. Splash comes
    /// last: when blue cannot hatch, splash cannot either (or every chick is splash).
    static let notPossiblePriority: [Trait] = [
        .colour(.lavender), .colour(.blue), .colour(.buff), .colour(.white), .barred, .laced, .silkieFeathered,
        .colour(.splash),
    ]
    /// Traits a bird can carry without showing them: recessives (lavender, buff, lacing, silkie, speckled
    /// eggs) and barring, which buff and white hide. Only these get "possible" and "likely no" lines.
    static let mayBeHiddenBits: UInt16 = bits([
        .colour(.lavender), .colour(.buff), .barred, .laced, .silkieFeathered, .speckledEggs,
    ])
    /// Traits white hides: under a white parent the white caveat speaks for them.
    static let hiddenByWhiteBits: UInt16 =
        bits(FeatherColour.allCases.filter { $0 != .white }.map { .colour($0) }) | bits([.barred, .laced])

    static func bits(_ traits: [Trait]) -> UInt16 { traits.reduce(0) { $0 | $1.bit } }

    private static let bitOf: [Trait: UInt16] = Dictionary(
        uniqueKeysWithValues: planned.enumerated().map { ($1, UInt16(1) << $0) })

    var bit: UInt16 { Trait.bitOf[self] ?? 0 }
    var isEggTrait: Bool { bit & Trait.eggBits != 0 }

    /// The genes that decide the trait, the most telling first.
    var loci: [LocusID] {
        switch self {
        case .colour(.white): [DominantWhite.locus]
        case .colour(.buff): [BaseColour.locus, DominantWhite.locus]
        case .colour(.lavender): [Lavender.locus, BaseColour.locus, DominantWhite.locus]
        case .colour: [BlueDilution.locus, Lavender.locus, BaseColour.locus, DominantWhite.locus]
        case .barred: [Barring.locus, BaseColour.locus, DominantWhite.locus]
        case .laced: [Lacing.locus, BaseColour.locus, DominantWhite.locus]
        case .silkieFeathered: [Feathering.locus]
        case .eggColour(.brown), .eggColour(.green): [BrownShell.locus, BlueShell.locus]
        case .eggColour: [BlueShell.locus, BrownShell.locus]
        case .speckledEggs: [Speckle.locus]
        }
    }

    /// The traits a seen look shows.
    static func shown(by look: SeenLook) -> UInt16 {
        var out: UInt16 = 0
        if let c = look.colour { out |= Trait.colour(c).bit }
        if look.isBarred == true { out |= Trait.barred.bit }
        if look.isLaced == true { out |= Trait.laced.bit }
        if look.isSilkieFeathered { out |= Trait.silkieFeathered.bit }
        if look.eggIsSpeckled == true { out |= Trait.speckledEggs.bit }
        return out
    }
}

// MARK: - Crossing genotype sets

/// Chicks of one mother genotype and one father genotype, with Mendel's shares.
enum Mendel {
    /// `shares[l][m * n + f]`: each chick genotype (by index) with its share out of 4, for mother
    /// genotype `m` and father genotype `f` at gene `l` (in `GenotypeSpace.all` order). A Z-linked gene
    /// counts daughters and sons together: two of the four are daughters.
    static let shares: [[[(genotype: Int, share: Int)]]] = GenotypeSpace.all.map { space in
        let n = space.genotypes.count
        let index = Dictionary(uniqueKeysWithValues: space.genotypes.enumerated().map { ($1, $0) })
        func at(_ alleles: [String]) -> Int { index[Genotype(alleles, at: space.locus)]! }
        return (0..<(n * n)).map { mf in
            let mother = space.genotypes[mf / n].alleles
            let father = space.genotypes[mf % n].alleles
            var count: [Int: Int] = [:]
            switch space.locus.inheritance {
            case .autosomal:
                guard mother.count == 2, father.count == 2 else { return [] }
                for a in mother { for b in father { count[at([a, b]), default: 0] += 1 } }
            case .zLinked:
                guard mother.count == 1, father.count == 2 else { return [] }
                for b in father {
                    count[at([b]), default: 0] += 1
                    count[at([mother[0], b]), default: 0] += 1
                }
            }
            return count.keys.sorted().map { ($0, count[$0]!) }
        }
    }

    /// The position of each genotype in its space, per gene.
    static let index: [[Genotype: Int]] = GenotypeSpace.all.map { space in
        Dictionary(uniqueKeysWithValues: space.genotypes.enumerated().map { ($1, $0) })
    }

    /// The position of a gene in `GenotypeSpace.all`.
    static func position(_ id: LocusID) -> Int { positions[id]! }
    private static let positions: [LocusID: Int] = Dictionary(
        uniqueKeysWithValues: GenotypeSpace.all.enumerated().map { ($1.locus.id, $0) })
}

/// What can hatch from two sets of parent genotypes, for one `ChickLookTable`.
struct Outcome {
    /// Traits some chick can show.
    var can: UInt16 = 0
    /// Traits every chick shows.
    var must: UInt16 = 0
    /// Traits whose share of chicks is settled: no gene the parents are not both pinned at changes it.
    var exact: UInt16 = 0
    /// For a settled trait (by bit position), how many chicks in `denominator` show it.
    var count = [Int](repeating: 0, count: 16)
    var denominator = 1
    /// For each gene the pair are not both pinned at (by position in `GenotypeSpace.all`), the traits
    /// that change with the genotype a chick gets there.
    var dependsOn: [Int: UInt16] = [:]

    /// Every chick genotype the parents can give, gene by gene. The parents' genotype sets are per gene,
    /// so the chicks' are every combination of the per-gene sets.
    init(_ table: ChickLookTable, hen: [GenotypeMask], rooster: [GenotypeMask]) {
        let spaces = GenotypeSpace.all
        var options: [[Int]] = []
        var shares: [[Int]] = []
        var pinned = 0
        for l in table.loci {
            let (h, r) = (hen[l], rooster[l])
            if h.nonzeroBitCount == 1, r.nonzeroBitCount == 1 {
                let kids = Mendel.shares[l][h.trailingZeroBitCount * spaces[l].genotypes.count + r.trailingZeroBitCount]
                options.append(kids.map(\.genotype))
                shares.append(kids.map(\.share))
                pinned += 1
            } else {
                options.append(spaces[l].children(mothers: h, fathers: r).indices)
                shares.append([])
            }
        }
        guard options.allSatisfy({ !$0.isEmpty }) else { return }
        denominator = 1 << (2 * pinned)
        let sizes = options.map(\.count)
        var steps = [Int](repeating: 1, count: sizes.count)
        for i in stride(from: sizes.count - 2, through: 0, by: -1) { steps[i] = steps[i + 1] * sizes[i + 1] }
        let total = steps[0] * sizes[0]
        var values = [UInt16](repeating: 0, count: total)
        var choice = [Int](repeating: 0, count: sizes.count)
        must = table.traits
        for n in 0..<total {
            var entry = 0
            var weight = 1
            // Shares are counted once per combination of the settled genes: the open genes stay at
            // their first option. A settled trait does not change with them.
            var counted = true
            for i in sizes.indices {
                entry += options[i][choice[i]] * table.strides[i]
                if shares[i].isEmpty {
                    if choice[i] != 0 { counted = false }
                } else {
                    weight *= shares[i][choice[i]]
                }
            }
            let bits = table.entries[entry]
            values[n] = bits
            can |= bits
            must &= bits
            if counted {
                var rest = bits
                while rest != 0 {
                    count[rest.trailingZeroBitCount] += weight
                    rest &= rest - 1
                }
            }
            var i = sizes.count - 1
            while i >= 0 {
                choice[i] += 1
                if choice[i] < sizes[i] { break }
                choice[i] = 0
                i -= 1
            }
        }
        exact = table.traits
        for i in sizes.indices where shares[i].isEmpty {
            var varies: UInt16 = 0
            if sizes[i] > 1 {
                for base in 0..<total where (base / steps[i]) % sizes[i] == 0 {
                    var all = values[base]
                    var any = values[base]
                    for k in 1..<sizes[i] {
                        let v = values[base + k * steps[i]]
                        all &= v
                        any |= v
                    }
                    varies |= any & ~all
                }
            }
            dependsOn[table.loci[i]] = varies
            exact &= ~varies
        }
    }
}

// MARK: - One pair

/// A likely fact about one parent: many seen chicks did not get an allele from it, and none surely has
/// it. The parent probably lacks the allele: `mask` is its genotypes without it. `chicks` counts the
/// chicks that showed it did not (laying daughters, for an egg gene).
private struct Likely {
    let bird: UUID
    let locus: Int
    let mask: GenotypeMask
    let chicks: Int

    var reason: Reason {
        .manyChicks(bird: bird, count: chicks, locus: GenotypeSpace.all[locus].locus.id)
    }
}

/// The working for one pair's forecast.
private struct PairWork {
    let hen: Visible
    let rooster: Visible
    let k: Knowledge
    let rules: Rules
    let henMasks: [GenotypeMask]
    let roosterMasks: [GenotypeMask]
    let plumage: Outcome
    let eggs: Outcome
    /// Traits the pair and their seen family (parents, grandparents, chicks) showed.
    let familyShown: UInt16
    /// Each parent's seen chicks.
    let chicks: [UUID: [Visible]]
    /// The white parent, if either is white (the hen first).
    let white: UUID?
    /// Outcomes with one gene opened up, for working out which gene and parent settle a line.
    var opened: [OpenKey: Outcome] = [:]

    struct OpenKey: Hashable {
        let eggs: Bool
        let locus: Int
        let hen: Bool
        let rooster: Bool
    }

    init(hen: Visible, rooster: Visible, knowledge: Knowledge, family: [Visible], rules: Rules) {
        self.hen = hen
        self.rooster = rooster
        k = knowledge
        self.rules = rules
        henMasks = Self.masks(hen, knowledge)
        roosterMasks = Self.masks(rooster, knowledge)
        plumage = Outcome(.plumage, hen: henMasks, rooster: roosterMasks)
        eggs = Outcome(.eggs, hen: henMasks, rooster: roosterMasks)
        var byID: [UUID: Visible] = [:]
        var chicks: [UUID: [Visible]] = [:]
        for v in family where byID[v.id] == nil {
            byID[v.id] = v
            guard v.isSeen else { continue }
            for parent in [v.motherID, v.fatherID].compactMap({ $0 }) where parent == hen.id || parent == rooster.id {
                chicks[parent, default: []].append(v)
            }
        }
        self.chicks = chicks
        var relatives = [hen, rooster]
        for bird in [hen, rooster] {
            let parents = [bird.motherID, bird.fatherID].compactMap { $0.flatMap { byID[$0] } }
            relatives += parents
            relatives += parents.flatMap { p in [p.motherID, p.fatherID].compactMap { $0.flatMap { byID[$0] } } }
            relatives += chicks[bird.id] ?? []
        }
        familyShown = relatives.reduce(0) { $0 | ($1.look.map(Trait.shown) ?? 0) }
        white = hen.look?.colour == .white ? hen.id : rooster.look?.colour == .white ? rooster.id : nil
    }

    /// A bird's genotype sets, gene by gene. A bird Knowledge does not cover may be anything its sex allows.
    static func masks(_ v: Visible, _ k: Knowledge) -> [GenotypeMask] {
        let spaces = GenotypeSpace.all
        guard let known = k.bird(v.id), known.loci.count == spaces.count else {
            return spaces.map { $0.mask(for: v.sex) }
        }
        return known.loci.enumerated().map { l, entry in
            entry.candidates.reduce(GenotypeMask(0)) { mask, g in mask | (Mendel.index[l][g].map { 1 << $0 } ?? 0) }
        }
    }

    // MARK: Lines

    mutating func lines(kinship: Relatedness?) -> [Forecast] {
        var certain: [Forecast] = []
        var ratios: [Forecast] = []
        var likely: [Forecast] = []
        var possible: [Forecast] = []
        var impossible: [Trait] = []

        let facts = likelyFacts()
        var likelyHen = henMasks
        var likelyRooster = roosterMasks
        for f in facts {
            if f.bird == hen.id { likelyHen[f.locus] = f.mask } else { likelyRooster[f.locus] = f.mask }
        }
        let likelyPlumage = facts.isEmpty ? plumage : Outcome(.plumage, hen: likelyHen, rooster: likelyRooster)
        let likelyEggs = facts.isEmpty ? eggs : Outcome(.eggs, hen: likelyHen, rooster: likelyRooster)

        // Ratios: a share of chicks, only where no open gene can change it. White hides what is
        // underneath, so a white parent gives no colour or pattern ratio.
        var shares: [Trait: (Int, Int)] = [:]
        for t in Trait.planned where t.bit & Trait.eggColourBits == 0 {
            let o = outcome(t)
            guard o.can & t.bit != 0, o.must & t.bit == 0, o.exact & t.bit != 0 else { continue }
            if white != nil, t.bit & (Trait.hiddenByWhiteBits | Trait.colour(.white).bit) != 0 { continue }
            shares[t] = reduced(o.count[t.bit.trailingZeroBitCount], o.denominator)
        }
        // Feather colours share one denominator: "1 in 4 black, 2 in 4 blue, 1 in 4 splash".
        let colours = Trait.planned.filter { t in
            if case .colour = t { return shares[t] != nil }
            return false
        }
        let colourDenominator = colours.map { shares[$0]!.1 }.max() ?? 1
        for t in colours { shares[t] = (shares[t]!.0 * colourDenominator / shares[t]!.1, colourDenominator) }

        for t in Trait.planned where t.bit & Trait.eggColourBits == 0 {
            let o = outcome(t)
            if o.can & t.bit == 0 {
                impossible.append(t)
            } else if o.must & t.bit != 0 {
                certain.append(.certain(t, proofReason(t, impossible: false)))
            } else if let share = shares[t], share.1 <= rules.plannerMaxRatioDenominator {
                ratios.append(.ratio(t, numerator: share.0, denominator: share.1, ratioReason(t)))
            } else {
                guard worthSaying(t) else { continue }
                // Only a trait a hidden recessive or a masked gene can bring out. Black, blue, splash and
                // white show whenever their genes are there: "hiding black" would make no sense.
                guard t.bit & Trait.mayBeHiddenBits != 0 else { continue }
                // White hides colour and pattern: the white caveat speaks for them.
                if white != nil, t.bit & Trait.hiddenByWhiteBits != 0 { continue }
                // "Likely no lavender": many chicks of an open parent, and none showed it.
                let lo = t.isEggTrait ? likelyEggs : likelyPlumage
                if lo.can & t.bit == 0, let fact = fact(ruling: t, facts) {
                    likely.append(.likely(t, fact.reason))
                } else {
                    possible.append(.possible(t, possibleReason(t, o)))
                }
            }
        }

        var out = certain + ratios
        if let link = sexLink() { out.append(link) }
        out.append(eggColours())
        // "Likely no blue eggs": an egg colour the daughters can lay only if a parent hides a gene that
        // many of its laying daughters did not get.
        let likelyEggColours = likelyEggs.can & Trait.eggColourBits
        for t in Trait.planned where eggs.can & t.bit & Trait.eggColourBits != 0 && likelyEggColours & t.bit == 0 {
            if let fact = fact(ruling: t, facts) { likely.append(.likely(t, fact.reason)) }
        }
        out += likely.sorted { rank($0) < rank($1) }
        out += possible
        out += notPossibleLines(impossible)
        if let a = hen.typeBand, let b = rooster.typeBand {
            out.append(.typeOutlook(a, b, .grades(hen: hen.id, rooster: rooster.id)))
        }
        if let kinship, kinship != .unrelated {
            out.append(.kinship(kinship, .family(hen: hen.id, rooster: rooster.id)))
        }
        if let white, plumage.must & Trait.colour(.white).bit == 0 {
            out.append(.unknownUnderWhite(.white(bird: white)))
        }
        return out
    }

    func outcome(_ t: Trait) -> Outcome { t.isEggTrait ? eggs : plumage }

    func worthSaying(_ t: Trait) -> Bool { t.bit & (Trait.commonBits | familyShown) != 0 }

    /// The trait order of a "likely" line.
    func rank(_ f: Forecast) -> Int {
        if case .likely(let t, _) = f { return t.bit.trailingZeroBitCount }
        return Int.max
    }

    /// "Not possible" lines: the traits the family showed first, then the common looks, at most
    /// `Rules.plannerNotPossibleLines`, listed in trait order.
    mutating func notPossibleLines(_ impossible: [Trait]) -> [Forecast] {
        let worth = impossible.filter(worthSaying)
        let shown = worth.filter { $0.bit & familyShown != 0 }
        let rest = Trait.notPossiblePriority.filter { worth.contains($0) && !shown.contains($0) }
        let picked = Set((shown + rest).prefix(max(0, rules.plannerNotPossibleLines)))
        var out: [Forecast] = []
        for t in worth where picked.contains(t) { out.append(.notPossible(t, proofReason(t, impossible: true))) }
        return out
    }

    func reduced(_ n: Int, _ d: Int) -> (Int, Int) {
        var (n, d) = (n, d)
        while n % 2 == 0, d % 2 == 0, d > 1 {
            n /= 2
            d /= 2
        }
        return (n, d)
    }

    func locusID(_ l: Int) -> LocusID { GenotypeSpace.all[l].locus.id }

    // MARK: Sex-link and eggs

    /// A barred hen and a rooster pinned not barred: every son gets her barring, no daughter does.
    func sexLink() -> Forecast? {
        guard hen.look?.isBarred == true, plumage.can & Trait.barred.bit != 0 else { return nil }
        let l = Mendel.position(Barring.locus)
        guard let plain = GenotypeSpace.all[l].index(of: [Barring.plain.rawValue, Barring.plain.rawValue]),
            roosterMasks[l] == 1 << plain
        else { return nil }
        return .sexLink(barredAre: .rooster, evidence(hen, l))
    }

    /// The egg colours the pair's daughters can lay if neither parent hides an egg gene nobody has
    /// seen. `sure` when no hidden gene can add another colour.
    func eggColours() -> Forecast {
        let loci = [BlueShell.locus, BrownShell.locus].map(Mendel.position)
        let full = eggs.can & Trait.eggColourBits
        var plainHen = henMasks
        var plainRooster = roosterMasks
        for l in loci {
            plainHen[l] = Self.plain(plainHen[l], l)
            plainRooster[l] = Self.plain(plainRooster[l], l)
        }
        let plain = Outcome(.eggs, hen: plainHen, rooster: plainRooster).can & Trait.eggColourBits
        let colours = Trait.planned.compactMap { t -> EggColour? in
            guard plain & t.bit != 0, case .eggColour(let c) = t else { return nil }
            return c
        }
        if plain == full {
            for (bird, l) in [(hen, loci[0]), (rooster, loci[0]), (hen, loci[1]), (rooster, loci[1])] {
                let r = evidence(bird, l)
                if case .look = r { continue }
                return .eggColours(colours, sure: true, r)
            }
            return .eggColours(colours, sure: true, .look(bird: hen.id, locus: locusID(loci[0])))
        }
        // The open gene that could add a colour: the rooster's first, since a rooster never shows his
        // egg genes.
        for (isHen, l) in [(false, loci[0]), (false, loci[1]), (true, loci[0]), (true, loci[1])] {
            var h = henMasks
            var r = roosterMasks
            if isHen { h[l] = plainHen[l] } else { r[l] = plainRooster[l] }
            guard h != henMasks || r != roosterMasks else { continue }
            if Outcome(.eggs, hen: h, rooster: r).can & Trait.eggColourBits != full {
                return .eggColours(colours, sure: false, .unknownFamily(locus: locusID(l)))
            }
        }
        return .eggColours(colours, sure: false, .unknownFamily(locus: locusID(loci[0])))
    }

    /// The genotypes in `mask` with the fewest non-plain alleles: the bird hides nothing it need not.
    static func plain(_ mask: GenotypeMask, _ l: Int) -> GenotypeMask {
        let space = GenotypeSpace.all[l]
        let plainAllele = space.locus.defaultAllele
        func extra(_ i: Int) -> Int { space.genotypes[i].alleles.count(where: { $0 != plainAllele }) }
        let fewest = mask.indices.map(extra).min() ?? 0
        return mask.indices.reduce(0) { m, i in extra(i) == fewest ? m | 1 << i : m }
    }

    // MARK: Likely

    /// Genes where a parent has had many seen chicks that did not get an allele from it, and none that
    /// surely has it. Each is a likelihood: the parent probably lacks the allele. Only seen chicks count.
    func likelyFacts() -> [Likely] {
        var out: [Likely] = []
        let need = max(1, rules.plannerLikelyAfterChicks)
        for (bird, start) in [(hen, henMasks), (rooster, roosterMasks)] {
            let seen = chicks[bird.id] ?? []
            guard seen.count >= need else { continue }
            for (l, space) in GenotypeSpace.all.enumerated() where start[l].nonzeroBitCount > 1 {
                var mask = start[l]
                // A hen passes her Z gene to her sons only.
                let sonsOnly = space.locus.inheritance == .zLinked && bird.sex == .hen
                // An egg gene shows only in a laying daughter: the count is of her laying daughters.
                let eggGene = Self.eggLoci.contains(l)
                var counted = 0
                for allele in space.locus.alleles {
                    let options = space.genotypes(in: mask)
                    let without = options.filter { !$0.has(allele) }
                    guard !without.isEmpty, without.count < options.count else { continue }
                    var informative = 0
                    var shows = false
                    for c in seen where (!sonsOnly || c.sex == .rooster) && (!eggGene || c.look?.eggColour != nil) {
                        let theirs = k.candidates(c.id, space.locus.id)
                        guard !theirs.isEmpty else { continue }
                        if theirs.allSatisfy({ $0.has(allele) }) {
                            shows = true
                            break
                        }
                        if !theirs.contains(where: { $0.has(allele) }) { informative += 1 }
                    }
                    guard !shows, informative >= need else { continue }
                    mask = without.reduce(0) { $0 | (Mendel.index[l][$1].map { 1 << $0 } ?? 0) }
                    counted = max(counted, informative)
                }
                if mask != start[l] { out.append(Likely(bird: bird.id, locus: l, mask: mask, chicks: counted)) }
            }
        }
        return out
    }

    /// The genes an egg trait turns on. Their likely facts count laying daughters only.
    static let eggLoci = Set(ChickLookTable.eggs.loci)

    /// The likely fact that rules a trait out on its own, at a gene that decides the trait. Nil when no
    /// single fact does.
    func fact(ruling t: Trait, _ facts: [Likely]) -> Likely? {
        let loci = t.loci.map(Mendel.position)
        return facts.first { f in
            guard loci.contains(f.locus) else { return false }
            var h = henMasks
            var r = roosterMasks
            if f.bird == hen.id { h[f.locus] = f.mask } else { r[f.locus] = f.mask }
            return Outcome(t.isEggTrait ? .eggs : .plumage, hen: h, rooster: r).can & t.bit == 0
        }
    }

    // MARK: Reasons

    /// Why a trait is certain (or impossible): the first gene that settles it, and the parent whose
    /// knowledge settles it alone (the hen when it takes both).
    mutating func proofReason(_ t: Trait, impossible: Bool) -> Reason {
        func holds(_ o: Outcome) -> Bool { impossible ? o.can & t.bit == 0 : o.must & t.bit != 0 }
        for id in t.loci {
            let l = Mendel.position(id)
            if holds(open(t.isEggTrait, l, hen: true, rooster: true)) { continue }
            if holds(open(t.isEggTrait, l, hen: false, rooster: true)) { return evidence(hen, l) }
            if holds(open(t.isEggTrait, l, hen: true, rooster: false)) { return evidence(rooster, l) }
            return evidence(hen, l)
        }
        return evidence(hen, Mendel.position(t.loci[0]))
    }

    /// The outcome with one gene opened up for one or both parents: anything their sex allows.
    mutating func open(_ isEgg: Bool, _ l: Int, hen openHen: Bool, rooster openRooster: Bool) -> Outcome {
        let key = OpenKey(eggs: isEgg, locus: l, hen: openHen, rooster: openRooster)
        if let known = opened[key] { return known }
        var h = henMasks
        var r = roosterMasks
        if openHen { h[l] = GenotypeSpace.all[l].henMask }
        if openRooster { r[l] = GenotypeSpace.all[l].roosterMask }
        let o = Outcome(isEgg ? .eggs : .plumage, hen: h, rooster: r)
        opened[key] = o
        return o
    }

    /// Why a share is known: the hen's knowledge of the gene that decides it, or the rooster's when
    /// his says more than a look.
    func ratioReason(_ t: Trait) -> Reason {
        let l = Mendel.position(t.loci[0])
        let h = evidence(hen, l)
        guard case .look = h else { return h }
        let r = evidence(rooster, l)
        if case .look = r { return h }
        return r
    }

    /// Why a trait may hatch: the first open gene that decides it. White hides what lies under it.
    /// "Nobody in the family has shown it" only when that is true; when the family showed it, the
    /// evidence of a parent whose gene is (half) known, such as "her mother was lavender".
    func possibleReason(_ t: Trait, _ o: Outcome) -> Reason {
        let whiteHides = [
            BaseColour.locus, BlueDilution.locus, Lavender.locus, Lacing.locus, Barring.locus, DominantWhite.locus,
        ].map(Mendel.position)
        let decides = t.loci.map(Mendel.position) + o.dependsOn.keys.sorted()
        for l in decides where (o.dependsOn[l] ?? 0) & t.bit != 0 {
            if let white, whiteHides.contains(l) {
                let masks = white == hen.id ? henMasks : roosterMasks
                if masks[l].nonzeroBitCount > 1 { return .white(bird: white) }
            }
            if familyShown & t.bit == 0 { return .unknownFamily(locus: locusID(l)) }
            return familyReason(l)
        }
        if let white { return .white(bird: white) }
        return evidence(hen, Mendel.position(t.loci[0]))
    }

    /// The family's evidence at an open gene: a parent's proven hidden allele there first, else the
    /// look of a parent known at least in part there, else the family tree.
    func familyReason(_ l: Int) -> Reason {
        let known = [hen, rooster].filter { k.state($0.id, locusID(l)) != .open }
        for bird in known {
            let r = evidence(bird, l)
            if case .look = r { continue }
            return r
        }
        if let bird = known.first { return evidence(bird, l) }
        return .family(hen: hen.id, rooster: rooster.id)
    }

    /// A bird's evidence at a gene, as a reason that names only seen birds: the bird's look when the
    /// look alone says as much, else the evidence Knowledge gives for an allele proven but not shown,
    /// else its breed (a bird from outside) or its family tree.
    func evidence(_ bird: Visible, _ l: Int) -> Reason {
        let id = locusID(l)
        let space = GenotypeSpace.all[l]
        let known = bird.id == hen.id ? henMasks[l] : bird.id == rooster.id ? roosterMasks[l] : 0
        let fromLook = bird.look.flatMap { LookTable.masks(for: $0, sex: bird.sex)?[l] } ?? space.allMask
        if known == fromLook & space.mask(for: bird.sex) { return .look(bird: bird.id, locus: id) }
        guard let proven = k.provenHidden(bird.id, includeDefault: true).first(where: { $0.locus == id }) else {
            if bird.isFromOutside, let breed = bird.breed { return .breed(bird: bird.id, breed) }
            return .family(hen: hen.id, rooster: rooster.id)
        }
        switch proven.evidence {
        case .look: return .look(bird: bird.id, locus: id)
        case .origin(let breed): return .breed(bird: bird.id, breed)
        case .outsideFlock: return bird.breed.map { .breed(bird: bird.id, $0) } ?? .look(bird: bird.id, locus: id)
        case .parent(let p): return .parent(bird: bird.id, parent: p, locus: id)
        case .parents(let mother, _): return .parent(bird: bird.id, parent: mother, locus: id)
        case .child(let c): return .chick(bird: bird.id, chick: c, locus: id)
        case .family: return .family(hen: hen.id, rooster: rooster.id)
        }
    }
}
