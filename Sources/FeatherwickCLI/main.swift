import FeatherwickCore
import Foundation

// Featherwick text front end.
// Usage: swift run featherwick [seed]     (seed is used only when no save exists)
// The game autosaves to featherwick-save.json in the current folder.

typealias SaveFile = SaveGame

let savePath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("featherwick-save.json")

func newSave(seed: UInt64) -> SaveFile {
    var rng = SeededRNG(seed: seed)
    let state = Engine.newGame(using: &rng)
    return SaveFile(state: state, rng: rng)
}

func load() -> SaveFile? {
    guard let data = try? Data(contentsOf: savePath) else { return nil }
    do {
        // Old saves are migrated here. They are written back in the new format on the next save.
        return try SaveFormat.decode(data)
    } catch SaveFormat.LoadError.tooNew(let version) {
        // Never overwrite a save from a newer game.
        print("This save is from a newer version of Featherwick (save version \(version)). Update the game to load it.")
        exit(1)
    } catch {
        // Not readable. Keep the old file instead of overwriting it.
        let backup = savePath.deletingPathExtension().appendingPathExtension("old.json")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: savePath, to: backup)
        print("Your save cannot be read. It was moved to \(backup.lastPathComponent). Starting a new game.")
        return nil
    }
}

func save(_ file: SaveFile) {
    if let data = try? SaveFormat.encode(file) { try? data.write(to: savePath) }
}

let seedArg = CommandLine.arguments.dropFirst().first.flatMap { UInt64($0) }
var game = load() ?? newSave(seed: seedArg ?? UInt64(Date().timeIntervalSince1970))

// MARK: - Text

func downText(_ d: ChickDown) -> String {
    switch d {
    case .black: "black down"
    case .slate: "slate-grey down"
    case .paleGrey: "pale grey down"
    case .silver: "silvery down"
    case .yellow: "yellow down"
    case .darkWithHeadSpot: "dark down with a white head spot"
    }
}

func label(_ b: Bird, _ s: GameState) -> String {
    let stage = b.stage(onDay: s.day, rules: s.rules)
    let p = b.phenotype
    let age = "day \(b.age(onDay: s.day))"
    guard b.revealed else {
        return "\(b.name): chick, \(downText(p.chickDown)), breed ?, sex ? (\(age))"
    }
    let kind: String = switch (stage, b.sex) {
    case (.chick, .hen): "hen chick"
    case (.chick, .rooster): "rooster chick"
    case (.grower, .hen): "pullet"
    case (.grower, .rooster): "cockerel"
    case (.adult, .hen): "hen"
    case (.adult, .rooster): "rooster"
    }
    var parts = ["\(b.varietyName) \(kind)", colourText(p)]
    if stage == .adult, let egg = p.eggColour, b.sex == .hen {
        parts.append("lays \(p.eggIsSpeckled ? "speckled " : "")\(egg.rawValue)")
    }
    if b.noLayUntilDay > s.day { parts.append("shaken, not laying yet") }
    if b.isBroody(onDay: s.day) { parts.append("broody") }
    return "\(b.name): " + parts.joined(separator: ", ") + " (\(age))"
}

func name(_ id: UUID, _ s: GameState) -> String { s.bird(id)?.name ?? "a bird" }

/// "gold laced", "barred blue", "lavender"...
func colourText(_ p: Phenotype) -> String {
    if p.isLaced { return "gold laced" }
    return (p.isBarred ? "barred " : "") + p.colour.rawValue
}

/// Finds a bird by name, ignoring case. "chick 3" can be typed as "chick3" too.
func noteText(_ n: JudgeNote) -> String {
    switch n {
    case .tooYoung: "too young to show"
    case .notPurebred: "a cross: crosses can enter the pet class"
    case .wrongBreedClass: "wrong class for this bird"
    case .notAStandardColour(let c): "\(c) is not a standard colour for this breed"
    case .wrongFeathering: "wrong feathering for the breed"
    case .notMatched: "the eggs do not match"
    case .plateNeeds(let n): "a plate needs \(n) eggs"
    case .standardColour(let c): "\(c), a standard colour"
    case .type(let b): "type \(b.rawValue)"
    case .moulting: "moulting"
    case .stressed: "still nervous after a fright"
    case .broody: "broody and out of condition"
    case .hungry: "not fed today"
    case .inFineCondition: "in fine condition"
    case .shape(let b): "shape \(b.rawValue)"
    case .shell(let b): "shells \(b.rawValue)"
    case .staleEggs(let n): "\(n) stale"
    }
}

