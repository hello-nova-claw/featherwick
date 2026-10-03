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

    /// An egg from this hen. With a father it is fertile: the chick's genome is fixed now.
    public static func layEgg<R: RandomNumberGenerator>(
        mother: Bird, father: Bird?, day: Int, using rng: inout R
    ) -> Egg {
        let p = mother.phenotype
        var egg = Egg(id: makeID(using: &rng), layDay: day, motherID: mother.id,
                      colour: p.eggColour ?? .cream, speckled: p.eggIsSpeckled,
                      motherBreed: mother.breed, motherPurebred: mother.isPurebred)
        if let father, let embryo = try? cross(mother: mother.genome, father: father.genome, using: &rng) {
            egg.fatherID = father.id
            egg.fatherBreed = father.breed
            egg.fatherPurebred = father.isPurebred
            egg.embryo = embryo
        }
        return egg
    }

    /// The chick from a fertile egg. Purebred only if both parents are purebred and the same breed.
    public static func hatch<R: RandomNumberGenerator>(
        _ egg: Egg, name: String, onDay day: Int, origin: String, using rng: inout R
    ) -> Bird? {
        guard let genome = egg.embryo else { return nil }
        let breed = egg.motherBreed ?? .orpington
        let pure = (egg.motherPurebred ?? true) && (egg.fatherPurebred ?? true)
            && egg.fatherBreed.map { $0 == breed } ?? true
        var chick = Bird(id: makeID(using: &rng), name: name, breed: breed, genome: genome,
                         hatchDay: day, motherID: egg.motherID, fatherID: egg.fatherID, origin: origin)
        chick.purebredFlag = pure
        return chick
    }
}
