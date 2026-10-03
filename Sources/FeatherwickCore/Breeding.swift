public enum BreedingError: Error, Equatable, Sendable {
    case motherMustBeHen
    case fatherMustBeRooster
}

public enum Breeding {
    /// Makes one chick genome from a hen and a rooster.
    ///
    /// Cozy rule: every cross hatches. There are no lethal combinations.
    /// The order of random draws is fixed, so a seeded RNG always gives the same chick.
    public static func cross<R: RandomNumberGenerator>(
        mother: Genome, father: Genome, using rng: inout R
    ) throws -> Genome {
        guard case .hen(let motherZ) = mother.sexChromosomes else {
            throw BreedingError.motherMustBeHen
        }
        guard case .rooster(let fatherZZ) = father.sexChromosomes else {
            throw BreedingError.fatherMustBeRooster
        }

        // The father always passes one of his two Z chromosomes.
        let zFromFather = fatherZZ.gamete(using: &rng)
        // The mother passes her W (chick is a hen) or her Z (chick is a rooster).
        let chickIsHen = Bool.random(using: &rng)
        let sexChromosomes: SexChromosomes =
            chickIsHen
            ? .hen(z: zFromFather)
            : .rooster(z: AllelePair(motherZ, zFromFather))

        return Genome(
            sexChromosomes: sexChromosomes,
            feathering: .cross(mother: mother.feathering, father: father.feathering, using: &rng),
            baseColour: .cross(mother: mother.baseColour, father: father.baseColour, using: &rng),
            blue: .cross(mother: mother.blue, father: father.blue, using: &rng),
            lavender: .cross(mother: mother.lavender, father: father.lavender, using: &rng),
            lacing: .cross(mother: mother.lacing, father: father.lacing, using: &rng),
            blueShell: .cross(mother: mother.blueShell, father: father.blueShell, using: &rng),
            brownShell: .cross(mother: mother.brownShell, father: father.brownShell, using: &rng),
            speckle: .cross(mother: mother.speckle, father: father.speckle, using: &rng)
        )
    }

    /// Hatches a named chick from two birds. Keeps lineage for the family tree and trading.
    public static func hatch<R: RandomNumberGenerator>(
        mother: Bird, father: Bird, name: String, onDay day: Int, origin: String, using rng: inout R
    ) throws -> Bird {
        let genome = try cross(mother: mother.genome, father: father.genome, using: &rng)
        return Bird(
            id: makeID(using: &rng), name: name, breed: mother.breed, genome: genome,
            hatchDay: day, motherID: mother.id, fatherID: father.id, origin: origin
        )
    }
}
