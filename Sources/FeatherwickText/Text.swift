import FeatherwickCore
import Foundation

// The words players read. Core returns IDs and enums only; every front end (the CLI now, the app)
// turns them into text here, so all front ends say the same thing.

public func downText(_ d: ChickDown) -> String {
    switch d {
    case .black: "black down"
    case .slate: "slate-grey down"
    case .paleGrey: "pale grey down"
    case .silver: "silvery down"
    case .yellow: "yellow down"
    case .darkWithHeadSpot: "dark down with a white head spot"
    }
}

public func birdLabel(_ b: Bird, _ s: GameState) -> String {
    let stage = b.stage(onDay: s.day, rules: s.rules)
    let p = b.phenotype
    let age = "day \(b.age(onDay: s.day))"
    guard b.revealed else {
        return "\(b.name): chick, \(downText(p.chickDown)), breed ?, sex ?, \(friendlyText(b.friendliness)) (\(age))"
    }
    let kind: String =
        switch (stage, b.sex) {
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

public func friendlyText(_ f: Friendliness) -> String {
    switch f {
    case .wild: "wild"
    case .skittish: "skittish"
    case .friendly: "friendly"
    case .lapChicken: "a lap chicken"
    }
}

public func storyText(_ id: String, step: String?) -> String {
    switch (id, step) {
    case ("broodySilkie", nil):
        return """
            The neighbour leans over the fence, laughing. "My old Silkie has gone broody again. She's sitting on a golf ball! \
            If you could spare 3 eggs you know are fertile, she'd hatch them for you." (Candle your eggs, then: give eggs)
            """
    case ("broodySilkie", "sitting"):
        return "The Silkie settles onto your eggs with a happy grumble. Check back in a few days."
    case ("lacedGift", nil):
        return """
            The Wyandotte keeper two doors down stops to admire your flock over the fence. "You've a proper \
            little henhaven going. Give me a few days — I've a girl who'd be happier with you."
            """
    case ("heritageBreed", nil):
        return """
            A travelling keeper is retiring her heritage Australorp line. "They're grand layers, gentle as \
            anything. Bring me 4 eggs you know are fertile, so I know they'll be in good hands." (candle, then: give eggs)
            """
    case ("heritageBreed", "settling"):
        return "The Australorp hen is settling in. Give her a few days to find her feet."
    default:
        return "Something is happening in Featherwick. Type: story"
    }
}

public func relatedText(_ r: Relatedness) -> String {
    switch r {
    case .unrelated: "not related"
    case .distant: "distantly related"
    case .cousins: "related like cousins"
    case .halfSiblings: "related like half-siblings"
    case .close: "closely related (like siblings, or parent and chick)"
    }
}

public func treeLines(_ id: UUID, _ s: GameState) -> [String] {
    var out: [String] = []
    guard let tree = Pedigree.tree(of: id, generations: 3, in: s) else { return [] }
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
                out.append(branch + "\(label): " + line(node.tree.record))
                walk(node.tree, prefix + (last ? "  " : "│ "))
            } else if let knownID, Pedigree.record(knownID, in: s) != nil {
                out.append(branch + "\(label): further back")
            } else if t.record.motherID != nil || t.record.fatherID != nil {
                out.append(branch + "\(label): unknown")
            }
        }
    }
    out.append(line(tree.record))
    walk(tree, "")
    let f = Pedigree.inbreeding(of: id, in: s)
    out.append("Parents: \(relatedText(Relatedness(kinship: f))) · \(Int((f * 100).rounded()))% inbred")
    let kids = Pedigree.offspring(of: id, in: s)
    if !kids.isEmpty { out.append("Chicks (\(kids.count)): " + kids.map { $0.name }.joined(separator: ", ")) }
    return out
}

