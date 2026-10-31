import FeatherwickCore
import Foundation

// The words for the market board by the bakery (see MarketBoard.swift in Core): each card's ask and the
// person's line, the board's events and refusals, and the CLI `board` page.

/// What a card asks for, in a few words: "3 blue eggs", "a friendly hen".
public func marketWantText(_ want: MarketWant) -> String {
    switch want {
    case .eggs(let colour, let count):
        let colour = colour.rawValue
        return count == 1
            ? String(
                localized: "market.want.eggs.one", defaultValue: "\(count) \(colour) egg", bundle: .module,
                comment: "A market card's ask, count == 1. The placeholders are the count and the egg colour.")
            : String(
                localized: "market.want.eggs.other", defaultValue: "\(count) \(colour) eggs", bundle: .module,
                comment: "A market card's ask, count other than 1. The placeholders are the count and the egg colour.")
    case .bird(let ask):
        return birdWantText(ask)
    }
}

/// The bird a card asks for, as a whole phrase: how friendly, then what kind of bird.
private func birdWantText(_ ask: MarketBirdAsk) -> String {
    enum Kind { case layingHen, hen, rooster, youngBird, any }
    let kind: Kind =
        if ask.laying { .layingHen } else if let sex = ask.sex {
            sex == .hen ? .hen : .rooster
        } else if ask.friendliness != .lapChicken { .youngBird } else { .any }
    switch (ask.friendliness, kind) {
    case (.lapChicken, .layingHen):
        return String(
            localized: "market.want.lapChickenLayingHen", defaultValue: "a lap chicken laying hen", bundle: .module,
            comment: "A market card's ask: a bird.")
    case (.lapChicken, .hen):
        return String(
            localized: "market.want.lapChickenHen", defaultValue: "a lap chicken hen", bundle: .module,
            comment: "A market card's ask: a bird.")
    case (.lapChicken, .rooster):
        return String(
            localized: "market.want.lapChickenRooster", defaultValue: "a lap chicken rooster", bundle: .module,
            comment: "A market card's ask: a bird.")
    case (.lapChicken, _):
        return String(
            localized: "market.want.lapChicken", defaultValue: "a lap chicken", bundle: .module,
            comment: "A market card's ask: a bird.")
    case (.friendly, .layingHen):
        return String(
            localized: "market.want.friendlyLayingHen", defaultValue: "a friendly laying hen", bundle: .module,
            comment: "A market card's ask: a bird.")
    case (.friendly, .hen):
        return String(
            localized: "market.want.friendlyHen", defaultValue: "a friendly hen", bundle: .module,
            comment: "A market card's ask: a bird.")
    case (.friendly, .rooster):
        return String(
            localized: "market.want.friendlyRooster", defaultValue: "a friendly rooster", bundle: .module,
            comment: "A market card's ask: a bird.")
    case (.friendly, _):
        return String(
            localized: "market.want.friendlyYoungBird", defaultValue: "a friendly young bird", bundle: .module,
            comment: "A market card's ask: a bird.")
    case (_, .layingHen):
        return String(
            localized: "market.want.layingHen", defaultValue: "a laying hen", bundle: .module,
            comment: "A market card's ask: a bird.")
    case (_, .hen):
        return String(
            localized: "market.want.hen", defaultValue: "a hen", bundle: .module,
            comment: "A market card's ask: a bird.")
    case (_, .rooster):
        return String(
            localized: "market.want.rooster", defaultValue: "a rooster", bundle: .module,
            comment: "A market card's ask: a bird.")
    case (_, _):
        return String(
            localized: "market.want.youngBird", defaultValue: "a young bird", bundle: .module,
            comment: "A market card's ask: a bird.")
    }
}

