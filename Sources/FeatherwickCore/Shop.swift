import Foundation

// Speckle & Down's daily special.
//
// Basic stock (a pullet, a cockerel, a fertile egg) is always there, but its breed is a surprise:
// the keeper learns it on purchase. The special is one young bird the seller names in full: breed,
// sex and colour. It changes each day. Now and then it is a rare colour, such as a splash Silkie.
//
// The special is worked out from `GameState.shopSeed` and the day, never from the game RNG. So looking
// at the shop changes nothing, and the same day always shows the same bird.

/// Today's special bird at Speckle & Down. The seller names its breed, sex and colour.
public struct ShopSpecial: Hashable, Codable, Sendable {
    public let breed: Breed
    public let sex: Sex
    /// The colour the bird shows. Its genes make this colour (see `variety(for:on:)`).
    public let colour: FeatherColour
    public let price: Int
    /// A colour keepers hunt for, or one the breed does not usually come in.
    public let isRare: Bool

    public init(breed: Breed, sex: Sex, colour: FeatherColour, price: Int, isRare: Bool) {
        self.breed = breed
        self.sex = sex
        self.colour = colour
        self.price = price
        self.isRare = isRare
    }

    /// Splash and lavender are the colours keepers hunt for (they are worth more to rehome, too),
    /// so the special always treats them as rare.
    static let alwaysRare: Set<FeatherColour> = [.splash, .lavender]

    /// Bl/Bl: two copies of blue. Real splash birds are made this way; splash × black hatches all blue.
    static let splash = ColourVariety("splash", [.two(BlueDilution.blue)])

    /// The colours a breed usually comes in at the shop: the colours of its varieties, minus the rare ones.
    /// In `FeatherColour` order, so the draw is stable.
    static func usualColours(of breed: Breed) -> [FeatherColour] {
        let looks = breed.definition.varieties.map { Phenotype(breed.purebred(.hen, variety: $0)) }
        let shown = Set(looks.filter { !$0.isBarred }.map(\.colour))
        return FeatherColour.allCases.filter { shown.contains($0) && !alwaysRare.contains($0) }
    }

    /// The genes for a colour on a breed: the breed's own variety if one shows that colour, else a
    /// plain recipe. Every colour here is real genetics on any breed, so the bird looks as advertised.
    public static func variety(for colour: FeatherColour, on breed: Breed) -> ColourVariety {
        let own = breed.definition.varieties.first { variety in
            let p = Phenotype(breed.purebred(.hen, variety: variety))
            return p.colour == colour && !p.isBarred
        }
        if let own { return own }
        switch colour {
        case .black: return .black
        case .blue: return .blue
        case .buff: return .buff
        case .lavender: return .lavender
        case .splash: return splash
        case .white: return .white
        }
    }

    /// A seed for the shop from an ID drawn at the start of the game. No extra RNG draw, so existing
    /// seeds keep their games. The salt keeps it apart from the bird's own quality genes (`localRNG`).
    static func seed(from id: UUID) -> UInt64 {
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        return bytes.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) } ^ 0x5348_4F50  // "SHOP"
    }
}

extension GameState {
    /// Speckle & Down's special on a day. The same day always gives the same bird.
    /// Nil only if no breed is in the game.
    public func shopSpecial(onDay day: Int) -> ShopSpecial? {
        let breeds = BreedTable.inGame.map(\.id)
        guard !breeds.isEmpty else { return nil }
        var rng = SeededRNG(seed: shopSeed ^ UInt64(truncatingIfNeeded: day))
        let breed = breeds[Int.random(in: 0..<breeds.count, using: &rng)]
        let sex: Sex = Bool.random(using: &rng) ? .hen : .rooster
        let usual = ShopSpecial.usualColours(of: breed)
        let rare = FeatherColour.allCases.filter { !usual.contains($0) }
        let rolledRare = Double.roll(rules.shopRareChance, using: &rng)
        let isRare = !rare.isEmpty && (rolledRare || usual.isEmpty)
        let pool = isRare ? rare : usual
        let colour = pool[Int.random(in: 0..<pool.count, using: &rng)]
        var price = sex == .hen ? rules.shopSpecialPulletPrice : rules.shopSpecialCockerelPrice
        if isRare { price += rules.shopRarePremium }
        return ShopSpecial(breed: breed, sex: sex, colour: colour, price: price, isRare: isRare)
    }

    /// Today's special, or nil once it is sold (one a day).
    public var todaysSpecial: ShopSpecial? {
        specialBoughtDay == day ? nil : shopSpecial(onDay: day)
    }
}

extension Engine {
    /// Buys today's special: a young bird of the named breed, sex and colour, for the coop.
    static func buySpecial<R: RandomNumberGenerator>(_ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        guard let special = s.todaysSpecial else { return [.rejected(.specialSoldOut)] }
        let cost = special.price
        if s.coins < cost { return [.rejected(.notEnoughCoins(needed: cost, have: s.coins))] }
        if s.coop.count >= s.perches { return [.rejected(.noFreePerch)] }
        let variety = ShopSpecial.variety(for: special.colour, on: special.breed)
        let bird = Bird(
            id: makeID(using: &rng), name: special.sex == .hen ? "New pullet" : "New cockerel",
            breed: special.breed, genome: special.breed.purebred(special.sex, variety: variety),
            hatchDay: s.day - s.rules.growerAge, origin: "Speckle & Down",
            revealed: true  // the seller names the breed, sex and colour
        ).withFounderQuality().withTameness(s.rules.boughtBirdTameness).waitingForName()
        s.coins -= cost
        s.specialBoughtDay = s.day
        s.coop.append(bird)
        var ev: [GameEvent] = [.boughtSpecial(bird.id, cost: cost)]
        ev += recordBreed(bird, into: &s.breedBook)
        return ev
    }
}