/// The name of a county show, from its season's theme.
public func showThemeName(_ theme: ShowTheme) -> String {
    switch theme {
    case .springEggFair: "Spring Egg Fair"
    case .summerFete: "Summer Fete"
    case .harvestShow: "Harvest Show"
    case .winterChampionship: "Winter Championship"
    }
}

/// "pet class", "egg classes", "breed classes".
public func showKindName(_ kind: ShowKind) -> String {
    switch kind {
    case .pet: "pet class"
    case .eggs: "egg classes"
    case .breed: "breed classes"
    }
}

/// What the theme means for the player, in one sentence.
public func showThemeLine(_ theme: ShowTheme) -> String {
    let bonus = "The \(showKindName(theme.featured)) pay extra coins."
    return theme == .winterChampionship ? bonus + " The rivals are the strongest of the year." : bonus
}

/// "12 coins", "3 treats" or "8 coins and 3 treats". Empty when nothing was won.
public func prizeWords(coins: Int, treats: Int) -> String {
    var parts: [String] = []
    if coins > 0 { parts.append("\(coins) coin\(coins == 1 ? "" : "s")") }
    if treats > 0 { parts.append("\(treats) treat\(treats == 1 ? "" : "s")") }
    return parts.joined(separator: " and ")
}

/// A show placing in words: "1st", "4th", "not placed". Only 1st to 3rd win a ribbon.
public func placingText(_ placing: Int) -> String {
    guard placing > 0 else { return "not placed" }
    let suffix =
        switch (placing % 10, placing % 100) {
        case (_, 11...13): "th"
        case (1, _): "st"
        case (2, _): "nd"
        case (3, _): "rd"
        default: "th"
        }
    return "\(placing)\(suffix)"
}

public func birdName(_ id: UUID, _ s: GameState) -> String { s.bird(id)?.name ?? "a bird" }

/// "gold laced", "barred blue", "lavender"...
public func colourText(_ p: Phenotype) -> String {
    featherColourName(p.colour, barred: p.isBarred, laced: p.isLaced)
}

public func noteText(_ n: JudgeNote) -> String {
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
    case .foraged: "well-foraged"
    case .lacksVigour: "lacks vigour (closely bred)"
    case .friendliness(let f): friendlyText(f)
    case .shape(let b): "shape \(b.rawValue)"
    case .shell(let b): "shells \(b.rawValue)"
    case .staleEggs(let n): "\(n) stale"
    }
}

public func cardText(_ c: JudgeCard) -> String {
    let grade =
        switch c.grade {
        case .disqualified: "not judged"
        case .fair: "Fair"
        case .good: "Good"
        case .veryGood: "Very good"
        case .excellent: "Excellent"
        }
    return "  \(c.showClass.name): \(grade) (\(c.score)/100) · " + c.notes.map(noteText).joined(separator: ", ")
}

/// " If no perch is free in 2 nights, …" for a bird waiting for a perch.
func homeDeadline(_ id: UUID, _ s: GameState) -> String {
    guard let nights = s.nightsUntilRehomed(id) else { return "" }
    let when = nights <= 1 ? "by tomorrow" : "in \(nights) nights"
    return " If no perch is free \(when), the neighbour will find \(birdName(id, s)) a new home."
}

