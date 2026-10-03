import Foundation

/// A trait made by many small genes, like body type or egg shape in real chickens.
///
/// Each gene has a "+" allele and a "-" allele. The score is the number of "+" alleles.
/// Chicks get half their genes from each parent, so good parents tend to make good chicks,
/// with real variation, and the score can never go past its maximum.
///
/// Half the genes default to "+" and half to "-". So a bird with no entry for these genes
/// (for example from an old save) scores exactly average.
public struct QuantitativeTrait: Sendable {
    public let name: String
    public let loci: [LocusDefinition]
    public static let plus = "+"
    public static let minus = "-"

    init(name: String, prefix: String, genes: Int, summary: String) {
        self.name = name
        loci = (1...genes).map { i in
            LocusDefinition(id: LocusID(rawValue: "\(prefix)\(i)"), alleles: [Self.plus, Self.minus],
                            defaultAllele: i <= genes / 2 ? Self.plus : Self.minus, summary: summary)
        }
    }

    /// The best possible score: two "+" alleles at every gene.
    public var maxScore: Int { loci.count * 2 }

    public func score(_ genome: Genome) -> Int {
        loci.reduce(0) { sum, locus in sum + genome.alleles(at: locus).filter { $0 == Self.plus }.count }
    }

    /// 0...1, for judging.
    public func fraction(_ genome: Genome) -> Double { Double(score(genome)) / Double(maxScore) }

    /// Gives a bird from outside the player's flock random genes for this trait.
    /// Each allele is "+" with chance `plusChance`.
    public func randomise<R: RandomNumberGenerator>(_ genome: inout Genome, plusChance: Double = 0.5, using rng: inout R) {
        for locus in loci {
            let a = Double.roll(plusChance, using: &rng) ? Self.plus : Self.minus
            let b = Double.roll(plusChance, using: &rng) ? Self.plus : Self.minus
            genome.setAlleles([a, b], at: locus)
        }
    }

    // MARK: - The traits

    /// Show type: body shape, size, carriage and feather quality, as a show judge sees them.
    /// SIMPLIFIED: real type is many genes plus how the bird was raised. Rearing is in "condition".
    public static let showType = QuantitativeTrait(name: "type", prefix: "type", genes: 10,
                                                   summary: "Show type. One of many small additive genes.")
    /// Egg shape: how close a hen's eggs are to the ideal egg shape. Real egg shape is heritable
    /// and very consistent for one hen.
    public static let eggShape = QuantitativeTrait(name: "egg shape", prefix: "eggShape", genes: 6,
                                                   summary: "Egg shape. One of many small additive genes.")

    public static let all: [QuantitativeTrait] = [showType, eggShape]
}

extension Bird {
    /// A bird bred outside the player's flock (neighbour, shop, trade) gets random quality genes.
    /// The random numbers come from the bird's own ID, so this does not move the game's RNG.
    public func withFounderQuality() -> Bird {
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        let seed = bytes.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        var local = SeededRNG(seed: seed)
        var genome = self.genome
        for trait in QuantitativeTrait.all { trait.randomise(&genome, using: &local) }
        var copy = Bird(id: id, name: name, breed: breed, genome: genome, hatchDay: hatchDay,
                        motherID: motherID, fatherID: fatherID, origin: origin,
                        revealed: revealed, timesScared: timesScared, noLayUntilDay: noLayUntilDay)
        copy.broodyUntilDay = broodyUntilDay
        copy.raisedBy = raisedBy
        copy.purebredFlag = purebredFlag
        return copy
    }
}
