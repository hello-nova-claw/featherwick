import Foundation
import Testing

@testable import FeatherwickCore
@testable import FeatherwickText

/// The words for the market board (MarketText.swift).
struct MarketTextTests {
    static func game() -> GameState {
        var rng = SeededRNG(seed: 4)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        return s
    }

    @Test func everyCardKindHasALine() {
        for kind in MarketCards.pool {
            let note = marketCardNote(kind.id)
            #expect(note?.isEmpty == false, "\(kind.id)")
        }
    }

    @Test func wantsReadAsWritten() {
        #expect(marketWantText(.eggs(.blue, count: 3)) == "3 blue eggs")
        #expect(marketWantText(.eggs(.cream, count: 1)) == "1 cream egg")
        #expect(marketWantText(.bird(MarketBirdAsk(sex: .hen, friendliness: .friendly))) == "a friendly hen")
        #expect(marketWantText(.bird(MarketBirdAsk(sex: .hen, laying: true))) == "a laying hen")
        #expect(marketWantText(.bird(MarketBirdAsk())) == "a young bird")
        #expect(marketWantText(.bird(MarketBirdAsk(friendliness: .lapChicken))) == "a lap chicken")
        #expect(marketWantText(.bird(MarketBirdAsk(sex: .rooster))) == "a rooster")
    }

    @Test func aCardSaysWhoWhatHowMuchAndUntilWhen() {
        let s = Self.game()
        let card = MarketCard(
            id: "okafor-blue@\(s.day)", kind: "okafor-blue", from: .okafor, want: .eggs(.blue, count: 3), coins: 18,
            pinnedDay: s.day, untilDay: 40)
        #expect(marketCardText(card, s) == "Mr Okafor wants 3 blue eggs. 18 coins, until day 40.")
    }

    @Test func everyBoardEventAndRefusalHasWords() {
        var s = Self.game()
        let card = MarketCard(
            id: "x", kind: "teddy-calmHen", from: .teddy,
            want: .bird(MarketBirdAsk(sex: .hen, friendliness: .friendly)),
            coins: 24, pinnedDay: s.day, untilDay: s.day + 6)
        s.marketBoard.cards = [card]
        let bird = s.birdsAtHome[0].id
        let events: [GameEvent] = [
            .marketCardsPinned([card]), .marketCardDown(card), .marketCardFilled(card, coins: 24),
            .marketCardPosted(.orpington), .marketBuyerCame(.orpington), .marketBuyerLeft(.orpington),
            .soldToBuyer(bird, coins: 12),
        ]
        let rejections: [Rejection] = [
            .noSuchCard, .notEnoughEggsForCard(.blue, need: 3, have: 1), .birdDoesNotFitCard, .tooYoungForCard,
            .keeperCardAlreadyUp, .noYoungBirdsForCard, .noBuyerYet, .noTimeLeft(.market),
        ]
        for e in events + rejections.map({ GameEvent.rejected($0) }) {
            let words = eventText(e, s) ?? ""
            #expect(!words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(e)")
        }
        #expect(introducedText(.marketBoard, s)?.contains("board") == true)
        #expect(!notYetText(.marketBoard, s).isEmpty)
    }

