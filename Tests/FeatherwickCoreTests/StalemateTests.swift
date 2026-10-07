import Foundation
import Testing

@testable import FeatherwickCore

/// Design rule: the player can never get stuck. Every game must always have a way forward to
/// eggs (a hen) and to hatching (a hen and a rooster).
struct StalemateTests {
    @Test func aRoosterStarterAlwaysGetsAHen() {
        var (s, rng) = startedGame(sex: .rooster, rules: calmRules())
        for _ in 0..<s.rules.growerAge { night(&s, &rng) }
        #expect(s.ownedBirds.contains { $0.sex == .hen })
    }

    /// A hen start has no rooster, but her eggs earn coins, and the shop sells cockerels.
    @Test func aHenStarterCanEarnARoosterAndHatch() {
        var r = calmRules()
        r.broodyChance = [:]
        var (s, rng) = startedGame(sex: .hen, rules: r)
        var day = 0
        while !s.ownedBirds.contains(where: { $0.sex == .rooster }) && day < 200 {
            _ = Engine.apply(.collectEggs, to: &s, using: &rng)
            _ = Engine.apply(.sellEggs, to: &s, using: &rng)
            _ = Engine.apply(.buy(.cockerel), to: &s, using: &rng)
            night(&s, &rng)
            day += 1
        }
        #expect(s.ownedBirds.contains { $0.sex == .rooster })
        // Once he is grown, eggs are fertile and the neighbour's incubator arrives.
        var ev: [GameEvent] = []
        for _ in 0..<40 { ev += night(&s, &rng) }
        #expect(ev.contains { if case .neighbourGaveIncubator = $0 { true } else { false } })
    }

    @Test func roostersOnlyAndNoCoinsGetsATradeOffer() {
        var (s, rng) = startedGame(sex: .rooster, rules: calmRules())
        for _ in 0..<s.rules.growerAge { night(&s, &rng) }
        let hen = s.ownedBirds.first { $0.sex == .hen }!
        _ = Engine.apply(.rehome(hen.id), to: &s, using: &rng)
        s.coins = 0
        let ev = night(&s, &rng)
        guard
            case .tradeOffered(let rooster, _) = ev.last(where: { if case .tradeOffered = $0 { true } else { false } })
        else {
            Issue.record("no trade offer")
            return
        }
        let accepted = Engine.apply(.acceptTrade, to: &s, using: &rng)
        #expect(accepted.contains { if case .tradeAccepted(rooster, _) = $0 { true } else { false } })
        #expect(s.ownedBirds.contains { $0.sex == .hen })
        #expect(!s.ownedBirds.contains { $0.id == rooster })
        #expect(s.tradeOffer == nil)
    }

    @Test func noTradeOfferWhenThePlayerCanAffordAPullet() {
        var (s, rng) = startedGame(sex: .rooster, rules: calmRules())
        for _ in 0..<s.rules.growerAge { night(&s, &rng) }
        _ = Engine.apply(.rehome(s.ownedBirds.first { $0.sex == .hen }!.id), to: &s, using: &rng)
        s.coins = s.rules.pulletPrice
        #expect(!night(&s, &rng).contains { if case .tradeOffered = $0 { true } else { false } })
        #expect(s.tradeOffer == nil)
    }

    @Test func theOfferDisappearsWhenAHenArrives() {
        var (s, rng) = startedGame(sex: .rooster, rules: calmRules())
        for _ in 0..<s.rules.growerAge { night(&s, &rng) }
        _ = Engine.apply(.rehome(s.ownedBirds.first { $0.sex == .hen }!.id), to: &s, using: &rng)
        s.coins = 0
        night(&s, &rng)
        #expect(s.tradeOffer != nil)
        s.coins = 100
        _ = Engine.apply(.buy(.pullet), to: &s, using: &rng)
        night(&s, &rng)
        #expect(s.tradeOffer == nil)
        #expect(Engine.apply(.acceptTrade, to: &s, using: &rng) == [.rejected(.noTradeOffer)])
    }

    /// Found by the random-game test: rehoming the rooster named in an offer left the offer behind.
    @Test func rehomingTheOfferedRoosterMovesTheOfferToAnother() {
        var (s, rng) = startedGame(sex: .rooster, rules: calmRules())
        for _ in 0..<s.rules.growerAge { night(&s, &rng) }
        _ = Engine.apply(.rehome(s.ownedBirds.first { $0.sex == .hen }!.id), to: &s, using: &rng)
        s.coop.append(plainBird(.araucana, .rooster, hatchDay: s.day - s.rules.adultAge, rng: &rng))
        s.coins = 0
        night(&s, &rng)
        let offered = s.tradeOffer!.roosterID
        _ = Engine.apply(.rehome(offered), to: &s, using: &rng)
        #expect(s.tradeOffer == nil)
        s.coins = 0
        night(&s, &rng)
        #expect(s.tradeOffer != nil && s.tradeOffer?.roosterID != offered)
    }

