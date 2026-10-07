import Foundation
import Testing

@testable import FeatherwickCore

/// Design rule: no bizarre genetics. Every bird the game can make must look like a bird a real
/// keeper could breed, and be named the way a keeper would name it.
struct GeneticsRealismTests {
    static let breedEgg: [Breed: EggColour] = [
        .orpington: .brown, .wyandotte: .brown, .araucana: .blue, .silkie: .cream, .australorp: .brown,
        .leghorn: .cream,
    ]

    /// Problems with one bird, or [] if it looks real.
    static func problems(_ b: Bird) -> [String] {
        let p = b.phenotype
        var out: [String] = []
        if p.isLaced && p.colour != .buff { out.append("lacing on a \(p.colour) bird") }
        if p.isBarred && p.colour == .buff { out.append("barring on buff") }
        if p.isLaced && p.isBarred { out.append("barred and laced") }
        if p.colour == .white && (p.isLaced || p.isBarred) { out.append("pattern showing on white") }
        if p.colour == .white && p.chickDown != .yellow { out.append("white bird without yellow down") }
        if b.isPurebred {
            if p.isLaced && b.breed != .wyandotte { out.append("laced purebred \(b.breed)") }
            if p.isSilkieFeathered != (b.breed == .silkie) { out.append("silkie feathering on purebred \(b.breed)") }
            if b.sex == .hen, p.eggColour != breedEgg[b.breed] {
                out.append("purebred \(b.breed) laying \(String(describing: p.eggColour))")
            }
        } else if b.sex == .hen, let egg = p.eggColour {
            switch b.crossName {
            case .oliveEgger: if egg != .olive && egg != .green { out.append("olive egger laying \(egg)") }
            case .easterEgger: if egg != .blue { out.append("easter egger laying \(egg)") }
            case .barnyardMix:
                if ![.brown, .chocolate, .cream].contains(egg) { out.append("barnyard mix laying \(egg)") }
            case nil: out.append("cross with no name")
            }
        }
        return out
    }

    static func founders(_ rng: inout SeededRNG, breeds: [Breed] = Breed.starters, white: Bool = false) -> [Bird] {
        var birds: [Bird] = []
        // White founders carry every hidden colour gene: one I, plus blue and barring underneath.
        if white {
            for breed in breeds {
                for sex in Sex.allCases {
                    var g = breed.purebred(sex, variety: .blue, barred: true)
                    g.dominantWhite = AllelePair(.white, .wildType)
                    g.baseColour = AllelePair(.black, .buff)
                    birds.append(
                        Bird(
                            id: makeID(using: &rng), name: "w", breed: breed, genome: g, hatchDay: 0,
                            origin: "Founder", revealed: true))
                }
            }
        }
        for breed in breeds {
            for colour in StarterColour.allCases {
                for barred in [false, true] {
                    for sex in Sex.allCases {
                        birds.append(
                            Bird(
                                id: makeID(using: &rng), name: "f", breed: breed,
                                genome: breed.purebred(sex, colour: colour, barred: barred),
                                hatchDay: 0, origin: "Founder", revealed: true))
                    }
                }
            }
        }
        return birds
    }

    /// Random mating for several generations, through the same egg and hatch code the game uses.
    static func population(
        seed: UInt64, generations: Int, perGeneration: Int, breeds: [Breed] = Breed.starters, white: Bool = false
    ) -> [Bird] {
        var rng = SeededRNG(seed: seed)
        var current = founders(&rng, breeds: breeds, white: white)
        var everyone = current
        for _ in 0..<generations {
            let hens = current.filter { $0.sex == .hen }
            let roosters = current.filter { $0.sex == .rooster }
            guard !hens.isEmpty, !roosters.isEmpty else { break }
            var next: [Bird] = []
            for _ in 0..<perGeneration {
                let egg = Breeding.layEgg(
                    mother: hens.randomElement(using: &rng)!,
                    father: roosters.randomElement(using: &rng)!, day: 0, using: &rng)
                if let chick = Breeding.hatch(egg, name: "c", onDay: 0, origin: "Test", using: &rng) {
                    next.append(chick)
                }
            }
            everyone += next
            current = next
        }
        return everyone
    }

    @Test(arguments: [UInt64(1), 2, 3])
    func everyBirdOverManyGenerationsLooksReal(seed: UInt64) {
        let birds = Self.population(seed: seed, generations: 6, perGeneration: 4000)
        var seen: [String: Int] = [:]
        for b in birds { for p in Self.problems(b) { seen[p, default: 0] += 1 } }
        #expect(seen.isEmpty, "bizarre birds: \(seen)")
    }

    @Test func silkiesAddedLaterStayReal() {
        let birds = Self.population(seed: 9, generations: 5, perGeneration: 4000, breeds: Breed.allCases)
        let bad = birds.flatMap(Self.problems)
        #expect(bad.isEmpty, "bizarre birds: \(Set(bad))")
    }

    /// Dominant white mixed into every colour and pattern: white birds never show a pattern, and the
    /// hidden genes come back in coloured chicks.
    @Test func whiteFlocksStayRealAndHiddenColoursComeBack() {
        let birds = Self.population(seed: 13, generations: 5, perGeneration: 4000, breeds: Breed.allCases, white: true)
        let bad = birds.flatMap(Self.problems)
        #expect(bad.isEmpty, "bizarre birds: \(Set(bad))")
        let looks = birds.map(\.phenotype)
        #expect(looks.contains { $0.colour == .white } && looks.contains { $0.colour != .white })
        #expect(looks.contains { $0.isBarred } && looks.contains { $0.colour == .splash })
    }

