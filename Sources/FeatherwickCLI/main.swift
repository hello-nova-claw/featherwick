import FeatherwickCore
import Foundation

// Featherwick text front end.
// Usage: swift run featherwick [seed]     (seed is used only when no save exists)
// The game autosaves to featherwick-save.json in the current folder.

struct SaveFile: Codable {
    var state: GameState
    var rng: SeededRNG
}

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
        return try JSONDecoder().decode(SaveFile.self, from: data)
    } catch {
        // The save format changed. Keep the old file instead of overwriting it.
        let backup = savePath.deletingPathExtension().appendingPathExtension("old.json")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: savePath, to: backup)
        print("Your save is from an older version and cannot be loaded. It was moved to \(backup.lastPathComponent). Starting a new game.")
        return nil
    }
}

func save(_ file: SaveFile) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(file) { try? data.write(to: savePath) }
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
    var parts = ["\(b.breed.rawValue) \(kind)", p.colour.rawValue]
    if p.isBarred { parts.append("barred") }
    if p.isLaced { parts.append("laced") }
    if stage == .adult, let egg = p.eggColour, b.sex == .hen {
        parts.append("lays \(p.eggIsSpeckled ? "speckled " : "")\(egg.rawValue)")
    }
    if b.noLayUntilDay > s.day { parts.append("shaken, not laying yet") }
    if b.isBroody(onDay: s.day) { parts.append("broody") }
    return "\(b.name): " + parts.joined(separator: ", ") + " (\(age))"
}

func name(_ id: UUID, _ s: GameState) -> String { s.bird(id)?.name ?? "a bird" }

/// Finds a bird by name, ignoring case. "chick 3" can be typed as "chick3" too.
func findBird(_ query: String, _ s: GameState) -> Bird? {
    let q = query.lowercased().replacingOccurrences(of: " ", with: "")
    return s.birdsAtHome.first { $0.name.lowercased().replacingOccurrences(of: " ", with: "") == q }
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
        case .notEnoughFeed(let n, let h): "You need \(n) feed but have \(h). Buy feed: buy feed"
        case .noEggsInNest: "The nest boxes are empty."
        case .cartonFull: "Your carton is full. Sell eggs first: sell"
        case .cartonEmpty: "Your carton is empty. Collect eggs first: collect"
        case .notEnoughCoins(let n, let h): "That costs \(n) coins. You have \(h)."
        case .invalidAmount: "Give a number of 1 or more."
        case .coopAlreadyClosed: "The coop is already closed."
        case .noSuchBird: "There is no bird with that name here."
        case .noIncubator: "You don't have an incubator. Buy one: buy incubator (\(s.rules.incubatorPrice) coins)"
        case .alreadyHaveIncubator: "You already have an incubator."
        case .incubatorBusy: "The incubator already has eggs in it."
        case .notBroody: "She isn't broody. Only a broody hen will sit on eggs."
        case .henAlreadySitting: "She is already sitting on eggs."
        case .clutchTooBig(let max): "That's too many eggs. The most is \(max)."
        case .notEnoughEggsInCarton(let have): "You only have \(have) egg\(have == 1 ? "" : "s") in your carton. Collect first: collect"
        case .brooderFull(let room): "The brooder only has room for \(room) more chick\(room == 1 ? "" : "s"). Set fewer eggs."
        }
    case .starterChosen(let id): return "You take \(name(id, s)) home and settle them under the heat lamp."
    case .fed(let units): return "You feed the flock (\(units) feed)."
    case .eggsCollected(let n, let left):
        return "You collect \(n) egg\(n == 1 ? "" : "s")." + (left > 0 ? " \(left) left in the nest: the carton is full." : "")
    case .eggsSold(let n, let coins, let stale):
        return "Speckle & Down buys \(n) egg\(n == 1 ? "" : "s") for \(coins) coin\(coins == 1 ? "" : "s")."
            + (stale > 0 ? " \(stale) sat in the nest too long and sold at half price." : "")
    case .feedBought(let units, let cost): return "You buy \(units) feed for \(cost) coins."
    case .coopClosed: return "You shut the coop door for the night."
    case .quietNight: return "A quiet night."
    case .foxVisited(let ids):
        return "A fox came in the night! It scared away: " + ids.map { name($0, s) }.joined(separator: ", ") + "."
    case .dayStarted(let d, let season): return "\n— Day \(d), \(season.rawValue) —"
    case .seasonChanged(let season): return "The season turns: it is \(season.rawValue)."
    case .birdReturned(let id): return "\(name(id, s)) has found their way home."
    case .birdWaitingForPerch(let id): return "\(name(id, s)) is nearby, but the coop has no free perch."
    case .grewUp: return nil  // shown through reveals and look
    case .revealed(let id, let sex, let breed):
        return "\(name(id, s)) is growing feathers: a \(breed.rawValue) \(sex == .hen ? "pullet" : "cockerel")!"
    case .newBreedBookEntry(let entry): return "New Breed Book entry: \(entry.colour.rawValue) \(entry.breed.rawValue)."
    case .neighbourGaveHen(let id):
        return "The neighbour visits: \"He'll want some company.\" She gives you a young hen: \(label(s.bird(id)!, s))."
    case .movedToCoop(let id): return "\(name(id, s)) is big enough to move from the brooder to the coop."
    case .stuckInBrooder(let id): return "\(name(id, s)) is ready for the coop, but there is no free perch."
    case .noEggsHungry: return "No eggs today. The hens were not fed yesterday."
    case .eggLaid(_, let by): return "\(name(by, s)) laid an egg."
    case .eggBroken(let by): return "The nest boxes were full, so \(name(by, s)) laid on the floor and the egg broke."
    case .newEggBookEntry(let entry):
        return "New egg colour: \(entry.speckled ? "speckled " : "")\(entry.colour.rawValue)!"
    case .wentBroody(let id): return "\(name(id, s)) has gone broody. She fluffs up on the pile of eggs and won't lay for a while."
    case .broodyEnded(let id): return "\(name(id, s)) is done being broody and is back to normal."
    case .incubatorBought(let cost): return "You buy an incubator for \(cost) coins. It hatches eggs overnight."
    case .candled(let fertile, let clear):
        if fertile == 0 { return "You hold each egg up to the light. All \(clear) are clear: none are fertile. They go back in the carton." }
        return "You hold each egg up to the light: \(fertile) fertile" + (clear > 0 ? ", \(clear) clear (back in the carton)." : ".")
    case .eggsSet(let n, let hen, let hatchDay):
        let who = hen.map { "under \(name($0, s))" } ?? "in the incubator"
        return "You set \(n) egg\(n == 1 ? "" : "s") \(who). They will hatch on day \(hatchDay)."
    case .chicksHatched(let ids, let hen):
        let where_ = hen.map { "under \(name($0, s))" } ?? "in the incubator"
        return "Peeping \(where_)! \(ids.count) chick\(ids.count == 1 ? "" : "s") hatched: "
            + ids.compactMap { s.bird($0) }.map { "\($0.name) (\(downText($0.phenotype.chickDown)))" }.joined(separator: ", ")
    case .renamed(let id): return "Renamed to \(name(id, s))."
    }
}

