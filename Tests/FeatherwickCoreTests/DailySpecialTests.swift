import Foundation
import Testing

@testable import FeatherwickCore

/// Speckle & Down: surprise basic stock, and one named special a day.
struct DailySpecialTests {
    /// A started game with plenty of coins and free perches.
    static func game(seed: UInt64 = 1) -> (GameState, SeededRNG) {
        var (s, rng) = startedGame(sex: .hen, seed: seed)
        s.coins = 1000
        return (s, rng)
    }

    @Test func aNewGameGetsAShopSeedFromItsOwnSeed() {
        var a = SeededRNG(seed: 21)
        var b = SeededRNG(seed: 21)
        var c = SeededRNG(seed: 22)
        let first = Engine.newGame(using: &a)
        #expect(first.shopSeed != 0)
        #expect(Engine.newGame(using: &b).shopSeed == first.shopSeed)
        #expect(Engine.newGame(using: &c).shopSeed != first.shopSeed)
        // No extra RNG draw: the seed comes from the first starter chick's ID.
        guard case .choosingStarter(let chicks) = first.phase else {
            Issue.record("no starter choice")
            return
        }
        #expect(first.shopSeed == ShopSpecial.seed(from: chicks[0].id))
    }

    @Test func theSpecialIsTheSameAllDayAndChangesAcrossDays() {
        var (s, rng) = Self.game()
        let today = s.todaysSpecial
        #expect(today != nil)
        #expect(s.shopSpecial(onDay: s.day) == today)
        _ = Engine.apply(.feed, to: &s, using: &rng)
        _ = Engine.apply(.collectEggs, to: &s, using: &rng)
        #expect(s.todaysSpecial == today)  // other commands never change it
        let specials = (0..<30).compactMap { s.shopSpecial(onDay: $0) }
        #expect(specials.count == 30)
        #expect(Set(specials).count > 5)
        #expect(Set(specials.map(\.breed)).count > 1)
    }

    @Test func rareSpecialsComeSometimesAndAreTrulyRare() {
        let (s, _) = Self.game()
        let specials = (0..<1000).compactMap { s.shopSpecial(onDay: $0) }
        let rare = specials.filter(\.isRare)
        #expect(rare.count > 20 && rare.count < 200)  // about 8%
        #expect(rare.contains { $0.colour == .splash })
        for special in specials {
            #expect(BreedTable.definition(special.breed)?.isInGame == true)
            let usual = ShopSpecial.usualColours(of: special.breed)
            #expect(usual.contains(special.colour) == !special.isRare, "\(special)")
            let r = s.rules
            let base = special.sex == .hen ? r.shopSpecialPulletPrice : r.shopSpecialCockerelPrice
            #expect(special.price == base + (special.isRare ? r.shopRarePremium : 0))
        }
    }

    /// Genetics stay real: every colour the shop can advertise comes from genes on every breed.
    @Test func everyAdvertisedColourComesFromTheGenes() {
        for breed in Breed.allCases {
            for sex in Sex.allCases {
                for colour in FeatherColour.allCases {
                    let variety = ShopSpecial.variety(for: colour, on: breed)
                    #expect(Phenotype(breed.purebred(sex, variety: variety)).colour == colour, "\(breed) \(colour)")
                }
            }
        }
    }

    @Test func buyingTheSpecialGivesTheAdvertisedBirdOnceADay() throws {
        var (s, rng) = Self.game()
        let special = try #require(s.todaysSpecial)
        let coins = s.coins
        let ev = Engine.apply(.buySpecial, to: &s, using: &rng)
        guard case .boughtSpecial(let id, let cost)? = ev.first else {
            Issue.record("not bought: \(ev)")
            return
        }
        #expect(cost == special.price && s.coins == coins - cost)
        let bird = try #require(s.coop.first { $0.id == id })
        #expect(bird.breed == special.breed && bird.sex == special.sex && bird.isPurebred)
        #expect(bird.phenotype.colour == special.colour)
        #expect(bird.revealed && bird.needsName == true)
        #expect(bird.stage(onDay: s.day, rules: s.rules) == .grower)

        // Sold out until tomorrow.
        #expect(s.todaysSpecial == nil)
        let before = s
        #expect(Engine.apply(.buySpecial, to: &s, using: &rng) == [.rejected(.specialSoldOut)])
        #expect(s == before)
        _ = Engine.apply(.passNight, to: &s, using: &rng)
        #expect(s.todaysSpecial != nil)
    }

    @Test func theSpecialNeedsCoinsAndAPerch() throws {
        var (s, rng) = Self.game()
        let price = try #require(s.todaysSpecial).price
        s.coins = price - 1
        var before = s
        #expect(
            Engine.apply(.buySpecial, to: &s, using: &rng) == [
                .rejected(.notEnoughCoins(needed: price, have: price - 1))
            ])
        #expect(s == before)
        s.coins = 1000
        while s.coop.count < s.perches { s.coop.append(plainBird(rng: &rng)) }
        before = s
        #expect(Engine.apply(.buySpecial, to: &s, using: &rng) == [.rejected(.noFreePerch)])
        #expect(s == before)
    }

    @Test func aRareSpecialLooksRare() throws {
        var (s, rng) = Self.game()
        let day = try #require((0..<2000).first { s.shopSpecial(onDay: $0)?.isRare == true })
        s.day = day
        let special = try #require(s.todaysSpecial)
        let ev = Engine.apply(.buySpecial, to: &s, using: &rng)
        guard case .boughtSpecial(let id, _)? = ev.first, let bird = s.bird(id) else {
            Issue.record("not bought: \(ev)")
            return
        }
        #expect(bird.phenotype.colour == special.colour)
        #expect(!ShopSpecial.usualColours(of: bird.breed).contains(bird.phenotype.colour))
    }

    /// Basic stock: the breed is a random starter breed, learned only once the bird is yours.
    @Test func basicStockIsARandomStarterBreed() {
        var (s, rng) = Self.game()
        s.perches = 15
        var breeds: Set<Breed> = []
        for _ in 0..<12 {
            let ev = Engine.apply(.buy(.pullet), to: &s, using: &rng)
            guard case .boughtBird(let id, .pullet, _)? = ev.first, let bird = s.bird(id) else {
                Issue.record("not bought: \(ev)")
                return
            }
            #expect(Breed.starters.contains(bird.breed) && bird.sex == .hen)
            breeds.insert(bird.breed)
        }
        #expect(breeds.count > 1)
    }

    @Test func anOldSaveGetsADailySpecial() throws {
        var game = try SaveFormat.decode(SaveFormatTests.fixture("save-v0"))
        #expect(game.state.shopSeed == 0 && game.state.specialBoughtDay == nil)
        #expect(game.state.todaysSpecial != nil)
        #expect(Set((0..<30).compactMap { game.state.shopSpecial(onDay: $0) }).count > 1)
        game.state.coins = 1000
        game.state.perches = game.state.coop.count + 1
        let ev = Engine.apply(.buySpecial, to: &game.state, using: &game.rng)
        #expect(ev.contains { if case .boughtSpecial = $0 { true } else { false } })
        #expect(game.state.specialBoughtDay == game.state.day)
    }
}