public func eventText(_ e: GameEvent, _ s: GameState) -> String? {
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
        case .incubatorBusy: "The incubator has eggs from an earlier day in it. Wait for them to hatch."
        case .incubatorFull(let room):
            room == 0 ? "The incubator is full." : "The incubator has room for \(room) more egg\(room == 1 ? "" : "s")."
        case .noSuchEgg: "That egg is not in your carton."
        case .eggIsClear: "That egg is clear. It will never hatch."
        case .cannotCandleYet:
            "You don't know how to candle eggs yet. Hatch a chick first, and the neighbour will show you."
        case .alreadyCandled: "You have already held that egg up to the light."
        case .notBroody: "She isn't broody. Only a broody hen will sit on eggs."
        case .henAlreadySitting: "She is already sitting on eggs."
        case .clutchTooBig(let max): "That's too many eggs. The most is \(max)."
        case .notEnoughEggsInCarton(let have):
            "You only have \(have) egg\(have == 1 ? "" : "s") in your carton. Collect first: collect"
        case .nothingToCandle: "You have already candled every egg in the carton."
        case .birdsBoarding:
            "You can't set eggs while a bird is staying with the neighbour. Make room first: rehome a bird or upgrade the coop."
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
        case .notShowEligible:
            "That bird can't enter that class. Chicks are too young for the show, only birds at home can be "
                + "entered, and only purebred adults in a standard colour can enter their breed class."
        case .alreadyEntered: "That bird is already entered in the next show."
        case .noMatchedPlate:
            "A plate needs 3 matching eggs from your carton: one colour, all speckled or all plain. Collect first."
        case .noPremiumFeed: "Your premium feed barrel is empty. Buy more: buy feed"
        case .alreadyFedPremium: "You already gave them premium feed today."
        }
    case .starterChosen(let id): return "You take \(birdName(id, s)) home and settle them under the heat lamp."
    case .fed: return "You fill the feeder and top up the water."
    case .eggsCollected(let n, let left):
        return "You collect \(n) egg\(n == 1 ? "" : "s")."
            + (left > 0 ? " \(left) left in the nest: the carton is full." : "")
    case .eggsSold(let n, let coins, let stale):
        return "Speckle & Down buys \(n) egg\(n == 1 ? "" : "s") for \(coins) coin\(coins == 1 ? "" : "s")."
            + (stale > 0 ? " \(stale) sat in the nest too long and sold at half price." : "")
    case .coopClosed: return "You shut the coop door for the night."
    case .quietNight: return "A quiet night."
    case .foxVisited(let ids):
        return "A fox came in the night! It scared away: " + ids.map { birdName($0, s) }.joined(separator: ", ") + "."
    case .dayStarted(let d, let season): return "\n— Day \(d), \(season.rawValue) —"
    case .seasonChanged(let season): return "The season turns: it is \(season.rawValue)."
    case .birdReturned(let id): return "\(birdName(id, s)) has found their way home."
    case .birdWaitingForPerch(let id): return "\(birdName(id, s)) is nearby, but the coop has no free perch."
    case .grewUp: return nil  // shown through reveals and look
    case .revealed(let id, let sex, _):
        let variety = s.bird(id)?.varietyName ?? "young"
        return "\(birdName(id, s)) is growing feathers: a \(variety) \(sex == .hen ? "pullet" : "cockerel")!"
    case .newBreedBookEntry(let entry): return "New Breed Book entry: \(entryText(entry))."
    case .neighbourGaveHen(let id):
        return
            "The neighbour visits: \"He'll want some company.\" She gives you a young hen: \(birdLabel(s.bird(id)!, s))."
    case .movedToCoop(let id): return "\(birdName(id, s)) is big enough to move from the brooder to the coop."
    case .needsHome(let id):
        return
            "\(birdName(id, s)) is ready for the coop, but there is no free perch. \(birdName(id, s)) waits in the brooder. "
            + "Make room: rehome a bird (rehome <name>) or add perches (upgrade coop, \(s.rules.coopUpgradePrice) coins)."
            + homeDeadline(id, s)
    case .boardingWithNeighbour(let id):
        return "\(birdName(id, s)) is staying with the neighbour: no perch, and the brooder is full. "
            + "You can't set eggs until \(birdName(id, s)) has a home. Rehome a bird or upgrade the coop."
            + homeDeadline(id, s)
    case .rehomedByNeighbour(let id, let coins):
        return "No perch came free for \(birdName(id, s)), so the neighbour found \(birdName(id, s)) a good home "
            + "down the lane. They pay you \(coins) coin\(coins == 1 ? "" : "s")."
    case .namedForYou(let id):
        return "Everyone has started calling the new bird \(birdName(id, s)). The name stuck. "
            + "(You can rename a bird any time.)"
    case .cameHomeFromBoarding(let id): return "\(birdName(id, s)) comes home from the neighbour's to a free perch."
    case .rehomed(let id, let coins):
        return
            "\(birdName(id, s)) goes to a new home in Featherwick. They pay you \(coins) coin\(coins == 1 ? "" : "s")."
    case .coopUpgraded(let perches, let cost):
        return "You add perches to the coop for \(cost) coins. It now has \(perches) perches."
    case .boughtBird(let id, _, let cost):
        return
            "Speckle & Down sells you a bird for \(cost) coins: \(s.bird(id).map { birdLabel($0, s) } ?? "a young bird")."
    case .boughtEgg(let cost):
        return
            "Speckle & Down sells you a fertile egg from a local flock for \(cost) coins. It's in your carton, already candled."
    case .tradeOffered:
        guard let offer = s.tradeOffer else { return nil }
        return "A neighbour's daughter is starting a flock and needs a rooster. She offers you a young hen "
            + "for \(birdName(offer.roosterID, s)): \(birdLabel(offer.hen, s)). To agree: accept trade"
    case .tradeAccepted(let rooster, let hen):
        return "\(birdName(rooster, s)) goes to his new flock, and \(birdName(hen, s)) moves into Henhaven."
    case .storyStarted(let id), .storyStep(let id, _):
        let step: String? = if case .storyStep(_, let st) = e { st } else { nil }
        return storyText(id, step: step)
    case .delivered:
        return "You hand the eggs over the fence, carefully."
    case .storyGiftWaitingForRoom:
        return
            "The neighbour has a gift for you, but your coop has no free perch. Make room, and it arrives that night."
    case .storyGift(_, let id):
        return
            "The neighbour comes round with a basket. \"She hatched every one. Here, one of my own girls, to say thank you.\" \(birdName(id, s)) moves into Henhaven."
    case .shopUnlocked(let breed):
        return "Speckle & Down now sells \(breed.definition.displayName) pullets. Type: shop"
    case .storyFinished:
        return nil
    case .boughtBreed(let id, let breed, let cost):
        return "You buy \(birdName(id, s)), a \(breed.definition.displayName) pullet, for \(cost) coins."
    case .boughtTreats(let count, let cost):
        return "You buy a bag of \(count) mealworm treats for \(cost) coins. You have \(s.treats) treats."
    case .handled(let id, let kind):
        let n = birdName(id, s)
        return kind == .pet
            ? "You pick up \(n) and hold \(n) for a while."
            : "\(n) takes a mealworm from your hand. \(s.treats) treats left."
    case .friendlierNow(let id, let f):
        return "\(birdName(id, s)) seems \(f == .lapChicken ? "to love being held now" : "\(friendlyText(f)) now")."
    case .boughtPremiumFeed(let count, let cost):
        return
            "You buy a sack of premium feed (\(count) days) for \(cost) coins. You have \(s.premiumFeed) days in the barrel."
    case .fedPremium(let units):
        return
            "You scatter rich premium feed for \(units) bird\(units == 1 ? "" : "s"). They'll lay a little better today. \(s.premiumFeed) days left."
    case .birdRetired(let id):
        return
            "\(birdName(id, s)) has earned a gentle retirement. She'll keep her perch, but her laying days are behind her."
    case .birdsForaged(let count):
        return "You left the coop open, and \(count == 1 ? "1 bird" : "\(count) birds") free-ranged overnight, "
            + "foraging for grubs and greens. They come back fed, so there's no need to feed today."
    case .noEggsHungry: return "No eggs today. The hens were not fed yesterday."
    case .eggLaid(_, let by): return "\(birdName(by, s)) laid an egg."
    case .eggBroken(let by):
        return "The nest boxes were full, so \(birdName(by, s)) laid on the floor and the egg broke."
    case .newEggBookEntry(let entry):
        return "New egg colour: \(entry.speckled ? "speckled " : "")\(entry.colour.rawValue)!"
    case .wentBroody(let id):
        return "\(birdName(id, s)) has gone broody. She fluffs up on the pile of eggs and won't lay for a while."
    case .broodyEnded(let id): return "\(birdName(id, s)) is done being broody and is back to normal."
    case .incubatorBought(let cost, let size):
        let nights = s.rules.incubatorHatchDays
        return "You buy a bigger incubator for \(cost) coins. It holds \(size) eggs. They hatch in \(nights) nights."
    case .neighbourGaveIncubator(let size):
        return """
            The neighbour leans over the fence. "I see your rooster has been busy. Some of your eggs will be fertile now. \
            Here, take my old incubator. It only fits \(size) egg\(size == 1 ? "" : "s"), but it works. \
            You can't tell which eggs are fertile yet, so try a few. The clear ones just won't hatch."

            How to hatch eggs:
              incubate \(size)      set eggs in the incubator; fertile ones hatch into the brooder in \
            \(s.rules.incubatorHatchDays) nights, clear ones come back to the carton
              sit <hen> <n>   if a hen goes broody, she can sit on up to \(s.rules.maxClutch) eggs; they hatch in \
            \(s.rules.broodyHatchDays) days and she raises the chicks herself
              buy incubator   a bigger incubator holds \(s.rules.bigIncubatorSize) eggs (\(s.rules.incubatorPrice) coins)
            """
    case .candled(let fertile, let clear):
        if fertile == 1 && clear == 0 {
            return "You hold the egg up to the light. You see a shadow and fine veins: it's fertile."
        }
        if fertile == 0 && clear == 1 { return "You hold the egg up to the light. It glows clear: it won't hatch." }
        if fertile == 0 { return "You hold each egg up to the light. All \(clear) are clear: none are fertile." }
        return "You hold each egg up to the light: \(fertile) fertile" + (clear > 0 ? ", \(clear) clear." : ".")
    case .eggsSet(let n, let hen, let hatchDay):
        let who = hen.map { "under \(birdName($0, s))" } ?? "in the incubator"
        let which = s.canCandle ? "They" : "Any fertile ones"
        return "You set \(n) egg\(n == 1 ? "" : "s") \(who). \(which) will hatch on day \(hatchDay)."
    case .chicksHatched(let ids, let hen):
        let where_ = hen.map { "under \(birdName($0, s))" } ?? "in the incubator"
        return "Peeping \(where_)! \(ids.count) chick\(ids.count == 1 ? "" : "s") hatched: "
            + ids.compactMap { s.bird($0) }.map { "\($0.name) (\(downText($0.phenotype.chickDown)))" }.joined(
                separator: ", ")
    case .eggsDidNotHatch(let n, let hen):
        let from = hen.map { "under \(birdName($0, s))" } ?? "in the incubator"
        return "\(n) egg\(n == 1 ? "" : "s") \(from) did not hatch. \(n == 1 ? "It was" : "They were") clear. "
            + "You put \(n == 1 ? "it" : "them") back with your eggs."
    case .learnedCandling:
        return """
            The neighbour comes to see your new chick. "Well done! Here, let me show you a trick." She holds an egg up \
            to a torch. "See the shadow and the little veins? That one's fertile. A clear one just glows." \
            You can candle eggs now.
              candle          hold the carton eggs up to a light to see which are fertile
              sell clear      sell your eggs but keep the fertile ones
            """
    case .renamed(let id): return "Hello, \(birdName(id, s))!"
    case .roostersSquabbling(let extra):
        return "The roosters were squabbling again. The hens are unsettled and laying less. "
            + "There \(extra == 1 ? "is 1 rooster" : "are \(extra) roosters") too many for this many hens (1 rooster per \(s.rules.hensPerRooster) hens, or just 1)."
    case .roosterAdvice:
        return "Tip: one rooster is plenty. Rehome a spare and a neighbour will adopt him for coins "
            + "(rehome <name>; see what he's worth with value <name>) — or wait, and someone may offer a hen in trade."
    case .milestoneReached(let id):
        let reached = Milestones.all.count(where: { s.milestonesReached.contains($0.id) })
        return "★ Milestone: \(milestoneText(id).title)! (\(reached)/\(Milestones.all.count) · see: journal)"
    case .enteredInShow(let id, let cls):
        let who = id.flatMap { s.bird($0)?.name } ?? "your eggs"
        let show = showThemeName(s.nextShowTheme)
        return "\(who) entered in the \(cls.name) class at the \(show) (day \(s.nextShowDay))."
    case .showDay(let day):
        let theme = ShowTheme.forSeason(s.season(onDay: day))
        return "\n🎪 The Featherwick county show, day \(day): the \(showThemeName(theme))! \(showThemeLine(theme))"
    case .showNoEntries:
        return "The show came and went. You didn't enter anything this time — next one is day \(s.nextShowDay)."
    case .showPlacing(let r):
        let medal =
            switch r.placing {
            case 1: " 🏆"
            case 2: " 🥈"
            case 3: " 🥉"
            default: ""
            }
        let ribbon = placingText(r.placing) + medal
        let won = prizeWords(coins: r.prize, treats: r.treats ?? 0)
        return "  \(r.showClass.name): \(r.entrantName) — \(ribbon) of \(r.fieldSize) (\(r.score)/100)"
            + (won.isEmpty ? "" : ", wins \(won)!")
    case .showPrizesWon(let coins):
        return "Prize money: \(coins) coins. 🎉"
    case .showTreatsWon(let treats):
        let won = "\(treats) mealworm treat\(treats == 1 ? "" : "s")"
        return "Prize treats: \(won) for the bag. You have \(s.treats) treats."
    }
}

