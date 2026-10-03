import FeatherwickCore
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
let startRules = presetArg.flatMap(Rules.preset(named:)) ?? .standard

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

var game = load(from: store) ?? newSave(seed: seedArg ?? UInt64(Date().timeIntervalSince1970), rules: startRules)

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
        return "\(b.name): chick, \(downText(p.chickDown)), breed ?, sex ?, \(friendlyText(b.friendliness)) (\(age))"
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
    let retired = b.isRetired(onDay: s.day, rules: s.rules)
    if stage == .adult, let egg = p.eggColour, b.sex == .hen, !retired {
        parts.append("lays \(p.eggIsSpeckled ? "speckled " : "")\(egg.rawValue)")
    }
    if retired { parts.append("retired") }
    if b.noLayUntilDay > s.day { parts.append("shaken, not laying yet") }
    if b.isBroody(onDay: s.day) { parts.append("broody") }
    parts.append(friendlyText(b.friendliness))
    return "\(b.name): " + parts.joined(separator: ", ") + " (\(age))"
}

func friendlyText(_ f: Friendliness) -> String {
    switch f {
    case .wild: "wild"
    case .skittish: "skittish"
    case .friendly: "friendly"
    case .lapChicken: "a lap chicken"
    }
}

func storyText(_ id: String, step: String?) -> String {
    switch (id, step) {
    case ("broodySilkie", nil):
        return """
        The neighbour leans over the fence, laughing. "My old Silkie has gone broody again. She's sitting on a golf ball! \
        If you could spare 3 eggs you know are fertile, she'd hatch them for you." (Candle your eggs, then: give eggs)
        """
    case ("broodySilkie", "sitting"):
        return "The Silkie settles onto your eggs with a happy grumble. Check back in a few days."
    default:
        return "Something is happening in Featherwick. Type: story"
    }
}

func relatedText(_ r: Relatedness) -> String {
    switch r {
    case .unrelated: "not related"
    case .distant: "distantly related"
    case .cousins: "related like cousins"
    case .halfSiblings: "related like half-siblings"
    case .close: "closely related (like siblings, or parent and chick)"
    }
}

func printTree(_ id: UUID, _ s: GameState) {
    guard let tree = Pedigree.tree(of: id, generations: 3, in: s) else { return }
    func line(_ r: PedigreeRecord) -> String {
        let from = r.motherID == nil && r.fatherID == nil ? ", from \(r.origin)" : ""
        return "\(r.name.isEmpty ? "unnamed" : r.name) (\(r.kind), hatched day \(r.hatchDay)\(from))"
    }
    func walk(_ t: FamilyTree, _ prefix: String) {
        let parents: [(String, FamilyTree.Indirect?, UUID?)] = [
            ("Mother", t.mother, t.record.motherID), ("Father", t.father, t.record.fatherID),
        ]
        for (i, (label, node, knownID)) in parents.enumerated() {
            let last = i == parents.count - 1
            let branch = prefix + (last ? "└ " : "├ ")
            if let node {
                print(branch + "\(label): " + line(node.tree.record))
                walk(node.tree, prefix + (last ? "  " : "│ "))
            } else if let knownID, Pedigree.record(knownID, in: s) != nil {
                print(branch + "\(label): further back")
            } else if t.record.motherID != nil || t.record.fatherID != nil {
                print(branch + "\(label): unknown")
            }
        }
    }
    print(line(tree.record))
    walk(tree, "")
    let f = Pedigree.inbreeding(of: id, in: s)
    print("Parents: \(relatedText(Relatedness(kinship: f))) · \(Int((f * 100).rounded()))% inbred")
    let kids = Pedigree.offspring(of: id, in: s)
    if !kids.isEmpty { print("Chicks (\(kids.count)): " + kids.map { $0.name }.joined(separator: ", ")) }
}

func name(_ id: UUID, _ s: GameState) -> String { s.bird(id)?.name ?? "a bird" }

/// "gold laced", "barred blue", "lavender"...
func colourText(_ p: Phenotype) -> String {
    featherColourName(p.colour, barred: p.isBarred, laced: p.isLaced)
}

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
    case .lacksVigour: "lacks vigour (closely bred)"
    case .friendliness(let f): friendlyText(f)
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

