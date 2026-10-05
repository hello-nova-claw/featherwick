import FeatherwickCore
import FeatherwickText
import Foundation

// Featherwick text front end.
// Usage: swift run featherwick [seed] [--slot <name>] [--preset relaxed|standard|challenge]
//   seed   : used only when starting a NEW game (replayable hatches)
//   --slot : which save to play (default "featherwick-save"); switch in-game with `slot <name>`
//   --preset : difficulty for a NEW game only; an existing save keeps its own rules
// Saves are atomic with rolling backups (see SaveStore), so a crash can't wipe your flock.

typealias SaveFile = SaveGame

// MARK: - Launch arguments and save store

let launchArgs = Array(CommandLine.arguments.dropFirst())
func launchFlag(_ name: String) -> String? {
    guard let i = launchArgs.firstIndex(of: name), i + 1 < launchArgs.count else { return nil }
    return launchArgs[i + 1]
}
let slotArg = launchFlag("--slot") ?? SaveStore.defaultSlot
let presetArg = launchFlag("--preset")
let seedArg = launchArgs.first { UInt64($0) != nil }.flatMap { UInt64($0) }
let startRules = presetArg.flatMap(Difficulty.init(named:))?.rules ?? .standard

var store = SaveStore(directory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath), slot: slotArg)

func newSave(seed: UInt64, rules: Rules = .standard) -> SaveFile {
    var rng = SeededRNG(seed: seed)
    let state = Engine.newGame(rules: rules, using: &rng)
    return SaveFile(state: state, rng: rng)
}

func load(from store: SaveStore) -> SaveFile? {
    let data = (try? store.read()) ?? nil
    guard let data else {
        // Main save gone: fall back to the newest backup if there is one.
        if let b = store.newestBackupData(), let save = try? SaveFormat.decode(b) {
            print("Main save was missing; restored from a backup.")
            return save
        }
        return nil
    }
    do {
        // Old saves are migrated here. They are written back in the new format on the next save.
        return try SaveFormat.decode(data)
    } catch SaveFormat.LoadError.tooNew(let version) {
        // Never overwrite a save from a newer game.
        print("This save is from a newer version of Featherwick (save version \(version)). Update the game to load it.")
        exit(1)
    } catch {
        // Not readable: keep it (quarantine, never delete), then try a backup, else start fresh.
        let kept = store.quarantine().map { " (kept as \($0.lastPathComponent))" } ?? ""
        if let b = store.newestBackupData(), let save = try? SaveFormat.decode(b) {
            print("Your save couldn't be read\(kept). Restored from a backup.")
            return save
        }
        print("Your save couldn't be read\(kept). Starting a new game.")
        return nil
    }
}

@MainActor func save(_ file: SaveFile) {
    guard let data = try? SaveFormat.encode(file) else { return }
    try? store.write(data)
}

var game = load(from: store) ?? newSave(seed: seedArg ?? UInt64.random(in: .min ... .max), rules: startRules)

// MARK: - Screens (the words live in FeatherwickText)

func look(_ s: GameState) { yardLines(s).forEach { print($0) } }
func printTree(_ id: UUID, _ s: GameState) { treeLines(id, s).forEach { print($0) } }
func journal(_ s: GameState) { journalLines(s).forEach { print($0) } }
func book(_ s: GameState) { bookLines(s).forEach { print($0) } }
func showsScreen(_ s: GameState) { showsLines(s).forEach { print($0) } }

/// Finds a bird by name, matched the way names are kept unique (`NameBook.key`): case and spaces
/// don't count, so "chick 3" can be typed as "chick3" too.
/// Read-only and renaming commands pass `includeLost` so a bird the fox scared off can still be reached.
func findBird(_ query: String, _ s: GameState, includeLost: Bool = false) -> Bird? {
    let q = NameBook.key(query)
    let birds = s.birdsAtHome + s.boarding + (includeLost ? s.lost.map(\.bird) : [])
    return birds.first { NameBook.key($0.name) == q }
}