func cardText(_ c: JudgeCard) -> String {
    let grade = switch c.grade {
    case .disqualified: "not judged"
    case .fair: "Fair"
    case .good: "Good"
    case .veryGood: "Very good"
    case .excellent: "Excellent"
    }
    return "  \(c.showClass.name): \(grade) (\(c.score)/100) · " + c.notes.map(noteText).joined(separator: ", ")
}

func findBird(_ query: String, _ s: GameState) -> Bird? {
    let q = query.lowercased().replacingOccurrences(of: " ", with: "")
    return (s.birdsAtHome + s.boarding).first { $0.name.lowercased().replacingOccurrences(of: " ", with: "") == q }
}

func text(_ e: GameEvent, _ s: GameState) -> String? {
    switch e {
    case .rejected(let r):
        return switch r {
        case .chooseStarterFirst: "Choose a chick first: choose <1-3> <name>"
        case .alreadyStarted: "You already have your chick."
        case .noSuchChick: "There is no chick with that number. Pick 1, 2 or 3."
        case .alreadyFed: "You already fed them today."
        case .nothingToFeed: "There are no birds to feed."
        case .noEggsInNest: "The nest boxes are empty."
        case .cartonFull: "Your carton is full. Sell eggs first: sell"
        case .cartonEmpty: "Your carton is empty. Collect eggs first: collect"
        case .notEnoughCoins(let n, let h): "That costs \(n) coins. You have \(h)."
        case .invalidAmount: "Give a number of 1 or more."
        case .coopAlreadyClosed: "The coop is already closed."
        case .noSuchBird: "There is no bird with that name here."
        case .noIncubator: "You don't have an incubator yet."
        case .alreadyHaveIncubator: "You already have the big incubator."
        case .incubatorBusy: "The incubator already has eggs in it."
        case .notBroody: "She isn't broody. Only a broody hen will sit on eggs."
        case .henAlreadySitting: "She is already sitting on eggs."
        case .clutchTooBig(let max): "That's too many eggs. The most is \(max)."
        case .notEnoughEggsInCarton(let have): "You only have \(have) egg\(have == 1 ? "" : "s") in your carton. Collect first: collect"
        case .nothingToCandle: "You have already candled every egg in the carton."
        case .birdsBoarding: "You can't set eggs while a bird is staying with the neighbour. Make room first: rehome a bird or upgrade the coop."
        case .birdIsBusy: "She is sitting on eggs or caring for chicks. She can't go to a new home right now."
        case .coopAtMax: "The coop can't hold any more perches."
        case .lastBird: "That's your only bird. Keep at least one, or Henhaven would be empty."
        case .noFreePerch: "There's no free perch for a new bird. Rehome a bird or upgrade the coop first."
        case .noTradeOffer: "Nobody is offering a trade right now."
        case .brooderFull(let room):
            room == 0
                ? "The brooder is full. Make room first: rehome a bird or upgrade the coop so the brooder birds can move out."
                : "The brooder only has room for \(room) more chick\(room == 1 ? "" : "s"). Set fewer eggs."
        }
    case .starterChosen(let id): return "You take \(name(id, s)) home and settle them under the heat lamp."
    case .fed: return "You fill the feeder and top up the water."
    case .eggsCollected(let n, let left):
        return "You collect \(n) egg\(n == 1 ? "" : "s")." + (left > 0 ? " \(left) left in the nest: the carton is full." : "")
    case .eggsSold(let n, let coins, let stale):
        return "Speckle & Down buys \(n) egg\(n == 1 ? "" : "s") for \(coins) coin\(coins == 1 ? "" : "s")."
            + (stale > 0 ? " \(stale) sat in the nest too long and sold at half price." : "")
    case .coopClosed: return "You shut the coop door for the night."
    case .quietNight: return "A quiet night."
    case .foxVisited(let ids):
        return "A fox came in the night! It scared away: " + ids.map { name($0, s) }.joined(separator: ", ") + "."
    case .dayStarted(let d, let season): return "\n— Day \(d), \(season.rawValue) —"
    case .seasonChanged(let season): return "The season turns: it is \(season.rawValue)."
    case .birdReturned(let id): return "\(name(id, s)) has found their way home."
    case .birdWaitingForPerch(let id): return "\(name(id, s)) is nearby, but the coop has no free perch."
    case .grewUp: return nil  // shown through reveals and look
    case .revealed(let id, let sex, _):
        let variety = s.bird(id)?.varietyName ?? "young"
        return "\(name(id, s)) is growing feathers: a \(variety) \(sex == .hen ? "pullet" : "cockerel")!"
    case .newBreedBookEntry(let entry): return "New Breed Book entry: \(entryText(entry))."
    case .neighbourGaveHen(let id):
        return "The neighbour visits: \"He'll want some company.\" She gives you a young hen: \(label(s.bird(id)!, s))."
    case .movedToCoop(let id): return "\(name(id, s)) is big enough to move from the brooder to the coop."
    case .needsHome(let id):
        return "\(name(id, s)) is ready for the coop, but there is no free perch. \(name(id, s)) waits in the brooder. "
            + "Make room: rehome a bird (rehome <name>) or add perches (upgrade coop, \(s.rules.coopUpgradePrice) coins)."
    case .boardingWithNeighbour(let id):
        return "\(name(id, s)) is staying with the neighbour: no perch, and the brooder is full. "
            + "You can't set eggs until \(name(id, s)) has a home. Rehome a bird or upgrade the coop."
    case .cameHomeFromBoarding(let id): return "\(name(id, s)) comes home from the neighbour's to a free perch."
    case .rehomed(let id, let coins):
        return "\(name(id, s)) goes to a new home in Featherwick. They pay you \(coins) coin\(coins == 1 ? "" : "s")."
    case .coopUpgraded(let perches, let cost): return "You add perches to the coop for \(cost) coins. It now has \(perches) perches."
    case .boughtBird(let id, _, let cost):
        return "Speckle & Down sells you a bird for \(cost) coins: \(s.bird(id).map { label($0, s) } ?? "a young bird")."
    case .boughtEgg(let cost):
        return "Speckle & Down sells you a fertile egg from a local flock for \(cost) coins. It's in your carton, already candled."
    case .tradeOffered:
        guard let offer = s.tradeOffer else { return nil }
        return "A neighbour's daughter is starting a flock and needs a rooster. She offers you a young hen "
            + "for \(name(offer.roosterID, s)): \(label(offer.hen, s)). To agree: accept trade"
    case .tradeAccepted(let rooster, let hen):
        return "\(name(rooster, s)) goes to his new flock, and \(name(hen, s)) moves into Henhaven."
    case .noEggsHungry: return "No eggs today. The hens were not fed yesterday."
    case .eggLaid(_, let by): return "\(name(by, s)) laid an egg."
    case .eggBroken(let by): return "The nest boxes were full, so \(name(by, s)) laid on the floor and the egg broke."
    case .newEggBookEntry(let entry):
        return "New egg colour: \(entry.speckled ? "speckled " : "")\(entry.colour.rawValue)!"
    case .wentBroody(let id): return "\(name(id, s)) has gone broody. She fluffs up on the pile of eggs and won't lay for a while."
    case .broodyEnded(let id): return "\(name(id, s)) is done being broody and is back to normal."
    case .incubatorBought(let cost, let size):
        return "You buy a bigger incubator for \(cost) coins. It holds \(size) eggs and hatches them overnight."
    case .neighbourGaveIncubator(let size):
        return """
        The neighbour leans over the fence. "I see your rooster has been busy. Some of your eggs will be fertile now. \
        Here, take my old incubator. It only fits \(size) egg\(size == 1 ? "" : "s"), but it works."

        How to hatch eggs:
          candle          hold the carton eggs up to a light to see which are fertile
          sell clear      sell your eggs but keep the fertile ones
          incubate \(size)      put a fertile egg in the incubator; it hatches overnight into the brooder
          sit <hen> <n>   if a hen goes broody, she can sit on up to \(s.rules.maxClutch) eggs; they hatch in \
        \(s.rules.broodyHatchDays) days and she raises the chicks herself
          buy incubator   a bigger incubator holds \(s.rules.bigIncubatorSize) eggs (\(s.rules.incubatorPrice) coins)
        """
    case .candled(let fertile, let clear):
        if fertile == 0 { return "You hold each egg up to the light. All \(clear) are clear: none are fertile." }
        return "You hold each egg up to the light: \(fertile) fertile" + (clear > 0 ? ", \(clear) clear." : ".")
    case .eggsSet(let n, let hen, let hatchDay):
        let who = hen.map { "under \(name($0, s))" } ?? "in the incubator"
        return "You set \(n) egg\(n == 1 ? "" : "s") \(who). They will hatch on day \(hatchDay)."
    case .chicksHatched(let ids, let hen):
        let where_ = hen.map { "under \(name($0, s))" } ?? "in the incubator"
        return "Peeping \(where_)! \(ids.count) chick\(ids.count == 1 ? "" : "s") hatched: "
            + ids.compactMap { s.bird($0) }.map { "\($0.name) (\(downText($0.phenotype.chickDown)))" }.joined(separator: ", ")
    case .renamed(let id): return "Renamed to \(name(id, s))."
    case .roostersSquabbling(let extra):
        return "The roosters were squabbling again. The hens are unsettled and laying less. "
            + "There \(extra == 1 ? "is 1 rooster" : "are \(extra) roosters") too many for this many hens (1 rooster per \(s.rules.hensPerRooster) hens, or just 1)."
    }
}

