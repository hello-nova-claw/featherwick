import Foundation
import Testing

@testable import FeatherwickCore

/// The market board by the bakery (MarketBoard.swift): weekly wanted cards, filling them, and the keeper's own card.
struct MarketBoardTests {
    /// A started game with every feature open, so the board is up from the first night.
    static func game(seed: UInt64 = 5) -> (GameState, SeededRNG) {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules(), seed: seed)
        s.coins = 100
        return (s, rng)
    }

    static func egg(_ colour: EggColour, day: Int, fertile: Bool = false) -> Egg {
        var egg = Egg(id: UUID(), layDay: day, motherID: UUID(), colour: colour, speckled: false)
        egg.collectedDay = day
        if fertile {
            egg.embryo = Breed.orpington.purebred(.hen)
            egg.candled = true
        }
        return egg
    }

    static func card(_ want: MarketWant, day: Int, rules: Rules = .standard) -> MarketCard {
        MarketCard(
            id: "test@\(day)", kind: "test", from: .okafor, want: want, coins: rules.marketReward(for: want),
            pinnedDay: day, untilDay: day + 2)
    }

    /// A young bird whose feathers are in: a grower, purebred.
    static func youngBird(
        _ breed: Breed = .orpington, _ sex: Sex = .hen, tame: Double = 0.25, _ s: GameState, _ rng: inout SeededRNG
    ) -> Bird {
        var bird = plainBird(breed, sex, hatchDay: s.day - s.rules.growerAge - 2, rng: &rng)
        bird.tameness = tame
        return bird
    }

    static func pinned(_ ev: [GameEvent]) -> [MarketCard] {
        var out: [MarketCard] = []
        for case .marketCardsPinned(let cards) in ev { out += cards }
        return out
    }

    // MARK: - Opening

    @Test func theBoardOpensOnItsDayAndRefusesBeforeThen() {
        var rng = SeededRNG(seed: 2)
        var s = Engine.newGame(using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        #expect(!s.isOpen(.marketBoard))
        #expect(s.introductionDay(of: .marketBoard) == Rules.standard.featureDays[.marketBoard])
        #expect(Engine.apply(.postCard(.orpington), to: &s, using: &rng) == [.rejected(.notYet(.marketBoard))])
        #expect(Engine.apply(.fillCard("x", bird: nil), to: &s, using: &rng) == [.rejected(.notYet(.marketBoard))])
        // Nothing pinned while it is closed.
        _ = Engine.marketBoardMorning(&s)
        #expect(s.marketBoard.cards.isEmpty)
        s.day = s.introductionDay(of: .marketBoard)
        #expect(Engine.introduceFeatures(&s).contains(.introduced(.marketBoard)))
    }

    @Test func mrOkaforsNoteOpensTheBoardEarly() {
        var rng = SeededRNG(seed: 2)
        var s = Engine.newGame(using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        #expect(!Engine.introduceFeatures(&s).contains(.introduced(.marketBoard)))
        s.notesSeen.insert(MarketBoard.openingNoteID)
        #expect(Engine.introduceFeatures(&s).contains(.introduced(.marketBoard)))
        #expect(s.isOpen(.marketBoard))
    }

    // MARK: - Weekly cards

    @Test func cardsGoUpOnceAWeekAndComeDownAfterTheirDays() {
        var (s, rng) = Self.game()
        let r = s.rules
        var pinDays: [Int] = []
        for _ in 0..<(r.marketPinIntervalDays * 3) {
            let ev = sleepTonight(&s, &rng)
            let cards = Self.pinned(ev)
            if !cards.isEmpty {
                pinDays.append(s.day)
                // Fewer than the least only while the Egg Book is too thin for egg cards.
                #expect((1...r.marketCardsMax).contains(cards.count))
                let birdCards = cards.count(where: { if case .bird = $0.want { true } else { false } })
                #expect(birdCards <= r.marketBirdCardsPerPin)
                #expect(Set(cards.map(\.kind)).count == cards.count)
                for card in cards { #expect(card.untilDay == s.day + r.marketCardDays - 1) }
            }
            // A card never stays up past its day.
            #expect(s.marketBoard.cards.allSatisfy { $0.untilDay >= s.day })
        }
        #expect(pinDays.count == 3)
        #expect(zip(pinDays, pinDays.dropFirst()).allSatisfy { $1 - $0 == r.marketPinIntervalDays })
    }

    @Test func aMissedCardJustComesDown() {
        var (s, rng) = Self.game()
        let card = Self.card(.eggs(.blue, count: 3), day: s.day)
        s.marketBoard.cards = [card]
        s.marketBoard.lastPinDay = s.day  // no new pin tonight
        let coins = s.coins
        var downs: [MarketCard] = []
        for _ in 0..<3 {
            for case .marketCardDown(let c) in sleepTonight(&s, &rng) { downs.append(c) }
        }
        #expect(downs == [card])
        #expect(s.marketBoard.cards.isEmpty)
        #expect(s.coins == coins)
    }

    @Test func theBoardDrawsNoGameRandomness() {
        var a = Self.game(seed: 11)
        var b = Self.game(seed: 11)
        a.0.introduced.remove(.marketBoard)
        for _ in 0..<30 {
            _ = sleepTonight(&a.0, &a.1)
            _ = sleepTonight(&b.0, &b.1)
        }
        #expect(!b.0.marketBoard.cards.isEmpty)
        #expect(a.0.marketBoard.cards.isEmpty)
        #expect(a.1 == b.1)
        #expect(a.0.coop.map(\.id) == b.0.coop.map(\.id))
        #expect(a.0.carton.map(\.id) == b.0.carton.map(\.id))
    }

    @Test func theSameSeedAndDayPinTheSameCards() {
        var (a, _) = Self.game()
        var (b, _) = Self.game()
        #expect(Engine.marketBoardMorning(&a) == Engine.marketBoardMorning(&b))
        #expect(!a.marketBoard.cards.isEmpty)
    }

    @Test func eggCardsAskOnlyForColoursInTheEggBook() {
        var (s, _) = Self.game()
        for day in stride(from: 10, to: 400, by: 7) {
            s.day = day
            s.marketBoard = MarketBoard()
            _ = Engine.marketBoardMorning(&s)
            for card in s.marketBoard.cards {
                guard case .eggs(let colour, _) = card.want else { continue }
                #expect(s.eggBook.contains { $0.colour == colour })
            }
        }
    }

    @Test func thePoolHasUniqueIDsAndSensibleAsks() {
        let ids = MarketCards.pool.map(\.id)
        #expect(Set(ids).count == ids.count)
        for kind in MarketCards.pool {
            switch kind.want {
            case .eggs(_, let count): #expect(count > 0)
            // A laying hen is a hen: the ask never mixes a sex the keeper cannot see.
            case .bird(let ask): if ask.laying { #expect(ask.sex == .hen) }
            }
        }
        // Some bird cards fit any keeper, so a pin always has something to show.
        #expect(MarketCards.pool.count(where: { $0.condition == .always }) >= Rules.standard.marketCardsMax)
    }

    @Test func rewardsComeFromTheRules() {
        let r = Rules.standard
        // "3 blue eggs, 23 coins": two and a half times the farm-gate price (9), rounded.
        #expect(r.marketReward(for: .eggs(.blue, count: 3)) == 23)
        // Six brown eggs pay what Mr Okafor's window pays for them.
        #expect(r.marketReward(for: .eggs(.brown, count: 6)) == 30)
        #expect(r.marketReward(for: .bird(MarketBirdAsk())) == r.marketBirdCoins)
        #expect(
            r.marketReward(for: .bird(MarketBirdAsk(sex: .hen, friendliness: .friendly)))
                == r.marketBirdCoins + r.marketFriendlyCoins)
        // A buyer always pays more than a new home would.
        for value in [0, 2, 6, 20, 40] { #expect(r.marketBuyerPrice(rehomeValue: value) > value) }
    }

    // MARK: - Filling a card

    @Test func anEggCardTakesPlainEggsFirstAndPays() {
        var (s, rng) = Self.game()
        let card = Self.card(.eggs(.blue, count: 3), day: s.day)
        s.marketBoard.cards = [card]
        let fertile = Self.egg(.blue, day: s.day - 3, fertile: true)
        let plain = (0..<3).map { Self.egg(.blue, day: s.day - $0) }
        let brown = Self.egg(.brown, day: s.day)
        s.carton = [fertile, brown] + plain
        let coins = s.coins
        let ev = Engine.apply(.fillCard(card.id, bird: nil), to: &s, using: &rng)
        #expect(ev.contains(.marketCardFilled(card, coins: card.coins)))
        #expect(s.coins == coins + card.coins)
        #expect(s.carton.map(\.id) == [fertile.id, brown.id])
        #expect(s.marketBoard.cards.isEmpty)
        #expect(s.marketBoard.cardsFilled == 1)
    }

    @Test func anEggCardWaitsForEnoughEggs() {
        var (s, rng) = Self.game()
        let card = Self.card(.eggs(.blue, count: 3), day: s.day)
        s.marketBoard.cards = [card]
        s.carton = [Self.egg(.blue, day: s.day), Self.egg(.cream, day: s.day)]
        let before = s
        let ev = Engine.apply(.fillCard(card.id, bird: nil), to: &s, using: &rng)
        #expect(ev == [.rejected(.notEnoughEggsForCard(.blue, need: 3, have: 1))])
        #expect(s == before)
        #expect(Engine.apply(.fillCard("nope", bird: nil), to: &s, using: &rng) == [.rejected(.noSuchCard)])
    }

    @Test func aBirdCardTakesOnlyABirdThatFits() {
        var (s, rng) = Self.game()
        let card = Self.card(.bird(MarketBirdAsk(sex: .hen, friendliness: .friendly)), day: s.day)
        s.marketBoard.cards = [card]
        let tameHen = Self.youngBird(.orpington, .hen, tame: 1, s, &rng)
        let shyHen = Self.youngBird(.orpington, .hen, tame: 0, s, &rng)
        let tameRooster = Self.youngBird(.orpington, .rooster, tame: 1, s, &rng)
        s.coop += [tameHen, shyHen, tameRooster]
        #expect(s.birdsFor(card).map(\.id).contains(tameHen.id))
        #expect(!s.birdsFor(card).map(\.id).contains(tameRooster.id))
        for wrong in [tameRooster, shyHen] where wrong.friendliness < .friendly || wrong.sex == .rooster {
            #expect(
                Engine.apply(.fillCard(card.id, bird: wrong.id), to: &s, using: &rng) == [
                    .rejected(.birdDoesNotFitCard)
                ])
        }
        #expect(Engine.apply(.fillCard(card.id, bird: nil), to: &s, using: &rng) == [.rejected(.noSuchBird)])
        let coins = s.coins
        let ev = Engine.apply(.fillCard(card.id, bird: tameHen.id), to: &s, using: &rng)
        #expect(ev.contains(.marketCardFilled(card, coins: card.coins)))
        #expect(s.coins == coins + card.coins)
        #expect(!s.coop.contains { $0.id == tameHen.id })
        #expect(s.rehomed.contains { $0.id == tameHen.id })
    }

    /// Rule 8: a chick whose sex does not show is refused for its age, the same way whatever it is.
    @Test func aChickIsTooYoungWhateverItsSex() {
        var (s, rng) = Self.game()
        let card = Self.card(.bird(MarketBirdAsk(sex: .hen)), day: s.day)
        s.marketBoard.cards = [card]
        for sex in Sex.allCases {
            var chick = plainBird(.orpington, sex, hatchDay: s.day - 1, rng: &rng)
            chick.revealed = false
            s.brooder.append(chick)
            #expect(
                Engine.apply(.fillCard(card.id, bird: chick.id), to: &s, using: &rng) == [.rejected(.tooYoungForCard)])
            #expect(!s.birdsFor(card).contains { $0.id == chick.id })
            for kind in MarketCards.pool {
                if case .bird(let ask) = kind.want { #expect(!ask.fits(chick, in: s)) }
            }
        }
    }

    @Test func theLastBirdStays() {
        var (s, rng) = Self.game()
        let card = Self.card(.bird(MarketBirdAsk()), day: s.day)
        s.marketBoard.cards = [card]
        guard let only = s.ownBirds.first, s.ownBirds.count == 1 else {
            Issue.record("expected one bird")
            return
        }
        s.day = s.rules.growerAge + 1
        for i in s.brooder.indices { s.brooder[i].revealed = true }
        for i in s.coop.indices { s.coop[i].revealed = true }
        #expect(Engine.apply(.fillCard(card.id, bird: only.id), to: &s, using: &rng) == [.rejected(.lastBird)])
    }

    @Test func fillingACardIsAMarketErrand() {
        var (s, rng) = Self.game()
        #expect(Engine.errand(for: .fillCard("x", bird: nil)) == .market)
        #expect(Engine.errand(for: .postCard(.orpington)) == .market)
        #expect(Engine.errand(for: .sellToBuyer(UUID())) == .market)
        let card = Self.card(.eggs(.cream, count: 1), day: s.day)
        s.marketBoard.cards = [card]
        s.carton = [Self.egg(.cream, day: s.day)]
        let ev = Engine.apply(.fillCard(card.id, bird: nil), to: &s, using: &rng)
        #expect(ev.contains { if case .slotSpent(.market, _) = $0 { true } else { false } })
    }

    // MARK: - The keeper's own card

    @Test func theKeepersCardBringsABuyerWhoPaysMore() {
        var (s, rng) = Self.game()
        s.marketBoard.lastPinDay = s.day
        #expect(Engine.apply(.postCard(.wyandotte), to: &s, using: &rng) == [.rejected(.noYoungBirdsForCard)])
        let young = Self.youngBird(.wyandotte, .hen, s, &rng)
        s.coop.append(young)
        #expect(s.breedsForKeeperCard.contains(.wyandotte))
        #expect(Engine.apply(.postCard(.wyandotte), to: &s, using: &rng).contains(.marketCardPosted(.wyandotte)))
        #expect(Engine.apply(.postCard(.wyandotte), to: &s, using: &rng) == [.rejected(.keeperCardAlreadyUp)])
        guard let mine = s.marketBoard.keeperCard else {
            Issue.record("no card")
            return
        }
        let r = s.rules
        #expect((s.day + r.marketBuyerMinDays...s.day + r.marketBuyerMaxDays).contains(mine.buyerDay))
        #expect(Engine.apply(.sellToBuyer(young.id), to: &s, using: &rng) == [.rejected(.noBuyerYet)])
        var came = false
        while s.day < mine.buyerDay {
            if sleepTonight(&s, &rng).contains(.marketBuyerCame(.wyandotte)) { came = true }
        }
        #expect(came)
        guard let bird = s.bird(young.id) else {
            Issue.record("bird gone")
            return
        }
        let rehome = s.rehomeValue(of: bird)
        let coins = s.coins
        let ev = Engine.apply(.sellToBuyer(young.id), to: &s, using: &rng)
        let paid = r.marketBuyerPrice(rehomeValue: rehome)
        #expect(ev.contains(.soldToBuyer(young.id, coins: paid)))
        #expect(paid > rehome)
        #expect(s.coins == coins + paid)
        #expect(s.marketBoard.keeperCard == nil)
        #expect(s.rehomed.contains { $0.id == young.id })
    }

    @Test func aBuyerWhoFindsNothingGoesHomeKindly() {
        var (s, rng) = Self.game()
        s.marketBoard.lastPinDay = s.day
        s.coop.append(Self.youngBird(.araucana, .rooster, s, &rng))
        _ = Engine.apply(.postCard(.araucana), to: &s, using: &rng)
        guard let mine = s.marketBoard.keeperCard else {
            Issue.record("no card")
            return
        }
        var left = false
        let coins = s.coins
        while s.day < mine.buyerLeavesDay {
            if sleepTonight(&s, &rng).contains(.marketBuyerLeft(.araucana)) { left = true }
        }
        #expect(left)
        #expect(s.marketBoard.keeperCard == nil)
        #expect(s.coins >= coins)
    }

    @Test func aCrossOrAGrownBirdCannotBeOffered() {
        var (s, rng) = Self.game()
        var cross = Self.youngBird(.orpington, .hen, s, &rng)
        cross.purebredFlag = false
        let grown = plainBird(.wyandotte, .hen, hatchDay: s.day - s.rules.adultAge - 1, rng: &rng)
        s.coop += [cross, grown]
        #expect(s.youngBirdsForSale(of: .orpington).allSatisfy { $0.id != cross.id })
        #expect(s.youngBirdsForSale(of: .wyandotte).isEmpty)
    }

    // MARK: - Report and saves

    @Test func boardNewsGoesUnderTheVillage() {
        let card = Self.card(.eggs(.blue, count: 3), day: 10)
        for event: GameEvent in [
            .marketCardsPinned([card]), .marketCardDown(card), .marketBuyerCame(.orpington),
            .marketBuyerLeft(.orpington),
        ] {
            #expect(MorningReport.group(of: event) == .village)
        }
    }

    @Test func aSaveFromBeforeTheBoardLoads() throws {
        let (s, rng) = Self.game()
        let data = try SaveFormat.encode(SaveGame(state: s, rng: rng))
        var root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var state = try #require(root["state"] as? [String: Any])
        state["marketBoard"] = nil
        var rules = try #require(state["rules"] as? [String: Any])
        for key in rules.keys where key.hasPrefix("market") { rules[key] = nil }
        state["rules"] = rules
        root["state"] = state
        let old = try JSONSerialization.data(withJSONObject: root)
        let loaded = try SaveFormat.decode(old)
        #expect(loaded.state.marketBoard == MarketBoard())
        #expect(loaded.state.rules.marketCardsMax == Rules.standard.marketCardsMax)
    }
}