/// The person's line on a card, by card kind. Every kind in `MarketCards.pool` has a line.
public func marketCardNote(_ kind: String) -> String? {
    switch kind {
    case "okafor-blue":
        String(
            localized: "market.note.okaforBlue", defaultValue: "For the window. Blue sells the brown loaves, somehow.",
            bundle: .module, comment: "Mr Okafor's line on a market card.")
    case "okafor-brown":
        String(
            localized: "market.note.okaforBrown", defaultValue: "Brown eggs for the Saturday buns.", bundle: .module,
            comment: "Mr Okafor's line on a market card.")
    case "okafor-cream":
        String(
            localized: "market.note.okaforCream", defaultValue: "Cream eggs for a custard tart. A big one.",
            bundle: .module, comment: "Mr Okafor's line on a market card.")
    case "okafor-olive":
        String(
            localized: "market.note.okaforOlive", defaultValue: "Olive eggs! The window needs a bit of green.",
            bundle: .module, comment: "Mr Okafor's line on a market card.")
    case "okafor-green":
        String(
            localized: "market.note.okaforGreen", defaultValue: "Green eggs for the window. The children love them.",
            bundle: .module, comment: "Mr Okafor's line on a market card.")
    case "okafor-white":
        String(
            localized: "market.note.okaforWhite", defaultValue: "White eggs for meringues. They must be white.",
            bundle: .module, comment: "Mr Okafor's line on a market card.")
    case "okafor-chocolate":
        String(
            localized: "market.note.okaforChocolate",
            defaultValue: "Dark eggs for the window. They look like little loaves.", bundle: .module,
            comment: "Mr Okafor's line on a market card.")
    case "teddy-calmHen":
        String(
            localized: "market.note.teddyCalmHen",
            defaultValue: "A calm hen for my cousin Ivy. She's six and very gentle.",
            bundle: .module, comment: "Teddy's line on a market card.")
    case "bea-youngBird":
        String(
            localized: "market.note.beaYoungBird",
            defaultValue: "A young bird for a new keeper on the hill. Any breed at all.", bundle: .module,
            comment: "Bea's line on a market card.")
    case "hazel-rooster":
        String(
            localized: "market.note.hazelRooster",
            defaultValue: "My hens have no rooster this year. Any boy who's grown his feathers.", bundle: .module,
            comment: "Hazel's line on a market card.")
    case "wren-layingHen":
        String(
            localized: "market.note.wrenLayingHen",
            defaultValue: "A laying hen for a customer whose old girl has retired.", bundle: .module,
            comment: "Wren's line on a market card.")
    case "dot-lapChicken":
        String(
            localized: "market.note.dotLapChicken",
            defaultValue: "A lap chicken for the children's corner at the show.",
            bundle: .module, comment: "Dot's line on a market card.")
    case "teddy-brown":
        String(
            localized: "market.note.teddyBrown", defaultValue: "Gran's baking a cake for Mum. She needs brown eggs.",
            bundle: .module, comment: "Teddy's line on a market card.")
    case "dot-blue":
        String(
            localized: "market.note.dotBlue", defaultValue: "Blue eggs for the show tea. Six, if you can spare them.",
            bundle: .module, comment: "Dot's line on a market card.")
    default: nil
    }
}

/// "until tonight" or "until day 40".
private func untilText(_ card: MarketCard, _ s: GameState) -> String {
    card.untilDay == s.day
        ? String(
            localized: "market.untilTonight", defaultValue: "until tonight", bundle: .module,
            comment: "A market card comes down tonight.")
        : String(
            localized: "market.untilDay", defaultValue: "until day \(card.untilDay)", bundle: .module,
            comment: "A market card stays up until a day. The placeholder is the day number.")
}

/// One card, in one line: "Mr Okafor wants 3 blue eggs. 18 coins, until day 40."
public func marketCardText(_ card: MarketCard, _ s: GameState) -> String {
    String(
        localized: "market.cardText",
        defaultValue:
            "\(People.name(card.from)) wants \(marketWantText(card.want)). \(card.coins) coins, \(untilText(card, s)).",
        bundle: .module,
        comment: """
            One market card. The placeholders are the person, what they want (market.want.*), the coins paid, and \
            until when (market.untilTonight or market.untilDay).
            """)
}

/// What a card asks and until when, for the app's card: "3 blue eggs · until day 40".
public func marketCardLine(_ card: MarketCard, _ s: GameState) -> String {
    String(
        localized: "market.cardLine",
        defaultValue: "\(marketWantText(card.want).capitalizedFirst) · \(untilText(card, s))",
        bundle: .module,
        comment: """
            The app's market card. The placeholders are what the card wants (market.want.*, first letter \
            capitalised) and until when (market.untilTonight or market.untilDay).
            """)
}