func look(_ s: GameState) {
    if case .choosingStarter(let chicks) = s.phase {
        print("The neighbour keeps orpingtons, wyandottes and araucanas. She offers you one chick.")
        for (i, c) in chicks.enumerated() { print("  \(i + 1). a chick with \(downText(c.phenotype.chickDown))") }
        print("Choose one: choose <1-3> <name>")
        return
    }
    print("Day \(s.day), \(s.season.rawValue) · \(s.coins) coins · coop door \(s.coopDoorOpen ? "open" : "closed")\(s.fedToday ? " · fed today" : "")")
    print("Brooder (\(s.brooder.count)/\(s.brooderSize)):")
    for b in s.brooder {
        let waiting = b.age(onDay: s.day) >= s.rules.brooderDays
        print("  " + label(b, s) + (waiting ? " · needs a home" : ""))
    }
    print("Coop (\(s.coop.count)/\(s.perches) perches, \(s.nestBoxes) nesting boxes):")
    for b in s.coop {
        var line = "  " + label(b, s)
        if let c = s.clutch(under: b.id) { line += " · sitting on \(c.eggs.count) eggs, hatch day \(c.hatchDay)" }
        let kids = s.henChicks.filter { $0.raisedBy == b.id }
        if !kids.isEmpty { line += " · with \(kids.count) chick\(kids.count == 1 ? "" : "s")" }
        print(line)
    }
    if !s.henChicks.isEmpty {
        print("Chicks with their mother:")
        s.henChicks.forEach { print("  " + label($0, s)) }
    }
    if s.hasIncubator {
        let c = s.incubatorClutch
        print("Incubator (holds \(s.incubatorSize)): " + (c.map { "\($0.eggs.count) egg\($0.eggs.count == 1 ? "" : "s"), hatch day \($0.hatchDay)" } ?? "empty"))
    }
    if !s.lost.isEmpty { print("Lost: " + s.lost.map(\.bird.name).joined(separator: ", ")) }
    if let offer = s.tradeOffer {
        print("Trade offer: a young hen (\(label(offer.hen, s))) for \(name(offer.roosterID, s)). Type: accept trade")
    }
    if !s.boarding.isEmpty {
        print("Staying with the neighbour (no eggs can be set until they have a home): " + s.boarding.map(\.name).joined(separator: ", "))
    }
    let fertile = s.carton.filter { $0.isCandled && $0.isFertile }.count
    let clear = s.carton.filter { $0.isCandled && !$0.isFertile }.count
    let unchecked = s.carton.count - fertile - clear
    var cartonInfo = "carton \(s.carton.count)/\(s.cartonCapacity)"
    if fertile + clear > 0 { cartonInfo += " (\(fertile) fertile, \(clear) clear, \(unchecked) not candled)" }
    print("Nest: \(s.nest.count)/\(s.nestCapacity) eggs · \(cartonInfo)")
}