/// Finds a bird by name, ignoring case. "chick 3" can be typed as "chick3" too.
/// Read-only and renaming commands pass `includeLost` so a bird the fox scared off can still be reached.
func findBird(_ query: String, _ s: GameState, includeLost: Bool = false) -> Bird? {
    let q = query.lowercased().replacingOccurrences(of: " ", with: "")
    let birds = s.birdsAtHome + s.boarding + (includeLost ? s.lost.map(\.bird) : [])
    return birds.first { $0.name.lowercased().replacingOccurrences(of: " ", with: "") == q }
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
        case .birdNotHome: "That bird is not at home right now."
        case .alreadyPettedToday: "You already gave that bird a cuddle today. Try again tomorrow."
        case .alreadyHadTreatToday: "That bird already had a treat today."
        case .noTreats: "Your treat bag is empty. Buy more: buy treats"
        case .nothingToDeliver: "Nobody is waiting for anything from you right now. See: story"
        case .needFertileEggs(let need, let have):
            "You need \(need) eggs you KNOW are fertile in your carton (candle them first). You have \(have)."
        case .nameTaken: "Another bird in your flock already has that name."
        case .nameTooLong(let max): "That name is too long. Use \(max) letters or fewer."
        case .breedNotInShop: "Speckle & Down doesn't sell that breed. Type shop to see what they have."
        case .brooderFull(let room):
            room == 0
                ? "The brooder is full. Make room first: rehome a bird or upgrade the coop so the brooder birds can move out."
                : "The brooder only has room for \(room) more chick\(room == 1 ? "" : "s"). Set fewer eggs."
        case .notShowEligible: "Chicks are too young for the show, and only birds at home can be entered."
        case .alreadyEntered: "That bird is already entered in the next show."
        case .noMatchedPlate: "You need 3 matching eggs in your carton to enter the egg class. Collect and candle first."
        case .noPremiumFeed: "Your premium feed barrel is empty. Buy more: buy feed"
        case .alreadyFedPremium: "You already gave them premium feed today."
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
    case .storyStarted(let id), .storyStep(let id, _):
        let step: String? = if case .storyStep(_, let st) = e { st } else { nil }
        return storyText(id, step: step)
    case .delivered:
        return "You hand the eggs over the fence, carefully."
    case .storyGiftWaitingForRoom:
        return "The neighbour has a gift for you, but your coop has no free perch. Make room, and it arrives that night."
    case .storyGift(_, let id):
        return "The neighbour comes round with a basket. \"She hatched every one. Here, one of my own girls, to say thank you.\" \(name(id, s)) moves into Henhaven."
    case .shopUnlocked(let breed):
        return "Speckle & Down now sells \(breed.definition.displayName) pullets. Type: shop"
    case .storyFinished:
        return nil
    case .boughtBreed(let id, let breed, let cost):
        return "You buy \(name(id, s)), a \(breed.definition.displayName) pullet, for \(cost) coins."
    case .boughtTreats(let count, let cost):
        return "You buy a bag of \(count) mealworm treats for \(cost) coins. You have \(s.treats) treats."
    case .handled(let id, let kind):
        let n = name(id, s)
        return kind == .pet
            ? "You pick up \(n) and hold \(n) for a while."
            : "\(n) takes a mealworm from your hand. \(s.treats) treats left."
    case .friendlierNow(let id, let f):
        return "\(name(id, s)) seems \(f == .lapChicken ? "to love being held now" : "\(friendlyText(f)) now")."
    case .boughtPremiumFeed(let count, let cost):
        return "You buy a sack of premium feed (\(count) days) for \(cost) coins. You have \(s.premiumFeed) days in the barrel."
    case .fedPremium(let units):
        return "You scatter rich premium feed for \(units) bird\(units == 1 ? "" : "s"). They'll lay a little better today. \(s.premiumFeed) days left."
    case .birdRetired(let id):
        return "\(name(id, s)) has earned a gentle retirement. She'll keep her perch, but her laying days are behind her."
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
    case .renamed(let id): return "Hello, \(name(id, s))!"
    case .roostersSquabbling(let extra):
        return "The roosters were squabbling again. The hens are unsettled and laying less. "
            + "There \(extra == 1 ? "is 1 rooster" : "are \(extra) roosters") too many for this many hens (1 rooster per \(s.rules.hensPerRooster) hens, or just 1)."
    case .enteredInShow(let id, let cls):
        let who = id.flatMap { s.bird($0)?.name } ?? "your eggs"
        return "\(who) entered in the \(cls.name) class at the next county show (day \(s.nextShowDay))."
    case .showDay(let day):
        return "\n🎪 The Featherwick county show, day \(day)!"
    case .showNoEntries:
        return "The show came and went. You didn't enter anything this time — next one is day \(s.nextShowDay)."
    case .showPlacing(let r):
        let ribbon = switch r.placing {
        case 1: "1st 🏆"
        case 2: "2nd 🥈"
        case 3: "3rd 🥉"
        case 0: "not placed"
        default: "\(r.placing)th"
        }
        return "  \(r.showClass.name): \(r.entrantName) — \(ribbon) of \(r.fieldSize) (\(r.score)/100)"
            + (r.prize > 0 ? ", wins \(r.prize) coins!" : "")
    case .showPrizesWon(let coins):
        return "Prize money: \(coins) coins. 🎉"
    }
}

