import Foundation
import Testing

@testable import FeatherwickCore

/// Knowledge: what the keeper can work out about hidden genes from looks and family alone.
/// Core rule 8 (no hidden-gene leaks) is what these tests guard.
@Suite struct KnowledgeTests {
    // MARK: - Helpers

    /// A test id from a small number, so birds sort in a known order.
    static func id(_ n: Int) -> UUID { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))! }

    /// A black Orpington changed by `edit`.
    static func genome(_ sex: Sex, _ edit: (inout Genome) -> Void = { _ in }) -> Genome {
        var g = Breed.orpington.purebred(sex)
        edit(&g)
        return g
    }

    /// The look of `g` at `level` (`.laying` for a laying hen, `.down` for a chick whose sex does not show).
    static func look(_ g: Genome, _ level: LookLevel = .feathers) -> SeenLook { SeenLook(Phenotype(g), level: level) }

    /// A bird as the keeper sees it. Home origin and no parents unless given: no origin evidence.
    static func seen(
        _ n: Int, _ sex: Sex?, _ look: SeenLook?, mother: Int? = nil, father: Int? = nil,
        breed: Breed? = .orpington, origin: String = Bird.homeOrigin, stage: LifeStage = .adult
    ) -> Visible {
        Visible(
            id: id(n), name: "Bird \(n)", sex: sex, stage: stage, breed: breed, isPurebred: true, origin: origin,
            motherID: mother.map(id), fatherID: father.map(id), look: look)
    }

    static func genotypes(_ locus: LocusID, _ list: [[String]]) -> Set<Genotype> {
        let def = Loci.definition(locus)!
        return Set(list.map { Genotype($0, at: def) })
    }

    /// Every genotype a bird of `sex` can have at `locus`.
    static func all(_ locus: LocusID, _ sex: Sex?) -> Set<Genotype> {
        let space = GenotypeSpace.all.first { $0.locus.id == locus }!
        return Set(space.genotypes(in: space.mask(for: sex)))
    }

    /// The genotype a real bird has at a single gene.
    static func truth(_ g: Genome, _ space: GenotypeSpace) -> Genotype {
        Genotype(g.alleles(at: space.locus), at: space.locus)
    }

    static func bird(
        _ g: Genome, _ breed: Breed, origin: String, _ s: GameState, _ rng: inout SeededRNG, age: Int? = nil,
        revealed: Bool = true, mother: UUID? = nil, father: UUID? = nil
    ) -> Bird {
        Bird(
            id: makeID(using: &rng), name: "Test", breed: breed, genome: g,
            hatchDay: s.day - (age ?? s.rules.adultAge), motherID: mother, fatherID: father, origin: origin,
            revealed: revealed)
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return try e.encode(value)
    }

    // MARK: - Blind test

    /// Games the blind test plays, each `blindDays` days by the balance sim's keeper.
    static let blindGames = 2_000
    static let blindDays = 120

    /// Everything the keeper can be told that comes from Knowledge, encoded. The blind test checks each
    /// one is byte-identical after every bird's genes are swapped for others with the same look.
    static let blindOutputs: [(name: String, make: @Sendable (GameState) throws -> Data)] = [
        ("knowledge", { try KnowledgeTests.encode(Knowledge.of($0)) }),
        (
            "carrier notes",
            { s in
                let k = Knowledge.of(s)
                let notes = (s.ownedBirds + s.rehomed).map(\.id).sorted { $0.uuidString < $1.uuidString }.map {
                    [$0.uuidString: k.provenHidden($0, includeDefault: true)]
                }
                return try KnowledgeTests.encode(notes)
            }
        ),
        ("planner", { try KnowledgeTests.encode(KnowledgeTests.blindForecasts($0)) }),
    ]

    /// The planner's forecast for pairs a keeper could pen: the penned pair, and each revealed adult
    /// hen with each revealed adult rooster in the coop (the sim keeper never pens): every pair, about 6
    /// a game. They add well under a minute to the blind test.
    static func blindForecasts(_ s: GameState) -> [[String: [Forecast]]] {
        var s = s
        s.plannerKnown = true
        var out: [[String: [Forecast]]] = []
        if case .forecast(let rooster, let pairs) = Planner.panel(in: s) {
            out += pairs.map { ["\($0.hen.uuidString) × \(rooster.uuidString)": $0.lines] }
        }
        let family = Visible.all(in: s)
        let k = Knowledge.of(family)
        let key = { (b: Bird) in b.id.uuidString }
        let adults = s.coop.filter { $0.revealed && $0.stage(onDay: s.day, rules: s.rules) == .adult }
            .sorted { key($0) < key($1) }
        let pairs = adults.filter { $0.sex == .rooster }.flatMap { r in
            adults.filter { $0.sex == .hen }.map { (hen: $0, rooster: r) }
        }
        for (hen, rooster) in pairs {
            let lines = Planner.forecast(
                hen: Visible(bird: hen, in: s), rooster: Visible(bird: rooster, in: s), knowledge: k, family: family,
                kinship: Pedigree.relatedness(hen.id, rooster.id, in: s), rules: s.rules)
            out.append(["\(key(hen)) × \(key(rooster))": lines])
        }
        return out
    }

    /// How much of a bird the keeper saw, worked out here from the game's own facts, not from `Visible`.
    /// At home: its down until it is revealed, then its feathers, and a grown hen's eggs. Out of sight
    /// (rehomed, boarding, lost): only the look frozen when it left, or its down for an old save.
    static func seenLevel(_ b: Bird, away: Bool, _ s: GameState) -> LookLevel {
        if away { return b.lastSeenLook?.level ?? .down }
        if !b.revealed { return .down }
        return b.sex == .hen && b.stage(onDay: s.day, rules: s.rules) == .adult ? .laying : .feathers
    }

    /// Replaces the genes of `g` with others that keep `key` (what the keeper saw) the same: at each
    /// single gene in turn, a different genotype when one keeps it, picked by `rng`. With `newSex`, a
    /// bird whose sex does not show first tries the other sex (with any barring that keeps the look).
    /// The quantitative genes stay as they are: Knowledge does not track them, and the egg shade reads
    /// them. Returns how many genes changed (a sex change counts as one).
    static func swapHidden(
        _ g: inout Genome, keeping key: (Genome) -> SeenLook, newSex: Bool = false, _ rng: inout SeededRNG
    ) -> Int {
        let before = key(g)
        var changed = 0
        if newSex, Bool.random(using: &rng) {
            let barring = GenotypeSpace.all.first { $0.locus.id == Barring.locus }!
            let other: Sex = g.sex == .hen ? .rooster : .hen
            for z in barring.genotypes(in: barring.mask(for: other)).shuffled(using: &rng) {
                let b = z.alleles.compactMap(Barring.init(rawValue:))
                var trial = g
                trial.sexChromosomes = other == .hen ? .hen(z: b[0]) : .rooster(z: AllelePair(b[0], b[1]))
                if key(trial) == before {
                    g = trial
                    changed += 1
                    break
                }
            }
        }
        for space in GenotypeSpace.all {
            let current = truth(g, space)
            let options = space.genotypes(in: space.mask(for: g.sex)).filter { $0 != current }.shuffled(using: &rng)
            for option in options {
                var trial = g
                trial.setAlleles(option.alleles, at: space.locus)
                if key(trial) == before {
                    g = trial
                    changed += 1
                    break
                }
            }
        }
        precondition(key(g) == before)
        return changed
    }

    /// Swaps the genes of every bird and every egg's chick in the state, keeping only what the keeper
    /// saw of each bird (`seenLevel`). A bird whose sex does not show may change sex. Eggs' chicks and a
    /// trade offer's hen were never seen; they keep their whole `Phenotype`, which is stricter.
    static func swapAll(_ s: inout GameState, _ rng: inout SeededRNG) -> Int {
        var changed = 0
        let state = s
        func swap(_ b: inout Bird, away: Bool) {
            let level = seenLevel(b, away: away, state)
            changed += swapHidden(
                &b.genome, keeping: { SeenLook(Phenotype($0), level: level).coarse }, newSex: !b.revealed, &rng)
        }
        let whole = { (g: Genome) in SeenLook(Phenotype(g), level: .laying) }
        for i in s.brooder.indices { swap(&s.brooder[i], away: false) }
        for i in s.henChicks.indices { swap(&s.henChicks[i], away: false) }
        for i in s.coop.indices { swap(&s.coop[i], away: false) }
        for i in s.boarding.indices { swap(&s.boarding[i], away: true) }
        for i in s.rehomed.indices { swap(&s.rehomed[i], away: true) }
        for i in s.lost.indices { swap(&s.lost[i].bird, away: true) }
        if s.tradeOffer != nil { changed += swapHidden(&s.tradeOffer!.hen.genome, keeping: whole, &rng) }
        for i in s.nest.indices where s.nest[i].embryo != nil {
            changed += swapHidden(&s.nest[i].embryo!, keeping: whole, &rng)
        }
        for i in s.carton.indices where s.carton[i].embryo != nil {
            changed += swapHidden(&s.carton[i].embryo!, keeping: whole, &rng)
        }
        for c in s.clutches.indices {
            for i in s.clutches[c].eggs.indices where s.clutches[c].eggs[i].embryo != nil {
                changed += swapHidden(&s.clutches[c].eggs[i].embryo!, keeping: whole, &rng)
            }
        }
        return changed
    }

    /// True if what Knowledge shows of an unsexed bird's sex-linked genes holds both a hen's form and a
    /// rooster's, so it cannot tell the sex.
    static func sexBlind(_ k: Knowledge, _ id: UUID) -> Bool {
        Loci.zLinked.allSatisfy { locus in
            let c = k.candidates(id, locus.id)
            return c.contains { $0.alleles.count == 1 } && c.contains { $0.alleles.count == 2 }
        }
    }

    struct BlindResult: Sendable {
        var games = 0
        var birds = 0
        var genesSwapped = 0
        var proven = 0
        var contradictions = 0
        var sexesSwapped = 0
        var mismatches: [String] = []
        var unsound: [String] = []

        mutating func add(_ o: BlindResult) {
            games += o.games
            birds += o.birds
            genesSwapped += o.genesSwapped
            proven += o.proven
            contradictions += o.contradictions
            sexesSwapped += o.sexesSwapped
            mismatches += o.mismatches.prefix(5)
            unsound += o.unsound.prefix(5)
        }
    }

    /// One game: play it, check the knowledge is sound (each real genotype is still a candidate, and no
    /// contradiction), then swap every bird's hidden genes and check every output is byte-identical.
    static func blindGame(seed: UInt64) -> BlindResult {
        var r = BlindResult(games: 1)
        var s = Simulation.play(seed: seed, days: blindDays)
        let k = Knowledge.of(s)
        r.contradictions = k.contradictions
        r.birds = k.birds.count
        for b in s.ownedBirds + s.rehomed {
            r.proven += k.provenHidden(b.id).count
            if !b.revealed, !sexBlind(k, b.id) { r.unsound.append("seed \(seed): \(b.name)'s sex shows") }
            for space in GenotypeSpace.all where !k.candidates(b.id, space.locus.id).contains(truth(b.genome, space)) {
                r.unsound.append("seed \(seed): \(b.name) at \(space.locus.id) is \(truth(b.genome, space))")
            }
        }
        do {
            let before = try blindOutputs.map { try $0.make(s) }
            var rng = SeededRNG(seed: seed ^ 0x5357_4150)  // "SWAP"
            let sexes = Dictionary(uniqueKeysWithValues: (s.ownedBirds + s.rehomed).map { ($0.id, $0.sex) })
            r.genesSwapped = swapAll(&s, &rng)
            r.sexesSwapped = (s.ownedBirds + s.rehomed).count { sexes[$0.id] != $0.sex }
            let after = try blindOutputs.map { try $0.make(s) }
            for (i, output) in blindOutputs.enumerated() where before[i] != after[i] {
                r.mismatches.append("seed \(seed): \(output.name) changed")
            }
        } catch {
            r.mismatches.append("seed \(seed): \(error)")
        }
        return r
    }

    /// The whole point: Knowledge never reads genes. Swap every bird's genes for others with the same
    /// look, in thousands of real games, and nothing it outputs may change by a single byte.
    @Test(.timeLimit(.minutes(30))) func blindTestOutputsDoNotDependOnHiddenGenes() async {
        _ = LookTable.table.count  // build the tables once, before the clock starts
        let clock = ContinuousClock()
        let start = clock.now
        let workers = max(1, ProcessInfo.processInfo.activeProcessorCount)
        let total = await withTaskGroup(of: BlindResult.self) { group in
            for w in 0..<workers {
                group.addTask {
                    var r = BlindResult()
                    for seed in stride(from: w + 1, through: Self.blindGames, by: workers) {
                        r.add(Self.blindGame(seed: UInt64(seed)))
                    }
                    return r
                }
            }
            var total = BlindResult()
            for await r in group { total.add(r) }
            return total
        }
        let elapsed = clock.now - start
        print(
            "Knowledge blind test: \(total.games) games × \(Self.blindDays) days, \(total.birds) birds, "
                + "\(total.genesSwapped) genes swapped, \(total.sexesSwapped) chicks changed sex, "
                + "\(total.proven) carrier notes, \(elapsed)")
        #expect(total.games == Self.blindGames)
        #expect(total.genesSwapped > 0)
        #expect(total.sexesSwapped > 0)
        #expect(total.proven > 0)
        #expect(total.mismatches.isEmpty, "\(total.mismatches)")
        // Sound in normal play: evidence never contradicts itself, and the truth is never ruled out.
        #expect(total.contradictions == 0)
        #expect(total.unsound.isEmpty, "\(total.unsound)")
    }

    // MARK: - Planner soundness

    /// Real crosses per checked pair.
    static let soundCrosses = 10_000
    /// Grown pairs taken from the sim games (`PlannerTests.simGames`), one per game in turn.
    static let soundGamePairs = 100
    /// Families bred here from shop birds, three pairs each: shop × shop (pinned, so ratios), and
    /// chicks of known parents (carriers proven by their parents).
    static let soundBredFamilies = 20

    struct SoundPair: Sendable {
        let state: GameState
        let hen: Bird
        let rooster: Bird
    }

    /// A family from shop birds: four grandparents, a daughter of the first two and a son of the last two.
    static func bredFamily(_ n: Int) -> [SoundPair] {
        var (s, rng) = startedGame(sex: .hen, seed: UInt64(1_000 + n))
        let breeds = Breed.allCases
        func shopBird(_ sex: Sex) -> Bird {
            let breed = breeds.randomElement(using: &rng)!
            let varieties =
                breed.definition.varieties + FeatherColour.allCases.map { ShopSpecial.variety(for: $0, on: breed) }
            let g = breed.purebred(
                sex, variety: varieties.randomElement(using: &rng)!, barred: Bool.random(using: &rng))
            let b = bird(g, breed, origin: "Speckle & Down", s, &rng, age: s.rules.adultAge * 3)
            s.coop.append(b)
            return b
        }
        func chick(_ sex: Sex, _ mother: Bird, _ father: Bird) -> Bird {
            var g = try! Breeding.cross(mother: mother.genome, father: father.genome, using: &rng)
            while g.sex != sex { g = try! Breeding.cross(mother: mother.genome, father: father.genome, using: &rng) }
            let b = bird(g, mother.breed, origin: Bird.homeOrigin, s, &rng, mother: mother.id, father: father.id)
            s.coop.append(b)
            return b
        }
        let grandparents = [shopBird(.hen), shopBird(.rooster), shopBird(.hen), shopBird(.rooster)]
        let daughter = chick(.hen, grandparents[0], grandparents[1])
        let son = chick(.rooster, grandparents[2], grandparents[3])
        return [
            SoundPair(state: s, hen: grandparents[0], rooster: grandparents[3]),
            SoundPair(state: s, hen: daughter, rooster: son),
            SoundPair(state: s, hen: grandparents[2], rooster: son),
        ]
    }

    static let soundPairs: [SoundPair] = {
        var out: [SoundPair] = []
        let games = PlannerTests.simGames.map { s in (s, PlannerTests.coopPairs(s)) }.filter { !$0.1.isEmpty }
        var round = 0
        while out.count < soundGamePairs, round < 50 {
            for (s, pairs) in games where out.count < soundGamePairs && round < pairs.count {
                out.append(SoundPair(state: s, hen: pairs[round].hen, rooster: pairs[round].rooster))
            }
            round += 1
        }
        return out + (0..<soundBredFamilies).flatMap(bredFamily)
    }()

    struct SoundResult: Sendable {
        var pairs = 0
        var lines: [String: Int] = [:]
        var failures: [String: [String]] = [:]

        mutating func checked(_ kind: String) { lines[kind, default: 0] += 1 }
        mutating func fail(_ kind: String, _ text: String) { failures[kind, default: []].append(text) }

        mutating func add(_ o: SoundResult) {
            pairs += o.pairs
            lines.merge(o.lines, uniquingKeysWith: +)
            for (kind, list) in o.failures { failures[kind, default: []] += list.prefix(5) }
        }
    }

    /// Breeds the real genomes of one pair `soundCrosses` times with `Breeding.cross` and checks each
    /// forecast line against the chicks. Egg colours are matched in their coarse form.
    static func checkSoundness(_ p: SoundPair, seed: UInt64) -> SoundResult {
        var r = SoundResult(pairs: 1)
        let s = p.state
        let family = Visible.all(in: s)
        let lines = Planner.forecast(
            hen: Visible(bird: p.hen, in: s), rooster: Visible(bird: p.rooster, in: s),
            knowledge: Knowledge.of(family), family: family, rules: s.rules)
        var rng = SeededRNG(seed: seed)
        var counts = [Int](repeating: 0, count: FeatherwickCore.Trait.planned.count)
        var daughters = 0
        var barredDaughters = 0
        var plainSons = 0
        var eggs: Set<EggColour> = []
        for _ in 0..<soundCrosses {
            let chick = Phenotype(try! Breeding.cross(mother: p.hen.genome, father: p.rooster.genome, using: &rng))
            for (i, t) in FeatherwickCore.Trait.planned.enumerated() where t.isShown(by: chick) { counts[i] += 1 }
            if chick.sex == .hen {
                daughters += 1
                if chick.isBarred { barredDaughters += 1 }
                if let egg = chick.eggColour { eggs.insert(egg.coarse) }
            } else if !chick.isBarred {
                plainSons += 1
            }
        }
        let shown = Dictionary(uniqueKeysWithValues: zip(FeatherwickCore.Trait.planned, counts))
        func total(_ t: FeatherwickCore.Trait) -> Int {
            switch t {
            case .eggColour, .speckledEggs: daughters
            default: soundCrosses
            }
        }
        let name = "\(p.hen.name) × \(p.rooster.name), day \(s.day)"
        for line in lines {
            switch line {
            case .notPossible(let t, _):
                r.checked("not possible")
                if shown[t, default: 0] > 0 { r.fail("not possible", "\(name): \(t) hatched \(shown[t]!) times") }
            case .certain(let t, _):
                r.checked("certain")
                if shown[t, default: 0] != total(t) {
                    r.fail("certain", "\(name): \(t) in \(shown[t, default: 0]) of \(total(t))")
                }
            case .ratio(let t, let n, let d, _):
                r.checked("ratio")
                let share = Double(shown[t, default: 0]) / Double(max(1, total(t)))
                if abs(share - Double(n) / Double(d)) > 0.03 {
                    r.fail("ratio", "\(name): \(t) \(n) in \(d), real \(share)")
                }
            case .eggColours(let colours, true, _):
                r.checked("egg colours")
                if !eggs.isSubset(of: colours) { r.fail("egg colours", "\(name): \(eggs) not in \(colours)") }
            case .sexLink:
                r.checked("sex-link")
                // "Every barred chick a cockerel, every plain one a pullet": both halves must hold.
                if barredDaughters > 0 { r.fail("sex-link", "\(name): \(barredDaughters) barred daughters") }
                if plainSons > 0 { r.fail("sex-link", "\(name): \(plainSons) plain sons") }
            default:
                break
            }
        }
        return r
    }

    /// Every pair checked once, in parallel. The three tests below read the result.
    static let soundness: SoundResult = {
        let pairs = soundPairs
        let clock = ContinuousClock()
        let start = clock.now
        let out = Collected<SoundResult>(count: pairs.count)
        DispatchQueue.concurrentPerform(iterations: pairs.count) { i in
            out.set(i, checkSoundness(pairs[i], seed: UInt64(i + 1)))
        }
        var total = SoundResult()
        for r in out.values { total.add(r) }
        print(
            "Planner soundness: \(total.pairs) pairs × \(soundCrosses) crosses, lines checked "
                + "\(total.lines.sorted { $0.key < $1.key }), \(clock.now - start)")
        return total
    }()

    /// "Not possible" is a proof: real crosses never hatch it.
    @Test(.timeLimit(.minutes(20))) func plannerNotPossibleNeverHatches() {
        let r = Self.soundness
        #expect(r.pairs == Self.soundPairs.count)
        #expect(r.pairs >= Self.soundGamePairs)
        #expect(r.lines["not possible", default: 0] > 100)
        #expect(r.failures["not possible", default: []].isEmpty, "\(r.failures["not possible", default: []])")
        // A sure egg-colour list and a sex-link are proofs too.
        #expect(r.lines["egg colours", default: 0] > 0)
        #expect(r.failures["egg colours", default: []].isEmpty, "\(r.failures["egg colours", default: []])")
        #expect(r.failures["sex-link", default: []].isEmpty, "\(r.failures["sex-link", default: []])")
    }

    /// "Certain" is a proof: every real chick (every daughter, for eggs) shows it.
    @Test(.timeLimit(.minutes(20))) func plannerCertainAlwaysHatches() {
        let r = Self.soundness
        #expect(r.lines["certain", default: 0] > 50)
        #expect(r.failures["certain", default: []].isEmpty, "\(r.failures["certain", default: []])")
    }

    /// A ratio is Mendel's share: real crosses land within 3 percentage points of it.
    @Test(.timeLimit(.minutes(20))) func plannerRatiosMatchRealCrosses() {
        let r = Self.soundness
        #expect(r.lines["ratio", default: 0] > 20)
        #expect(r.failures["ratio", default: []].isEmpty, "\(r.failures["ratio", default: []])")
    }

    // MARK: - Elimination: look

    @Test func blueIsOneCopyOfBlue() {
        let k = Knowledge.of([
            Self.seen(1, .hen, Self.look(Self.genome(.hen) { $0.blue = AllelePair(.blue, .notBlue) }))
        ])
        #expect(k.candidates(Self.id(1), BlueDilution.locus) == Self.genotypes(BlueDilution.locus, [["Bl", "bl+"]]))
        #expect(k.state(Self.id(1), BlueDilution.locus) == .pinned)
        #expect(k.provenHidden(Self.id(1)).isEmpty)  // blue shows: nothing hidden
    }

    @Test func splashIsTwoCopiesOfBlue() {
        let k = Knowledge.of([Self.seen(1, .rooster, Self.look(Self.genome(.rooster) { $0.blue = .homozygous(.blue) }))]
        )
        #expect(k.candidates(Self.id(1), BlueDilution.locus) == Self.genotypes(BlueDilution.locus, [["Bl", "Bl"]]))
    }

    @Test func lavenderIsTwoCopiesOfLavender() {
        let k = Knowledge.of([
            Self.seen(1, .hen, Self.look(Self.genome(.hen) { $0.lavender = .homozygous(.lavender) }))
        ])
        #expect(k.candidates(Self.id(1), Lavender.locus) == Self.genotypes(Lavender.locus, [["lav", "lav"]]))
        // Lavender hides blue: the blue gene stays open.
        #expect(k.state(Self.id(1), BlueDilution.locus) == .open)
    }

    @Test func aBlackBirdWithALavenderParentCarriesLavender() {
        let k = Knowledge.of([
            Self.seen(1, .hen, Self.look(Self.genome(.hen) { $0.lavender = .homozygous(.lavender) })),
            Self.seen(2, .rooster, Self.look(Self.genome(.rooster)), mother: 1),
        ])
        #expect(k.candidates(Self.id(2), Lavender.locus) == Self.genotypes(Lavender.locus, [["lav+", "lav"]]))
        #expect(k.state(Self.id(2), Lavender.locus) == .pinned)
        let note = k.provenHidden(Self.id(2))
        #expect(
            note == [
                ProvenAllele(
                    locus: Lavender.locus, allele: "lav", copies: 1, isDefault: false, evidence: .parent(Self.id(1)))
            ])
    }

    /// The chick's sex does not show yet: the evidence must not need it.
    @Test func aBlackPairWithALavenderChickAreBothCarriers() {
        let chick = Self.genome(.hen) { $0.lavender = .homozygous(.lavender) }
        let k = Knowledge.of([
            Self.seen(1, .hen, Self.look(Self.genome(.hen))),
            Self.seen(2, .rooster, Self.look(Self.genome(.rooster))),
            Self.seen(3, nil, Self.look(chick, .down), mother: 1, father: 2, breed: nil, stage: .chick),
        ])
        #expect(Self.look(chick, .down).chickDown == .silver)
        for parent in [1, 2] {
            #expect(k.candidates(Self.id(parent), Lavender.locus) == Self.genotypes(Lavender.locus, [["lav+", "lav"]]))
            #expect(k.provenHidden(Self.id(parent)).map(\.allele) == ["lav"])
            #expect(k.provenHidden(Self.id(parent)).first?.evidence == .child(Self.id(3)))
        }
        // The same chick as a rooster chick gives the very same knowledge: its sex is not used.
        let asRooster = Self.genome(.rooster) { $0.lavender = .homozygous(.lavender) }
        #expect(Self.look(asRooster, .down) == Self.look(chick, .down))
    }

    /// A blue-egg mother passes O only if she has two copies. A purebred Araucana from outside does;
    /// a home-bred blue layer may have one, so her son may not carry it.
    @Test func aRoosterFromAPureBlueEggMotherCarriesBlueShell() {
        let mother = Breed.araucana.purebred(.hen)
        #expect(Phenotype(mother).eggColour == .blue)
        let son = Self.genome(.rooster)
        let k = Knowledge.of([
            Self.seen(1, .hen, Self.look(mother, .laying), breed: .araucana, origin: "Speckle & Down"),
            Self.seen(2, .rooster, Self.look(son), mother: 1),
        ])
        #expect(k.provenHidden(Self.id(2)).contains { $0.locus == BlueShell.locus && $0.allele == "O" })
        #expect(k.provenHidden(Self.id(2)).first { $0.allele == "O" }?.evidence == .parent(Self.id(1)))

        // A blue layer hatched at home, parents unknown: she may be O/o+, so nothing is proven.
        let home = Knowledge.of([
            Self.seen(1, .hen, Self.look(mother, .laying), breed: .araucana),
            Self.seen(2, .rooster, Self.look(son), mother: 1),
        ])
        #expect(
            home.candidates(Self.id(1), BlueShell.locus)
                == Self.genotypes(BlueShell.locus, [["O", "O"], ["O", "o+"]]))
        #expect(!home.provenHidden(Self.id(2)).contains { $0.allele == "O" })
    }

    /// A rooster whose daughters (by blue-egg hens) all lay cream. Each daughter got o+ from him, so
    /// he is not O/O. But any number of cream daughters fits O/o+ too: elimination can never rule it
    /// out. "After N daughters he is likely o+/o+" is a likelihood: the planner shows it as "likely"
    /// (`Reason.manyChicks`), never as an elimination.
    @Test func creamDaughtersNeverEliminateOneCopyOfBlueShell() {
        let blueHen = Self.genome(.hen) { $0.blueShell = AllelePair(.blue, .white) }
        let creamDaughter = Self.genome(.hen)
        for daughters in 1...8 {
            var birds = [Self.seen(1, .rooster, Self.look(Self.genome(.rooster)))]
            for d in 0..<daughters {
                birds.append(Self.seen(10 + d, .hen, Self.look(blueHen, .laying)))
                birds.append(Self.seen(100 + d, .hen, Self.look(creamDaughter, .laying), mother: 10 + d, father: 1))
            }
            let k = Knowledge.of(birds)
            #expect(
                k.candidates(Self.id(1), BlueShell.locus)
                    == Self.genotypes(BlueShell.locus, [["O", "o+"], ["o+", "o+"]]))
            #expect(k.state(Self.id(1), BlueShell.locus) == .halfPinned)
            #expect(!k.provenHidden(Self.id(1)).contains { $0.allele == "O" })
        }
    }

    /// White hides base colour, blue, lavender, lacing and barring: each stays fully open.
    @Test func aWhiteBirdLeavesTheHiddenColourGenesOpen() {
        let white = Self.genome(.hen) { $0.dominantWhite = .homozygous(.white) }
        let k = Knowledge.of([Self.seen(1, .hen, Self.look(white))])
        #expect(
            k.candidates(Self.id(1), DominantWhite.locus)
                == Self.genotypes(DominantWhite.locus, [["I", "I"], ["I", "i+"]]))
        for locus in [BaseColour.locus, BlueDilution.locus, Lavender.locus, Lacing.locus, Barring.locus] {
            #expect(k.candidates(Self.id(1), locus) == Self.all(locus, .hen), "\(locus)")
        }
        // A grown hen not yet laying: her egg genes are open too.
        for locus in [BlueShell.locus, BrownShell.locus, Speckle.locus] {
            #expect(k.candidates(Self.id(1), locus) == Self.all(locus, .hen))
        }
    }

    @Test func aBarredHenHasOneBarredZ() {
        let barred = Self.genome(.hen) { $0.sexChromosomes = .hen(z: .barred) }
        let k = Knowledge.of([Self.seen(1, .hen, Self.look(barred))])
        #expect(k.candidates(Self.id(1), Barring.locus) == Self.genotypes(Barring.locus, [["B"]]))
    }

    @Test func aPlainGrownRoosterHasNoBarring() {
        let k = Knowledge.of([Self.seen(1, .rooster, Self.look(Self.genome(.rooster)))])
        #expect(k.candidates(Self.id(1), Barring.locus) == Self.genotypes(Barring.locus, [["b+", "b+"]]))
    }

    /// A chick whose sex does not show keeps the hen and the rooster forms of a Z gene.
    @Test func anUnsexedChickKeepsBothSexesOfBarring() {
        let k = Knowledge.of([Self.seen(1, nil, Self.look(Self.genome(.hen), .down), breed: nil, stage: .chick)])
        #expect(k.candidates(Self.id(1), Barring.locus) == Self.genotypes(Barring.locus, [["b+"], ["b+", "b+"]]))
    }

    /// Yellow down is buff or white. That ties two genes together, which per-gene lists cannot hold; they
    /// stay sound. It is the only such look.
    @Test func lookSetsAreProductSetsExceptYellowDown() {
        let odd = LookTable.nonProductLooks
        #expect(!odd.isEmpty)
        #expect(odd.allSatisfy { $0.look.chickDown == .yellow }, "\(odd)")
    }

    /// Barred hen × plain rooster: a barred chick can only be a son (real keepers autosex this way). Its
    /// sex does not show yet, so Knowledge must keep the hen's and the rooster's barred forms alike.
    @Test func anUnsexedBarredChickKeepsBothSexes() {
        let barredHen = Self.genome(.hen) { $0.sexChromosomes = .hen(z: .barred) }
        let son = Self.genome(.rooster) { $0.sexChromosomes = .rooster(z: AllelePair(.barred, .plain)) }
        let k = Knowledge.of([
            Self.seen(1, .hen, Self.look(barredHen)),
            Self.seen(2, .rooster, Self.look(Self.genome(.rooster)), origin: "Speckle & Down"),
            Self.seen(3, nil, Self.look(son, .down), mother: 1, father: 2, breed: nil, stage: .chick),
        ])
        #expect(
            k.candidates(Self.id(3), Barring.locus)
                == Self.genotypes(Barring.locus, [["B"], ["B", "B"], ["B", "b+"]]))
        #expect(Self.sexBlind(k, Self.id(3)))
        // The look-alike pullet chick gives the very same knowledge.
        let daughter = Self.genome(.hen) { $0.sexChromosomes = .hen(z: .barred) }
        #expect(Self.look(daughter, .down) == Self.look(son, .down))
    }

    // MARK: - Birds out of sight

    /// A grower hen rehomed before she laid. Her egg genes never showed, so no age she reaches later
    /// may tell the keeper anything about them, or about her father.
    @Test func aRehomedGrowerHenNeverShowsHerEggs() throws {
        var (s, rng) = startedGame(sex: .hen)
        let father = Self.bird(Self.genome(.rooster), .orpington, origin: Bird.homeOrigin, s, &rng)
        let hen = Self.bird(
            Self.genome(.hen) { $0.blueShell = AllelePair(.blue, .white) }, .orpington, origin: Bird.homeOrigin, s,
            &rng, age: s.rules.growerAge, father: father.id)
        s.coop += [father, hen]
        _ = Engine.apply(.rehome(hen.id), to: &s, using: &rng)
        try #require(s.rehomed.contains { $0.id == hen.id })
        #expect(s.rehomed.first { $0.id == hen.id }?.lastSeenLook?.level == .feathers)
        s.day += 2 * s.rules.adultAge
        let k = Knowledge.of(s)
        #expect(Visible.all(in: s).first { $0.id == hen.id }?.look?.eggColour == nil)
        for locus in [BlueShell.locus, BrownShell.locus, Speckle.locus] {
            #expect(k.candidates(hen.id, locus) == Self.all(locus, .hen), "\(locus)")
            #expect(k.candidates(father.id, locus) == Self.all(locus, .rooster), "\(locus)")
        }
        #expect(k.provenHidden(father.id).isEmpty)
    }

    /// Lost and boarding birds are out of sight too: their look stays as it was when they left, and
    /// comes back to today's when they are home again.
    @Test func lostAndBoardingBirdsKeepTheLookTheyLeftWith() {
        var (s, rng) = startedGame(sex: .hen)
        let blue = Self.genome(.hen) { $0.blueShell = .homozygous(.blue) }
        let lost = Self.bird(blue, .orpington, origin: Bird.homeOrigin, s, &rng, age: s.rules.growerAge)
        let boarding = Self.bird(blue, .orpington, origin: Bird.homeOrigin, s, &rng, age: s.rules.growerAge)
        s.lost.append(LostBird(bird: lost.leavingSight(in: s, onDay: s.day), returnsOnDay: s.day + 999))
        s.boarding.append(boarding.leavingSight(in: s, onDay: s.day))
        s.day += s.rules.adultAge
        let k = Knowledge.of(s)
        for b in [lost, boarding] {
            #expect(Visible.all(in: s).first { $0.id == b.id }?.look?.level == .feathers)
            #expect(k.candidates(b.id, BlueShell.locus) == Self.all(BlueShell.locus, .hen))
        }
        // Home again, she lays where the keeper sees.
        var home = s.boarding.removeFirst()
        home.lastSeenLook = nil
        s.coop.append(home)
        #expect(Visible.all(in: s).first { $0.id == home.id }?.look?.eggColour != nil)
    }

    /// A rehomed bird from a save made before looks were frozen: the day it left is not known, so it
    /// shows only its down.
    @Test func anOldRehomedBirdShowsOnlyItsDown() {
        var (s, rng) = startedGame(sex: .hen)
        let hen = Self.bird(Self.genome(.hen), .orpington, origin: Bird.homeOrigin, s, &rng)
        s.rehomed.append(hen)
        #expect(hen.lastSeenLook == nil)
        let v = Visible.all(in: s).first { $0.id == hen.id }
        #expect(v?.look?.level == .down)
        #expect(v?.sex == .hen)  // its sex showed before it left
    }

    // MARK: - Origin

    @Test func aLavenderOrpingtonFromTheShopIsPinnedEverywhere() {
        var (s, rng) = startedGame(sex: .hen)
        let g = Breed.orpington.purebred(.hen, variety: .lavender)
        let b = Self.bird(g, .orpington, origin: "Speckle & Down", s, &rng, age: s.rules.growerAge)
        s.coop.append(b)
        let k = Knowledge.of(s)
        for space in GenotypeSpace.all {
            #expect(k.state(b.id, space.locus.id) == .pinned, "\(space.locus.id)")
            #expect(k.candidates(b.id, space.locus.id) == [Self.truth(g, space)])
        }
        // Brown shell is pinned by the breed and not shown on a pullet: a carrier note from origin.
        #expect(
            k.provenHidden(b.id).contains {
                $0.locus == BrownShell.locus && $0.copies == 2 && $0.evidence == .origin(.orpington)
            })
    }

    /// A surprise pullet: any recipe of its breed (each variety, and any colour the shop can name,
    /// barred or not) that gives the look it shows. Worked out here straight from the recipes.
    @Test func aSurprisePulletIsHerBreedsRecipesThatFitHerLook() throws {
        for seed in UInt64(1)...12 {
            var (s, rng) = startedGame(sex: .rooster, seed: seed)
            s.coins = 1_000
            s.perches = 20
            _ = Engine.apply(.buy(.pullet), to: &s, using: &rng)
            let pullet = try #require(s.coop.last)
            let seen = SeenLook(of: pullet, in: s)
            let def = pullet.breed.definition
            let varieties =
                def.varieties + FeatherColour.allCases.map { ShopSpecial.variety(for: $0, on: pullet.breed) }
            var expected = GenotypeSpace.all.map { _ in Set<Genotype>() }
            for variety in varieties {
                for barred in [false, true] {
                    let g = pullet.breed.purebred(.hen, variety: variety, barred: barred)
                    guard SeenLook(Phenotype(g), level: seen.level).coarse == seen.coarse else { continue }
                    for (l, space) in GenotypeSpace.all.enumerated() { expected[l].insert(Self.truth(g, space)) }
                }
            }
            let k = Knowledge.of(s)
            for (l, space) in GenotypeSpace.all.enumerated() {
                #expect(k.candidates(pullet.id, space.locus.id) == expected[l], "\(pullet.breed) \(space.locus.id)")
                #expect(expected[l].contains(Self.truth(pullet.genome, space)))
            }
        }
    }

    @Test func aHomeHatchedPurebredIsPinnedOnlyThroughItsParents() {
        var (s, rng) = startedGame(sex: .hen)
        let hen = Self.bird(Breed.orpington.purebred(.hen), .orpington, origin: "Speckle & Down", s, &rng)
        let rooster = Self.bird(Breed.orpington.purebred(.rooster), .orpington, origin: "Speckle & Down", s, &rng)
        let g = Breed.orpington.purebred(.rooster)
        let chick = Self.bird(
            g, .orpington, origin: Bird.homeOrigin, s, &rng, age: s.rules.growerAge, mother: hen.id, father: rooster.id)
        s.coop += [hen, rooster, chick]
        let k = Knowledge.of(s)
        for space in GenotypeSpace.all {
            #expect(k.candidates(chick.id, space.locus.id) == [Self.truth(g, space)], "\(space.locus.id)")
        }
        // Brown shell: one copy from each parent, so the credit goes to both.
        #expect(
            k.provenHidden(chick.id).first { $0.locus == BrownShell.locus }?.evidence
                == .parents(hen.id, rooster.id))
        // Without its parents on record, the same chick has no origin evidence: its egg genes stay open.
        s.coop.removeAll { $0.id != chick.id }
        let alone = Knowledge.of(s)
        #expect(alone.state(chick.id, BrownShell.locus) == .open)
        #expect(alone.provenHidden(chick.id).isEmpty)
    }

    // MARK: - Fixpoint

    /// A grandchild's look reaches its grandmother, through a father whose look says nothing.
    @Test func grandchildEvidenceReachesTheGrandmother() {
        let black = Self.genome(.rooster)
        let lavender = Self.genome(.hen) { $0.lavender = .homozygous(.lavender) }
        // Grandmother 1: a record with no look. Grandfather 2: a black Orpington from outside (lav+/lav+).
        // Father 3: black. Mother 4: lavender. Chick 5: lavender.
        var birds = [
            Self.seen(1, .hen, nil),
            Self.seen(2, .rooster, Self.look(black), origin: "Speckle & Down"),
            Self.seen(3, .rooster, Self.look(black), mother: 1, father: 2),
            Self.seen(4, .hen, Self.look(lavender)),
        ]
        #expect(Knowledge.of(birds).candidates(Self.id(1), Lavender.locus) == Self.all(Lavender.locus, .hen))
        birds.append(Self.seen(5, nil, Self.look(lavender, .down), mother: 4, father: 3, breed: nil, stage: .chick))
        let k = Knowledge.of(birds)
        #expect(k.candidates(Self.id(2), Lavender.locus) == Self.genotypes(Lavender.locus, [["lav+", "lav+"]]))
        #expect(k.candidates(Self.id(3), Lavender.locus) == Self.genotypes(Lavender.locus, [["lav+", "lav"]]))
        #expect(
            k.candidates(Self.id(1), Lavender.locus)
                == Self.genotypes(Lavender.locus, [["lav+", "lav"], ["lav", "lav"]]))
        #expect(k.provenHidden(Self.id(1)).first { $0.allele == "lav" }?.evidence == .child(Self.id(3)))
    }

    @Test func aRehomedChickStillCounts() {
        var (s, rng) = startedGame(sex: .hen)
        let mother = Self.bird(
            Self.genome(.hen) { $0.lavender = AllelePair(.normal, .lavender) }, .orpington, origin: Bird.homeOrigin, s,
            &rng)
        let chick = Self.bird(
            Self.genome(.rooster) { $0.lavender = .homozygous(.lavender) }, .orpington, origin: Bird.homeOrigin, s,
            &rng, mother: mother.id)
        s.coop.append(mother)
        s.rehomed.append(chick)
        let k = Knowledge.of(s)
        #expect(k.candidates(mother.id, Lavender.locus) == Self.genotypes(Lavender.locus, [["lav+", "lav"]]))
        #expect(k.provenHidden(mother.id).first { $0.allele == "lav" }?.evidence == .child(chick.id))
    }

    /// An outside bird from an old save may fit no recipe the game has now (here: a silkie-feathered
    /// Orpington). Origin evidence is skipped for it, not counted as a contradiction.
    @Test func aLookThatFitsNoRecipeSkipsOriginEvidence() {
        let odd = Self.genome(.hen) { $0.feathering = .homozygous(.silkie) }
        let k = Knowledge.of([Self.seen(1, .hen, Self.look(odd, .laying), origin: "Speckle & Down")])
        #expect(k.contradictions == 0)
        #expect(k.candidates(Self.id(1), Feathering.locus) == Self.genotypes(Feathering.locus, [["h", "h"]]))
        // No breed evidence: lacing, which every Orpington recipe leaves plain, stays open.
        #expect(k.state(Self.id(1), Lacing.locus) == .open)
    }

    /// A record with no look (a parent of a bought egg) gives its breed's recipes and nothing more.
    @Test func aRecordWithNoLookGivesBreedEvidenceOnly() {
        var (s, rng) = startedGame(sex: .hen)
        let g = Breed.araucana.purebred(.hen, variety: .blue)
        let parent = Self.bird(g, .araucana, origin: "Local flock", s, &rng)
        s.pedigree[parent.id] = PedigreeRecord(parent, look: nil)
        let k = Knowledge.of(s)
        let araucana = RecipeTable.recipes(breed: .araucana, sex: .hen)
        for (l, space) in GenotypeSpace.all.enumerated() {
            let fromRecipes = Set(araucana.map { $0.genotypes[l] })
            #expect(k.candidates(parent.id, space.locus.id) == fromRecipes, "\(space.locus.id)")
        }
        // The breed fixes the blue shell, and nothing showed it: a note from the breed, not the look.
        #expect(k.provenHidden(parent.id).first { $0.allele == "O" }?.evidence == .origin(.araucana))
        // Its blue colour never showed, so the blue gene keeps every colour the breed comes in.
        #expect(k.state(parent.id, BlueDilution.locus) == .open)
    }

    /// Evidence that cannot all be true (a lavender chick from two pure black birds) is counted and
    /// ignored, never a crash or an empty set.
    @Test func contradictionsKeepTheLastSet() {
        let k = Knowledge.of([
            Self.seen(1, .hen, Self.look(Self.genome(.hen)), origin: "Speckle & Down"),
            Self.seen(2, .rooster, Self.look(Self.genome(.rooster)), origin: "Speckle & Down"),
            Self.seen(
                3, .hen, Self.look(Self.genome(.hen) { $0.lavender = .homozygous(.lavender) }), mother: 1, father: 2),
        ])
        #expect(k.contradictions > 0)
        for n in 1...3 { #expect(!k.candidates(Self.id(n), Lavender.locus).isEmpty) }
    }

    // MARK: - No reading of genes

    /// Every stored value of a `Visible`, all the way down. None may be genes.
    static func values(_ x: Any) -> [Any] {
        Mirror(reflecting: x).children.flatMap { [$0.value] + values($0.value) }
    }

    @Test func visibleHoldsNoGenes() {
        var (s, rng) = startedGame(sex: .rooster)
        let b = Self.bird(Breed.wyandotte.purebred(.hen, variety: .buff), .wyandotte, origin: "Neighbour", s, &rng)
        s.coop.append(b)
        let made = [
            Visible(bird: b, in: s),
            Visible(record: PedigreeRecord(b, look: SeenLook(of: b, in: s)), in: s),
            Visible(record: PedigreeRecord(b), in: s),
            Self.seen(1, .hen, Self.look(b.genome)),
        ]
        for v in made {
            #expect(!Self.values(v).contains { $0 is Genome || $0 is Bird || $0 is Phenotype })
        }
        #expect(!Self.values(Knowledge.of(s)).contains { $0 is Genome })
    }

    /// The files that reason about hidden genes, and what they may never contain.
    static let blindFiles = ["Knowledge.swift", "Planner.swift", "Inheritance.swift"]
    static let forbidden = ["genome", "Genome", "alleles(at:"]

    @Test func knowledgeSourceNeverReadsGenes() throws {
        let core = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/FeatherwickCore")
        for file in Self.blindFiles {
            let text = try String(contentsOf: core.appendingPathComponent(file), encoding: .utf8)
            #expect(text.count > 1_000, "\(file) not found")
            for word in Self.forbidden { #expect(!text.contains(word), "\(file) contains \(word)") }
        }
    }

    // MARK: - Determinism, speed, old saves

    @Test func sameStateGivesTheSameBytes() throws {
        let s = Simulation.play(seed: 9, days: 90)
        let a = try Self.encode(Knowledge.of(s))
        let b = try Self.encode(Knowledge.of(s))
        #expect(a == b)
        // The order the birds come in does not matter.
        var rng = SeededRNG(seed: 3)
        let shuffled = Knowledge.of(Visible.all(in: s).shuffled(using: &rng))
        #expect(try Self.encode(shuffled) == a)
        // And it round-trips.
        let decoded = try JSONDecoder().decode(Knowledge.self, from: a)
        #expect(decoded == Knowledge.of(s))
        #expect(
            decoded.candidates(s.coop[0].id, Lavender.locus) == Knowledge.of(s).candidates(s.coop[0].id, Lavender.locus)
        )
    }

    /// 40 birds in under a millisecond, once the tables are built: about 0.6 ms in a release build.
    /// `swift test` runs a debug build, about ten times slower (about 5 ms), so a debug run checks a
    /// looser limit. The measured median is printed either way.
    @Test func fortyBirdsAreQuick() {
        var birds: [Visible] = []
        var seed: UInt64 = 1
        while birds.count < 40 {
            birds = Visible.all(in: Simulation.play(seed: seed, days: 150))
            seed += 1
        }
        let forty = Array(birds.prefix(40))
        _ = Knowledge.of(forty)  // warm up the tables
        let clock = ContinuousClock()
        var times: [Duration] = []
        for _ in 0..<31 { times.append(clock.measure { _ = Knowledge.of(forty) }) }
        let median = times.sorted()[times.count / 2]
        print("Knowledge.of, \(forty.count) birds: median \(median)")
        #expect(forty.count == 40)
        #if DEBUG
            #expect(median < .milliseconds(25))
        #else
            #expect(median < .milliseconds(1))
        #endif
    }

    @Test func oldSaveLoadsAndBuildsKnowledge() throws {
        let game = try SaveFormat.decode(SaveFormatTests.fixture("save-v0"))
        let k = Knowledge.of(game.state)
        #expect(k.birds.count == Visible.all(in: game.state).count)
        #expect(!k.birds.isEmpty)
        #expect(k.contradictions == 0)
        #expect(game.state.pedigree.values.allSatisfy { $0.look == nil })
        // Sound for old saves too: every bird's real genotype is still among its candidates.
        let birds = game.state.ownedBirds + game.state.rehomed
        #expect(!birds.isEmpty)
        for b in birds {
            for space in GenotypeSpace.all {
                #expect(
                    k.candidates(b.id, space.locus.id).contains(Self.truth(b.genome, space)),
                    "\(b.name) at \(space.locus.id) is \(Self.truth(b.genome, space))")
            }
        }
    }
}