func entryText(_ e: BreedBookEntry) -> String {
    let colour = e.laced ? "gold laced" : (e.barred ? "barred " : "") + e.colour.rawValue
    return "\(colour) \(e.variety)" + (e.silkieFeathered && e.variety != "silkie" ? ", silkie-feathered" : "")
}

func book(_ s: GameState) {
    print("Breed Book (\(s.breedBook.count)):")
    let pure = s.breedBook.filter { !$0.isCross }.map(entryText).sorted()
    let crosses = s.breedBook.filter(\.isCross).map(entryText).sorted()
    pure.forEach { print("  " + $0) }
    print("Crosses (\(crosses.count)):")
    crosses.forEach { print("  " + $0) }
    print("Egg colours (\(s.eggBook.count)):")
    for e in s.eggBook.sorted(by: { $0.colour.rawValue < $1.colour.rawValue }) {
        print("  \(e.speckled ? "speckled " : "")\(e.colour.rawValue)")
    }
}

let help = """
Commands:
  look                 see your birds and supplies
  choose <1-3> <name>  pick your starter chick
  feed                 feed everyone for today
  collect              move eggs from the nest to your carton
  sell                 sell every egg in your carton
  sell clear           sell every egg except the ones you know are fertile
  candle               hold the carton eggs up to a light to see which are fertile
  buy incubator        buy a \(game.state.rules.bigIncubatorSize)-egg incubator (\(game.state.rules.incubatorPrice) coins)
  incubate <n>         candle n eggs from the carton; fertile ones go in the incubator
  sit <hen> <n>        candle n eggs; fertile ones go under a broody hen
  rename <name> <new>  rename a bird
  value <name>         what a neighbour would pay to adopt a bird
  judge <name>         practice judging: breed class (purebred adults) and pet class
  judge eggs           practice judging: your best plate of 3 matched eggs
  rehome <name>        a neighbour adopts the bird and pays you (rarer birds pay more)
  shop                 see what Speckle & Down sells
  buy pullet|cockerel|egg   buy a young hen, a young rooster, or a fertile egg
  accept trade         accept a neighbour's offer of a hen for a rooster
  upgrade coop         add \(game.state.rules.perchesPerUpgrade) perches (\(game.state.rules.coopUpgradePrice) coins)
  close                shut the coop door for the night
  sleep                pass the night
  day [n]              do a full day n times: feed, collect, close, sleep
  book                 Breed Book and egg colours
  new yes              delete the save and start again
  quit
"""