    @Test func theOfferWaitsWhileEveryRoosterIsLost() {
        var (s, rng) = startedGame(sex: .rooster, rules: calmRules())
        for _ in 0..<s.rules.growerAge { night(&s, &rng) }
        _ = Engine.apply(.rehome(s.ownedBirds.first { $0.sex == .hen }!.id), to: &s, using: &rng)
        s.coins = 0
        let rooster = s.coop.first { $0.sex == .rooster }!
        s.coop.removeAll { $0.id == rooster.id }
        s.lost = [LostBird(bird: rooster, returnsOnDay: s.day + 3)]
        night(&s, &rng)
        #expect(s.tradeOffer == nil)
        for _ in 0..<3 { night(&s, &rng) }
        #expect(s.tradeOffer?.roosterID == rooster.id)
    }
}

struct ShopTests {
    @Test func buyingYoungBirds() {
        var (s, rng) = startedGame(sex: .hen)
        s.coins = 100
        let ev = Engine.apply(.buy(.pullet), to: &s, using: &rng)
        guard case .boughtBird(let id, .pullet, 25) = ev.first else {
            Issue.record("not bought")
            return
        }
        let bird = s.bird(id)!
        #expect(bird.sex == .hen && bird.revealed && Breed.starters.contains(bird.breed))
        #expect(bird.stage(onDay: s.day, rules: s.rules) == .grower)
        #expect(s.coop.contains { $0.id == id })
        _ = Engine.apply(.buy(.cockerel), to: &s, using: &rng)
        #expect(s.coins == 100 - 25 - 15)
        #expect(s.coop.count(where: { $0.sex == .rooster }) == 1)
    }

    @Test func birdsNeedAFreePerch() {
        var (s, rng) = startedGame(sex: .hen)
        s.coins = 100
        s.perches = 0
        #expect(Engine.apply(.buy(.pullet), to: &s, using: &rng) == [.rejected(.noFreePerch)])
        #expect(s.coins == 100)
    }

    @Test func notEnoughCoins() {
        var (s, rng) = startedGame(sex: .hen)
        s.coins = 5
        #expect(
            Engine.apply(.buy(.fertileEgg), to: &s, using: &rng) == [.rejected(.notEnoughCoins(needed: 6, have: 5))])
    }

    @Test func aBoughtEggIsFertileCandledAndHatchable() {
        var (s, rng) = startedGame(sex: .hen)
        s.coins = 100
        s.incubatorSize = 1
        #expect(
            Engine.apply(.buy(.fertileEgg), to: &s, using: &rng) == [
                .boughtEgg(cost: 6), .slotSpent(.village, left: 2),
            ])
        #expect(s.carton.count == 1 && s.carton[0].isFertile && s.carton[0].isCandled)
        _ = Engine.apply(.incubate(count: 1), to: &s, using: &rng)
        let ev = night(&s, &rng)
        #expect(ev.contains { if case .chicksHatched(let ids, nil) = $0 { ids.count == 1 } else { false } })
    }

    @Test func aFullCartonBlocksBuyingAnEgg() {
        var (s, rng) = startedGame(sex: .hen)
        s.coins = 100
        s.carton = (0..<12).map { _ in clearEgg(mother: s.brooder[0], day: 0, rng: &rng) }
        #expect(Engine.apply(.buy(.fertileEgg), to: &s, using: &rng) == [.rejected(.cartonFull)])
    }

    @Test func shopBirdsAreAlwaysNormalStarterBirds() {
        var (s, rng) = startedGame(sex: .hen)
        s.perches = 1000
        for _ in 0..<300 {
            s.coins = 100
            _ = Engine.apply(.buy(.pullet), to: &s, using: &rng)
            _ = Engine.apply(.buy(.cockerel), to: &s, using: &rng)
        }
        for b in s.coop {
            #expect(Breed.starters.contains(b.breed))
            #expect(!b.phenotype.isSilkieFeathered)
            #expect(b.isPurebred)
            // Only gold (buff) Wyandottes show lacing.
            #expect(b.phenotype.isLaced == (b.breed == .wyandotte && b.phenotype.colour == .buff))
        }
    }
}

/// Anti-leak rule: the trade safety net must not tell the player a chick's sex before the game does.
struct TradeOfferLeakTests {
    @Test func anUnrevealedRoosterChickIsNeverOfferedInTrade() {
        // The bug: a rooster starter chick, coins spent, day 2. The offer "a hen for Pip" said Pip is a rooster.
        var (s, rng) = startedGame(sex: .rooster, rules: calmRules())
        s.coins = 0
        let pip = s.brooder[0]
        #expect(!pip.revealed)
        for _ in 0..<(s.rules.growerAge - 1) {
            night(&s, &rng)
            #expect(s.tradeOffer == nil, "day \(s.day): offer before Pip is revealed")
        }
    }

    @Test func theOfferComesOnceTheRoosterIsKnown() {
        var (s, rng) = startedGame(sex: .rooster, rules: calmRules())
        s.giftHenGiven = true  // no neighbour's gift hen: the trade is the only way to a hen
        s.coins = 0
        while !(s.bird(s.brooder.first?.id ?? s.coop[0].id)?.revealed ?? false) { night(&s, &rng) }
        night(&s, &rng)
        #expect(s.tradeOffer != nil)
        let offered = s.bird(s.tradeOffer!.roosterID)!
        #expect(offered.revealed && offered.sex == .rooster)
    }
}
