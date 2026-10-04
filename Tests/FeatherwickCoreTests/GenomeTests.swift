import Testing

@testable import FeatherwickCore

struct GenomeTests {
    // MARK: - Breeds breed true

    @Test(arguments: Breed.allCases)
    func purebredsBreedTrue(breed: Breed) throws {
        var rng = SeededRNG(seed: 1)
        let mother = breed.purebred(.hen)
        let father = breed.purebred(.rooster)
        let parentLook = Phenotype(mother)
        for _ in 0..<200 {
            let chick = Phenotype(try Breeding.cross(mother: mother, father: father, using: &rng))
            #expect(chick.isSilkieFeathered == parentLook.isSilkieFeathered)
            #expect(chick.isLaced == parentLook.isLaced)
            #expect(chick.colour == parentLook.colour)
            if chick.sex == .hen {
                #expect(chick.eggColour == parentLook.eggColour)
            }
        }
    }

    // MARK: - Mendelian ratios

    @Test func silkieFeatheringIsRecessive() throws {
        var rng = SeededRNG(seed: 42)
        var mother = Breed.orpington.purebred(.hen)
        var father = Breed.orpington.purebred(.rooster)
        mother.feathering = AllelePair(.normal, .silkie)
        father.feathering = AllelePair(.normal, .silkie)

        let total = 4000
        var silkies = 0
        for _ in 0..<total {
            let chick = Phenotype(try Breeding.cross(mother: mother, father: father, using: &rng))
            if chick.isSilkieFeathered { silkies += 1 }
        }
        // Two carriers give about 1 in 4 silkie-feathered chicks.
        #expect(abs(Double(silkies) / Double(total) - 0.25) < 0.03)
    }

    @Test func blueTimesBlueGivesBlackBlueSplash() throws {
        var rng = SeededRNG(seed: 99)
        let mother = Breed.orpington.purebred(.hen, colour: .blue)
        let father = Breed.orpington.purebred(.rooster, colour: .blue)

        let total = 4000
        var counts: [FeatherColour: Int] = [:]
        for _ in 0..<total {
            let chick = Phenotype(try Breeding.cross(mother: mother, father: father, using: &rng))
            counts[chick.colour, default: 0] += 1
        }
        func share(_ colour: FeatherColour) -> Double { Double(counts[colour, default: 0]) / Double(total) }
        // 1 : 2 : 1
        #expect(abs(share(.black) - 0.25) < 0.03)
        #expect(abs(share(.blue) - 0.50) < 0.03)
        #expect(abs(share(.splash) - 0.25) < 0.03)
    }

    @Test func aboutHalfTheChicksAreHens() throws {
        var rng = SeededRNG(seed: 5)
        let mother = Breed.silkie.purebred(.hen)
        let father = Breed.silkie.purebred(.rooster)
        let total = 4000
        var hens = 0
        for _ in 0..<total where try Breeding.cross(mother: mother, father: father, using: &rng).sex == .hen {
            hens += 1
        }
        #expect(abs(Double(hens) / Double(total) - 0.5) < 0.03)
    }

    // MARK: - Egg colour

    @Test func araucanaHenTimesOrpingtonRoosterGivesOliveEggers() throws {
        var rng = SeededRNG(seed: 7)
        let mother = Breed.araucana.purebred(.hen)
        let father = Breed.orpington.purebred(.rooster)
        for _ in 0..<200 {
            let chick = Phenotype(try Breeding.cross(mother: mother, father: father, using: &rng))
            if chick.sex == .hen {
                #expect(chick.eggColour == .olive)
            } else {
                #expect(chick.eggColour == nil)
            }
        }
    }

    @Test func roostersDoNotLay() {
        for breed in Breed.allCases {
            #expect(Phenotype(breed.purebred(.rooster)).eggColour == nil)
        }
    }

    // MARK: - Sex-linked barring

    @Test func barredHenTimesPlainRoosterGivesBarredSonsAndPlainDaughters() throws {
        var rng = SeededRNG(seed: 11)
        let mother = Breed.orpington.purebred(.hen, barred: true)
        let father = Breed.orpington.purebred(.rooster)
        for _ in 0..<200 {
            let chick = Phenotype(try Breeding.cross(mother: mother, father: father, using: &rng))
            // Daughters get their only Z from the plain father.
            #expect(chick.isBarred == (chick.sex == .rooster))
        }
    }

    // MARK: - Determinism and validation

    @Test func sameSeedGivesSameChicks() throws {
        let mother = Breed.wyandotte.purebred(.hen, colour: .blue)
        let father = Breed.araucana.purebred(.rooster, colour: .blue)
        var rngA = SeededRNG(seed: 2026)
        var rngB = SeededRNG(seed: 2026)
        for _ in 0..<50 {
            let a = try Breeding.cross(mother: mother, father: father, using: &rngA)
            let b = try Breeding.cross(mother: mother, father: father, using: &rngB)
            #expect(a == b)
        }
    }

    @Test func crossNeedsAHenAndARooster() {
        var rng = SeededRNG(seed: 3)
        let hen = Breed.silkie.purebred(.hen)
        let rooster = Breed.silkie.purebred(.rooster)
        #expect(throws: BreedingError.motherMustBeHen) {
            try Breeding.cross(mother: rooster, father: rooster, using: &rng)
        }
        #expect(throws: BreedingError.fatherMustBeRooster) {
            try Breeding.cross(mother: hen, father: hen, using: &rng)
        }
    }
}
