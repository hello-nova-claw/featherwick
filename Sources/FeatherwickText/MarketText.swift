import FeatherwickCore

// The words for the market board by the bakery (see MarketBoard.swift in Core): each card's ask and the
// person's line, the board's events and refusals, and the CLI `board` page.

/// What a card asks for, in a few words: "3 blue eggs", "a friendly hen".
public func marketWantText(_ want: MarketWant) -> String {
    switch want {
    case .eggs(let colour, let count):
        return "\(count) \(colour.rawValue) egg\(count == 1 ? "" : "s")"
    case .bird(let ask):
        var words: [String] = []
        switch ask.friendliness {
        case .lapChicken: words.append("lap chicken")
        case .friendly: words.append("friendly")
        case .skittish, .wild, nil: break
        }
        if ask.laying {
            words.append("laying hen")
        } else if let sex = ask.sex {
            words.append(sex == .hen ? "hen" : "rooster")
        } else if ask.friendliness != .lapChicken {
            words.append("young bird")
        }
        let phrase = words.joined(separator: " ")
        return "\(article(phrase)) \(phrase)"
    }
}

/// The person's line on a card, by card kind. Every kind in `MarketCards.pool` has a line.
public func marketCardNote(_ kind: String) -> String? {
    switch kind {
    case "okafor-blue": "For the window. Blue sells the brown loaves, somehow."
    case "okafor-brown": "Brown eggs for the Saturday buns."
    case "okafor-cream": "Cream eggs for a custard tart. A big one."
    case "okafor-olive": "Olive eggs! The window needs a bit of green."
    case "okafor-green": "Green eggs for the window. The children love them."
    case "okafor-white": "White eggs for meringues. They must be white."
    case "okafor-chocolate": "Dark eggs for the window. They look like little loaves."
    case "teddy-calmHen": "A calm hen for my cousin Ivy. She's six and very gentle."
    case "bea-youngBird": "A young bird for a new keeper on the hill. Any breed at all."
    case "hazel-rooster": "My hens have no rooster this year. Any boy who's grown his feathers."
    case "wren-layingHen": "A laying hen for a customer whose old girl has retired."
    case "dot-lapChicken": "A lap chicken for the children's corner at the show."
    case "teddy-brown": "Gran's baking a cake for Mum. She needs brown eggs."
    case "dot-blue": "Blue eggs for the show tea. Six, if you can spare them."
    default: nil
    }
}

/// One card, in one line: "Mr Okafor wants 3 blue eggs. 18 coins, until day 40."
public func marketCardText(_ card: MarketCard, _ s: GameState) -> String {
    let until = card.untilDay == s.day ? "until tonight" : "until day \(card.untilDay)"
    return "\(People.name(card.from)) wants \(marketWantText(card.want)). \(card.coins) coins, \(until)."
}

/// What a card asks and until when, for the app's card: "3 blue eggs · until day 40".
public func marketCardLine(_ card: MarketCard, _ s: GameState) -> String {
    let until = card.untilDay == s.day ? "until tonight" : "until day \(card.untilDay)"
    return marketWantText(card.want).capitalizedFirst + " · " + until
}

/// The words for the market board's events.
func marketEventText(_ e: GameEvent, _ s: GameState) -> String? {
    switch e {
    case .marketCardsPinned(let cards):
        let lines = cards.map { "  • " + marketCardText($0, s) }
        return "New cards on the market board by the bakery:\n" + lines.joined(separator: "\n") + "\n(see: board)"
    case .marketCardDown(let card):
        return "\(People.name(card.from))'s card for \(marketWantText(card.want)) has come down. "
            + "Someone else had some. There'll be new cards next week."
    case .marketCardFilled(let card, let coins):
        return "You bring \(People.name(card.from)) \(marketWantText(card.want)). "
            + "\"Just what I hoped for!\" You're paid \(coins) coins."
    case .marketCardPosted(let breed):
        let r = s.rules
        return "You pin a card on the board: \"Young \(breed.definition.displayName)s, from my own flock.\" "
            + "A buyer may come in \(r.marketBuyerMinDays) to \(r.marketBuyerMaxDays) days."
    case .marketBuyerCame(let breed):
        let r = s.rules
        return "Someone saw your card at the bakery. They'd like a young \(breed.definition.displayName), "
            + "and they'll be in the village for \(r.marketBuyerWaitDays) days. (see: board)"
    case .marketBuyerLeft(let breed):
        return "The buyer for a young \(breed.definition.displayName) has gone home. Your card comes down. "
            + "Pin another any time."
    case .soldToBuyer(let id, let coins):
        return
            "\(birdName(id, s)) goes to a new home with the buyer, who pays \(coins) coins. \"We'll take good care.\""
    default:
        return nil
    }
}

/// The words for the market board's refusals.
func marketRejectionText(_ r: Rejection, _ s: GameState) -> String? {
    switch r {
    case .noSuchCard: return "There's no card like that on the board. Type: board"
    case .notEnoughEggsForCard(let colour, let need, let have):
        return "That card needs \(need) \(colour.rawValue) egg\(need == 1 ? "" : "s"). "
            + "Your carton has \(have). Collect first: collect"
    case .birdDoesNotFitCard: return "That bird isn't quite what the card asks for."
    // Rule 8: about age only, never about which sex the bird is.
    case .tooYoungForCard: return "That bird is too young. Wait until its feathers come in."
    case .keeperCardAlreadyUp: return "Your card is already on the board. One at a time."
    case .noYoungBirdsForCard:
        return "You need a young purebred of that breed, feathers in and free to go, to pin a card for it."
    case .noBuyerYet: return "No buyer has come for your card yet. Type: board"
    default: return nil
    }
}

/// The market board page, for the CLI `board`.
public func marketBoardLines(_ s: GameState) -> [String] {
    guard s.isOpen(.marketBoard) else { return [notYetText(.marketBoard, s)] }
    var out = ["The market board by the bakery:"]
    let cards = s.marketBoard.cards
    if cards.isEmpty { out.append("  No cards up just now. New ones come each week.") }
    for (i, card) in cards.enumerated() {
        let ready = s.canFill(card) ? "  ✓ you can fill this" : ""
        out.append("  \(i + 1). \(marketCardText(card, s))\(ready)")
        if let note = marketCardNote(card.kind) { out.append("     \"\(note)\"") }
        if case .bird = card.want, s.canFill(card) {
            out.append("     Fits: " + s.birdsFor(card).map(\.name).joined(separator: ", "))
        }
    }
    if let mine = s.marketBoard.keeperCard {
        let name = mine.breed.definition.displayName
        if mine.buyerHere(onDay: s.day) {
            let left = mine.buyerLeavesDay - s.day
            out.append("  Your card: young \(name)s. A buyer is here for \(left) more day\(left == 1 ? "" : "s").")
            for bird in s.youngBirdsForSale(of: mine.breed) {
                let price = s.rules.marketBuyerPrice(rehomeValue: s.rehomeValue(of: bird))
                out.append("     \(bird.name): \(price) coins (sell \(bird.name))")
            }
        } else {
            out.append("  Your card: young \(name)s. No buyer yet.")
        }
    }
    out.append("Fill a card: fill <number> [bird name] · Pin your own: post <breed> · Sell to your buyer: sell <name>")
    return out
}
