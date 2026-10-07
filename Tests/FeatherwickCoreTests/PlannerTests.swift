import Foundation
import Testing

@testable import FeatherwickCore

/// "What might hatch": the planner's forecast for a penned pair, from what the keeper could know.
/// Its soundness against real crosses is in `KnowledgeTests` ("Planner soundness").
@Suite struct PlannerTests {
    // MARK: - Helpers

    static let shop = "Speckle & Down"

    /// Adds a grown bird (an adult unless `age` says otherwise) to the coop.
    @discardableResult
    static func add(
        _ g: Genome, _ breed: Breed, origin: String = Bird.homeOrigin, _ s: inout GameState,
        _ rng: inout SeededRNG, mother: Bird? = nil, father: Bird? = nil, age: Int? = nil
    ) -> Bird {
        let b = KnowledgeTests.bird(
            g, breed, origin: origin, s, &rng, age: age, mother: mother?.id, father: father?.id)
        s.coop.append(b)
        return b
    }

    /// The forecast for the pair, through the pen panel.
    static func lines(_ s: GameState, hen: Bird, rooster: Bird) -> [Forecast] {
        var s = s
        s.plannerKnown = true
        s.pen = [hen.id, rooster.id]
        guard case .forecast(let r, let pairs) = Planner.panel(in: s), r == rooster.id, pairs.count == 1 else {
            Issue.record("no forecast for the pair")
            return []
        }
        #expect(pairs[0].hen == hen.id)
        return pairs[0].lines
    }

    /// Every bird a reason names.
    static func birds(in r: Reason) -> [UUID] {
        switch r {
        case .look(let b, _), .breed(let b, _), .white(let b), .manyChicks(let b, _, _): [b]
        case .parent(let b, let p, _): [b, p]
        case .chick(let b, let c, _): [b, c]
        case .unknownFamily: []
        case .grades(let h, let r), .family(let h, let r): [h, r]
        }
    }

    static func ratio(_ lines: [Forecast], _ t: FeatherwickCore.Trait) -> (Int, Int)? {
        for line in lines { if case .ratio(t, let n, let d, _) = line { return (n, d) } }
        return nil
    }

    static func has(_ lines: [Forecast], _ match: (Forecast) -> Bool) -> Bool { lines.contains(where: match) }

    static func isPossible(_ f: Forecast, _ t: FeatherwickCore.Trait) -> Bool {
        if case .possible(t, _) = f { return true }
        return false
    }

    static func isNotPossible(_ f: Forecast, _ t: FeatherwickCore.Trait) -> Bool {
        if case .notPossible(t, _) = f { return true }
        return false
    }

    static func isRatio(_ f: Forecast) -> Bool {
        if case .ratio = f { return true }
        return false
    }

    /// The group of a line, in the order the panel lists them.
    static func group(_ f: Forecast) -> Int {
        switch f {
        case .certain: 0
        case .ratio: 1
        case .sexLink: 2
        case .eggColours: 3
        case .likely: 4
        case .possible: 5
        case .notPossible: 6
        case .typeOutlook: 7
        case .kinship: 8
        case .unknownUnderWhite: 9
        }
    }

    /// Sim games for the checks that need many real states: 200 seeds, 120 days each.
    static let simSeeds: [UInt64] = Array(1...200)
    static let simDays = 120
    static let simGames: [GameState] = {
        let out = Collected<GameState>(count: simSeeds.count)
        DispatchQueue.concurrentPerform(iterations: simSeeds.count) { i in
            out.set(i, Simulation.play(seed: simSeeds[i], days: simDays))
        }
        return out.values
    }()

    /// Every grown hen with every grown rooster in the coop: pairs a keeper could pen.
    static func coopPairs(_ s: GameState) -> [(hen: Bird, rooster: Bird)] {
        let grown = s.coop.filter { $0.revealed && $0.stage(onDay: s.day, rules: s.rules) == .adult }
        let hens = grown.filter { $0.sex == .hen }
        let roosters = grown.filter { $0.sex == .rooster }
        return roosters.flatMap { r in hens.map { (hen: $0, rooster: r) } }
    }

    // MARK: - 1. Ratios