@MainActor func run(_ command: Command) {
    var state = game.state, rng = game.rng
    let events = Engine.apply(command, to: &state, using: &rng)
    game = SaveFile(state: state, rng: rng)
    for e in events { if let t = text(e, state) { print(t) } }
}

print("Featherwick · save: \(savePath.path)")
print("Type help for commands.\n")
look(game.state)

while true {
    print("\n> ", terminator: "")
    guard let line = readLine() else { break }
    let words = line.lowercased().split(separator: " ").map(String.init)
    guard let verb = words.first else { continue }
    switch verb {
    case "help", "?": print(help)
    case "look", "l": look(game.state)
    case "choose":
        let index = (words.count > 1 ? Int(words[1]) : nil) ?? 0
        let original = line.split(separator: " ").dropFirst(2).joined(separator: " ")
        run(.chooseStarter(index: index - 1, name: original))
    case "feed", "f": run(.feed)
    case "collect", "c": run(.collectEggs)
    case "sell": run(words.count > 1 && words[1] == "clear" ? .sellClearEggs : .sellEggs)
    case "candle": run(.candle)
    case "buy":
        let item = words.count > 1 ? words[1] : ""
        switch item {
        case "incubator": run(.buyIncubator)
        case "pullet", "hen": run(.buy(.pullet))
        case "cockerel", "rooster": run(.buy(.cockerel))
        case "egg", "fertile": run(.buy(.fertileEgg))
        default: print("You can buy: pullet, cockerel, egg, incubator. Basic feed is free.")
        }
    case "shop":
        let r = game.state.rules
        print("""
        Speckle & Down (you have \(game.state.coins) coins):
          pullet      a young hen, breed known        \(r.pulletPrice) coins
          cockerel    a young rooster, breed known    \(r.cockerelPrice) coins
          egg         a fertile egg from a local flock \(r.fertileEggPrice) coins
          incubator   holds \(r.bigIncubatorSize) eggs                   \(r.incubatorPrice) coins
        """)
    case "accept":
        run(.acceptTrade)
    case "incubate":
        run(.incubate(count: words.count > 1 ? Int(words[1]) ?? 0 : 0))
    case "sit":
        guard words.count > 2, let n = Int(words[2]) else { print("Use: sit <hen> <number of eggs>"); break }
        guard let hen = findBird(words[1], game.state) else { print("There is no bird called \(words[1])."); break }
        run(.sit(hen: hen.id, count: n))
    case "rename":
        let parts = line.split(separator: " ").map(String.init)
        guard parts.count > 2 else { print("Use: rename <name> <new name>"); break }
        guard let bird = findBird(parts[1], game.state) else { print("There is no bird called \(parts[1])."); break }
        run(.rename(bird.id, name: parts.dropFirst(2).joined(separator: " ")))
    case "rehome":
        guard words.count > 1, let bird = findBird(words.dropFirst().joined(separator: ""), game.state) else { print("Use: rehome <name>"); break }
        run(.rehome(bird.id))
    case "value":
        guard words.count > 1, let bird = findBird(words.dropFirst().joined(separator: ""), game.state) else { print("Use: value <name>"); break }
        print("A neighbour would pay \(game.state.rules.rehomeValue(of: bird, onDay: game.state.day)) coins for \(bird.name).")
    case "judge":
        guard words.count > 1 else { print("Use: judge <name> or judge eggs"); break }
        if words[1] == "eggs" {
            let plates = Judge.bestPlates(from: game.state.carton, state: game.state)
            if plates.isEmpty { print("You need 3 matching eggs in your carton for a plate."); break }
            for plate in plates { print(cardText(plate.card)) }
            break
        }
        guard let bird = findBird(words.dropFirst().joined(separator: ""), game.state) else { print("There is no bird called \(words[1])."); break }
        print("The judge looks over \(bird.name).")
        if bird.isPurebred { print(cardText(Judge.judge(bird, in: .breed(bird.breed), state: game.state))) }
        print(cardText(Judge.judge(bird, in: .pet, state: game.state)))
    case "upgrade":
        guard words.count > 1, words[1] == "coop" else { print("You can upgrade: coop"); break }
        run(.upgradeCoop)
    case "close": run(.closeCoop)
    case "sleep", "s": run(.passNight)
    case "day":
        let n = max(1, words.count > 1 ? Int(words[1]) ?? 1 : 1)
        for _ in 0..<n {
            run(.feed)
            if !game.state.nest.isEmpty { run(.collectEggs) }
            if game.state.carton.count >= game.state.cartonCapacity { run(.sellEggs) }
            run(.closeCoop)
            run(.passNight)
        }
    case "book", "b": book(game.state)
    case "new":
        if words.count > 1, words[1] == "yes" {
            game = newSave(seed: UInt64(Date().timeIntervalSince1970))
            print("A new game begins.")
            look(game.state)
        } else {
            print("This deletes your save. Type: new yes")
        }
    case "quit", "q", "exit":
        save(game)
        exit(0)
    default:
        print("Unknown command \"\(verb)\". Type help.")
    }
    save(game)
}
save(game)