public func yardLines(_ s: GameState) -> [String] {
    var out: [String] = []
    if case .choosingStarter(let chicks) = s.phase {
        out.append("The neighbour keeps orpingtons, wyandottes and araucanas. She offers you one chick.")
        for (i, c) in chicks.enumerated() { out.append("  \(i + 1). a chick with \(downText(c.phenotype.chickDown))") }
        out.append("Choose one: choose <1-3> <name>")
        return out
    }
    let fedLabel = s.fedPremiumToday ? " · premium-fed today" : (s.fedToday ? " · fed today" : "")
    let feedBarrel = s.premiumFeed > 0 ? " · premium feed \(s.premiumFeed)d" : ""
    out.append(
        "Day \(s.day), \(s.season.rawValue) · \(s.coins) coins · coop door \(s.coopDoorOpen ? "open" : "closed")\(fedLabel)\(feedBarrel)"
    )
    out.append("Brooder (\(s.brooder.count)/\(s.brooderSize)):")
    for b in s.brooder {
        let waiting = b.age(onDay: s.day) >= s.rules.brooderDays
        out.append("  " + birdLabel(b, s) + (waiting ? " · needs a home" : ""))
    }
    out.append("Coop (\(s.coop.count)/\(s.perches) perches, \(s.nestBoxes) nesting boxes):")
    for b in s.coop {
        var line = "  " + birdLabel(b, s)
        if let c = s.clutch(under: b.id) { line += " · sitting on \(c.eggs.count) eggs, hatch day \(c.hatchDay)" }
        let kids = s.henChicks.filter { $0.raisedBy == b.id }
        if !kids.isEmpty { line += " · with \(kids.count) chick\(kids.count == 1 ? "" : "s")" }
        out.append(line)
    }
    if !s.henChicks.isEmpty {
        out.append("Chicks with their mother:")
        s.henChicks.forEach { out.append("  " + birdLabel($0, s)) }
    }
    if s.hasIncubator {
        let c = s.incubatorClutch
        out.append(
            "Incubator (holds \(s.incubatorSize)): "
                + (c.map { "\($0.eggs.count) egg\($0.eggs.count == 1 ? "" : "s"), hatch day \($0.hatchDay)" } ?? "empty")
        )
    }
    if !s.lost.isEmpty { out.append("Lost: " + s.lost.map(\.bird.name).joined(separator: ", ")) }
    if let offer = s.tradeOffer {
        out.append(
            "Trade offer: a young hen (\(birdLabel(offer.hen, s))) for \(birdName(offer.roosterID, s)). Type: accept trade"
        )
    }
    if !s.boarding.isEmpty {
        out.append(
            "Staying with the neighbour (no eggs can be set until they have a home): "
                + s.boarding.map(\.name).joined(separator: ", "))
    }
    let fertile = s.carton.count(where: { $0.isCandled && $0.isFertile })
    let clear = s.carton.count(where: { $0.isCandled && !$0.isFertile })
    let unchecked = s.carton.count - fertile - clear
    var cartonInfo = "carton \(s.carton.count)/\(s.cartonCapacity)"
    if fertile + clear > 0 { cartonInfo += " (\(fertile) fertile, \(clear) clear, \(unchecked) not candled)" }
    out.append("Nest: \(s.nest.count)/\(s.nestCapacity) eggs · \(cartonInfo)")
    return out
}