func look(_ s: GameState) {
    if case .choosingStarter(let chicks) = s.phase {
        print("The neighbour keeps orpingtons, wyandottes and araucanas. She offers you one chick.")
        for (i, c) in chicks.enumerated() { print("  \(i + 1). a chick with \(downText(c.phenotype.chickDown))") }
        print("Choose one: choose <1-3> <name>")
        return
    }
    let fedLabel = s.fedPremiumToday ? " · premium-fed today" : (s.fedToday ? " · fed today" : "")
    let feedBarrel = s.premiumFeed > 0 ? " · premium feed \(s.premiumFeed)d" : ""
    print("Day \(s.day), \(s.season.rawValue) · \(s.coins) coins · coop door \(s.coopDoorOpen ? "open" : "closed")\(fedLabel)\(feedBarrel)")
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
    let colour = featherColourName(e.colour, barred: e.barred, laced: e.laced)
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

func showsScreen(_ s: GameState) {
    let r = s.rules
    print("County show — next on day \(s.nextShowDay) (one every \(r.showIntervalDays) days).")
    print("Entry fee \(r.showEntryFee) coins. Ribbons: 1st \(r.showPrizeFirst), 2nd \(r.showPrizeSecond), 3rd \(r.showPrizeThird) coins.")
    if s.showEntries.isEmpty {
        print("No entries yet. Enter a bird (enter <name>) or your best plate of eggs (enter eggs).")
    } else {
        print("Entered for day \(s.nextShowDay):")
        for e in s.showEntries {
            if let id = e.birdID, let b = s.bird(id) {
                print("  \(b.name) — \(Engine.showClass(for: b, in: s).name) class")
            } else if let first = e.eggs.first {
                print("  a plate of \(first.speckled ? "speckled " : "")\(first.colour.rawValue) eggs")
            }
        }
    }
    let ribbons = s.firstPlaceRibbons
    print("Trophy case: \(ribbons) first-place ribbon\(ribbons == 1 ? "" : "s").")
    let recent = s.showResults.suffix(5)
    if !recent.isEmpty {
        print("Recent results:")
        for r in recent {
            let place = r.placing == 0 ? "unplaced" : "\(r.placing)/\(r.fieldSize)"
            print("  day \(r.day) \(r.showClass.name): \(r.entrantName) \(place) (\(r.score)/100)" + (r.prize > 0 ? " · \(r.prize) coins" : ""))
        }
    }
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
  candle               hold the carton eggs up to a light to see which are fertile
  buy incubator        buy a \(game.state.rules.bigIncubatorSize)-egg incubator (\(game.state.rules.incubatorPrice) coins)
  incubate <n>         candle n eggs from the carton; fertile ones go in the incubator
  sit <hen> <n>        candle n eggs; fertile ones go under a broody hen
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
  buy pullet|cockerel|egg   buy a young hen, a young rooster, or a fertile egg
  buy treats           a bag of mealworm treats
  buy feed             a sack of premium feed (several days)
  pet <name>           pick a bird up and hold it (once a day; chicks learn trust fastest)
  treat <name>         give a bird a treat from your hand (once a day)
  accept trade         accept a neighbour's offer of a hen for a rooster
  upgrade coop         add \(game.state.rules.perchesPerUpgrade) perches (\(game.state.rules.coopUpgradePrice) coins)
  close                shut the coop door for the night
  sleep                pass the night
  day [n]              do a full day n times: feed, collect, close, sleep
  book                 Breed Book and egg colours
  slot [name]          list your saves, or switch to / create a save slot
  sim [days] [games]   balance report: simulate seeded games and show the numbers
  new yes [difficulty] delete the save and start again (relaxed | standard | challenge)
  quit
"""

@MainActor func run(_ command: Command) {
    var state = game.state, rng = game.rng
    let events = Engine.apply(command, to: &state, using: &rng)
    game = SaveFile(state: state, rng: rng)
    for e in events { if let t = text(e, state) { print(t) } }
}

print("Featherwick · slot: \(store.slot) · save: \(store.url.path)")
print("Type help for commands.\n")
look(game.state)

/// New birds you hatched or bought need a name. Ask now, with a suggestion (Enter takes it).
@MainActor func askForNames() {
    while let bird = game.state.unnamedBirds.first {
        let suggestion = NameBook.suggestion(for: bird, in: game.state)
        let p = bird.phenotype
        let what = bird.revealed
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
        case let other where game.state.shopBreeds.contains(where: { $0.rawValue == other }):
            run(.buyBreed(Breed(rawValue: other)))
        default: print("You can buy: pullet, cockerel, egg, treats, feed, incubator. Basic feed is free.")
        }
    case "shop":
        let r = game.state.rules
        print("""
        Speckle & Down (you have \(game.state.coins) coins):
          pullet      a young hen, breed known        \(r.pulletPrice) coins
          cockerel    a young rooster, breed known    \(r.cockerelPrice) coins
          egg         a fertile egg from a local flock \(r.fertileEggPrice) coins
          incubator   holds \(r.bigIncubatorSize) eggs                   \(r.incubatorPrice) coins
          treats      \(r.treatBagSize) mealworms                        \(r.treatBagPrice) coins
          feed        \(r.premiumFeedBagSize) days of premium feed          \(r.premiumFeedPrice) coins (basic feed is free)
        """)
        for breed in game.state.shopBreeds.sorted(by: { $0.rawValue < $1.rawValue }) {
            print("  \(breed.rawValue.padding(toLength: 11, withPad: " ", startingAt: 0)) a \(breed.definition.displayName) pullet          \(r.rareBreedPulletPrice) coins")
        }
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
        guard let bird = findBird(parts[1], game.state, includeLost: true) else { print("There is no bird called \(parts[1])."); break }
        run(.rename(bird.id, name: parts.dropFirst(2).joined(separator: " ")))
    case "rehome":
        guard words.count > 1, let bird = findBird(words.dropFirst().joined(separator: ""), game.state) else { print("Use: rehome <name>"); break }
        run(.rehome(bird.id))
    case "value":
        guard words.count > 1, let bird = findBird(words.dropFirst().joined(separator: ""), game.state, includeLost: true) else { print("Use: value <name>"); break }
        print("A neighbour would pay \(game.state.rules.rehomeValue(of: bird, onDay: game.state.day)) coins for \(bird.name).")
    case "pet", "cuddle", "treat":
        guard words.count > 1, let bird = findBird(words.dropFirst().joined(separator: ""), game.state) else { print("Use: \(verb) <name>"); break }
        run(verb == "treat" ? .giveTreat(bird.id) : .pet(bird.id))
    case "tree":
        guard words.count > 1, let bird = findBird(words.dropFirst().joined(separator: ""), game.state, includeLost: true) else { print("Use: tree <name>"); break }
        printTree(bird.id, game.state)
    case "kin":
        let parts = line.split(separator: " ").dropFirst().map(String.init)
        guard parts.count == 2, let a = findBird(parts[0], game.state, includeLost: true), let b = findBird(parts[1], game.state, includeLost: true) else {
            print("Use: kin <name> <name> (names without spaces, e.g. chick3)"); break
        }
        let k = Pedigree.kinship(a.id, b.id, in: game.state)
        print("\(a.name) and \(b.name): \(relatedText(Relatedness(kinship: k))). A chick of theirs would be \(Int((k * 100).rounded()))% inbred.")
    case "draw":
        guard words.count > 1, let bird = findBird(words.dropFirst().joined(separator: ""), game.state, includeLost: true) else { print("Use: draw <name>"); break }
        let look = bird.look(onDay: game.state.day, rules: game.state.rules)
        print("\(bird.name): \(look.stage.rawValue), scale \(String(format: "%.2f", look.scale))")
        for placed in look.parts {
            let fills = placed.part.masks.map { "\($0.rawValue) \(placed.fills[$0]?.rawValue ?? "?")" }.joined(separator: ", ")
            let size = placed.scale == 1 ? "" : " ×\(String(format: "%.2f", placed.scale))"
            print("  \(placed.part)\(size): \(fills)")
        }
        for o in look.overlays { print("  + \(o.pattern.rawValue) in \(o.tone.rawValue) on \(o.masks.map(\.rawValue).joined(separator: ", "))") }
    case "art":
        let keys = ArtChecklist.required(includePlanned: words.count > 1 && words[1] == "all")
        print("Parts to paint (\(keys.count)), each greyscale with flat mask layers:")
        for key in keys { print("  \(key): \(key.masks.map(\.rawValue).joined(separator: ", "))") }
    case "story":
        let s = game.state
        if s.stories.isEmpty { print("Nothing yet. Keep caring for your flock."); break }
        for story in Storylines.all {
            guard let p = s.stories[story.id] else { continue }
            if p.rewarded { print("✓ \(story.id): finished"); continue }
            let step = p.step < story.steps.count ? story.steps[p.step] : nil
            switch step?.goal {
            case .deliverFertileEggs(let n)?: print("• \(story.id): bring \(n) eggs you know are fertile, then: give eggs")
            case .waitDays?: print("• \(story.id): wait a few days")
            default: print("• \(story.id): a gift is waiting for a free perch")
            }
        }
    case "give":
        guard let story = Engine.storyAwaitingDelivery(game.state) else { print("Nobody is waiting for anything from you right now."); break }
        run(.deliver(story: story))
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
    case "shows", "show": showsScreen(game.state)
    case "enter":
        guard words.count > 1 else { print("Use: enter <name>, or enter eggs"); break }
        if words[1] == "eggs" { run(.enterEggs); break }
        guard let bird = findBird(words.dropFirst().joined(separator: ""), game.state) else { print("There is no bird called \(words[1])."); break }
        run(.enterShow(bird.id))
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
            let name = words.count > 2 ? words[2] : "standard"
            let rules = Rules.preset(named: name) ?? .standard
            let used = Rules.preset(named: name) != nil ? name : "standard"
            game = newSave(seed: UInt64(Date().timeIntervalSince1970), rules: rules)
            print("A new game begins (\(used)).")
            look(game.state)
        } else {
            print("This deletes your save. Type: new yes [relaxed|standard|challenge]")
        }
    case "slot":
        guard words.count > 1 else {
            let all = SaveStore.slots(in: store.directory)
            print("Current slot: \(store.slot). Saves: \(all.isEmpty ? "none" : all.joined(separator: ", "))")
            print("Switch to or create a slot: slot <name>")
            break
        }
        let name = words[1].filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        guard !name.isEmpty else { print("Use letters, numbers, - or _ for a slot name."); break }
        guard name != store.slot else { print("You're already playing slot \(name)."); break }
        save(game)  // keep the current game safe in its own slot before switching
        store = SaveStore(directory: store.directory, slot: name)
        if let loaded = load(from: store) {
            game = loaded
            print("Switched to slot \(store.slot).")
        } else {
            game = newSave(seed: UInt64(Date().timeIntervalSince1970), rules: startRules)
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