let help = """
    Commands:
      look                 see your birds and supplies
      choose <1-3> <name>  pick your starter chick
      feed                 feed everyone for today (basic feed is free)
      feed premium         use premium feed: feeds them and lifts laying (buy feed first)
      collect              move eggs from the nest to your carton
      sell                 sell every egg in your carton
      sell clear           sell every egg except the ones you know are fertile
      candle               hold the carton eggs up to a light to see which are fertile (once you know how)
      buy incubator        buy a \(game.state.rules.bigIncubatorSize)-egg incubator (\(game.state.rules.incubatorPrice) coins)
      incubate <n>         set n eggs from the carton in the incubator (known-fertile first)
      sit <hen> <n>        set n eggs under a broody hen (known-fertile first)
      rename <name> <new>  rename any of your birds, any time
      value <name>         what a neighbour would pay to adopt a bird
      tree <name>          family tree, 3 generations, and how closely bred the bird is
      kin <name> <name>    how closely related two birds are (plan your pairings)
      draw <name>          which art parts and colours make up this bird
      art                  the parts the artist needs to paint
      story                what's happening in Featherwick
      give eggs            hand over the eggs someone asked for
      judge <name>         practice judging: breed class (purebred adults) and pet class
      judge eggs           practice judging: your best plate of 3 matched eggs
      shows                the county show: schedule, your entries, and the trophy case
      enter <name>         enter a bird in the next show (breed class, or pet class)
      enter eggs           enter your best plate of 3 matched eggs
      rehome <name>        a neighbour adopts the bird and pays you (rarer birds pay more)
      shop                 see what Speckle & Down sells
      buy pullet|cockerel|egg   buy a young hen, a young rooster, or a fertile egg (breed: a surprise)
      buy special          buy today's special: a named breed, sex and colour (one a day)
      buy treats           a bag of mealworm treats
      buy feed             a sack of premium feed (several days)
      pet <name>           pick a bird up and hold it (once a day; chicks learn trust fastest)
      treat <name>         give a bird a treat from your hand (once a day)
      accept trade         accept a neighbour's offer of a hen for a rooster
      upgrade coop         add \(game.state.rules.perchesPerUpgrade) perches (\(game.state.rules.coopUpgradePrice) coins)
      close                shut the coop door (safe from the fox, but you must feed)
      sleep                pass the night (door left open? birds forage: fed free + a small bonus, but fox risk)
      day [n]              do a full day n times: feed, collect, close, sleep
      book                 Breed Book and egg colours
      journal              your milestones and what to aim for next
      slot [name]          list your saves, or switch to / create a save slot
      sim [days] [games]   balance report: simulate seeded games and show the numbers
      new yes [difficulty] delete the save and start again (relaxed | standard | challenge)
      quit
    """

@MainActor func run(_ command: Command) {
    var state = game.state
    var rng = game.rng
    let events = Engine.apply(command, to: &state, using: &rng)
    game = SaveFile(state: state, rng: rng)
    for e in events { if let t = eventText(e, state) { print(t) } }
}

print("Featherwick · slot: \(store.slot) · save: \(store.url.path)")
print("Type help for commands.\n")
look(game.state)

/// New birds you hatched or bought need a name. Ask now, with a suggestion (Enter takes it).
@MainActor func askForNames() {
    while let bird = game.state.unnamedBirds.first {
        let suggestion = NameBook.suggestion(for: bird, in: game.state)
        let p = bird.phenotype
        let what =
            bird.revealed
            ? "your new \(bird.varietyName) \(bird.sex == .hen ? "pullet" : "cockerel") (\(colourText(p)))"
            : "your new chick (\(downText(p.chickDown)))"
        print("\nWhat will you call \(what)? [Enter for \(suggestion)] ", terminator: "")
        guard let input = readLine() else { return }
        let typed = input.trimmingCharacters(in: .whitespaces)
        run(.rename(bird.id, name: typed.isEmpty ? suggestion : typed))
    }
}

