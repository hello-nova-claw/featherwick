import Foundation

// The market board by the bakery: wanted cards from Featherwick's people, and the keeper's own card.
//
// Each week (a night step after the early game) the board pins `Rules.marketCardsMin` to `marketCardsMax`
// wanted cards, at most `marketBirdCardsPerPin` of them for a bird: "3 blue eggs, 14 coins, until day 40",
// or "a friendly hen for a child". The keeper fills a
// card by bringing the eggs or the bird before the card's last day ends. A card that is not filled just
// comes down. No penalty: another week brings new cards.
//
// The keeper can pin a card of their own: "I have young Orpingtons". A buyer comes 1 to 3 days later and
// waits a few days. The buyer pays more than a neighbour would for a new home (`Rules.marketBuyerPrice`).
//
// The pins come from `GameState.shopSeed` and the day, never from the game RNG, so the board changes no
// seeded game. Core holds IDs, wants and numbers only. The words live in FeatherwickText (`MarketText`).
//
// Rule 8: a card asks only for what the keeper can see: an egg colour, a sex that shows, a friendliness
// band, a grown hen. A bird whose feathers are not in yet never fits a card, whatever the card asks.
//
// The board opens with `Feature.marketBoard`: on its day, or the morning Mr Okafor's note about the board
// comes (`MarketBoard.openingNoteID`), if that is sooner.

/// What a bird card asks for. Every field is something the keeper can see on a grown bird.
public struct MarketBirdAsk: Hashable, Codable, Sendable {
    /// Hen or rooster. Nil: either.
    public var sex: Sex?
    /// This friendly or friendlier. Nil: any band.
    public var friendliness: Friendliness?
    /// A laying hen: an adult hen, not retired. Only with `sex: .hen`.
    public var laying: Bool

    public init(sex: Sex? = nil, friendliness: Friendliness? = nil, laying: Bool = false) {
        self.sex = sex
        self.friendliness = friendliness
        self.laying = laying
    }

    /// True when this bird is what the card asks for. A bird whose sex does not show yet never fits,
    /// so the answer leaks nothing.
    public func fits(_ bird: Bird, in s: GameState) -> Bool {
        guard bird.revealed else { return false }
        if let sex, bird.sex != sex { return false }
        if let friendliness, bird.friendliness < friendliness { return false }
        if laying {
            guard bird.sex == .hen, bird.stage(onDay: s.day, rules: s.rules) == .adult,
                !bird.isRetired(onDay: s.day, rules: s.rules)
            else { return false }
        }
        return true
    }
}

/// What a wanted card asks for.
public enum MarketWant: Hashable, Codable, Sendable {
    /// This many carton eggs of one colour, speckled or plain.
    case eggs(EggColour, count: Int)
    /// One bird that fits the ask.
    case bird(MarketBirdAsk)
}

/// One kind of wanted card in the table: who pins it, what it asks, and when it may be pinned.
public struct MarketCardKind: Hashable, Sendable, Identifiable {
    public let id: String
    public let from: Person
    public let want: MarketWant
    /// When the card may be pinned. Reads only what the keeper can see (the same conditions as the post).
    public let condition: NoteCondition

    public init(_ id: String, from: Person, wants want: MarketWant, when condition: NoteCondition = .always) {
        self.id = id
        self.from = from
        self.want = want
        self.condition = condition
    }
}

/// A card on the board. It keeps its own copy of the want and the reward, so a later change to the table
/// never changes a card already pinned in a save.
public struct MarketCard: Hashable, Codable, Sendable, Identifiable {
    /// The kind's ID and the pin day: "okafor-blue@42". Unique on the board.
    public let id: String
    /// The `MarketCardKind` it came from. The words come from this.
    public let kind: String
    public let from: Person
    public let want: MarketWant
    public let coins: Int
    public let pinnedDay: Int
    /// The last day the card can be filled. It comes down the next morning.
    public let untilDay: Int
}

/// The keeper's own card: "I have young <breed>s". One at a time.
public struct KeeperCard: Hashable, Codable, Sendable {
    public let breed: Breed
    public let postedDay: Int
    /// The morning the buyer comes.
    public let buyerDay: Int
    /// The morning the buyer goes home, if nothing suited. The card comes down with them.
    public let buyerLeavesDay: Int

    /// True while the buyer is in the village and a bird can be sold.
    public func buyerHere(onDay day: Int) -> Bool { day >= buyerDay && day < buyerLeavesDay }
}