/// The words for the market board's events.
func marketEventText(_ e: GameEvent, _ s: GameState) -> String? {
    switch e {
    case .marketCardsPinned(let cards):
        let lines = cards.map { "  • " + marketCardText($0, s) }.joined(separator: "\n")
        return String(
            localized: "market.cardsPinned",
            defaultValue: "New cards on the market board by the bakery:\n\(lines)\n(see: board)",
            bundle: .module,
            comment: "New market cards. The placeholder is the cards, one a line. \"board\" is a CLI command.")
    case .marketCardDown(let card):
        return String(
            localized: "market.cardDown",
            defaultValue: """
                \(People.name(card.from))'s card for \(marketWantText(card.want)) has come down. \
                Someone else had some. There'll be new cards next week.
                """,
            bundle: .module, comment: "A market card comes down. The placeholders are the person and what they wanted.")
    case .marketCardFilled(let card, let coins):
        return String(
            localized: "market.cardFilled",
            defaultValue: """
                You bring \(People.name(card.from)) \(marketWantText(card.want)). \
                "Just what I hoped for!" You're paid \(coins) coins.
                """,
            bundle: .module,
            comment: "The keeper fills a market card. The placeholders are the person, what they wanted and the coins.")
    case .marketCardPosted(let breed):
        let r = s.rules
        return String(
            localized: "market.cardPosted",
            defaultValue: """
                You pin a card on the board: "Young \(breed.definition.displayName)s, from my own flock." \
                A buyer may come in \(r.marketBuyerMinDays) to \(r.marketBuyerMaxDays) days.
                """,
            bundle: .module,
            comment: """
                The keeper pins a card for young birds. The placeholders are the breed's name (made plural with \
                "s"), and the fewest and most days until a buyer comes.
                """)
    case .marketBuyerCame(let breed):
        let name = breed.definition.displayName
        let days = s.rules.marketBuyerWaitDays
        if days == 1 {
            return String(
                localized: "market.buyerCame.one",
                defaultValue: """
                    Someone saw your card at the bakery. They'd like a young \(name), \
                    and they'll be in the village for \(days) day. (see: board)
                    """,
                bundle: .module,
                comment: """
                    A buyer comes for the keeper's card and stays one day. The placeholders are the breed's name \
                    and the number of days (1). "board" is a CLI command.
                    """)
        }
        return String(
            localized: "market.buyerCame.other",
            defaultValue: """
                Someone saw your card at the bakery. They'd like a young \(name), \
                and they'll be in the village for \(days) days. (see: board)
                """,
            bundle: .module,
            comment: """
                A buyer comes for the keeper's card. The placeholders are the breed's name and the days the \
                buyer stays. "board" is a CLI command.
                """)
    case .marketBuyerLeft(let breed):
        return String(
            localized: "market.buyerLeft",
            defaultValue: """
                The buyer for a young \(breed.definition.displayName) has gone home. Your card comes down. \
                Pin another any time.
                """,
            bundle: .module, comment: "The buyer leaves. The placeholder is the breed's name.")
    case .soldToBuyer(let id, let coins):
        return String(
            localized: "market.soldToBuyer",
            defaultValue:
                "\(birdName(id, s)) goes to a new home with the buyer, who pays \(coins) coins. \"We'll take good care.\"",
            bundle: .module, comment: "A bird is sold to the buyer. The placeholders are the bird's name and the coins."
        )
    default:
        return nil
    }
}

/// The words for the market board's refusals.
func marketRejectionText(_ r: Rejection, _ s: GameState) -> String? {
    switch r {
    case .noSuchCard:
        return String(
            localized: "market.refusal.noSuchCard", defaultValue: "There's no card like that on the board. Type: board",
            bundle: .module, comment: "Refusal: no such market card. \"board\" is a CLI command.")
    case .notEnoughEggsForCard(let colour, let need, let have):
        let colour = colour.rawValue
        return need == 1
            ? String(
                localized: "market.refusal.notEnoughEggs.one",
                defaultValue: "That card needs \(need) \(colour) egg. Your carton has \(have). Collect first: collect",
                bundle: .module,
                comment: """
                    Refusal: too few eggs for a card, when need == 1. The placeholders are the eggs needed, their \
                    colour and the eggs in the carton. "collect" is a CLI command.
                    """)
            : String(
                localized: "market.refusal.notEnoughEggs.other",
                defaultValue: "That card needs \(need) \(colour) eggs. Your carton has \(have). Collect first: collect",
                bundle: .module,
                comment: """
                    Refusal: too few eggs for a card, when need is other than 1. The placeholders are the eggs \
                    needed, their colour and the eggs in the carton. "collect" is a CLI command.
                    """)
    case .birdDoesNotFitCard:
        return String(
            localized: "market.refusal.birdDoesNotFit", defaultValue: "That bird isn't quite what the card asks for.",
            bundle: .module, comment: "Refusal: the bird does not fit the card.")
    // Rule 8: about age only, never about which sex the bird is.
    case .tooYoungForCard:
        return String(
            localized: "market.refusal.tooYoung",
            defaultValue: "That bird is too young. Wait until its feathers come in.",
            bundle: .module, comment: "Refusal: the bird is too young for the card. Never name its sex.")
    case .keeperCardAlreadyUp:
        return String(
            localized: "market.refusal.keeperCardUp", defaultValue: "Your card is already on the board. One at a time.",
            bundle: .module, comment: "Refusal: the keeper's own card is up already.")
    case .noYoungBirdsForCard:
        return String(
            localized: "market.refusal.noYoungBirds",
            defaultValue: "You need a young purebred of that breed, feathers in and free to go, to pin a card for it.",
            bundle: .module, comment: "Refusal: no young bird of the breed to offer.")
    case .noBuyerYet:
        return String(
            localized: "market.refusal.noBuyerYet", defaultValue: "No buyer has come for your card yet. Type: board",
            bundle: .module, comment: "Refusal: no buyer yet. \"board\" is a CLI command.")
    default: return nil
    }
}