    /// Two blue Orpingtons from the shop: pinned everywhere, so the shares are exact.
    @Test func blueByBlueGivesOneTwoOne() {
        var (s, rng) = startedGame(sex: .hen)
        let hen = Self.add(Breed.orpington.purebred(.hen, variety: .blue), .orpington, origin: Self.shop, &s, &rng)
        let rooster = Self.add(
            Breed.orpington.purebred(.rooster, variety: .blue), .orpington, origin: Self.shop, &s, &rng)
        let lines = Self.lines(s, hen: hen, rooster: rooster)
        #expect(Self.ratio(lines, .colour(.black)) ?? (0, 0) == (1, 4))
        #expect(Self.ratio(lines, .colour(.blue)) ?? (0, 0) == (2, 4))
        #expect(Self.ratio(lines, .colour(.splash)) ?? (0, 0) == (1, 4))
        #expect(!Self.has(lines) { Self.isPossible($0, .colour(.blue)) })
        #expect(!Self.has(lines) { Self.isPossible($0, .colour(.splash)) })
        // Shop birds are pinned: nothing is merely possible.
        #expect(!Self.has(lines) { if case .possible = $0 { true } else { false } })
        // The shares are the colours of every chick.
        #expect(Self.has(lines) { Self.isNotPossible($0, .colour(.lavender)) })
        // Lines come in group order.
        #expect(lines.map(Self.group) == lines.map(Self.group).sorted())
        // The reason is a bird's look.
        for line in lines {
            if case .ratio(_, _, _, let r) = line { #expect(r == .look(bird: hen.id, locus: BlueDilution.locus)) }
        }
    }

    /// Carriers proven by their parents: a silkie ratio from pinned hidden genes.
    @Test func provenCarriersGiveARatio() throws {
        var (s, rng) = startedGame(sex: .hen)
        let silkieHen = Self.add(Breed.silkie.purebred(.hen), .silkie, origin: Self.shop, &s, &rng)
        let silkieRooster = Self.add(Breed.silkie.purebred(.rooster), .silkie, origin: Self.shop, &s, &rng)
        let orpHen = Self.add(Breed.orpington.purebred(.hen), .orpington, origin: Self.shop, &s, &rng)
        let orpRooster = Self.add(Breed.orpington.purebred(.rooster), .orpington, origin: Self.shop, &s, &rng)
        let carrier = KnowledgeTests.genome(.hen) { $0.feathering = AllelePair(.normal, .silkie) }
        let hen = Self.add(carrier, .orpington, &s, &rng, mother: silkieHen, father: orpRooster)
        let rooster = Self.add(
            KnowledgeTests.genome(.rooster) { $0.feathering = AllelePair(.normal, .silkie) }, .orpington, &s, &rng,
            mother: orpHen, father: silkieRooster)
        let lines = Self.lines(s, hen: hen, rooster: rooster)
        #expect(Self.ratio(lines, .silkieFeathered) ?? (0, 0) == (1, 4))
        let reason = try #require(
            lines.compactMap { if case .ratio(.silkieFeathered, _, _, let r) = $0 { r } else { nil } }.first)
        #expect(reason == .parent(bird: hen.id, parent: silkieHen.id, locus: Feathering.locus))
    }

    // MARK: - 2, 3. Not possible and possible