/// The board's state, saved with the game.
public struct MarketBoard: Hashable, Codable, Sendable {
    /// Wanted cards up now, oldest pin first.
    public var cards: [MarketCard] = []
    /// The morning the last cards were pinned. Nil before the first pin.
    public var lastPinDay: Int?
    /// The keeper's own card, if one is up.
    public var keeperCard: KeeperCard?
    /// Wanted cards the keeper has filled, ever.
    public var cardsFilled = 0
    /// Birds sold to buyers from the keeper's card, ever.
    public var birdsSold = 0

    public init() {}

    /// Mr Okafor's note that there is talk of a market board. When it comes, the board opens the same
    /// morning, if its timeline day has not come yet.
    public static let openingNoteID = "okafor-marketBoard"

    public func card(_ id: String) -> MarketCard? { cards.first { $0.id == id } }
}

public enum MarketCards {
    /// Every kind of wanted card. Append, never insert: the seeded pick reads list order.
    public static let pool: [MarketCardKind] = [
        MarketCardKind("okafor-blue", from: .okafor, wants: .eggs(.blue, count: 3), when: .eggBookHas(.blue)),
        MarketCardKind("okafor-brown", from: .okafor, wants: .eggs(.brown, count: 6), when: .eggBookHas(.brown)),
        MarketCardKind("okafor-cream", from: .okafor, wants: .eggs(.cream, count: 6), when: .eggBookHas(.cream)),
        MarketCardKind("okafor-olive", from: .okafor, wants: .eggs(.olive, count: 3), when: .eggBookHas(.olive)),
        MarketCardKind("okafor-green", from: .okafor, wants: .eggs(.green, count: 3), when: .eggBookHas(.green)),
        MarketCardKind("okafor-white", from: .okafor, wants: .eggs(.white, count: 6), when: .eggBookHas(.white)),
        MarketCardKind(
            "okafor-chocolate", from: .okafor, wants: .eggs(.chocolate, count: 3), when: .eggBookHas(.chocolate)),
        MarketCardKind("teddy-calmHen", from: .teddy, wants: .bird(MarketBirdAsk(sex: .hen, friendliness: .friendly))),
        MarketCardKind("bea-youngBird", from: .bea, wants: .bird(MarketBirdAsk())),
        MarketCardKind("hazel-rooster", from: .hazel, wants: .bird(MarketBirdAsk(sex: .rooster))),
        MarketCardKind(
            "wren-layingHen", from: .wren, wants: .bird(MarketBirdAsk(sex: .hen, laying: true)),
            when: .hasEggs),
        MarketCardKind(
            "dot-lapChicken", from: .dot, wants: .bird(MarketBirdAsk(friendliness: .lapChicken)),
            when: .bandCount(.friendly, 1)),
        MarketCardKind("teddy-brown", from: .teddy, wants: .eggs(.brown, count: 4), when: .eggBookHas(.brown)),
        MarketCardKind("dot-blue", from: .dot, wants: .eggs(.blue, count: 6), when: .eggBookHas(.blue)),
    ]

    public static func kind(_ id: String) -> MarketCardKind? { pool.first { $0.id == id } }
}

extension Rules {
    /// The coins a card pays for what it asks. Eggs pay `marketEggRewardFactor` times their fresh price.
    /// A bird pays a base, more for a laying hen, and more for a friendlier band.
    public func marketReward(for want: MarketWant) -> Int {
        switch want {
        case .eggs(let colour, let count):
            let each = freshPrice(of: colour)
            return Int((Double(each * max(0, count)) * marketEggRewardFactor).rounded())
        case .bird(let ask):
            var coins = marketBirdCoins
            if ask.laying { coins += marketLayingHenCoins }
            switch ask.friendliness {
            case .lapChicken: coins += marketLapChickenCoins
            case .friendly: coins += marketFriendlyCoins
            case .wild, .skittish, nil: break
            }
            return coins
        }
    }

    /// What a buyer from the keeper's card pays for a bird a neighbour would give `rehomeValue` for.
    /// Always more than the rehome price.
    public func marketBuyerPrice(rehomeValue: Int) -> Int {
        Int((Double(max(0, rehomeValue)) * marketBuyerFactor).rounded(.up)) + marketBuyerBonus
    }

    /// The price of one fresh, plain egg of this colour at the farm gate.
    func freshPrice(of colour: EggColour) -> Int {
        switch colour {
        case .cream: creamEggPrice
        case .brown: brownEggPrice
        case .blue: blueEggPrice
        case .olive: oliveEggPrice
        case .chocolate: chocolateEggPrice
        case .green: greenEggPrice
        case .white: whiteEggPrice
        }
    }
}