/// The market board page, for the CLI `board`.
public func marketBoardLines(_ s: GameState) -> [String] {
    guard s.isOpen(.marketBoard) else { return [notYetText(.marketBoard, s)] }
    var out = [
        String(
            localized: "market.board.title", defaultValue: "The market board by the bakery:", bundle: .module,
            comment: "CLI board page heading.")
    ]
    let cards = s.marketBoard.cards
    if cards.isEmpty {
        out.append(
            "  "
                + String(
                    localized: "market.board.empty", defaultValue: "No cards up just now. New ones come each week.",
                    bundle: .module, comment: "CLI board page: no cards."))
    }
    for (i, card) in cards.enumerated() {
        let ready =
            s.canFill(card)
            ? "  "
                + String(
                    localized: "market.board.canFill", defaultValue: "✓ you can fill this", bundle: .module,
                    comment: "CLI board page: after a card the keeper can fill.") : ""
        out.append("  \(i + 1). \(marketCardText(card, s))\(ready)")
        if let note = marketCardNote(card.kind) {
            out.append(
                "     "
                    + String(
                        localized: "market.board.quotedNote", defaultValue: "\"\(note)\"", bundle: .module,
                        comment: "CLI board page: the person's line, in quotes. The placeholder is the line."))
        }
        if case .bird = card.want, s.canFill(card) {
            let names = s.birdsFor(card).map(\.name).joined(separator: ", ")
            out.append(
                "     "
                    + String(
                        localized: "market.board.fits", defaultValue: "Fits: \(names)", bundle: .module,
                        comment:
                            "CLI board page: the birds that fit a card. The placeholder is their names, comma-separated."
                    ))
        }
    }
    if let mine = s.marketBoard.keeperCard {
        let name = mine.breed.definition.displayName
        if mine.buyerHere(onDay: s.day) {
            let left = mine.buyerLeavesDay - s.day
            out.append(
                "  "
                    + (left == 1
                        ? String(
                            localized: "market.board.buyerHere.one",
                            defaultValue: "Your card: young \(name)s. A buyer is here for \(left) more day.",
                            bundle: .module,
                            comment: """
                                CLI board page: the keeper's card, when left == 1. The placeholders are the breed's \
                                name (made plural with "s") and the days the buyer stays.
                                """)
                        : String(
                            localized: "market.board.buyerHere.other",
                            defaultValue: "Your card: young \(name)s. A buyer is here for \(left) more days.",
                            bundle: .module,
                            comment: """
                                CLI board page: the keeper's card, when left is other than 1. The placeholders are \
                                the breed's name (made plural with "s") and the days the buyer stays.
                                """)))
            for bird in s.youngBirdsForSale(of: mine.breed) {
                let price = s.rules.marketBuyerPrice(rehomeValue: s.rehomeValue(of: bird))
                out.append(
                    "     "
                        + String(
                            localized: "market.board.forSale",
                            defaultValue: "\(bird.name): \(price) coins (sell \(bird.name))",
                            bundle: .module,
                            comment: """
                                CLI board page: a bird the buyer would take. The placeholders are the bird's name, \
                                the price and the bird's name again. "sell" is a CLI command.
                                """))
            }
        } else {
            out.append(
                "  "
                    + String(
                        localized: "market.board.noBuyer", defaultValue: "Your card: young \(name)s. No buyer yet.",
                        bundle: .module,
                        comment:
                            "CLI board page: the keeper's card. The placeholder is the breed's name (made plural with \"s\")."
                    ))
        }
    }
    out.append(
        String(
            localized: "market.board.help",
            defaultValue:
                "Fill a card: fill <number> [bird name] · Pin your own: post <breed> · Sell to your buyer: sell <name>",
            bundle: .module, comment: "CLI board page: the commands. \"fill\", \"post\" and \"sell\" are CLI commands.")
    )
    return out
}