func look(_ s: GameState) {
    if case .choosingStarter(let chicks) = s.phase {
        print("The neighbour keeps orpingtons, wyandottes and araucanas. She offers you one chick.")
        for (i, c) in chicks.enumerated() { print("  \(i + 1). a chick with \(downText(c.phenotype.chickDown))") }
        print("Choose one: choose <1-3> <name>")
        return
    }
    print("Day \(s.day), \(s.season.rawValue) · \(s.coins) coins · feed \(s.feedStock) · coop door \(s.coopDoorOpen ? "open" : "closed")\(s.fedToday ? " · fed today" : "")")
    print("Brooder (\(s.brooder.count)/\(s.brooderSize)):")
    s.brooder.forEach { print("  " + label($0, s)) }
    print("Coop (\(s.coop.count)/\(s.perches) perches, \(s.nestBoxes) nesting boxes):")
    for b in s.coop {
        var line = "  " + label(b, s)
        if let c = s.clutch(under: b.id) { line += " · sitting on \(c.eggs.count) eggs, hatch day \(c.hatchDay)" }
        let kids = s.henChicks.filter { $0.motherID == b.id }
        if !kids.isEmpty { line += " · with \(kids.count) chick\(kids.count == 1 ? "" : "s")" }
        print(line)
    }
    if !s.henChicks.isEmpty {
        print("Chicks with their mother:")
        s.henChicks.forEach { print("  " + label($0, s)) }
    }
    if s.hasIncubator {
        let c = s.incubatorClutch
        print("Incubator: " + (c.map { "\($0.eggs.count) eggs, hatch day \($0.hatchDay)" } ?? "empty"))
    }
    if !s.lost.isEmpty { print("Lost: " + s.lost.map(\.bird.name).joined(separator: ", ")) }
    print("Nest: \(s.nest.count)/\(s.nestCapacity) eggs · carton \(s.carton.count)/\(s.cartonCapacity)")
}

func book(_ s: GameState) {
    print("Breed Book (\(s.breedBook.count)):")
    for e in s.breedBook.sorted(by: { "\($0.breed)\($0.colour)" < "\($1.breed)\($1.colour)" }) {
        print("  \(e.colour.rawValue) \(e.breed.rawValue)\(e.barred ? ", barred" : "")\(e.laced ? ", laced" : "")")
    }
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
  buy feed [bags]      buy feed (\(game.state.rules.feedBagUnits) per bag, \(game.state.rules.feedBagPrice) coins)
  buy incubator        buy an incubator (\(game.state.rules.incubatorPrice) coins)
  incubate <n>         candle n eggs from the carton; fertile ones go in the incubator
  sit <hen> <n>        candle n eggs; fertile ones go under a broody hen
  rename <name> <new>  rename a bird
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
    case "sell": run(.sellEggs)
    case "buy":
        if words.count > 1, words[1] == "feed" {
            run(.buyFeed(bags: words.count > 2 ? Int(words[2]) ?? 0 : 1))
        } else if words.count > 1, words[1] == "incubator" {
            run(.buyIncubator)
        } else {
            print("You can buy: feed, incubator")
        }
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
    case "close": run(.closeCoop)
    case "sleep", "s": run(.passNight)
    case "day":
        let n = max(1, words.count > 1 ? Int(words[1]) ?? 1 : 1)
        for _ in 0..<n {
            if game.state.feedStock < game.state.birdsAtHome.count, game.state.coins >= game.state.rules.feedBagPrice {
                run(.buyFeed(bags: 1))
            }
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