extension GameState {
    /// The keeper's birds a buyer could take for a card about this breed: purebred, young (not adult yet),
    /// feathers in, at home, and free to go to a new home.
    public func youngBirdsForSale(of breed: Breed) -> [Bird] {
        birdsAtHome.filter { bird in
            bird.revealed && bird.isPurebred && bird.breed == breed
                && bird.stage(onDay: day, rules: rules) < .adult
                && Engine.rehomeBlocker(bird.id, in: self) == nil
        }
    }

    /// The breeds the keeper could pin a card for now, in breed-table order.
    public var breedsForKeeperCard: [Breed] {
        BreedTable.all.map(\.id).filter { !youngBirdsForSale(of: $0).isEmpty }
    }

    /// The carton eggs a card would take, in the order it takes them: eggs not known to be fertile first,
    /// then the oldest. Nil for a bird card.
    public func eggsFor(_ card: MarketCard) -> [Egg]? {
        guard case .eggs(let colour, let count) = card.want else { return nil }
        let matching = carton.filter { $0.colour == colour }
        let plain = matching.filter { !($0.isCandled && $0.isFertile) }
        let fertile = matching.filter { $0.isCandled && $0.isFertile }
        let ordered = plain.sorted { $0.layDay < $1.layDay } + fertile.sorted { $0.layDay < $1.layDay }
        return Array(ordered.prefix(count))
    }

    /// The birds at home that fit a bird card and can go now. Empty for an egg card.
    public func birdsFor(_ card: MarketCard) -> [Bird] {
        guard case .bird(let ask) = card.want else { return [] }
        return birdsAtHome.filter { ask.fits($0, in: self) && Engine.rehomeBlocker($0.id, in: self) == nil }
    }

    /// True when the keeper could fill this card right now.
    public func canFill(_ card: MarketCard) -> Bool {
        switch card.want {
        case .eggs(_, let count): (eggsFor(card)?.count ?? 0) >= count
        case .bird: !birdsFor(card).isEmpty
        }
    }
}

extension Engine {
    /// Each morning, once the board is open: cards past their day come down, the keeper's buyer comes or
    /// goes, and on a pin day new cards go up. Seeded from the shop seed and the day: no game RNG.
    static func marketBoardMorning(_ s: inout GameState, pool: [MarketCardKind] = MarketCards.pool) -> [GameEvent] {
        guard s.isOpen(.marketBoard) else { return [] }
        var ev: [GameEvent] = []
        let down = s.marketBoard.cards.filter { $0.untilDay < s.day }
        s.marketBoard.cards.removeAll { $0.untilDay < s.day }
        ev += down.map { .marketCardDown($0) }

        if let card = s.marketBoard.keeperCard {
            if s.day >= card.buyerLeavesDay {
                s.marketBoard.keeperCard = nil
                ev.append(.marketBuyerLeft(card.breed))
            } else if s.day == card.buyerDay {
                ev.append(.marketBuyerCame(card.breed))
            }
        }

        let r = s.rules
        let due = s.marketBoard.lastPinDay.map { s.day - $0 >= r.marketPinIntervalDays } ?? true
        guard due else { return ev }
        s.marketBoard.lastPinDay = s.day
        var rng = SeededRNG(seed: s.shopSeed ^ 0x4D52_4B54 ^ UInt64(truncatingIfNeeded: s.day))  // "MRKT"
        let low = max(0, min(r.marketCardsMin, r.marketCardsMax))
        let want = Int.random(in: low...max(low, r.marketCardsMax), using: &rng)
        let up = Set(s.marketBoard.cards.map(\.kind))
        var fits = pool.filter { !up.contains($0.id) && $0.condition.holds(in: s) }
        var pinned: [MarketCard] = []
        while pinned.count < want, !fits.isEmpty {
            let kind = fits.remove(at: Int.random(in: 0..<fits.count, using: &rng))
            if case .bird = kind.want {
                let birdCards = pinned.count(where: { if case .bird = $0.want { true } else { false } })
                if birdCards >= r.marketBirdCardsPerPin { continue }
            }
            pinned.append(
                MarketCard(
                    id: "\(kind.id)@\(s.day)", kind: kind.id, from: kind.from, want: kind.want,
                    coins: r.marketReward(for: kind.want), pinnedDay: s.day,
                    untilDay: s.day + max(1, r.marketCardDays) - 1))
        }
        s.marketBoard.cards += pinned
        if !pinned.isEmpty { ev.append(.marketCardsPinned(pinned)) }
        return ev
    }