/// The goal ladder's words (kept in the UI, keyed by milestone id). Title, and a hint while locked.
public func milestoneText(_ id: String) -> (title: String, hint: String) {
    switch id {
    case "firstEgg": ("First egg", "Collect your first egg from the nest.")
    case "firstHatch": ("First hatch", "Hatch a chick from a fertile egg.")
    case "firstFriend": ("A friend", "Win a bird's trust up to 'friendly' with handling and treats.")
    case "growingFlock": ("A proper flock", "Grow your flock to eight birds.")
    case "blueEgg": ("Blue egg", "Keep an Araucana line laying blue eggs.")
    case "oliveEgg": ("Olive egg", "Cross a blue-egg bird with a brown-egg bird for an olive egger.")
    case "speckledEgg": ("Speckled egg", "Breed the speckle gene into a pair to get speckled eggs.")
    case "colourCollector": ("Collector", "Record eight kinds in your Breed Book.")
    case "showRibbon": ("In the ribbons", "Place in the top three at the county show.")
    case "blueRibbon": ("Blue ribbon", "Win a class at the county show.")
    case "lapChicken": ("Lap chicken", "Tame a bird all the way to a lap chicken.")
    case "storyteller": ("Neighbourly", "Finish a Featherwick storyline.")
    case "elderHen": ("Grand old lady", "Keep a hen into her beloved retirement.")
    default: (id, "")
    }
}

