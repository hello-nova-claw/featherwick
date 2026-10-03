public enum Breed: String, Hashable, Codable, Sendable, CaseIterable {
    case silkie, orpington, wyandotte, araucana
}

/// Colours a starter bird can come in.
public enum StarterColour: String, Hashable, Codable, Sendable, CaseIterable {
    case black, blue, buff, lavender
}

extension Breed {
    /// A true-breeding starter bird of this breed.
    ///
    /// Breed signatures: Silkie = silkie feathering, Wyandotte = lacing,
    /// Araucana = blue shell, Orpington and Wyandotte = brown coating.
    /// Starter blue birds are Bl/bl+, so two blues can hatch black, blue and splash.
    public func purebred(_ sex: Sex, colour: StarterColour = .black, barred: Bool = false) -> Genome {
        let feathering: AllelePair<Feathering> =
            self == .silkie ? .homozygous(.silkie) : .homozygous(.normal)
        let lacing: AllelePair<Lacing> =
            self == .wyandotte ? .homozygous(.laced) : .homozygous(.solid)
        let blueShell: AllelePair<BlueShell> =
            self == .araucana ? .homozygous(.blue) : .homozygous(.white)
        let brownShell: AllelePair<BrownShell> =
            (self == .orpington || self == .wyandotte) ? .homozygous(.brown) : .homozygous(.noCoating)

        let baseColour: AllelePair<BaseColour> =
            colour == .buff ? .homozygous(.buff) : .homozygous(.black)
        let blue: AllelePair<BlueDilution> =
            colour == .blue ? AllelePair(.blue, .notBlue) : .homozygous(.notBlue)
        let lavender: AllelePair<Lavender> =
            colour == .lavender ? .homozygous(.lavender) : .homozygous(.normal)

        let barring: Barring = barred ? .barred : .plain
        let sexChromosomes: SexChromosomes =
            sex == .hen ? .hen(z: barring) : .rooster(z: .homozygous(barring))

        return Genome(
            sexChromosomes: sexChromosomes,
            feathering: feathering,
            baseColour: baseColour,
            blue: blue,
            lavender: lavender,
            lacing: lacing,
            blueShell: blueShell,
            brownShell: brownShell,
            speckle: .homozygous(.plain)
        )
    }
}

/// A named bird in the flock.
public struct Bird: Hashable, Codable, Sendable {
    public var name: String
    /// V1 PLACEHOLDER RULE: a chick takes its mother's breed (like Pokémon).
    /// Open question: how mixed-breed chicks show in the Breed Book.
    public var breed: Breed
    public var genome: Genome

    public init(name: String, breed: Breed, genome: Genome) {
        self.name = name
        self.breed = breed
        self.genome = genome
    }

    public var phenotype: Phenotype { Phenotype(genome) }
}