    /// Rule 8: the refusal for a chick is about age, and names no sex.
    @Test func theTooYoungRefusalNamesNoSex() {
        let words = eventText(.rejected(.tooYoungForCard), Self.game()) ?? ""
        for word in ["hen", "rooster", "cockerel", "pullet", " she ", " he "] { #expect(!words.contains(word)) }
    }

    /// Every market line reads the same after the words moved into the String Catalog (#58).
    @Test func theMarketWordsReadAsBefore() {
        var s = Self.game()
        var lines: [String?] = []
        for friendliness in [nil, Friendliness.friendly, .lapChicken, .skittish] {
            for sex in [nil, Sex.hen, .rooster] {
                lines.append(marketWantText(.bird(MarketBirdAsk(sex: sex, friendliness: friendliness))))
            }
            lines.append(marketWantText(.bird(MarketBirdAsk(sex: .hen, friendliness: friendliness, laying: true))))
        }
        lines += [1, 3].map { marketWantText(.eggs(.olive, count: $0)) }
        lines += MarketCards.pool.map { marketCardNote($0.id) }
        let eggs = MarketCard(
            id: "a", kind: "okafor-blue", from: .okafor, want: .eggs(.blue, count: 3), coins: 18, pinnedDay: s.day,
            untilDay: s.day + 3)
        let bird = MarketCard(
            id: "b", kind: "teddy-calmHen", from: .teddy, want: .bird(MarketBirdAsk()), coins: 24,
            pinnedDay: s.day, untilDay: s.day)
        #expect(marketCardLine(eggs, s) == "3 blue eggs · until day \(s.day + 3)")
        lines += [eggs, bird].flatMap { [marketCardText($0, s), marketCardLine($0, s)] }
        let birdID = s.birdsAtHome[0].id
        let events: [GameEvent] = [
            .marketCardsPinned([eggs, bird]), .marketCardDown(eggs), .marketCardFilled(bird, coins: 24),
            .marketCardPosted(.orpington), .marketBuyerCame(.orpington), .marketBuyerLeft(.orpington),
            .soldToBuyer(birdID, coins: 12),
        ]
        let rejections: [Rejection] = [
            .noSuchCard, .notEnoughEggsForCard(.blue, need: 3, have: 1),
            .notEnoughEggsForCard(.brown, need: 1, have: 0),
            .birdDoesNotFitCard, .tooYoungForCard, .keeperCardAlreadyUp, .noYoungBirdsForCard, .noBuyerYet,
        ]
        lines += (events + rejections.map { GameEvent.rejected($0) }).map { eventText($0, s) }
        lines += marketBoardLines(s)
        s.marketBoard.cards = [eggs, bird]
        lines += marketBoardLines(s)
        s.marketBoard.keeperCard = KeeperCard(
            breed: .orpington, postedDay: s.day, buyerDay: s.day + 5, buyerLeavesDay: s.day + 8)
        lines += marketBoardLines(s)
        for leaves in [1, 2] {
            s.marketBoard.keeperCard = KeeperCard(
                breed: .silkie, postedDay: s.day, buyerDay: s.day, buyerLeavesDay: s.day + leaves)
            lines += marketBoardLines(s)
        }
        let fingerprint = pin(lines)
        #expect(fingerprint == "be42659ff9b2b7c4")
    }

    /// The board's rarer lines: a bird card the keeper can fill, the birds that fit it, and a buyer here
    /// for the keeper's own card with the birds it would take.
    @Test func theBoardReadsItsRarerLines() {
        var s = Self.game()
        s.brooder = ["Clover", "Dulcie"].map { name in
            Bird(
                id: UUID(), name: name, breed: .orpington, genome: Breed.orpington.purebred(.hen, variety: .buff),
                hatchDay: s.day, origin: "Speckle & Down", revealed: true)
        }
        s.coop = []
        s.marketBoard.cards = [
            MarketCard(
                id: "b", kind: "bea-youngBird", from: .bea, want: .bird(MarketBirdAsk()), coins: 20, pinnedDay: s.day,
                untilDay: s.day + 2)
        ]
        s.marketBoard.keeperCard = KeeperCard(
            breed: .orpington, postedDay: s.day, buyerDay: s.day, buyerLeavesDay: s.day + 2)
        let price = { (bird: Bird) in s.rules.marketBuyerPrice(rehomeValue: s.rehomeValue(of: bird)) }
        #expect(
            marketBoardLines(s) == [
                "The market board by the bakery:",
                "  1. Bea wants a young bird. 20 coins, until day \(s.day + 2).  ✓ you can fill this",
                "     \"A young bird for a new keeper on the hill. Any breed at all.\"",
                "     Fits: Clover, Dulcie",
                "  Your card: young Orpingtons. A buyer is here for 2 more days.",
                "     Clover: \(price(s.brooder[0])) coins (sell Clover)",
                "     Dulcie: \(price(s.brooder[1])) coins (sell Dulcie)",
                "Fill a card: fill <number> [bird name] · Pin your own: post <breed> · Sell to your buyer: sell <name>",
            ])
        #expect(
            eventText(.soldToBuyer(s.brooder[0].id, coins: 12), s)
                == "Clover goes to a new home with the buyer, who pays 12 coins. \"We'll take good care.\"")
        // An event that is not the board's has no board words.
        #expect(marketEventText(.hatchAlongChickWaiting, s) == nil)
        #expect(marketRejectionText(.blankName, s) == nil)
    }

    @Test func theBoardPageListsCardsAndHowToFillThem() {
        var s = Self.game()
        s.marketBoard.cards = [
            MarketCard(
                id: "a", kind: "okafor-blue", from: .okafor, want: .eggs(.blue, count: 3), coins: 18, pinnedDay: s.day,
                untilDay: s.day + 3)
        ]
        let page = marketBoardLines(s).joined(separator: "\n")
        #expect(page.contains("1. Mr Okafor wants 3 blue eggs."))
        #expect(page.contains("fill <number>"))
    }
}