public func journalLines(_ s: GameState) -> [String] {
    var out: [String] = []
    let done = Milestones.all.count(where: { s.milestonesReached.contains($0.id) })
    out.append("Keeper's journal — \(done)/\(Milestones.all.count) milestones:")
    for m in Milestones.all {
        let got = s.milestonesReached.contains(m.id)
        let t = milestoneText(m.id)
        out.append("  \(got ? "✓" : "○") \(t.title)" + (got ? "" : " — \(t.hint)"))
    }
    return out
}

public func entryText(_ e: BreedBookEntry) -> String {
    let colour = featherColourName(e.colour, barred: e.barred, laced: e.laced)
    return "\(colour) \(e.variety)" + (e.silkieFeathered && e.variety != "silkie" ? ", silkie-feathered" : "")
}

public func bookLines(_ s: GameState) -> [String] {
    var out: [String] = []
    out.append("Breed Book (\(s.breedBook.count)):")
    let pure = s.breedBook.filter { !$0.isCross }.map(entryText).sorted()
    let crosses = s.breedBook.filter(\.isCross).map(entryText).sorted()
    pure.forEach { out.append("  " + $0) }
    out.append("Crosses (\(crosses.count)):")
    crosses.forEach { out.append("  " + $0) }
    out.append("Egg colours (\(s.eggBook.count)):")
    for e in s.eggBook.sorted(by: { $0.colour.rawValue < $1.colour.rawValue }) {
        out.append("  \(e.speckled ? "speckled " : "")\(e.colour.rawValue)")
    }
    return out
}

