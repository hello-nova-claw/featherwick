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
        guard mother.sex == .hen else { throw BreedingError.motherMustBeHen }
        guard father.sex == .rooster else { throw BreedingError.fatherMustBeRooster }

        // The father always passes one of his two Z chromosomes.
        // SIMPLIFIED: each Z-linked gene is drawn on its own (no linkage between Z genes).
        let fromFather = Loci.zLinked.map { locus in
            let zz = father.alleles(at: locus)
            return AllelePair(zz[0], zz[1]).gamete(using: &rng)
        }
        // The mother passes her W (chick is a hen) or her Z (chick is a rooster).
        let chickIsHen = Bool.random(using: &rng)
        var chick = Genome(sex: chickIsHen ? .hen : .rooster)
        for (locus, fatherAllele) in zip(Loci.zLinked, fromFather) {
            let motherAllele = mother.alleles(at: locus)[0]
            chick.setAlleles(chickIsHen ? [fatherAllele] : [motherAllele, fatherAllele], at: locus)
        }

        // One allele from each parent for every other gene, mother's first.
        for locus in Loci.autosomal {
            let m = mother.alleles(at: locus), f = father.alleles(at: locus)
            let pair = AllelePair.cross(mother: AllelePair(m[0], m[1]), father: AllelePair(f[0], f[1]), using: &rng)
            chick.setAlleles([pair.first, pair.second], at: locus)
        }
        return chick
    }

    /// An egg from this hen. With a father it is fertile: the chick's genome is fixed now.
    public static func layEgg<R: RandomNumberGenerator>(
        mother: Bird, father: Bird?, day: Int, using rng: inout R
    ) -> Egg {
        let p = mother.phenotype
        var egg = Egg(id: makeID(using: &rng), layDay: day, motherID: mother.id,
                      colour: p.eggColour ?? .cream, speckled: p.eggIsSpeckled,
                      motherBreed: mother.breed, motherPurebred: mother.isPurebred)
        egg.shape = QuantitativeTrait.eggShape.score(mother.genome)
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
