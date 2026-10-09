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