    @Test func shopAustralorpsCannotHatchLavenderOrBlue() {
        var (s, rng) = startedGame(sex: .hen)
        let hen = Self.add(Breed.australorp.purebred(.hen), .australorp, origin: Self.shop, &s, &rng)
        let rooster = Self.add(Breed.australorp.purebred(.rooster), .australorp, origin: Self.shop, &s, &rng)
        let lines = Self.lines(s, hen: hen, rooster: rooster)
        #expect(Self.has(lines) { Self.isNotPossible($0, .colour(.lavender)) })
        #expect(Self.has(lines) { Self.isNotPossible($0, .colour(.blue)) })
        #expect(Self.has(lines) { if case .certain(.colour(.black), _) = $0 { true } else { false } })
        // Bounded: at most `plannerNotPossibleLines` lines.
        #expect(lines.count { if case .notPossible = $0 { true } else { false } } <= s.rules.plannerNotPossibleLines)
        // Lavender: the breed settles it.
        #expect(
            lines.contains(.notPossible(.colour(.lavender), .breed(bird: hen.id, .australorp))))
    }

    @Test func homeHatchedBlackPairMayHideLavender() {
        var (s, rng) = startedGame(sex: .hen)
        let hen = Self.add(KnowledgeTests.genome(.hen), .orpington, &s, &rng)
        let rooster = Self.add(KnowledgeTests.genome(.rooster), .orpington, &s, &rng)
        let lines = Self.lines(s, hen: hen, rooster: rooster)
        #expect(lines.contains(.possible(.colour(.lavender), .unknownFamily(locus: Lavender.locus))))
        #expect(!lines.contains(where: Self.isRatio))
        // Their looks prove some things: neither is white or barred.
        #expect(Self.has(lines) { Self.isNotPossible($0, .colour(.white)) })
        #expect(Self.has(lines) { Self.isNotPossible($0, .barred) })
        #expect(lines.map(Self.group) == lines.map(Self.group).sorted())
        // Black shows whenever its genes are there: no "if one of them is hiding black" line.
        for c in [FeatherColour.black, .blue, .splash, .white] {
            #expect(!Self.has(lines) { Self.isPossible($0, .colour(c)) }, "\(c)")
        }
    }

    /// The family showed lavender: the possible line names that evidence, never "nobody showed it".
    @Test func aPossibleLineNamesTheFamilyThatShowedIt() {
        var (s, rng) = startedGame(sex: .hen)
        let mother = Self.add(
            KnowledgeTests.genome(.hen) { $0.lavender = .homozygous(.lavender) }, .orpington, &s, &rng)
        let hen = Self.add(
            KnowledgeTests.genome(.hen) { $0.lavender = AllelePair(.normal, .lavender) }, .orpington, &s, &rng,
            mother: mother)
        let rooster = Self.add(KnowledgeTests.genome(.rooster), .orpington, &s, &rng)
        let lines = Self.lines(s, hen: hen, rooster: rooster)
        #expect(
            lines.contains(
                .possible(.colour(.lavender), .parent(bird: hen.id, parent: mother.id, locus: Lavender.locus))))
        #expect(!lines.contains(.possible(.colour(.lavender), .unknownFamily(locus: Lavender.locus))))
    }

    /// The same look and family give the same forecast, whatever the birds really carry (rule 8).
    @Test func lookAlikesGetTheSameForecast() {
        var (s, rng) = startedGame(sex: .hen)
        let plain = Self.add(KnowledgeTests.genome(.hen), .orpington, &s, &rng)
        let carrier = Self.add(
            KnowledgeTests.genome(.hen) { $0.lavender = AllelePair(.normal, .lavender) }, .orpington, &s, &rng)
        let rooster = Self.add(KnowledgeTests.genome(.rooster), .orpington, &s, &rng)
        let a = Self.lines(s, hen: plain, rooster: rooster).map { Self.renamed($0, plain.id, carrier.id) }
        let b = Self.lines(s, hen: carrier, rooster: rooster)
        #expect(a == b)
    }

    /// A line with one bird's id swapped for another's.
    static func renamed(_ f: Forecast, _ from: UUID, _ to: UUID) -> Forecast {
        func r(_ x: Reason) -> Reason {
            func n(_ id: UUID) -> UUID { id == from ? to : id }
            switch x {
            case .look(let b, let l): return .look(bird: n(b), locus: l)
            case .breed(let b, let br): return .breed(bird: n(b), br)
            case .parent(let b, let p, let l): return .parent(bird: n(b), parent: n(p), locus: l)
            case .chick(let b, let c, let l): return .chick(bird: n(b), chick: n(c), locus: l)
            case .unknownFamily: return x
            case .manyChicks(let b, let c, let l): return .manyChicks(bird: n(b), count: c, locus: l)
            case .grades(let h, let ro): return .grades(hen: n(h), rooster: n(ro))
            case .family(let h, let ro): return .family(hen: n(h), rooster: n(ro))
            case .white(let b): return .white(bird: n(b))
            }
        }
        switch f {
        case .certain(let t, let x): return .certain(t, r(x))
        case .ratio(let t, let a, let b, let x): return .ratio(t, numerator: a, denominator: b, r(x))
        case .likely(let t, let x): return .likely(t, r(x))
        case .possible(let t, let x): return .possible(t, r(x))
        case .notPossible(let t, let x): return .notPossible(t, r(x))
        case .sexLink(let sex, let x): return .sexLink(barredAre: sex, r(x))
        case .eggColours(let c, let sure, let x): return .eggColours(c, sure: sure, r(x))
        case .typeOutlook(let a, let b, let x): return .typeOutlook(a, b, r(x))
        case .kinship(let k, let x): return .kinship(k, r(x))
        case .unknownUnderWhite(let x): return .unknownUnderWhite(r(x))
        }
    }

    // MARK: - 4. Sex-link

    @Test func barredHenByPlainRoosterIsSexLinked() {
        var (s, rng) = startedGame(sex: .hen)
        let hen = Self.add(
            Breed.orpington.purebred(.hen, variety: .barred), .orpington, origin: Self.shop, &s, &rng)
        let plain = Self.add(Breed.orpington.purebred(.rooster), .orpington, origin: Self.shop, &s, &rng)
        let lines = Self.lines(s, hen: hen, rooster: plain)
        #expect(lines.contains(.sexLink(barredAre: .rooster, .look(bird: hen.id, locus: Barring.locus))))
        #expect(Self.ratio(lines, .barred) ?? (0, 0) == (1, 2))

        // A white rooster may carry barring under his white: no sex-link.
        let white = Self.add(
            KnowledgeTests.genome(.rooster) { $0.dominantWhite = .homozygous(.white) }, .orpington, &s, &rng)
        let underWhite = Self.lines(s, hen: hen, rooster: white)
        #expect(!Self.has(underWhite) { if case .sexLink = $0 { true } else { false } })
        // A plain hen never gives one.
        let plainHen = Self.add(Breed.orpington.purebred(.hen), .orpington, origin: Self.shop, &s, &rng)
        #expect(
            !Self.has(Self.lines(s, hen: plainHen, rooster: plain)) { if case .sexLink = $0 { true } else { false } })
    }

    // MARK: - 5. Egg colours

    @Test func eggColoursFromAPureBlueEggLine() {
        var (s, rng) = startedGame(sex: .hen)
        let hen = Self.add(Breed.araucana.purebred(.hen), .araucana, origin: Self.shop, &s, &rng)
        // His mother is a shop Araucana (two blue-shell genes), his father a shop Orpington (brown coat).
        let mother = Self.add(Breed.araucana.purebred(.hen), .araucana, origin: Self.shop, &s, &rng)
        let father = Self.add(Breed.orpington.purebred(.rooster), .orpington, origin: Self.shop, &s, &rng)
        let son = Self.add(
            KnowledgeTests.genome(.rooster) {
                $0.blueShell = AllelePair(.blue, .white)
                $0.brownShell = AllelePair(.brown, .noCoating)
            }, .orpington, &s, &rng, mother: mother, father: father)
        let lines = Self.lines(s, hen: hen, rooster: son)
        // Her two blue-shell genes (her breed) make every daughter's egg blue-based; his brown coat is half.
        #expect(
            lines.contains(
                .eggColours([.blue, .green], sure: true, .breed(bird: hen.id, .araucana))
            ))

        // A rooster of unknown family may carry the brown coat: blue, unless he carries brown.
        let stranger = Self.add(KnowledgeTests.genome(.rooster), .orpington, &s, &rng)
        #expect(
            Self.lines(s, hen: hen, rooster: stranger).contains(
                .eggColours([.blue], sure: false, .unknownFamily(locus: BrownShell.locus))))

        // A cream layer and a stranger: cream, unless he carries blue.
        let creamHen = Self.add(
            KnowledgeTests.genome(.hen) { $0.brownShell = .homozygous(.noCoating) }, .orpington, &s, &rng)
        #expect(
            Self.lines(s, hen: creamHen, rooster: stranger).contains(
                .eggColours([.cream], sure: false, .unknownFamily(locus: BlueShell.locus))))
    }

    // MARK: - Likely

    /// A buff rooster can hide barring. Five plain black chicks, none barred: "likely no barred chicks".
    @Test func manyPlainChicksMakeBarringUnlikely() {
        let buff = KnowledgeTests.genome(.rooster) { $0.baseColour = .homozygous(.buff) }
        let black = KnowledgeTests.genome(.hen)
        var birds = [
            KnowledgeTests.seen(1, .rooster, KnowledgeTests.look(buff)),
            KnowledgeTests.seen(2, .hen, KnowledgeTests.look(black, .laying)),
        ]
        for c in 0..<5 {
            birds.append(KnowledgeTests.seen(10 + c, .hen, KnowledgeTests.look(black)))
            birds.append(KnowledgeTests.seen(100 + c, .hen, KnowledgeTests.look(black), mother: 10 + c, father: 1))
        }
        let lines = Planner.forecast(hen: birds[1], rooster: birds[0], knowledge: Knowledge.of(birds), family: birds)
        #expect(
            lines.contains(.likely(.barred, .manyChicks(bird: KnowledgeTests.id(1), count: 5, locus: Barring.locus))))
        #expect(!Self.has(lines) { Self.isPossible($0, .barred) })
    }

    /// A rooster whose five laying daughters all lay cream probably has no blue-shell or brown-coat
    /// gene: "likely no blue eggs", "likely no brown eggs".
    @Test func manyCreamDaughtersMakeBlueUnlikely() {
        func forecast(daughters: Int) -> [Forecast] {
            let blueHen = KnowledgeTests.genome(.hen) { $0.blueShell = AllelePair(.blue, .white) }
            let cream = KnowledgeTests.genome(.hen) { $0.brownShell = .homozygous(.noCoating) }
            var birds = [
                KnowledgeTests.seen(1, .rooster, KnowledgeTests.look(KnowledgeTests.genome(.rooster))),
                KnowledgeTests.seen(2, .hen, KnowledgeTests.look(cream, .laying)),
            ]
            for d in 0..<daughters {
                birds.append(KnowledgeTests.seen(10 + d, .hen, KnowledgeTests.look(blueHen, .laying)))
                birds.append(
                    KnowledgeTests.seen(100 + d, .hen, KnowledgeTests.look(cream, .laying), mother: 10 + d, father: 1))
            }
            return Planner.forecast(
                hen: birds[1], rooster: birds[0], knowledge: Knowledge.of(birds), family: birds)
        }
        let rooster = KnowledgeTests.id(1)
        let five = forecast(daughters: Rules.standard.plannerLikelyAfterChicks)
        #expect(
            five.contains(.likely(.eggColour(.blue), .manyChicks(bird: rooster, count: 5, locus: BlueShell.locus))))
        #expect(
            five.contains(.likely(.eggColour(.brown), .manyChicks(bird: rooster, count: 5, locus: BrownShell.locus))))
        #expect(!Self.has(five) { if case .likely(.eggColour(.cream), _) = $0 { true } else { false } })
        // Still only likely: the egg colours line is not sure.
        #expect(five.contains(.eggColours([.cream], sure: false, .unknownFamily(locus: BlueShell.locus))))
        let four = forecast(daughters: Rules.standard.plannerLikelyAfterChicks - 1)
        #expect(!Self.has(four) { if case .likely = $0 { true } else { false } })
        // Without the family list there is nothing to count.
        let birds = [
            KnowledgeTests.seen(1, .rooster, KnowledgeTests.look(KnowledgeTests.genome(.rooster))),
            KnowledgeTests.seen(2, .hen, KnowledgeTests.look(KnowledgeTests.genome(.hen), .laying)),
        ]
        #expect(
            !Self.has(Planner.forecast(hen: birds[1], rooster: birds[0], knowledge: Knowledge.of(birds))) {
                if case .likely = $0 { true } else { false }
            })
    }

    // MARK: - 6. White

    @Test func whiteByWhiteGivesTheCaveatAndNoRatio() {
        var (s, rng) = startedGame(sex: .hen)
        let hen = Self.add(
            KnowledgeTests.genome(.hen) { $0.dominantWhite = AllelePair(.white, .wildType) }, .orpington, &s, &rng)
        let rooster = Self.add(
            KnowledgeTests.genome(.rooster) { $0.dominantWhite = AllelePair(.white, .wildType) }, .orpington, &s,
            &rng)
        let lines = Self.lines(s, hen: hen, rooster: rooster)
        #expect(lines.last == .unknownUnderWhite(.white(bird: hen.id)))
        #expect(!lines.contains(where: Self.isRatio))
        // The caveat speaks for the colours white hides: no flood of "possible" lines.
        for c in FeatherColour.allCases where c != .white {
            #expect(!Self.has(lines) { Self.isPossible($0, .colour(c)) })
        }

        // Shop white Orpingtons are white through and through: every chick white, no caveat.
        let pureHen = Self.add(
            Breed.orpington.purebred(.hen, variety: .white), .orpington, origin: Self.shop, &s, &rng)
        let pure = Self.lines(s, hen: pureHen, rooster: rooster)
        #expect(pure.contains { if case .certain(.colour(.white), _) = $0 { true } else { false } })
        #expect(!Self.has(pure) { if case .unknownUnderWhite = $0 { true } else { false } })
    }

    // MARK: - Type and kinship

    /// A type band comes only from a judge's notes the keeper was shown: the newest show that judged type.
    @Test func typeBandComesFromTheNewestShowNotes() {
        var (s, rng) = startedGame(sex: .hen)
        let hen = Self.add(Breed.orpington.purebred(.hen), .orpington, origin: Self.shop, &s, &rng)
        let rooster = Self.add(Breed.orpington.purebred(.rooster), .orpington, origin: Self.shop, &s, &rng)
        func result(_ bird: Bird, day: Int, _ notes: [JudgeNote]) -> ShowResult {
            ShowResult(
                day: day, showClass: .breed(.orpington), entrantName: bird.name, placing: 1, fieldSize: 8, score: 80,
                prize: 30, birdID: bird.id, treats: 0, notes: notes, theme: nil, podium: nil)
        }
        #expect(Visible(bird: hen, in: s).typeBand == nil)
        #expect(
            !Self.has(Self.lines(s, hen: hen, rooster: rooster)) { if case .typeOutlook = $0 { true } else { false } })
        s.showResults = [
            result(hen, day: 28, [.type(.fair)]), result(rooster, day: 28, [.type(.excellent)]),
            result(hen, day: 56, [.type(.good), .inFineCondition]),
            // A pet-class card has no type note: the band stays the last one judged.
            result(hen, day: 84, [.friendliness(.friendly)]),
        ]
        #expect(Visible(bird: hen, in: s).typeBand == .good)
        #expect(
            Self.lines(s, hen: hen, rooster: rooster).contains(
                .typeOutlook(.good, .excellent, .grades(hen: hen.id, rooster: rooster.id))))
    }

    @Test func typeOutlookNeedsBothBands() {
        let hen = Visible(
            id: KnowledgeTests.id(1), name: "Hen", sex: .hen, stage: .adult, breed: .orpington, isPurebred: true,
            origin: Bird.homeOrigin, motherID: nil, fatherID: nil,
            look: KnowledgeTests.look(KnowledgeTests.genome(.hen), .laying), typeBand: .good)
        var rooster = Visible(
            id: KnowledgeTests.id(2), name: "Rooster", sex: .rooster, stage: .adult, breed: .orpington,
            isPurebred: true, origin: Bird.homeOrigin, motherID: nil, fatherID: nil,
            look: KnowledgeTests.look(KnowledgeTests.genome(.rooster)), typeBand: .excellent)
        let both = Planner.forecast(hen: hen, rooster: rooster, knowledge: Knowledge.of([hen, rooster]))
        #expect(both.contains(.typeOutlook(.good, .excellent, .grades(hen: hen.id, rooster: rooster.id))))
        rooster = Visible(
            id: rooster.id, name: rooster.name, sex: .rooster, stage: .adult, breed: .orpington, isPurebred: true,
            origin: Bird.homeOrigin, motherID: nil, fatherID: nil, look: rooster.look)
        let one = Planner.forecast(hen: hen, rooster: rooster, knowledge: Knowledge.of([hen, rooster]))
        #expect(!Self.has(one) { if case .typeOutlook = $0 { true } else { false } })
    }

    @Test func kinshipOnlyWhenRelated() {
        var (s, rng) = startedGame(sex: .hen)
        let mother = Self.add(Breed.orpington.purebred(.hen), .orpington, origin: Self.shop, &s, &rng)
        let father = Self.add(Breed.orpington.purebred(.rooster), .orpington, origin: Self.shop, &s, &rng)
        let sister = Self.add(Breed.orpington.purebred(.hen), .orpington, &s, &rng, mother: mother, father: father)
        let brother = Self.add(
            Breed.orpington.purebred(.rooster), .orpington, &s, &rng, mother: mother, father: father)
        #expect(
            Self.lines(s, hen: sister, rooster: brother).contains(
                .kinship(.close, .family(hen: sister.id, rooster: brother.id))))
        #expect(
            !Self.has(Self.lines(s, hen: mother, rooster: father)) { if case .kinship = $0 { true } else { false } })
    }

    // MARK: - Panel

    @Test func panelStates() {
        var (s, rng) = startedGame(sex: .hen)
        let hens = (0..<3).map { _ in Self.add(KnowledgeTests.genome(.hen), .orpington, &s, &rng) }
        let rooster = Self.add(KnowledgeTests.genome(.rooster), .orpington, &s, &rng)
        s.plannerKnown = false
        s.pen = [hens[0].id, rooster.id]
        #expect(Planner.panel(in: s) == .hidden)
        s.plannerKnown = true
        s.pen = []
        #expect(Planner.panel(in: s) == .needsHen)
        s.pen = [rooster.id]
        #expect(Planner.panel(in: s) == .needsHen)
        s.pen = [hens[1].id]
        #expect(Planner.panel(in: s) == .needsRooster)
        // Hens in pen order, not coop order.
        s.pen = [hens[2].id, rooster.id, hens[0].id, hens[1].id]
        guard case .forecast(let r, let pairs) = Planner.panel(in: s) else {
            Issue.record("no forecast")
            return
        }
        #expect(r == rooster.id)
        #expect(pairs.map(\.hen) == [hens[2].id, hens[0].id, hens[1].id])
        #expect(Planner.panel(in: s) == Planner.panel(in: s))
    }

    /// A full pen (3 hens and a rooster, Knowledge built once): under 5 ms in a release build (about
    /// 1 ms measured, with 34 birds known). `swift test` runs a debug build, about ten times slower, so it
    /// checks under 100 ms. The limits leave room for slow CI machines; the median is printed either way.
    @Test func aFullPenIsQuick() {
        var s = Self.simGames.max { $0.coop.count < $1.coop.count }!
        let pairs = Self.coopPairs(s)
        let hens = Array(Set(pairs.map(\.hen.id)).sorted { $0.uuidString < $1.uuidString }.prefix(3))
        guard let rooster = pairs.first?.rooster.id, !hens.isEmpty else {
            Issue.record("no pair")
            return
        }
        s.plannerKnown = true
        s.pen = hens + [rooster]
        _ = Planner.panel(in: s)
        let clock = ContinuousClock()
        var times: [Duration] = []
        for _ in 0..<21 { times.append(clock.measure { _ = Planner.panel(in: s) }) }
        let median = times.sorted()[times.count / 2]
        print("Planner.panel, \(hens.count) hens, \(Visible.all(in: s).count) birds known: median \(median)")
        #if DEBUG
            #expect(median < .milliseconds(100))
        #else
            #expect(median < .milliseconds(5))
        #endif
    }

    // MARK: - 7. Reasons name only seen birds

    @Test func everyReasonNamesOnlySeenBirds() {
        var lines = 0
        var pairs = 0
        for s in Self.simGames {
            let family = Visible.all(in: s)
            let k = Knowledge.of(family)
            let seen = Set(
                s.ownedBirds.map(\.id) + s.rehomed.map(\.id) + s.pedigree.values.filter { $0.look != nil }.map(\.id))
            for (hen, rooster) in Self.coopPairs(s) {
                let forecast = Planner.forecast(
                    hen: Visible(bird: hen, in: s), rooster: Visible(bird: rooster, in: s), knowledge: k,
                    family: family, kinship: Pedigree.relatedness(hen.id, rooster.id, in: s), rules: s.rules)
                pairs += 1
                lines += forecast.count
                #expect(forecast.contains { if case .eggColours = $0 { true } else { false } })
                #expect(forecast.map(Self.group) == forecast.map(Self.group).sorted())
                for line in forecast {
                    for id in Self.birds(in: line.reason) {
                        #expect(id == hen.id || id == rooster.id || seen.contains(id), "\(line)")
                    }
                    if case .ratio(_, _, let d, _) = line { #expect([2, 4, 8, 16].contains(d)) }
                    Self.checkShape(line, family: family, hen: hen.id, rooster: rooster.id)
                }
            }
        }
        print("Planner reasons: \(pairs) pairs, \(lines) lines in \(Self.simGames.count) games")
        #expect(pairs > 100)
    }

    /// Lines the words expect: egg colours only in the egg-colours and "likely no" lines; "possible"
    /// and "likely no" only for traits a bird can hide; "nobody in the family has shown it" only when
    /// nobody in the pair's seen family (the pair, parents, grandparents, chicks) has.
    static func checkShape(_ line: Forecast, family: [Visible], hen: UUID, rooster: UUID) {
        let hidable: [FeatherwickCore.Trait] = [
            .colour(.lavender), .colour(.buff), .barred, .laced, .silkieFeathered, .speckledEggs,
        ]
        switch line {
        case .certain(.eggColour, _), .ratio(.eggColour, _, _, _), .possible(.eggColour, _),
            .notPossible(.eggColour, _):
            Issue.record("egg colour outside its own line: \(line)")
        case .possible(let t, let r):
            #expect(hidable.contains(t), "\(line)")
            guard case .unknownFamily = r else { break }
            let byID = Dictionary(family.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            func parents(_ v: Visible) -> [Visible] { [v.motherID, v.fatherID].compactMap { $0.flatMap { byID[$0] } } }
            let pair = [hen, rooster].compactMap { byID[$0] }
            let up = pair.flatMap(parents)
            let chicks = family.filter {
                $0.motherID == hen || $0.fatherID == hen || $0.motherID == rooster || $0.fatherID == rooster
            }
            let relatives = pair + up + up.flatMap(parents) + chicks
            #expect(!relatives.contains { ($0.look.map(FeatherwickCore.Trait.shown) ?? 0) & t.bit != 0 }, "\(line)")
        case .likely(let t, _):
            if case .eggColour = t { break }
            #expect(hidable.contains(t), "\(line)")
        default:
            break
        }
    }

    // MARK: - 9. Carrier notes

    @Test func carrierNotesShowOnlyProvenHiddenAlleles() {
        var (s, rng) = startedGame(sex: .hen)
        let lavender = Self.add(
            KnowledgeTests.genome(.hen) { $0.lavender = .homozygous(.lavender) }, .orpington, &s, &rng)
        let carrier = Self.add(
            KnowledgeTests.genome(.rooster) { $0.lavender = AllelePair(.normal, .lavender) }, .orpington, &s, &rng,
            mother: lavender)
        // Same genes, unknown family: the lavender gene stays open, so no note.
        let open = Self.add(
            KnowledgeTests.genome(.rooster) { $0.lavender = AllelePair(.normal, .lavender) }, .orpington, &s, &rng)
        s.plannerKnown = false
        #expect(Planner.carrierNotes(for: carrier.id, in: s).isEmpty)
        s.plannerKnown = true
        #expect(Planner.carrierNotes(for: carrier.id, in: s).map(\.allele) == ["lav"])
        #expect(!Planner.carrierNotes(for: open.id, in: s).contains { $0.locus == Lavender.locus })
        #expect(Planner.carrierNotes(for: lavender.id, in: s).isEmpty)  // her lavender shows
    }

    // MARK: - 10. Old saves

    @Test func oldSaveLoadsWithThePlannerHidden() throws {
        let game = try SaveFormat.decode(SaveFormatTests.fixture("save-v0"))
        #expect(!game.state.plannerKnown)
        #expect(Planner.panel(in: game.state) == .hidden)
        #expect(!Knowledge.of(game.state).birds.isEmpty)
        #expect(game.state.rules.plannerLikelyAfterChicks == Rules.standard.plannerLikelyAfterChicks)
        #expect(game.state.rules.plannerNotPossibleLines == Rules.standard.plannerNotPossibleLines)
        #expect(game.state.rules.plannerMaxRatioDenominator == Rules.standard.plannerMaxRatioDenominator)
        // Once known, the old flock still gets a forecast.
        var s = game.state
        s.plannerKnown = true
        if let pair = Self.coopPairs(s).first {
            s.pen = [pair.hen.id, pair.rooster.id]
            guard case .forecast = Planner.panel(in: s) else {
                Issue.record("no forecast")
                return
            }
        }
    }
}

/// Results filled in from many threads, each into its own slot.
final class Collected<T>: @unchecked Sendable {
    private var slots: [T?]
    private let lock = NSLock()

    init(count: Int) { slots = Array(repeating: nil, count: count) }

    func set(_ i: Int, _ value: T) {
        lock.lock()
        slots[i] = value
        lock.unlock()
    }

    var values: [T] {
        lock.lock()
        defer { lock.unlock() }
        return slots.compactMap { $0 }
    }
}