public func showsLines(_ s: GameState) -> [String] {
    var out: [String] = []
    let r = s.rules
    let theme = s.nextShowTheme
    let every = "one every \(r.showIntervalDays) days"
    out.append("County show — next: the \(showThemeName(theme)), day \(s.nextShowDay) (\(every)).")
    out.append(showThemeLine(theme))
    out.append("Entry fee \(r.showEntryFee) coins. Ribbons for 1st, 2nd and 3rd at this show:")
    for kind in ShowKind.allCases {
        let sample: ShowClass =
            switch kind {
            case .pet: .pet
            case .eggs: .eggs(.brown)
            case .breed: .breed(.orpington)
            }
        let prizes = (1...3).map { Engine.prize(for: $0, in: sample, theme: theme, rules: r) }
        var line = "  \(showKindName(kind)): " + prizes.map { "\($0.coins)" }.joined(separator: " / ") + " coins"
        if prizes.contains(where: { $0.treats > 0 }) {
            line += " + " + prizes.map { "\($0.treats)" }.joined(separator: " / ") + " treats"
        }
        let rivals = r.showCompetitorsByKind[kind] ?? 0
        out.append(line + " · \(rivals) rival\(rivals == 1 ? "" : "s")")
    }
    if s.showEntries.isEmpty {
        out.append("No entries yet. Enter a bird (enter <name>) or your best plate of eggs (enter eggs).")
    } else {
        out.append("Entered for day \(s.nextShowDay):")
        for e in s.showEntries {
            if let id = e.birdID, let b = s.bird(id) {
                out.append("  \(b.name) — \(Engine.entryClass(e, of: b, in: s).name) class")
            } else if let first = e.eggs.first {
                out.append("  a plate of \(first.speckled ? "speckled " : "")\(first.colour.rawValue) eggs")
            }
        }
    }
    let ribbons = s.firstPlaceRibbons
    out.append("Trophy case: \(ribbons) first-place ribbon\(ribbons == 1 ? "" : "s").")
    let recent = s.showResults.suffix(5)
    if !recent.isEmpty {
        out.append("Recent results:")
        for r in recent {
            let place = r.placing == 0 ? "unplaced" : "\(r.placing)/\(r.fieldSize)"
            let won = prizeWords(coins: r.prize, treats: r.treats ?? 0)
            out.append(
                "  day \(r.day) \(r.showClass.name): \(r.entrantName) \(place) (\(r.score)/100)"
                    + (won.isEmpty ? "" : " · \(won)"))
        }
    }
    return out
}

/// Where each started storyline stands: finished, waiting on the player, or waiting on time.
public func storyLines(_ s: GameState) -> [String] {
    guard !s.stories.isEmpty else { return ["Nothing yet. Keep caring for your flock."] }
    var out: [String] = []
    for story in Storylines.all {
        guard let p = s.stories[story.id] else { continue }
        if p.rewarded {
            out.append("✓ \(story.id): finished")
            continue
        }
        let step = p.step < story.steps.count ? story.steps[p.step] : nil
        switch step?.goal {
        case .deliverFertileEggs(let n)?:
            out.append("• \(story.id): bring \(n) eggs you know are fertile, then: give eggs")
        case .waitDays?: out.append("• \(story.id): wait a few days")
        default: out.append("• \(story.id): a gift is waiting for a free perch")
        }
    }
    return out
}