    @Test func whiteHidesPatternGenesThatStillPassOn() {
        // A white hen carrying barring, blue and lacing on buff shows none of them.
        var hen = Breed.wyandotte.purebred(.hen, variety: .buff, barred: true)
        hen.blue = AllelePair(.blue, .notBlue)
        hen.dominantWhite = AllelePair(.white, .wildType)
        let p = Phenotype(hen)
        #expect(p.colour == .white && !p.isBarred && !p.isLaced && p.chickDown == .yellow)
        #expect(featherColourName(p.colour, barred: p.isBarred, laced: p.isLaced) == "white")
        // Her coloured chicks by a buff Wyandotte rooster show the gold lacing she hid.
        var rng = SeededRNG(seed: 8)
        let rooster = Breed.wyandotte.purebred(.rooster, variety: .buff)
        let chicks = try! (0..<200).map { _ in Phenotype(try Breeding.cross(mother: hen, father: rooster, using: &rng))
        }
        #expect(chicks.contains { $0.colour == .white })
        #expect(chicks.contains { $0.colour == .buff && $0.isLaced })
    }

    // MARK: - Purebred or cross

    func bird(
        _ breed: Breed, _ sex: Sex, pure: Bool = true, colour: StarterColour = .black, rng: inout SeededRNG
    ) -> Bird {
        var b = Bird(
            id: makeID(using: &rng), name: "p", breed: breed, genome: breed.purebred(sex, colour: colour),
            hatchDay: 0, origin: "Test", revealed: true)
        b.purebredFlag = pure
        return b
    }

    func child(_ m: Bird, _ f: Bird, _ rng: inout SeededRNG) -> Bird {
        Breeding.hatch(
            Breeding.layEgg(mother: m, father: f, day: 0, using: &rng), name: "c", onDay: 0, origin: "t", using: &rng)!
    }

    @Test func sameBreedPurebredParentsMakeAPurebred() {
        var rng = SeededRNG(seed: 1)
        let c = child(bird(.wyandotte, .hen, rng: &rng), bird(.wyandotte, .rooster, rng: &rng), &rng)
        #expect(c.isPurebred && c.breed == .wyandotte && c.varietyName == "wyandotte")
    }

    @Test func differentBreedsMakeACross() {
        var rng = SeededRNG(seed: 1)
        let c = child(bird(.orpington, .hen, rng: &rng), bird(.wyandotte, .rooster, rng: &rng), &rng)
        #expect(!c.isPurebred && c.crossName == .barnyardMix)
    }

    @Test func aCrossParentAlwaysMakesACross() {
        var rng = SeededRNG(seed: 1)
        let c = child(bird(.orpington, .hen, pure: false, rng: &rng), bird(.orpington, .rooster, rng: &rng), &rng)
        #expect(!c.isPurebred)
    }

    @Test func blueEggTimesBrownEggIsAnOliveEgger() {
        var rng = SeededRNG(seed: 1)
        for (m, f) in [(Breed.araucana, Breed.orpington), (.orpington, .araucana)] {
            for _ in 0..<50 {
                let c = child(bird(m, .hen, rng: &rng), bird(f, .rooster, rng: &rng), &rng)
                #expect(c.crossName == .oliveEgger)  // hens and roosters alike: every chick carries both genes
            }
        }
    }

    @Test func blueEggTimesCreamEggIsAnEasterEgger() {
        var rng = SeededRNG(seed: 1)
        let c = child(bird(.araucana, .hen, rng: &rng), bird(.silkie, .rooster, rng: &rng), &rng)
        #expect(c.crossName == .easterEgger)
    }

    // MARK: - Patterns and hidden genes

    @Test func blackWyandottesCarryHiddenLacingThatGoldChicksShow() {
        var rng = SeededRNG(seed: 4)
        // Black Wyandottes (black over buff, carrying lacing) can throw gold-laced chicks.
        var hen = bird(.wyandotte, .hen, rng: &rng)
        var rooster = bird(.wyandotte, .rooster, rng: &rng)
        var hg = hen.genome
        var rg = rooster.genome
        hg.baseColour = AllelePair(.black, .buff)
        rg.baseColour = AllelePair(.black, .buff)
        hen = Bird(id: hen.id, name: "h", breed: .wyandotte, genome: hg, hatchDay: 0, origin: "t", revealed: true)
        rooster = Bird(
            id: rooster.id, name: "r", breed: .wyandotte, genome: rg, hatchDay: 0, origin: "t", revealed: true)
        #expect(!hen.phenotype.isLaced && !rooster.phenotype.isLaced)
        let chicks = (0..<200).map { _ in child(hen, rooster, &rng) }
        #expect(chicks.contains { $0.phenotype.isLaced && $0.phenotype.colour == .buff })
        #expect(chicks.allSatisfy { !$0.phenotype.isLaced || $0.phenotype.colour == .buff })
    }

    @Test func barringIsHiddenOnBuffButStillPassedOn() {
        let buffBarred = Breed.orpington.purebred(.hen, colour: .buff, barred: true)
        #expect(!Phenotype(buffBarred).isBarred)
        #expect(Phenotype(buffBarred).chickDown == .yellow)
        // Her son by a black rooster gets her barring on a black-based coat, where it shows.
        var rng = SeededRNG(seed: 2)
        let black = Breed.orpington.purebred(.rooster, colour: .black)
        var sawBarredSon = false
        for _ in 0..<50 {
            let c = try! Breeding.cross(mother: buffBarred, father: black, using: &rng)
            if c.sex == .rooster && Phenotype(c).isBarred { sawBarredSon = true }
        }
        #expect(sawBarredSon)
    }
}