while true {
    askForNames()
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
    case "feed", "f": run(words.count > 1 && words[1] == "premium" ? .feedPremium : .feed)
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
        case "treats", "treat", "mealworms": run(.buy(.treats))
        case "feed", "premium", "premiumfeed": run(.buy(.premiumFeed))
        case "special": run(.buySpecial)
        case let other where game.state.shopBreeds.contains(where: { $0.rawValue == other }):
            run(.buyBreed(Breed(rawValue: other)))
        default: print("You can buy: pullet, cockerel, egg, special, treats, feed, incubator. Basic feed is free.")
        }
    case "shop":
        let r = game.state.rules
        print(
            """
            Speckle & Down (you have \(game.state.coins) coins):
              pullet      a young hen, breed a surprise   \(r.pulletPrice) coins
              cockerel    a young rooster, breed a surprise \(r.cockerelPrice) coins
              egg         a fertile egg from a local flock \(r.fertileEggPrice) coins
              incubator   holds \(r.bigIncubatorSize) eggs                   \(r.incubatorPrice) coins
              treats      \(r.treatBagSize) mealworms                        \(r.treatBagPrice) coins
              feed        \(r.premiumFeedBagSize) days of premium feed          \(r.premiumFeedPrice) coins (basic feed is free)
            """)
        for breed in game.state.shopBreeds.sorted(by: { $0.rawValue < $1.rawValue }) {
            print(
                "  \(breed.rawValue.padding(toLength: 11, withPad: " ", startingAt: 0)) a \(breed.definition.displayName) pullet          \(r.rareBreedPulletPrice) coins"
            )
        }
        if let special = game.state.todaysSpecial {
            print("  special     today only: \(shopSpecialText(special))")
        } else {
            print("  special     sold today. A new one comes tomorrow.")
        }
    case "accept":
        run(.acceptTrade)
    case "incubate":
        run(.incubate(count: words.count > 1 ? Int(words[1]) ?? 0 : 0))
    case "sit":
        guard words.count > 2, let n = Int(words[2]) else {
            print("Use: sit <hen> <number of eggs>")
            break
        }
        guard let hen = findBird(words[1], game.state) else {
            print("There is no bird called \(words[1]).")
            break
        }
        run(.sit(hen: hen.id, count: n))
    case "rename":
        let parts = line.split(separator: " ").map(String.init)
        guard parts.count > 2 else {
            print("Use: rename <name> <new name>")
            break
        }
        guard let bird = findBird(parts[1], game.state, includeLost: true) else {
            print("There is no bird called \(parts[1]).")
            break
        }
        run(.rename(bird.id, name: parts.dropFirst(2).joined(separator: " ")))
    case "rehome":
        guard words.count > 1, let bird = findBird(words.dropFirst().joined(separator: ""), game.state) else {
            print("Use: rehome <name>")
            break
        }
        run(.rehome(bird.id))
    case "value":
        guard words.count > 1,
            let bird = findBird(words.dropFirst().joined(separator: ""), game.state, includeLost: true)
        else {
            print("Use: value <name>")
            break
        }
        print("A neighbour would pay \(game.state.rehomeValue(of: bird)) coins for \(bird.name).")
    case "pet", "cuddle", "treat":
        guard words.count > 1, let bird = findBird(words.dropFirst().joined(separator: ""), game.state) else {
            print("Use: \(verb) <name>")
            break
        }
        run(verb == "treat" ? .giveTreat(bird.id) : .pet(bird.id))
    case "tree":
        guard words.count > 1,
            let bird = findBird(words.dropFirst().joined(separator: ""), game.state, includeLost: true)
        else {
            print("Use: tree <name>")
            break
        }
        printTree(bird.id, game.state)
    case "kin":
        let parts = line.split(separator: " ").dropFirst().map(String.init)
        guard parts.count == 2, let a = findBird(parts[0], game.state, includeLost: true),
            let b = findBird(parts[1], game.state, includeLost: true)
        else {
            print("Use: kin <name> <name> (names without spaces, e.g. chick3)")
            break
        }
        let k = Pedigree.kinship(a.id, b.id, in: game.state)
        print(
            "\(a.name) and \(b.name): \(relatedText(Relatedness(kinship: k))). A chick of theirs would be \(Int((k * 100).rounded()))% inbred."
        )
    case "draw":
        guard words.count > 1,
            let bird = findBird(words.dropFirst().joined(separator: ""), game.state, includeLost: true)
        else {
            print("Use: draw <name>")
            break
        }
        let look = bird.look(onDay: game.state.day, rules: game.state.rules)
        print("\(bird.name): \(look.stage.rawValue), scale \(String(format: "%.2f", look.scale))")
        for placed in look.parts {
            let fills = placed.part.masks.map { "\($0.rawValue) \(placed.fills[$0]?.rawValue ?? "?")" }.joined(
                separator: ", ")
            let size = placed.scale == 1 ? "" : " ×\(String(format: "%.2f", placed.scale))"
            print("  \(placed.part)\(size): \(fills)")
        }
        for o in look.overlays {
            print(
                "  + \(o.pattern.rawValue) in \(o.tone.rawValue) on \(o.masks.map(\.rawValue).joined(separator: ", "))")
        }
    case "art":
        let keys = ArtChecklist.required(includePlanned: words.count > 1 && words[1] == "all")
        print("Parts to paint (\(keys.count)), each greyscale with flat mask layers:")
        for key in keys { print("  \(key): \(key.masks.map(\.rawValue).joined(separator: ", "))") }
    case "story": storyLines(game.state).forEach { print($0) }
    case "give":
        guard let story = Engine.storyAwaitingDelivery(game.state) else {
            print("Nobody is waiting for anything from you right now.")
            break
        }
        run(.deliver(story: story))
    case "judge":
        guard words.count > 1 else {
            print("Use: judge <name> or judge eggs")
            break
        }
        if words[1] == "eggs" {
            let plates = Judge.bestPlates(from: game.state.carton, state: game.state)
            if plates.isEmpty {
                print("You need 3 matching eggs in your carton for a plate.")
                break
            }
            for plate in plates { print(cardText(plate.card)) }
            break
        }
        guard let bird = findBird(words.dropFirst().joined(separator: ""), game.state) else {
            print("There is no bird called \(words[1]).")
            break
        }
        print("The judge looks over \(bird.name).")
        if bird.isPurebred { print(cardText(Judge.judge(bird, in: .breed(bird.breed), state: game.state))) }
        print(cardText(Judge.judge(bird, in: .pet, state: game.state)))
    case "shows", "show": showsScreen(game.state)
    case "enter":
        guard words.count > 1 else {
            print("Use: enter <name>, or enter eggs")
            break
        }
        if words[1] == "eggs" {
            run(.enterEggs)
            break
        }
        guard let bird = findBird(words.dropFirst().joined(separator: ""), game.state) else {
            print("There is no bird called \(words[1]).")
            break
        }
        run(.enterShow(bird.id))
    case "upgrade":
        guard words.count > 1, words[1] == "coop" else {
            print("You can upgrade: coop")
            break
        }
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
    case "journal", "goals", "j": journal(game.state)
    case "new":
        if words.count > 1, words[1] == "yes" {
            let difficulty = (words.count > 2 ? Difficulty(named: words[2]) : nil) ?? .standard
            game = newSave(seed: UInt64.random(in: .min ... .max), rules: difficulty.rules)
            print("A new game begins (\(difficulty.rawValue)).")
            look(game.state)
        } else {
            print(
                "This deletes your save. Type: new yes [\(Difficulty.allCases.map(\.rawValue).joined(separator: "|"))]")
        }
    case "slot":
        guard words.count > 1 else {
            let all = SaveStore.slots(in: store.directory)
            print("Current slot: \(store.slot). Saves: \(all.isEmpty ? "none" : all.joined(separator: ", "))")
            print("Switch to or create a slot: slot <name>")
            break
        }
        let name = words[1].filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        guard !name.isEmpty else {
            print("Use letters, numbers, - or _ for a slot name.")
            break
        }
        guard name != store.slot else {
            print("You're already playing slot \(name).")
            break
        }
        save(game)  // keep the current game safe in its own slot before switching
        store = SaveStore(directory: store.directory, slot: name)
        if let loaded = load(from: store) {
            game = loaded
            print("Switched to slot \(store.slot).")
        } else {
            game = newSave(seed: UInt64.random(in: .min ... .max), rules: startRules)
            print("New slot \(store.slot): a new game begins.")
        }
        look(game.state)
    case "sim":
        let days = (words.count > 1 ? Int(words[1]) : nil) ?? 120
        let games = (words.count > 2 ? Int(words[2]) : nil) ?? 20
        print(Simulation.textReport(days: max(1, days), games: max(1, games), rules: game.state.rules))
    case "quit", "q", "exit":
        save(game)
        exit(0)
    default:
        print("Unknown command \"\(verb)\". Type help.")
    }
    save(game)
}
save(game)