    /// The keeper fills a wanted card: the eggs or the bird go, and the card pays.
    static func fillCard(_ id: String, bird birdID: UUID?, _ s: inout GameState) -> [GameEvent] {
        guard let card = s.marketBoard.card(id) else { return [.rejected(.noSuchCard)] }
        switch card.want {
        case .eggs(let colour, let count):
            let eggs = s.eggsFor(card) ?? []
            guard eggs.count >= count else {
                return [.rejected(.notEnoughEggsForCard(colour, need: count, have: eggs.count))]
            }
            let taken = Set(eggs.map(\.id))
            s.carton.removeAll { taken.contains($0.id) }
        case .bird(let ask):
            guard let birdID, let bird = s.bird(birdID), !s.rehomed.contains(where: { $0.id == birdID }) else {
                return [.rejected(.noSuchBird)]
            }
            // Rule 8: a bird whose feathers are not in is refused for its age, never for its sex.
            guard bird.revealed else { return [.rejected(.tooYoungForCard)] }
            guard ask.fits(bird, in: s) else { return [.rejected(.birdDoesNotFitCard)] }
            if let blocker = rehomeBlocker(birdID, in: s) { return [.rejected(blocker)] }
            guard let (keyPath, i) = locate(birdID, in: s, groups: [\.brooder, \.henChicks, \.coop]) else {
                return [.rejected(.birdNotHome)]
            }
            let leaving = s[keyPath: keyPath].remove(at: i)
            _ = sendToNewHome(leaving, &s, coins: 0)
        }
        s.coins += card.coins
        s.marketBoard.cards.removeAll { $0.id == id }
        s.marketBoard.cardsFilled += 1
        return [.marketCardFilled(card, coins: card.coins)]
    }

    /// The keeper pins their own card: "I have young <breed>s". A buyer comes 1 to 3 days later.
    static func postCard(_ breed: Breed, _ s: inout GameState) -> [GameEvent] {
        if s.marketBoard.keeperCard != nil { return [.rejected(.keeperCardAlreadyUp)] }
        if s.youngBirdsForSale(of: breed).isEmpty { return [.rejected(.noYoungBirdsForCard)] }
        let r = s.rules
        var rng = SeededRNG(seed: s.shopSeed ^ 0x4255_5952 ^ UInt64(truncatingIfNeeded: s.day))  // "BUYR"
        let low = max(1, min(r.marketBuyerMinDays, r.marketBuyerMaxDays))
        let buyerDay = s.day + Int.random(in: low...max(low, r.marketBuyerMaxDays), using: &rng)
        s.marketBoard.keeperCard = KeeperCard(
            breed: breed, postedDay: s.day, buyerDay: buyerDay,
            buyerLeavesDay: buyerDay + max(1, r.marketBuyerWaitDays))
        return [.marketCardPosted(breed)]
    }

    /// The buyer from the keeper's card takes one young bird of the card's breed, and pays well for it.
    static func sellToBuyer(_ birdID: UUID, _ s: inout GameState) -> [GameEvent] {
        guard let card = s.marketBoard.keeperCard, card.buyerHere(onDay: s.day) else {
            return [.rejected(.noBuyerYet)]
        }
        guard let bird = s.bird(birdID), !s.rehomed.contains(where: { $0.id == birdID }) else {
            return [.rejected(.noSuchBird)]
        }
        guard s.youngBirdsForSale(of: card.breed).contains(where: { $0.id == birdID }) else {
            if let blocker = rehomeBlocker(birdID, in: s) { return [.rejected(blocker)] }
            return [.rejected(bird.revealed ? .birdDoesNotFitCard : .tooYoungForCard)]
        }
        guard let (keyPath, i) = locate(birdID, in: s, groups: [\.brooder, \.henChicks, \.coop]) else {
            return [.rejected(.birdNotHome)]
        }
        let price = s.rules.marketBuyerPrice(rehomeValue: s.rehomeValue(of: bird))
        let leaving = s[keyPath: keyPath].remove(at: i)
        let paid = sendToNewHome(leaving, &s, coins: price)
        s.marketBoard.keeperCard = nil
        s.marketBoard.birdsSold += 1
        return [.soldToBuyer(birdID, coins: paid)]
    }
}
