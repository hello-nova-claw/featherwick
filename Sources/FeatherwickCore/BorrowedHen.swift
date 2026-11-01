import Foundation

// The borrowed hen: the first fortnight's story.
//
// On day 3 Hazel goes to her sister's for a week and lends the keeper Marigold, the starter's mother.
// Marigold is a grown hen of the starter's breed, so the coop door lesson (day 3) and the laying lesson
// (day 4) have a real hen to be about. Her eggs are the keeper's. On day 10 Hazel is home and asks:
// send Marigold home (with a fertile egg of her line, which brings the neighbour's small incubator), or
// keep her (her price is a debt, paid when the keeper can). Neither choice is wrong.
//
// Marigold is a real mother. Her genes fit the starter's: at every gene she holds one of the starter's
// alleles, and the starter's family tree names her. Her mate stays at Hazel's: a family-tree record
// only, with no look. So `Knowledge` reads them as parents, the way it reads any family.
//
// Rule 8: her look is evidence, like any mother's, and must never tell the starter's sex. A hen passes
// her one Z to her sons only, so a barred hen with an unbarred chick would say "a daughter". So her
// one Z copy is the starter's own first Z copy: her barring always matches the starter's, whatever its sex.
//
// Only new games get her (`StoryGoal.newKeeper`). An old save already past day 3 gets no loan.

extension Storylines {
    /// The loan's tag, the story's ID, its choice's ID and the debt's ID.
    public static let marigold = "marigold"

    /// Marigold, Hazel's hen: the starter's mother, on loan from day 3.
    public static let marigoldSpec = LoanSpec(
        tag: marigold, owner: .hazel, name: "Marigold", sex: .hen, ageDays: .rule(.marigoldAgeDays),
        motherOfStarter: true)

    /// The borrowed hen. Day 2: Hazel asks if Marigold may stay. Day 3 (the coop door lesson): she comes.
    /// Day 10 (`marigoldStayDays` later): Hazel is home,
    /// and the keeper chooses: send her home with an egg of her line, or keep her and owe Hazel.
    public static let borrowedHen = Storyline(
        id: marigold,
        person: .hazel,
        trigger: .newKeeper,
        steps: [
            // She comes the morning of the coop door lesson (day 3), and Hazel is home a week later (day 10).
            StoryStep(id: "arrives", goal: .featureDay(.coopDoor), rewards: [.loanBird(marigoldSpec)]),
            StoryStep(id: "staying", goal: .waitDays(.rule(.marigoldStayDays))),
            StoryStep(
                id: "decide", goal: .choice(id: marigold, options: ["return", "keep"]),
                rewards: [
                    .ifChosen(marigold, "return", [.endLoan(birdTag: marigold)]),
                    .ifChosen(marigold, "keep", [.offerToKeep(birdTag: marigold, price: .rule(.marigoldPrice))]),
                ]),
        ],
        // Hazel's thank-you for sending her home: an egg of the starter's breed, from Marigold's line. Its own
        // reward, after the choice, so a full carton holds up only the egg, never Marigold's going home.
        rewards: [.ifChosen(marigold, "return", [.giftEgg(nil, fertile: true)])]
    )
}

extension GameState {
    /// True once Marigold has come to stay in this game, whether she is here, went home or was kept.
    public var marigoldCame: Bool { (stories[Storylines.marigold]?.step ?? 0) >= 1 }
    /// True while Hazel is at her sister's: from the morning Marigold comes until Hazel is home (day 10).
    /// The words use it: in this week Hazel writes, she does not lean over the fence.
    public var hazelAway: Bool { hazelHomeDay != nil }
    /// The morning Hazel is home again, while she is away; nil otherwise. `marigoldStayDays` after Marigold came.
    public var hazelHomeDay: Int? {
        guard let p = stories[Storylines.marigold], !p.rewarded, p.step == 1 else { return nil }
        return p.stepStartedDay + rules.marigoldStayDays
    }
}

extension Breed {
    /// The genome of a purebred hen of this breed who could be `chick`'s mother, or nil if none of the
    /// breed's colours can be. She is one of the breed's colours (a public recipe, so `Knowledge` reads
    /// her as it reads any bought bird) that holds one of the chick's alleles at every single gene. At a
    /// recessive the breed carries (`BreedDefinition.carried`) she takes the chick's first copy.
    /// Her one Z copy is the chick's first: her barring matches the chick's, so it never tells its sex.
    /// One draw from `rng` picks among the colours that fit.
    public func motherGenome<R: RandomNumberGenerator>(of chick: Genome, using rng: inout R) -> Genome? {
        let recipes = RecipeTable.recipes(breed: self, sex: .hen).map(\.genotypes)
        let autosomal = Loci.mendelian.filter { $0.inheritance == .autosomal }
        let fits = definition.varieties.compactMap { variety -> Genome? in
            var g = purebred(.hen, variety: variety)
            for locus in Loci.zLinked { g.setAlleles([chick.alleles(at: locus)[0]], at: locus) }
            // A recessive that runs in the breed: she has the chick's first copy and the usual one.
            for gene in definition.carried {
                guard let def = Loci.definition(gene.locus), def.inheritance == .autosomal else { continue }
                g.setAlleles([chick.alleles(at: def)[0], gene.first], at: def)
            }
            let shares = autosomal.allSatisfy { !Set(g.alleles(at: $0)).isDisjoint(with: chick.alleles(at: $0)) }
            let genotypes = GenotypeSpace.all.map { Genotype(g.alleles(at: $0.locus), at: $0.locus) }
            return shares && recipes.contains(genotypes) ? g : nil
        }
        guard !fits.isEmpty else { return nil }
        return fits[Int.random(in: 0..<fits.count, using: &rng)]
    }

    /// The genome of a purebred rooster of this breed who could be `chick`'s father beside the mother from
    /// `motherGenome(of:using:)`. At a recessive the breed carries he takes the chick's second copy, the
    /// one its mother did not give, and the usual one. So a chick with two carried copies has a father
    /// who could give one. He makes no draw from the game's random numbers.
    public func fatherGenome(of chick: Genome) -> Genome {
        var g = purebred(.rooster)
        for gene in definition.carried {
            guard let def = Loci.definition(gene.locus), def.inheritance == .autosomal else { continue }
            g.setAlleles([chick.alleles(at: def)[1], gene.first], at: def)
        }
        return g
    }
}

extension Genome {
    /// Gives this bird the chick's first allele at every gene behind a quantitative trait, keeping its own
    /// second. A mother passes one copy of each gene, so her chick's must be among hers.
    mutating func shareQuantitativeAlleles(with chick: Genome) {
        for locus in QuantitativeTrait.all.flatMap(\.loci) where locus.inheritance == .autosomal {
            setAlleles([chick.alleles(at: locus)[0], alleles(at: locus)[1]], at: locus)
        }
    }
}

extension Engine {
    /// The starter's mother comes to stay (`LoanSpec.motherOfStarter`). Her genes fit the starter's,
    /// and the starter's family tree gets her and her mate (a record only: he stays home). Nil when the
    /// starter is not here, already has parents, or is not of this breed: then a plain hen comes instead.
    static func lendStartersMother<R: RandomNumberGenerator>(
        _ spec: LoanSpec, breed: Breed, _ s: inout GameState, _ rng: inout R
    ) -> [GameEvent]? {
        guard spec.sex == .hen, let starterID = s.starterID,
            let found = locate(starterID, in: s, groups: [\.brooder, \.henChicks, \.coop, \.boarding])
        else { return nil }
        let (home, i) = found
        let starter = s[keyPath: home][i]
        guard starter.motherID == nil, starter.fatherID == nil, starter.breed == breed, starter.isPurebred,
            let genome = breed.motherGenome(of: starter.genome, using: &rng)
        else { return nil }
        var mother = Bird(
            id: makeID(using: &rng), name: spec.name, breed: breed, genome: genome,
            hatchDay: s.day - spec.ageDays.value(in: s.rules), origin: spec.owner.origin, revealed: true
        ).withFounderQuality()
        mother.genome.shareQuantitativeAlleles(with: starter.genome)
        // Her founder draw must not undo the copy she shares with the chick at a carried recessive.
        for def in breed.definition.carried.compactMap({ Loci.definition($0.locus) }) {
            mother.genome.setAlleles(genome.alleles(at: def), at: def)
        }
        // Her mate: a purebred rooster of the breed at his owner's. The keeper never sees him, so his
        // record has no look, and `Knowledge` reads only his breed.
        let mate = Bird(
            id: makeID(using: &rng), name: "\(spec.name)'s mate", breed: breed,
            genome: breed.fatherGenome(of: starter.genome),
            hatchDay: mother.hatchDay, origin: spec.owner.origin, revealed: true)
        s.pedigree[mate.id] = PedigreeRecord(mate, look: nil)
        s[keyPath: home][i].motherID = mother.id
        s[keyPath: home][i].fatherID = mate.id
        return welcome(mother, on: spec, &s)
    }
}
