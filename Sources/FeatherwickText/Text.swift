import FeatherwickCore
import Foundation

// The words players read. Core returns IDs and enums only; every front end (the CLI and the app)
// turns them into text here, so all front ends say the same thing.

public func downText(_ d: ChickDown) -> String {
    switch d {
    case .black:
        String(localized: "bird.down.black", defaultValue: "black down", bundle: .module, comment: "A chick's down.")
    case .slate:
        String(
            localized: "bird.down.slate", defaultValue: "slate-grey down", bundle: .module, comment: "A chick's down.")
    case .paleGrey:
        String(
            localized: "bird.down.paleGrey", defaultValue: "pale grey down", bundle: .module, comment: "A chick's down."
        )
    case .silver:
        String(localized: "bird.down.silver", defaultValue: "silvery down", bundle: .module, comment: "A chick's down.")
    case .yellow:
        String(localized: "bird.down.yellow", defaultValue: "yellow down", bundle: .module, comment: "A chick's down.")
    case .darkWithHeadSpot:
        String(
            localized: "bird.down.darkWithHeadSpot", defaultValue: "dark down with a white head spot", bundle: .module,
            comment: "A chick's down.")
    }
}

public func birdLabel(_ b: Bird, _ s: GameState) -> String {
    let stage = b.stage(onDay: s.day, rules: s.rules)
    let p = b.phenotype
    let age = b.age(onDay: s.day)
    guard b.revealed else {
        let down = downText(p.chickDown)
        let friendly = friendlyText(b.friendliness)
        return String(
            localized: "bird.labelHidden",
            defaultValue: "\(b.name): chick, \(down), breed ?, sex ?, \(friendly) (day \(age))", bundle: .module,
            comment:
                "A chick whose breed and sex do not show yet. Placeholders: the name, its down, how friendly it is, its age in days."
        )
    }
    let variety = b.varietyName
    let kind: String =
        switch (stage, b.sex) {
        case (.chick, .hen):
            String(
                localized: "bird.kind.henChick", defaultValue: "\(variety) hen chick", bundle: .module,
                comment: "A bird's label. The placeholder is its breed and colour variety.")
        case (.chick, .rooster):
            String(
                localized: "bird.kind.roosterChick", defaultValue: "\(variety) rooster chick", bundle: .module,
                comment: "A bird's label. The placeholder is its breed and colour variety.")
        case (.grower, .hen):
            String(
                localized: "bird.kind.pullet", defaultValue: "\(variety) pullet", bundle: .module,
                comment: "A bird's label. The placeholder is its breed and colour variety.")
        case (.grower, .rooster):
            String(
                localized: "bird.kind.cockerel", defaultValue: "\(variety) cockerel", bundle: .module,
                comment: "A bird's label. The placeholder is its breed and colour variety.")
        case (.adult, .hen):
            String(
                localized: "bird.kind.hen", defaultValue: "\(variety) hen", bundle: .module,
                comment: "A bird's label. The placeholder is its breed and colour variety.")
        case (.adult, .rooster):
            String(
                localized: "bird.kind.rooster", defaultValue: "\(variety) rooster", bundle: .module,
                comment: "A bird's label. The placeholder is its breed and colour variety.")
        }
    var parts = [kind, colourText(p)]
    let retired = b.isRetired(onDay: s.day, rules: s.rules)
    if stage == .adult, let egg = p.eggColour, b.sex == .hen, !retired {
        let colour = egg.rawValue
        parts.append(
            p.eggIsSpeckled
                ? String(
                    localized: "bird.laysSpeckled", defaultValue: "lays speckled \(colour)", bundle: .module,
                    comment: "A bird's label. The placeholder is the egg colour, such as brown.")
                : String(
                    localized: "bird.lays", defaultValue: "lays \(colour)", bundle: .module,
                    comment: "A bird's label. The placeholder is the egg colour, such as brown."))
    }
    if retired {
        parts.append(
            String(
                localized: "bird.retired", defaultValue: "retired", bundle: .module,
                comment: "A bird's label: the hen no longer lays."))
    }
    if b.noLayUntilDay > s.day {
        parts.append(
            String(
                localized: "bird.shaken", defaultValue: "shaken, not laying yet", bundle: .module,
                comment: "A bird's label: a fright stopped her laying for a while."))
    }
    if b.isBroody(onDay: s.day) {
        parts.append(
            String(localized: "bird.broody", defaultValue: "broody", bundle: .module, comment: "A bird's label."))
    }
    parts.append(friendlyText(b.friendliness))
    let attributes = parts.joined(
        separator: String(
            localized: "bird.labelSeparator", defaultValue: ", ", bundle: .module,
            comment: "Between the parts of a bird's label: breed, colour, eggs, friendliness."))
    return String(
        localized: "bird.label", defaultValue: "\(b.name): \(attributes) (day \(age))", bundle: .module,
        comment: "A bird's label. Placeholders: the name, a list of what it is (breed, colour, eggs), its age in days.")
}

public func friendlyText(_ f: Friendliness) -> String {
    switch f {
    case .wild:
        String(
            localized: "bird.friendliness.wild", defaultValue: "wild", bundle: .module, comment: "How tame a bird is.")
    case .skittish:
        String(
            localized: "bird.friendliness.skittish", defaultValue: "skittish", bundle: .module,
            comment: "How tame a bird is.")
    case .friendly:
        String(
            localized: "bird.friendliness.friendly", defaultValue: "friendly", bundle: .module,
            comment: "How tame a bird is.")
    case .lapChicken:
        String(
            localized: "bird.friendliness.lapChicken", defaultValue: "a lap chicken", bundle: .module,
            comment: "How tame a bird is: the tamest.")
    }
}

/// A small, gentle note when a cuddle or a treat made a bird a little tamer: "Juniper liked that".
/// A move up a band has its own words (`.friendlierNow` in `eventText`).
public func handledToastText(_ id: UUID, _ kind: Handling, _ s: GameState) -> String {
    guard let name = s.bird(id)?.name else {
        return kind == .pet
            ? String(
                localized: "bird.toast.unknownPetted", defaultValue: "The bird liked that", bundle: .module,
                comment: "A short note after a cuddle, when the bird is gone.")
            : String(
                localized: "bird.toast.unknownTreated", defaultValue: "The bird enjoyed the mealworm", bundle: .module,
                comment: "A short note after a treat, when the bird is gone.")
    }
    return kind == .pet
        ? String(
            localized: "bird.toast.petted", defaultValue: "\(name) liked that", bundle: .module,
            comment: "A short note after a cuddle made a bird tamer. The placeholder is the bird's name.")
        : String(
            localized: "bird.toast.treated", defaultValue: "\(name) enjoyed the mealworm", bundle: .module,
            comment: "A short note after a treat made a bird tamer. The placeholder is the bird's name.")
}

public func storyText(_ id: String, step: String?) -> String {
    switch (id, step) {
    case ("broodySilkie", nil):
        return String(
            localized: "story.broodySilkie.start",
            defaultValue: """
                Hazel leans over the fence, laughing. "My old Silkie has gone broody again. She's sitting on a golf ball! \
                My mother hatched her whole lavender line under Silkies, you know. \
                If you could spare 3 eggs you know are fertile, she'd hatch them for you." (Candle your eggs, then: give eggs)
                """, bundle: .module,
            comment: "Hazel's broody Silkie story. \"give eggs\" is the CLI command the player types.")
    case ("broodySilkie", "sitting"):
        return String(
            localized: "story.broodySilkie.sitting",
            defaultValue: "The Silkie settles onto your eggs with a happy grumble. Check back in a few days.",
            bundle: .module)
    case ("lacedGift", nil):
        return String(
            localized: "story.lacedGift.start",
            defaultValue: """
                The Wyandotte keeper two doors down stops to admire your flock over the fence. "You've a proper \
                little henhaven going. Give me a few days — I've a girl who'd be happier with you." \
                Hazel smiles. "That's how my mother's lavender line began: one hen, handed over a fence."
                """, bundle: .module)
    case ("heritageBreed", nil):
        return String(
            localized: "story.heritageBreed.start",
            defaultValue: """
                A travelling keeper is retiring her heritage Australorp line. "They're grand layers, gentle as \
                anything. Bring me 4 eggs you know are fertile, so I know they'll be in good hands." \
                Hazel nods. "My mother found homes for her lavender birds the same way, when she retired." \
                (candle, then: give eggs)
                """, bundle: .module,
            comment: "The heritage Australorp story. \"give eggs\" is the CLI command the player types.")
    case ("heritageBreed", "settling"):
        return String(
            localized: "story.heritageBreed.settling",
            defaultValue: "The Australorp hen is settling in. Give her a few days to find her feet.", bundle: .module)
    case ("marigold", nil):
        return String(
            localized: "story.marigold.start",
            defaultValue: """
                Hazel leans over the fence. "I'm off to my sister's soon, for a few days. Could Marigold stay \
                with you while I'm gone? She's your chick's mother, and a good layer. She brings her own box."
                """, bundle: .module)
    case ("marigold", "staying"):
        return String(
            localized: "story.marigold.staying",
            defaultValue: """
                Hazel lifts Marigold over the fence, box and all. "Her eggs are yours. Shut the door at night. \
                I'll be back before you know it!"
                """, bundle: .module)
    case ("marigold", "decide"):
        return String(
            localized: "story.marigold.decide",
            defaultValue: """
                Hazel is home, and at the fence first thing. "Has Marigold been good? She can come home with me, \
                and I'll give you an egg from my flock to hatch. Or keep her, if you like. Pay me when you can."
                """, bundle: .module)
    default:
        return peopleStoryText(id, step: step)
            ?? String(
                localized: "story.unknown", defaultValue: "Something is happening in Featherwick. Type: story",
                bundle: .module, comment: "A story with no words of its own. \"story\" is the CLI command.")
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

/// One line of the family tree, with the bird's carrier notes in a few words when it has any.
public struct TreeLine: Hashable, Sendable {
    public let text: String
    /// "carries lavender", or nil. Always nil before the keeper knows the planner.
    public let carries: String?
}

/// The family tree as text lines: carrier notes after a " · ". For the CLI.
public func treeLines(_ id: UUID, _ s: GameState) -> [String] {
    treeEntries(id, s).map { line in line.text + (line.carries.map { " · \($0)" } ?? "") }
}

/// The family tree, three generations, each bird with its carrier notes. The app shows the notes under each bird.
public func treeEntries(_ id: UUID, _ s: GameState) -> [TreeLine] {
    var out: [TreeLine] = []
    guard let tree = Pedigree.tree(of: id, generations: 3, in: s) else { return [] }
    // Carrier notes (`Planner.carrierNotes`), worked out once for the whole tree. None before the planner is known.
    let knowledge = s.plannerKnown ? Knowledge.of(s) : nil
    func text(_ r: PedigreeRecord) -> String {
        let from = r.motherID == nil && r.fatherID == nil ? ", from \(r.origin)" : ""
        return "\(r.name.isEmpty ? "unnamed" : r.name) (\(r.kind), hatched day \(r.hatchDay)\(from))"
    }
    func carries(_ r: PedigreeRecord) -> String? { carrierShortText(knowledge?.provenHidden(r.id) ?? []) }
    func walk(_ t: FamilyTree, _ prefix: String) {
        let parents: [(String, FamilyTree.Indirect?, UUID?)] = [
            ("Mother", t.mother, t.record.motherID), ("Father", t.father, t.record.fatherID),
        ]
        for (i, (label, node, knownID)) in parents.enumerated() {
            let last = i == parents.count - 1
            let branch = prefix + (last ? "└ " : "├ ")
            if let node {
                let r = node.tree.record
                out.append(TreeLine(text: branch + "\(label): " + text(r), carries: carries(r)))
                walk(node.tree, prefix + (last ? "  " : "│ "))
            } else if let knownID, Pedigree.record(knownID, in: s) != nil {
                out.append(TreeLine(text: branch + "\(label): further back", carries: nil))
            } else if t.record.motherID != nil || t.record.fatherID != nil {
                out.append(TreeLine(text: branch + "\(label): unknown", carries: nil))
            }
        }
    }
    out.append(TreeLine(text: text(tree.record), carries: carries(tree.record)))
    walk(tree, "")
    // How related the parents are, in words. No percentage: playtesters found the number a worry.
    let related = relatedText(Relatedness(kinship: Pedigree.inbreeding(of: id, in: s)))
    out.append(TreeLine(text: "Parents: \(related)", carries: nil))
    let kids = Pedigree.offspring(of: id, in: s)
    if !kids.isEmpty {
        out.append(
            TreeLine(text: "Chicks (\(kids.count)): " + kids.map { $0.name }.joined(separator: ", "), carries: nil))
    }
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

/// What the theme means for the player: the bonus, and anything special about the season.
public func showThemeLine(_ theme: ShowTheme) -> String {
    let bonus = "The \(showKindName(theme.featured)) \(theme.featured == .pet ? "pays" : "pay") extra coins."
    return showSeasonNote(theme).map { "\(bonus) \($0)" } ?? bonus
}

/// What the season does to the show, or nil when nothing. Told before the show, never only after.
public func showSeasonNote(_ theme: ShowTheme) -> String? {
    switch theme {
    case .winterChampionship: "The rivals are the strongest of the year."
    case .springEggFair, .summerFete, .harvestShow: nil
    }
}

/// What the judge looks at in a kind of class, with the points for each part (`ShowPoints`).
public func judgingText(_ kind: ShowKind) -> String {
    let parts: [(String, Int)] =
        switch kind {
        case .breed:
            [
                ("type (size, shape and carriage)", ShowPoints.breedType),
                ("a standard colour and feathering", ShowPoints.breedColour),
                ("condition", ShowPoints.breedCondition),
            ]
        case .pet: [("condition", ShowPoints.petCondition), ("friendliness", ShowPoints.petFriendliness)]
        case .eggs:
            [
                ("a matched plate", ShowPoints.eggMatch), ("shape", ShowPoints.eggShape),
                ("shells", ShowPoints.eggShell), ("freshness", ShowPoints.eggFreshness),
            ]
        }
    return "Judged on " + parts.map { "\($0.0) \($0.1)" }.joined(separator: " · ")
}

/// A condition worry for show day (`Judge.forecast`), with what the keeper can do about it.
public func forecastText(_ n: JudgeNote) -> String {
    switch n {
    case .stressed: "still nervous after a fright"
    case .broody: "broody: a broody hen loses condition"
    case .hungry: "hungry unless you feed the flock today"
    case .lacksVigour: "closely bred, so lacks a little vigour"
    default: noteText(n)
    }
}

/// How a bird should look on the next show day: "In fine condition for day 84." or
/// "On day 84: broody: …; still nervous after a fright".
public func showReadinessText(_ bird: Bird, _ s: GameState) -> String {
    let worries = Judge.forecast(for: bird, in: s)
    if worries.isEmpty { return "In fine condition for day \(s.nextShowDay)." }
    return "On day \(s.nextShowDay): " + worries.map(forecastText).joined(separator: "; ") + "."
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

// MARK: - The show podium

/// Village keepers who show at the county show. A rival's owner number (`Engine.showOwnerSlots`) picks
/// one. Changing this list renames the owners of past podiums; nothing else depends on it.
public let showKeeperNames: [String] = [
    "Mrs Pennywhistle", "Mr Hollyoak", "Miss Thistlewood", "Old Tom Furrow", "Mrs Bramble", "Mr Ashdown",
    "Auntie Clover", "the Misses Wren", "Mr Pippin", "Mrs Goodacre", "Farmer Lark", "Mrs Honeysett",
    "Mr Mossop", "Granny Fennel", "Mr Quince", "Mrs Dimity",
]

/// The owner of each podium place, in order: nil for the keeper's own entries. Two rivals on one
/// podium never share a name: a name already used steps on to the next one in the list.
public func podiumOwnerNames(_ podium: [PodiumPlace]) -> [String?] {
    let count = showKeeperNames.count
    var used: Set<Int> = []
    return podium.map { place in
        guard let owner = rivalOwner(place.entrant) else { return nil }
        var i = ((owner % count) + count) % count
        while used.contains(i), used.count < count { i = (i + 1) % count }
        used.insert(i)
        return showKeeperNames[i]
    }
}

func rivalOwner(_ entrant: PodiumEntrant) -> Int? {
    switch entrant {
    case .keeper: nil
    case .rivalBird(let owner, _): owner
    case .rivalPlate(let owner, _, _): owner
    }
}

/// A show bird as a spectator sees it: "buff Orpington hen", "black Silkie cock". Show birds are
/// adults, so breed, colour and sex are plain to see.
public func showBirdText(_ bird: Bird) -> String {
    "\(colourText(bird.phenotype)) \(bird.breed.definition.displayName) \(bird.sex == .hen ? "hen" : "cock")"
}

/// Who stood in a podium place: "Mrs Pennywhistle's buff Orpington hen", "your Champion",
/// "Mr Hollyoak's plate of brown eggs", "your plate of brown eggs".
public func podiumWhoText(_ place: PodiumPlace, owner: String?, in cls: ShowClass) -> String {
    switch place.entrant {
    case .keeper(let name, let birdID):
        if birdID == nil, case .eggs(let colour) = cls { return "your plate of \(colour.rawValue) eggs" }
        return "your \(name)"
    case .rivalBird(_, let bird):
        return "\(owner ?? "a visitor")'s \(showBirdText(bird))"
    case .rivalPlate(_, let colour, let speckled):
        return "\(owner ?? "a visitor")'s plate of \(speckled ? "speckled " : "")\(colour.rawValue) eggs"
    }
}

/// Why the judge placed it there: its notes in one line, with the same words as the keeper's own.
public func podiumWhyText(_ place: PodiumPlace) -> String {
    place.notes.map(noteText).joined(separator: "; ")
}

/// The podium in lines: "1st: Mrs Pennywhistle's buff Orpington hen, 88 of 100 — buff, a standard colour; …".
public func podiumLines(_ cls: ShowClass, _ podium: [PodiumPlace]) -> [String] {
    let owners = podiumOwnerNames(podium)
    return zip(podium, owners).map { place, owner in
        let who = podiumWhoText(place, owner: owner, in: cls)
        return "\(placingText(place.placing)): \(who), \(place.score) of 100 — \(podiumWhyText(place))"
    }
}

/// Where a seen Breed Book entry came from: "Seen at the Summer Fete".
public func seenText(_ seen: SeenBreedBookEntry) -> String {
    "Seen at the \(showThemeName(seen.theme))"
}

/// One line for Speckle & Down's daily special: "Splash Silkie pullet — rare! 50 coins".
/// The seller names breed, sex and colour, so nothing here is hidden.
public func shopSpecialText(_ special: ShopSpecial) -> String {
    let variety = ShopSpecial.variety(for: special.colour, on: special.breed)
    let colour = colourText(Phenotype(special.breed.purebred(special.sex, variety: variety)))
    let kind = special.sex == .hen ? "pullet" : "cockerel"
    let name = "\(colour) \(special.breed.definition.displayName) \(kind)"
    let rare = special.isRare ? " — rare!" : ""
    return name.prefix(1).uppercased() + String(name.dropFirst()) + "\(rare) \(special.price) coins"
}

/// The neighbour's one-sentence "why" for a chick that looks like neither parent. It names only
/// colours the chick or its parents show, and never the chick's sex (it may not show yet).
public func hatchReasonText(_ r: HatchReason) -> String {
    switch r {
    case .recessiveFromBothParents(let locus):
        let look =
            switch locus {
            case Lavender.locus: "lavender"
            case BaseColour.locus: "buff"
            default: "that colour"
            }
        return "Both parents must carry \(look) out of sight, and this one got a copy from each!"
    case .blueSplitsThreeWays:
        return "Blue never breeds true: two blues hatch black, blue and splash, and black with splash hatches all blue!"
    case .whiteHidIt:
        return "White hides every other colour, so a white bird can pass on a colour it never shows!"
    }
}

/// A bird's name. A bird that left the keeper's care (a loan gone home) keeps its family-tree name.
public func birdName(_ id: UUID, _ s: GameState) -> String { s.bird(id)?.name ?? s.pedigree[id]?.name ?? "a bird" }

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
    case .feathering(let silkie): silkie ? "true silkie feathering, soft as down" : "smooth, tight feathering"
    case .type(let b): "type \(b.rawValue): \(typeWords(b))"
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

/// What a type band looks like in the hand. Type is body size, shape and carriage.
func typeWords(_ b: JudgeNote.Band) -> String {
    switch b {
    case .poor: "small, and not the breed's shape"
    case .fair: "a little small or narrow for the breed"
    case .good: "a good size and shape"
    case .excellent: "a fine size and shape, carried proudly"
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
    return " If no perch is free \(when), Hazel will find \(birdName(id, s)) a new home."
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
            "You don't know how to candle eggs yet. Hatch a chick first, and Hazel will show you."
        case .alreadyCandled: "You have already held that egg up to the light."
        case .notBroody: "She isn't broody. Only a broody hen will sit on eggs."
        case .henAlreadySitting: "She is already sitting on eggs."
        case .clutchTooBig(let max): "That's too many eggs. The most is \(max)."
        case .notEnoughEggsInCarton(let have):
            "You only have \(have) egg\(have == 1 ? "" : "s") in your carton. Collect first: collect"
        case .nothingToCandle: "You have already candled every egg in the carton."
        case .birdsBoarding:
            "You can't set eggs while a bird is staying with Hazel. Make room first: rehome a bird or upgrade the coop."
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
            "You need \(need) eggs you KNOW are fertile in your carton. You have \(have). "
                + "Candle your eggs to find them (candle), or buy fertile eggs at Speckle & Down: they come candled."
        case .nameTaken: "Another bird in your flock already has that name."
        case .nameTooLong(let max): "That name is too long. Use \(max) letters or fewer."
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
        case .specialSoldOut: "Today's special is sold. Speckle & Down has a new one tomorrow."
        case .notYet(let f): notYetText(f, s)
        case .penFull(let hens): "The breeding pen holds \(hens) hens. Take one out first: unpen <name>"
        case .penHasRooster: "The breeding pen already has a rooster. Take him out first: unpen <name>"
        case .notInPen: "That bird is not in the breeding pen."
        case .alreadyInPen: "That bird is already in the breeding pen."
        case .notInCoop: "Only birds with a perch in the coop can go in the breeding pen."
        // Rule 8: says nothing about which sex the bird will be.
        case .tooYoungForPen: "That bird is too young for the breeding pen. Wait until its feathers come in."
        case .noTimeLeft(let errand): noTimeLeftText(errand)
        case .notEveningYet(let left):
            "The sun's still up. There's time for \(left) more thing\(left == 1 ? "" : "s")."
        case .timeForBed: "The light's gone. Time for bed: sleep"
        case .blankName: "A name needs at least one letter."
        // Rule 8: about age only, never about which sex the bird is.
        case .tooLateToGuess: "Too late for a guess: that bird's feathers are in."
        case .alreadyGuessed: "You've made your guess for that chick. Wait and see."
        case .noSuchChoice: "Nobody is waiting on that choice. Type: people"
        case .noSuchDebt: "You don't owe anything by that name. Type: people"
        case .onLoan: "That bird is on loan, so that's for the owner to decide."
        case .needEggs, .needEggsOfNewColour: peopleEventText(e, s) ?? ""
        case .hatchAlong(let why): hatchAlongRefusalText(why)
        case .noSuchCard, .notEnoughEggsForCard, .birdDoesNotFitCard, .tooYoungForCard, .keeperCardAlreadyUp,
            .noYoungBirdsForCard, .noBuyerYet:
            marketRejectionText(r, s) ?? ""
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
        // While Marigold stays, Hazel is at her sister's: the hen comes from there, with a note.
        if s.hazelAway {
            return "A young hen arrives from Hazel's sister's, with a note: \"He'll want some company.\" "
                + "She is yours: \(birdLabel(s.bird(id)!, s))."
        }
        return
            "Hazel visits: \"He'll want some company.\" She gives you a young hen: \(birdLabel(s.bird(id)!, s))."
    case .movedToCoop(let id): return "\(birdName(id, s)) is big enough to move from the brooder to the coop."
    case .needsHome(let id):
        return
            "\(birdName(id, s)) is ready for the coop, but there is no free perch. \(birdName(id, s)) waits in the brooder. "
            + "Make room: rehome a bird (rehome <name>) or add perches (upgrade coop, \(s.rules.coopUpgradePrice) coins)."
            + homeDeadline(id, s)
    case .boardingWithNeighbour(let id):
        return "\(birdName(id, s)) is staying with Hazel: no perch, and the brooder is full. "
            + "You can't set eggs until \(birdName(id, s)) has a home. Rehome a bird or upgrade the coop."
            + homeDeadline(id, s)
    case .rehomedByNeighbour(let id, let coins):
        return "No perch came free for \(birdName(id, s)), so Hazel found \(birdName(id, s)) a good home "
            + "down the lane. They pay you \(coins) coin\(coins == 1 ? "" : "s")."
    case .namedForYou(let id):
        return "Everyone has started calling the new bird \(birdName(id, s)). The name stuck. "
            + "(You can rename a bird any time.)"
    case .cameHomeFromBoarding(let id): return "\(birdName(id, s)) comes home from Hazel's to a free perch."
    case .rehomed(let id, let coins):
        return
            "\(birdName(id, s)) goes to a new home in Featherwick. They pay you \(coins) coin\(coins == 1 ? "" : "s")."
    case .coopUpgraded(let perches, let cost):
        return "You add perches to the coop for \(cost) coins. It now has \(perches) perches."
    case .boughtBird(let id, _, let cost):
        return "You pay \(cost) coins and open the box to see who you got: "
            + "\(s.bird(id).map { birdLabel($0, s) } ?? "a young bird")."
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
        return peopleEventText(e, s) ?? storyText(id, step: step)
    case .delivered:
        return peopleEventText(e, s) ?? "You hand the eggs over the fence, carefully."
    case .storyGiftWaitingForRoom(let id):
        let who = Storylines.story(id).map { People.name($0.person) } ?? People.neighbour
        return "\(who) has something for you, but there's no room for it yet: it needs a free perch, "
            + "or space in the egg carton. Make room, and it comes that night."
    case .storyGift(_, let id):
        return
            "Hazel comes round with a basket. \"She hatched every one. Here, one of my own girls, to say thank you.\" \(birdName(id, s)) moves into Henhaven."
    case .shopUnlocked(let breed):
        return
            "Speckle & Down now stocks \(breed.definition.displayName)s. A surprise pullet or cockerel from the shop may be one."
    case .storyFinished:
        return nil
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
    case .neighbourGaveIncubator(let size, let ownRooster):
        let fits = "It only fits \(size) egg\(size == 1 ? "" : "s"), but it works."
        let nights = s.rules.incubatorHatchDays
        let note: String
        if ownRooster {
            note =
                "\"I see your rooster has been busy. Some of your eggs will be fertile now. "
                + "Here, take my old incubator. \(fits) "
                + "You can't tell which eggs are fertile yet, so try a few. The clear ones just won't hatch.\""
        } else if s.chosen(Storylines.marigold, in: Storylines.marigold) == "return", s.incubatorGiftDay == s.day,
            hasHazelsEgg(s)
        {
            // Hazel's thank-you egg for sending Marigold home: it brings the incubator with it.
            note =
                "\"That egg needs keeping warm to hatch. Here, take my old incubator. \(fits) "
                + "Set the egg in it, and in about \(nights) night\(nights == 1 ? "" : "s") you'll have "
                + "a chick from my flock.\""
        } else {
            // An egg bought at Speckle & Down: it is already known to be fertile.
            note =
                "\"I see you brought home a fertile egg. It needs keeping warm to hatch. "
                + "Here, take my old incubator. \(fits) "
                + "Set your egg in it, and in about \(nights) night\(nights == 1 ? "" : "s") you'll have a chick.\""
        }
        // Plain words, not command names: the app and the CLI both show this note.
        return "Hazel leans over the fence. \(note)\n\n"
            + "To hatch eggs, choose them from the carton and set them in the incubator. "
            + "Fertile eggs hatch into the brooder; clear ones come back to the carton."
    case .candled(let fertile, let clear):
        if fertile == 1 && clear == 0 {
            return "You hold the egg up to the light. You see a shadow and fine veins: it's fertile."
        }
        if fertile == 0 && clear == 1 { return "You hold the egg up to the light. It glows clear: it won't hatch." }
        if fertile == 0 { return "You hold each egg up to the light. All \(clear) are clear: none are fertile." }
        return "You hold each egg up to the light: \(fertile) fertile" + (clear > 0 ? ", \(clear) clear." : ".")
    case .eggsSet(let n, let hen, let hatchDay):
        let who = hen.map { "under \(birdName($0, s))" } ?? "in the incubator"
        // "They will hatch" only when every egg in the clutch is known fertile. Unchecked eggs are a guess.
        let clutch = s.clutches.first { $0.henID == hen && $0.hatchDay == hatchDay }
        let allKnown = clutch?.eggs.allSatisfy { $0.isCandled && $0.isFertile } ?? false
        let which = allKnown ? "They" : "Any fertile ones"
        return "You set \(n) egg\(n == 1 ? "" : "s") \(who). \(which) will hatch on day \(hatchDay)."
    case .chicksHatched(let ids, let hen):
        let where_ = hen.map { "under \(birdName($0, s))" } ?? "in the incubator"
        return "Peeping \(where_)! \(ids.count) chick\(ids.count == 1 ? "" : "s") hatched: "
            + ids.compactMap { s.bird($0) }.map { "\($0.name) (\(downText($0.phenotype.chickDown)))" }.joined(
                separator: ", ")
    case .eggsDidNotHatch(let n, let hen):
        // Warm surprise, not loss: a clear egg was never going to hatch. Every fertile egg does (cozy rule).
        let opener = hen.map { "\(birdName($0, s))'s clutch:" } ?? "Hm,"
        let eggs = "\(n) egg\(n == 1 ? "" : "s") didn't hatch."
        let why = n == 1 ? "It mustn't have been fertile." : "They mustn't have been fertile."
        // A full carton sends them to the nest boxes (`returnUnhatched`).
        var back = n == 1 ? "It's back in the carton." : "They're back in the carton."
        if s.carton.count >= s.cartonCapacity { back = "The carton is full, so look in the nest boxes." }
        return "\(opener) \(eggs) \(why) \(back)"
    case .hatchSurprise(let id, let reason):
        return "Hazel peers at \(birdName(id, s)): \"\(hatchReasonText(reason))\""
    case .plannerShownAtPen:
        return """
            Hazel leans on the breeding pen. "Here's a trick. Put a rooster and some hens in, and I'll tell you \
            what their chicks could look like, and why." (Coop ▸ Breeding pen ▸ What might hatch)
            """
    case .plannerIntroduced:
        // Right after the first why note. Before the pen opens, the neighbour saves the trick for later.
        let next = s.isOpen(.breedingPen) ? "Come and look at the pen." : "I'll show you once you have a breeding pen."
        return "She winks. \"You can work this out ahead of time, you know. \(next)\""
    case .learnedCandling:
        return """
            Hazel comes round with a torch. "Here, let me show you a trick." She holds an egg up \
            to the light. "See the shadow and the little veins? That one's fertile. A clear one just glows." \
            You can candle eggs now. Candle before you set them, and a clear egg won't take a place in the incubator.
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
    case .introduced(let f): return introducedText(f, s)
    case .showAnnounced(let tip): return showTipText(tip, s)
    case .boughtSpecial(let id, let cost):
        return "You buy today's special for \(cost) coins: \(s.bird(id).map { birdLabel($0, s) } ?? "a young bird")."
    case .milestoneReached(let id):
        let reached = Milestones.all.count(where: { s.milestonesReached.contains($0.id) })
        return "★ Milestone: \(milestoneText(id).title)! (\(reached)/\(Milestones.all.count) · see: journal)"
    case .enteredInShow(let id, let cls):
        let who = id.flatMap { s.bird($0)?.name } ?? "your eggs"
        let show = showThemeName(s.nextShowTheme)
        let entered = "\(who) entered in the \(cls.name) class at the \(show) (day \(s.nextShowDay))."
        // Say now what the judge will see, so nothing is a surprise on the day.
        guard let bird = id.flatMap({ s.bird($0) }), !Judge.forecast(for: bird, in: s).isEmpty else { return entered }
        return "\(entered) \(showReadinessText(bird, s))"
    case .showDay(let day):
        let theme = ShowTheme.forSeason(s.season(onDay: day))
        return "\n🎪 The Featherwick county show, day \(day): the \(showThemeName(theme))! \(showThemeLine(theme))"
    case .showNoEntries:
        return "The show came and went. You didn't enter anything this time — next one is day \(s.nextShowDay)."
    case .showPodium(let cls, let podium):
        guard !podium.isEmpty else { return nil }
        let lines = podiumLines(cls, podium).map { "    " + $0 }
        return "  \(cls.name), the top three:\n" + lines.joined(separator: "\n")
    case .breedBookEntrySeen(let entry, let theme):
        return "Seen at the \(showThemeName(theme)): \(entryText(entry)). Added to the Breed Book."
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
    case .jobsSet:
        let jobs = s.todaysJobs.map { jobText($0, s) }
        guard !jobs.isEmpty else { return nil }
        return "Today's jobs: " + jobs.joined(separator: " · ") + ". (see: jobs)"
    case .jobDone(let kind):
        let job = s.todaysJobs.first { $0.kind == kind } ?? Job(kind: kind)
        return "✓ Job done: \(jobText(job, s))."
    case .allJobsDone(let coins):
        return "That's all of today's jobs done. A good day's work! You earn \(coins) coin\(coins == 1 ? "" : "s")."
    case .seasonGoalSet(let kind, let previous):
        guard let goal = s.seasonGoal, goal.kind == kind else { return nil }
        let season = s.season(of: goal).rawValue.capitalized
        let newGoal = "\(season) goal: \(seasonGoalText(goal, s)). (see: jobs)"
        guard let previous else { return newGoal }
        return "Last season's goal (\(goalName(previous))) can rest. There's no hurry: it may come round again. "
            + newGoal
    case .seasonGoalProgress(let kind, let progress, let target):
        return "Season goal, \(goalWords(kind, s)): \(progress) of \(target)."
    case .seasonGoalReached(let kind, let coins):
        return "★ Season goal reached: \(goalWords(kind, s))! You earn \(coins) coins."
    case .birdPenned(let id): return pennedText(id, s)
    case .birdUnpenned(let id): return "\(birdName(id, s)) goes back to the coop flock."
    case .slotSpent(_, let left):
        return left == 0
            ? "The light's going. Time for bed: sleep"
            : "The sun moves on. Time for \(left) more thing\(left == 1 ? "" : "s") today."
    case .rested(let time): return restedText(time, s)
    case .keeperNamed(let name): return "\(People.neighbour) waves over the fence. \"Welcome, \(name)!\""
    case .sexGuessed(let id, let guess):
        return "You look \(birdName(id, s)) over and say \(sexGuessWord(guess)). "
            + "\(People.neighbour) smiles. \"We'll know when the feathers come in.\""
    case .sexGuessResolved(let id, let guessed, let actual):
        return sexGuessResolvedText(id, guessed: guessed, actual: actual, s)
    case .chose, .storyCoins, .storyTreats, .storyGiftEgg, .loanArrived, .loanReturned, .loanKept, .debtOwed,
        .debtReminder, .debtPaid, .noteArrived, .villageDayComing, .villageDay:
        return villageEventText(e, s)
    case .chickNamed:
        return peopleEventText(e, s)
    case .villageDayScene, .villageDayGift, .hatchAlongEggGiven, .hatchAlongChickWaiting, .hatchAlongChickArrived:
        return calendarEventText(e, s)
    case .marketCardsPinned, .marketCardDown, .marketCardFilled, .marketCardPosted, .marketBuyerCame,
        .marketBuyerLeft, .soldToBuyer:
        return marketEventText(e, s)
    }
}

/// The keeper's word for a guess: hen or roo.
public func sexGuessWord(_ sex: Sex) -> String { sex == .hen ? "hen" : "roo" }

/// The neighbour's words on the morning a guessed chick's sex shows. Said only then, so nothing leaks.
func sexGuessResolvedText(_ id: UUID, guessed: Sex, actual: Sex, _ s: GameState) -> String {
    let treats = s.rules.sexGuessTreats
    let reward = treats == 1 ? "Have a mealworm." : "Have \(treats) mealworms."
    let said = "You said \(sexGuessWord(guessed))"
    let words =
        switch (guessed, actual) {
        case (.hen, .hen): "\(said), and she is. Well spotted. \(reward)"
        case (.rooster, .rooster): "\(said), and he is. Well spotted. \(reward)"
        case (.hen, .rooster): "\(said). He's a cockerel, as it turns out. They fool everyone at that age."
        case (.rooster, .hen): "\(said). She's a pullet, as it turns out. They fool everyone at that age."
        }
    return "\(People.neighbour) leans on the fence to look at \(birdName(id, s)). \"\(words)\""
}

/// Why an errand must wait for the morning.
func noTimeLeftText(_ errand: Errand) -> String {
    switch errand {
    case .village: "Speckle & Down will be shut by the time you get there. Tomorrow."
    case .candling: "Too dark to candle now. First thing in the morning."
    case .showDesk: "The show desk has packed up for the day."
    case .neighbour: "Hazel's lights are off. Pop round tomorrow."
    case .building: "Not enough light left to build. Tomorrow."
    case .market: "The bakery's shut and the board's in shadow. Tomorrow."
    }
}

/// The time of day and the errands left, for the CLI `time` command and the app's sun mark.
public func timeOfDayText(_ s: GameState) -> String {
    guard s.isOpen(.daylight) else { return notYetText(.daylight, s) }
    let time =
        switch s.timeOfDay {
        case .morning: "Morning."
        case .afternoon: "Afternoon."
        case .evening: "Evening."
        }
    let left = s.slotsLeft
    guard left > 0 else { return "\(time) No time left for errands: sleep" }
    return "\(time) Time for \(left) more errand\(left == 1 ? "" : "s")."
}

/// A line for a rest, by time of day. Chosen from the shop seed, the day and the slot, never the game
/// RNG, so reading it changes nothing and the same rest always reads the same.
func restedText(_ time: TimeOfDay, _ s: GameState) -> String {
    let lines = restedLines(time, s)
    let mix =
        s.shopSeed ^ (UInt64(truncatingIfNeeded: s.day) &* 0x9E37_79B9_7F4A_7C15)
        ^ UInt64(truncatingIfNeeded: s.slotsUsed)
    return lines[Int(mix % UInt64(lines.count))]
}

/// Every line a rest can read at this time of day. Rule 8: no line names a sex, so "it" and "the flock",
/// never "she" or "a hen".
public func restedLines(_ time: TimeOfDay, _ s: GameState) -> [String] {
    switch time {
    case .morning:
        return [
            "You sit on the step with a cup of tea and watch them scratch about.",
            "You lean on the fence while the dew burns off the grass.",
            "You stand a while and listen to the morning chatter.",
            "You sit on an upturned bucket and watch the sun come over the hedge.",
        ]
    case .afternoon:
        return [
            bootNap(s),
            "You doze in the warm grass while the flock dust-bathes nearby.",
            "You watch a chicken chase a moth, lose it, and pretend it meant to.",
            "You sit in the shade and count feathers drifting past.",
        ]
    case .evening:
        return [
            "The flock drifts toward the coop on its own.",
            "The light goes gold over the yard. Someone clucks a sleepy complaint.",
            "You watch the last bird hop up to bed.",
            "The swallows come out, and the yard goes quiet and soft.",
        ]
    }
}

/// The nap on the keeper's boot: the starter if still at home, else one of the flock.
func bootNap(_ s: GameState) -> String {
    if let id = s.starterID, let starter = s.birdsAtHome.first(where: { $0.id == id }) {
        return "\(starter.name) falls asleep on your boot."
    }
    return s.birdsAtHome.isEmpty
        ? "You nearly fall asleep on the step in the sun." : "One of the flock falls asleep on your boot."
}

/// What penning a bird means for the eggs. A bird is penned only once its sex shows.
func pennedText(_ id: UUID, _ s: GameState) -> String {
    let name = birdName(id, s)
    guard let bird = s.bird(id), bird.revealed else { return "\(name) goes into the breeding pen." }
    if bird.sex == .rooster {
        let grown = s.penRoosterGrownDay.map { " He is still young: the pen hens' eggs stay clear until day \($0)." }
        return "\(name) goes into the breeding pen. He fathers the eggs of the hens in the pen, and only theirs."
            + (grown ?? "")
    }
    guard let rooster = s.penRooster else {
        return "\(name) goes into the breeding pen. Her eggs won't be fertile until a rooster joins her: pen <name>"
    }
    if let day = s.penRoosterGrownDay {
        return "\(name) goes into the breeding pen. \(rooster.name) is still young, so her eggs stay clear "
            + "until day \(day). After that, her chicks will have \(rooster.name) for a father."
    }
    return "\(name) goes into the breeding pen. Her chicks will have \(rooster.name) for a father."
}

/// The breeding pen: its rooster, its hens, and room for more.
public func penLines(_ s: GameState) -> [String] {
    guard s.isOpen(.breedingPen) else { return [notYetText(.breedingPen, s)] }
    var out = ["Breeding pen (1 rooster, \(s.rules.penHens) hens). Pen birds keep their coop perch."]
    out.append("  Rooster: " + (s.penRooster.map { birdLabel($0, s) } ?? "none (the pen hens' eggs are not fertile)"))
    if let day = s.penRoosterGrownDay { out.append("    still young: the pen hens' eggs stay clear until day \(day)") }
    let hens = s.pennedHens
    if hens.isEmpty { out.append("  Hens: none") }
    for hen in hens { out.append("  Hen: " + birdLabel(hen, s)) }
    out.append("Put a bird in: pen <name> · take one out: unpen <name>")
    return out
}

/// The current goal in a sentence ("hatch 3 chicks"), or its short name if it has gone.
func goalWords(_ kind: GoalKind, _ s: GameState) -> String {
    guard let goal = s.seasonGoal, goal.kind == kind else { return goalName(kind) }
    return seasonGoalText(goal, s).lowercasedFirst
}

// MARK: - Today's jobs and the season goal

/// One of today's jobs, as a short line: "Cuddle Pip", "Cuddle Juniper, Pip and Hazel (1 of 3)".
public func jobText(_ job: Job, _ s: GameState) -> String {
    let title: String =
        switch job.kind {
        case .feed: "Feed the flock"
        case .collectEggs: "Collect the eggs"
        case .petBirds: "Cuddle \(petBirdsWords(job, s))"
        case .petBird: "Cuddle \(job.birdID.map { birdList([$0], s) } ?? "a bird")"
        case .giveTreat: "Give a bird a treat"
        case .shutCoop: "Shut the coop door tonight"
        case .sellEggs: "Sell some eggs"
        case .candleEgg: "Hold an egg up to the light"
        case .setEggs: "Set some eggs to hatch"
        case .nameBird: "Give the new \(newBirdWord(job.birdID, s)) a name"
        case .enterShow: "Enter the \(showThemeName(s.nextShowTheme))"
        }
    // The count shows once the job is started: "Cuddle Juniper and Pip", then "(1 of 2)".
    guard job.target > 1, job.progress > 0, !job.isDone else { return title }
    return title + " (\(job.progress) of \(job.target))"
}

/// The birds a "cuddle" job names. A job from a save made before jobs named birds: "2 birds".
func petBirdsWords(_ job: Job, _ s: GameState) -> String {
    guard let ids = job.birdIDs, !ids.isEmpty else { return "\(job.target) bird\(job.target == 1 ? "" : "s")" }
    return birdList(ids, s)
}

/// Birds by name, for a job: "Juniper", "Juniper and Pip", "Juniper, Pip and Hazel".
/// A bird with no name yet is "the new chick" (or "2 new chicks"): the word never tells a hidden sex.
func birdList(_ ids: [UUID], _ s: GameState) -> String {
    var names: [String] = []
    var newWords: [String] = []  // kind words of unnamed birds, first seen first
    var newCounts: [String: Int] = [:]
    for id in ids {
        guard let bird = s.bird(id) else { continue }
        if bird.needsName == true {
            let word = kindWord(bird, s)
            if newCounts[word] == nil { newWords.append(word) }
            newCounts[word, default: 0] += 1
        } else {
            names.append(bird.name)
        }
    }
    var parts = names
    for word in newWords {
        let n = newCounts[word] ?? 1
        parts.append(n == 1 ? "the new \(word)" : "\(n) new \(word)s")
    }
    guard let last = parts.last else { return "a bird" }
    guard parts.count > 1 else { return last }
    return parts.dropLast().joined(separator: ", ") + " and " + last
}

/// "chick" while the sex is hidden, else "pullet", "hen"... ("bird" if it has gone).
func newBirdWord(_ id: UUID?, _ s: GameState) -> String {
    guard let id, let bird = s.bird(id) else { return "bird" }
    return kindWord(bird, s)
}

/// The season goal, as a short line: "Hatch 3 chicks". Progress is in `seasonGoalProgressText`.
public func seasonGoalText(_ goal: SeasonGoal, _ s: GameState) -> String {
    let n = goal.target
    return switch goal.kind {
    case .hatchChicks: "Hatch \(n) chick\(n == 1 ? "" : "s")"
    case .breedBookPage: "Add a new page to the Breed Book"
    case .newEgg: "Find an egg you have not seen before"
    case .showRibbon: "Win a ribbon at the county show"
    case .newFriend: "Help one more bird become friendly"
    case .growFlock: "Grow the flock by \(n) bird\(n == 1 ? "" : "s")"
    case .collectEggs: "Collect \(n) egg\(n == 1 ? "" : "s")"
    }
}

/// "2 of 3", or "Reached" once it is done.
public func seasonGoalProgressText(_ goal: SeasonGoal, _ s: GameState) -> String {
    goal.reached ? "Reached" : "\(s.progress(of: goal)) of \(goal.target)"
}

/// A short name for a goal kind, when the goal itself has gone: "a new friend".
public func goalName(_ kind: GoalKind) -> String {
    switch kind {
    case .hatchChicks: "hatching chicks"
    case .breedBookPage: "a new Breed Book page"
    case .newEgg: "a new egg"
    case .showRibbon: "a show ribbon"
    case .newFriend: "a new friend"
    case .growFlock: "a bigger flock"
    case .collectEggs: "a basket of eggs"
    }
}

/// The `jobs` screen: today's jobs, ticked when done, and the season goal.
public func jobsLines(_ s: GameState) -> [String] {
    var out: [String] = []
    let jobs = s.todaysJobs
    if jobs.isEmpty {
        out.append("No jobs yet today. New jobs come each morning.")
    } else {
        out.append("Today's jobs (day \(s.day)):")
        for job in jobs { out.append("  \(job.isDone ? "✓" : "○") \(jobText(job, s))") }
        let reward = s.rules.jobsRewardCoins
        if s.todaysJobsRewarded {
            out.append("  All done. Well done! (+\(reward) coins)")
        } else {
            out.append("  Do them all for \(reward) coins. Any you skip simply go tomorrow.")
        }
    }
    guard let goal = s.seasonGoal else {
        out.append("Season goal: none yet. One comes when there is something to aim for.")
        return out
    }
    let season = s.season(of: goal).rawValue.capitalized
    out.append("\(season) goal: \(seasonGoalText(goal, s)) · \(seasonGoalProgressText(goal, s))")
    if !goal.reached {
        out.append(
            "  Until day \(goal.endDay), for \(s.rules.seasonGoalRewardCoins) coins. If it waits, a new goal comes.")
    }
    return out
}

extension String {
    /// "Hatch 3 chicks" → "hatch 3 chicks", for use inside a sentence.
    var lowercasedFirst: String { prefix(1).lowercased() + dropFirst() }
}

public func yardLines(_ s: GameState) -> [String] {
    var out: [String] = []
    if case .choosingStarter(let chicks) = s.phase {
        out.append("Hazel keeps orpingtons, wyandottes and araucanas. She offers you one chick.")
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
    out.append("Coop (\(s.perchesUsed)/\(s.perches) perches, \(s.nestBoxes) nesting boxes):")
    for b in s.coop {
        var line = "  " + birdLabel(b, s)
        if s.isPenned(b.id) { line += " · in the breeding pen" }
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
            "Staying with Hazel (no eggs can be set until they have a home): "
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

/// The goal ladder's words (kept here, not in Core, keyed by milestone id). Title, and a hint while locked.
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
    case "chocolateEgg": ("Chocolate egg", "Find a hen that lays very dark chocolate-brown eggs.")
    case "greenEgg": ("Green egg", "Cross an Araucana with a brown-egg breed. Some of the hens lay green eggs.")
    case "whiteEgg":
        ("White egg", "Find a hen that lays pure white eggs. Pale-egg breeds like the Silkie sometimes have one.")
    case "henOrRoo":
        ("Guessed hen or roo right", "Guess hen or roo for a young chick. You find out when its feathers come in.")
    default: (id, "")
    }
}

/// A quirk in one line, present tense. Hen and rooster lines may say she or he: they show only once
/// the bird's sex is visible (`Quirks.of`).
public func quirkText(_ q: Quirk) -> String {
    switch q {
    case .dustBathLover: "Dust-bath lover. Finds the one dry patch and rolls in it."
    case .singsWhenLaying: "Sings when laying. She tells the whole farm about every egg."
    case .firstToTheGate: "First to the gate. Waits there at dawn for the door to open."
    case .escapeArtist: "Escape artist. Knows every gap in the fence."
    case .followsYouAbout: "Follows you about. Never more than three steps behind."
    case .sitsOnTheFencePost: "Sits on the fence post. Keeps watch over the yard from up there."
    case .hatesRain: "Hates rain. Sulks under the coop at the first drop."
    case .likesACuddleAtDusk: "Likes a cuddle at dusk. Comes to sit with you as the light goes."
    case .hoardsTheMealworms: "Hoards the mealworms. Runs off with one before the others look up."
    case .talksToTheDucks: "Talks to the ducks next door. Chatters at the fence for hours."
    case .roostsOnTheHighestPerch: "Roosts on the highest perch. Nobody else may have it."
    case .broodsOverGolfBalls: "Broods over golf balls. She sits on them as if they will hatch."
    case .napsInTheSun: "Naps in the sun. Flops down with one wing out."
    case .pecksAtBootlaces: "Pecks at bootlaces. Yours are never safe."
    case .runsAtTheFox: "Runs at the fox. He puffs up and charges the hedge."
    case .alwaysLastToBed: "Always last to bed. Still pecking about when the others roost."
    }
}

/// This bird's quirks, one line each, for the bird card.
public func quirkLines(_ bird: Bird, _ s: GameState) -> [String] {
    Quirks.of(bird, in: s).map(quirkText)
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
    let seen = s.breedBookSeenOnly
    if !seen.isEmpty {
        out.append("Seen at shows (\(seen.count)):")
        seen.forEach { out.append("  \(entryText($0.entry)) — \(seenText($0).lowercasedFirst), day \($0.day)") }
    }
    out.append("Egg colours (\(s.eggBook.count)):")
    for e in s.eggBook.sorted(by: { $0.colour.rawValue < $1.colour.rawValue }) {
        out.append("  \(e.speckled ? "speckled " : "")\(e.colour.rawValue)")
    }
    return out + dotBookLines(s)
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
        out.append("    \(judgingText(kind)).")
    }
    if s.showEntries.isEmpty {
        out.append("No entries yet. Enter a bird (enter <name>) or your best plate of eggs (enter eggs).")
    } else {
        out.append("Entered for day \(s.nextShowDay):")
        for e in s.showEntries {
            if let id = e.birdID, let b = s.bird(id) {
                out.append("  \(b.name) — \(Engine.entryClass(e, of: b, in: s).name) class. \(showReadinessText(b, s))")
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
        switch step?.goal.resolved(p.chosen) {
        case .deliverFertileEggs(let n)?:
            out.append("• \(story.id): bring \(n) eggs you know are fertile, then: give eggs")
        case .deliverEggs(let colour, let n)?:
            out.append("• \(story.id): bring \(n) \(colour.rawValue) eggs, then: give eggs \(story.id)")
        case .deliverEggsOfNewColour(let n)?:
            let colours = anyOfList((p.wantedColours ?? []).map(\.rawValue))
            out.append("• \(story.id): bring \(n) eggs of one new colour (\(colours)), then: give eggs \(story.id)")
        case .choiceOfBreeds(let id)? where p.chosen[id] == nil:
            let list = (p.options ?? []).map { "\($0) (\(choiceText(story: story.id, option: $0)))" }
                .joined(separator: ", ")
            out.append(
                "• \(story.id): \(People.name(story.person)) asks you to choose: \(list). Type: choose \(story.id) <option>"
            )
        case .friendliness?: out.append("• \(story.id): when a bird is a lap chicken")
        case .birdRehomed?: out.append("• \(story.id): when more birds have new homes")
        case .waitDays?, .onDay?, .featureDay?: out.append("• \(story.id): wait a few days")
        case .choice(let id, let options)? where p.chosen[id] == nil:
            let list = options.map { "\($0) (\(choiceText(story: story.id, option: $0)))" }.joined(separator: ", ")
            out.append(
                "• \(story.id): \(People.name(story.person)) asks you to choose: \(list). Type: choose \(story.id) <option>"
            )
        case nil, .choice?, .choiceOfBreeds?: out.append("• \(story.id): a gift is waiting for room")
        default: out.append("• \(story.id): in a while")
        }
    }
    return out
}

// MARK: - The early game

/// "she", "he", or the bird's name while its sex is hidden. Never leaks a hidden sex.
public func subjectPronoun(_ b: Bird) -> String { b.revealed ? (b.sex == .hen ? "she" : "he") : b.name }

/// "her", "him", or the bird's name while its sex is hidden.
public func objectPronoun(_ b: Bird) -> String { b.revealed ? (b.sex == .hen ? "her" : "him") : b.name }

/// "pullet", "hen", "cockerel", "rooster", or "chick" while the sex is hidden.
public func kindWord(_ b: Bird, _ s: GameState) -> String {
    guard b.revealed else { return "chick" }
    switch (b.stage(onDay: s.day, rules: s.rules), b.sex) {
    case (.chick, _): return "chick"
    case (.grower, .hen): return "pullet"
    case (.grower, .rooster): return "cockerel"
    case (.adult, .hen): return "hen"
    case (.adult, .rooster): return "rooster"
    }
}

/// "a" or "an" for the word that follows.
func article(_ next: String) -> String { "aeiou".contains(next.lowercased().first ?? "x") ? "an" : "a" }

/// The starter's name, or "your chick" if the starter has gone.
func starterName(_ s: GameState) -> String { s.starterID.flatMap { s.bird($0)?.name } ?? "your chick" }

/// True when the carton holds a fertile egg from a story gift (its mother is a village record), not one
/// bought at Speckle & Down (a local flock's). For the incubator note on the day Marigold goes home.
func hasHazelsEgg(_ s: GameState) -> Bool {
    s.carton.contains { $0.isCandled && $0.isFertile && s.pedigree[$0.motherID]?.origin == Bird.villageOrigin }
}

/// What the neighbour says when the early game reaches a feature. The show is announced by `showTipText`.
public func introducedText(_ f: Feature, _ s: GameState) -> String? {
    let r = s.rules
    switch f {
    case .handling:
        let n = starterName(s)
        return """
            Hazel leans over the fence. "How's \(n) settling in? Pick \(n) up every day. \
            Chicks learn to trust you fastest while they're small." (pet \(n))
            """
    case .treats:
        return """
            Hazel hands you a twist of paper. "Mealworms! Chickens adore them. One a day from your hand, \
            and they'll follow you anywhere." You get \(r.welcomeTreats) treats. Speckle & Down sells more. \
            (treat <name>, buy treats)
            """
    case .premiumFeed:
        return "Speckle & Down has premium feed in. Basic feed stays free. Premium feed also lifts laying a little, "
            + "so it helps once your hens lay. (buy feed, feed premium)"
    case .coopDoor:
        let fox = """
            A fox comes by now and then. It won't hurt anyone, but it gives them a terrible fright. \
            Leave the door open and they forage all night, and come back fed. Your choice.
            """
        // Day 3: Marigold is the first bird in the coop, so the lesson is about her.
        if let hen = s.loanedBird(tag: Storylines.marigold), s.coop.contains(where: { $0.id == hen.id }) {
            return """
                Before she goes, Hazel shows you the coop door. "Shut this behind \(hen.name) at night. \(fox)" (close)
                """
        }
        let n = starterName(s)
        return """
            Hazel looks at \(n). "Nearly big enough for the coop! Remember to shut the coop door at night. \(fox)" (close)
            """
    case .breedBook:
        guard let starter = s.starterID.flatMap({ s.bird($0) }), starter.revealed else {
            return "Every breed and colour you keep goes in your Breed Book. (book)"
        }
        let what = "\(colourText(starter.phenotype)) \(starter.varietyName) \(kindWord(starter, s))"
        let book = "Write that in your Breed Book. Every breed and colour you keep goes in it."
        // Marigold came: Hazel knew the breed all along. Said once the breed shows, so it tells nothing early.
        if s.hazelAway {
            // Hazel is still at her sister's: she writes.
            return """
                A postcard comes from Hazel: "By now you'll see what \(starter.name) is: \(article(what)) \(what)! \
                Marigold's chick, of course. \(book)" (book)
                """
        }
        if s.marigoldCame {
            return """
                Hazel peers at \(starter.name). "So that's what \(subjectPronoun(starter))'s turned into: \
                \(article(what)) \(what)! Marigold's chick, of course. \(book)" (book)
                """
        }
        return """
            Hazel peers at \(starter.name). "So that's what \(subjectPronoun(starter))'s turned into: \
            \(article(what)) \(what)! \(book)" (book)
            """
    case .laying:
        let lesson = """
            Hens lay when they were fed the day before. Collect the eggs every day: full nest boxes mean \
            broken eggs, and old eggs sell for less.
            """
        let hens = s.birdsAtHome.filter { $0.revealed && $0.sex == .hen }
        guard let hen = hens.min(by: { $0.hatchDay < $1.hatchDay }) else {
            // Marigold is on loan but not home (the fox scared her off): she lays once she is back.
            if let away = s.loanedBird(tag: Storylines.marigold) {
                return """
                    A note from Hazel is tucked in \(away.name)'s empty box: "\(away.name) will lay when she's \
                    home. A fright puts a hen off laying for a few days. \(lesson)" (collect, sell)
                    """
            }
            // A chick whose sex does not show yet: say nothing about roosters, so nothing hints at it.
            if s.ownBirds.contains(where: { !$0.revealed }) {
                return "Hazel's hens are laying well. \"\(lesson)\" (collect, sell)"
            }
            return "Hazel's hens are laying well. \"Roosters don't lay, mind. A pullet from Speckle & Down "
                + "would.\" (shop)"
        }
        let n = hen.name
        // Day 4: Hazel is away, and Marigold is laying. Hazel left the lesson in her box.
        if hen.loan?.tag == Storylines.marigold {
            return """
                A note from Hazel is tucked in \(n)'s box: "\(n) lays most days, and her eggs are yours. \
                \(lesson) Speckle & Down buys them." (collect, sell)
                """
        }
        if hen.stage(onDay: s.day, rules: s.rules) == .adult {
            return "Hazel nods at \(n). \"\(n) is laying now. \(lesson)\" (collect, sell)"
        }
        return "Hazel nods at \(n). \"\(n) will start to lay soon. \(lesson)\" (collect, sell)"
    case .daylight:
        return "There's only so much daylight. Feed and cuddle whenever you like, but you'll fit about three "
            + "errands in a day. The shop, candling, the show desk, a visit to mine. When the light's gone, "
            + "it's bedtime."
    case .birdShop:
        return "Speckle & Down has birds in! Pullets, cockerels, fertile eggs, and a special bird each day. "
            + "Your flock can grow now. (shop)"
    case .coopUpgrade:
        return "The carpenter can add perches to your coop now: \(r.perchesPerUpgrade) more perches for "
            + "\(r.coopUpgradePrice) coins. More perches, more birds. (upgrade coop)"
    case .shows:
        return nil  // the neighbour announces the show herself (showTipText)
    case .incubatorShop:
        return "Speckle & Down now sells a big incubator. It holds \(r.bigIncubatorSize) eggs, for "
            + "\(r.incubatorPrice) coins. (buy incubator)"
    case .breedingPen:
        return """
            Hazel helps you fence off a corner of the coop. "A breeding pen! Put one rooster in with up to \
            \(r.penHens) hens. Then you know who fathered every egg they lay. They keep their perches, so it costs \
            you no room." (pen <name>, unpen <name>, pen)
            """
    case .marketBoard:
        return """
            Mr Okafor has put up a board by the bakery door. "A market board! People pin what they want, \
            and you bring it. Eggs, a bird, whatever's on the cards. Pin your own card too, if you have \
            young birds to sell. New cards every week." (board)
            """
    }
}

/// Why a command is refused before the early game reaches its feature, and when it comes.
public func notYetText(_ f: Feature, _ s: GameState) -> String {
    let day = s.introductionDay(of: f)
    let when = day <= s.day + 1 ? "tomorrow" : "on day \(day)"
    switch f {
    case .treats: return "Speckle & Down has no mealworms in yet. They come \(when)."
    case .premiumFeed: return "Speckle & Down has no premium feed in yet. It comes \(when)."
    case .birdShop: return "Speckle & Down has no birds or eggs for sale yet. Look after \(starterName(s)) for now."
    case .coopUpgrade: return "The carpenter is busy. Ask about more perches \(when)."
    case .shows: return "There is no show to enter yet."
    case .incubatorShop: return "Speckle & Down has no incubators in yet. They come \(when)."
    case .breedingPen: return "There is no breeding pen yet. Hazel comes to help build one \(when)."
    case .daylight: return "No need to rest yet. There's plenty of daylight."
    case .marketBoard: return "There's talk of a market board by the bakery. It goes up \(when)."
    case .handling, .coopDoor, .breedBook, .laying: return "Not yet."
    }
}

/// The neighbour announces the county show, a week ahead, and names one of your birds and a class for it.
public func showTipText(_ tip: ShowTip?, _ s: GameState) -> String {
    let day = tip?.showDay ?? s.nextShowDay
    let theme = ShowTheme.forSeason(s.season(onDay: day))
    let show = "The \(showThemeName(theme)) is coming up next week, on day \(day)."
    guard let tip, let bird = s.bird(tip.birdID) else {
        return """
            Hazel waves a poster over the fence. "\(show) Your birds are a bit young to show this time. \
            There's one every season." (shows)
            """
    }
    let n = bird.name
    let her = objectPronoun(bird)
    let she = subjectPronoun(bird)
    let classes = Engine.eligibleClasses(for: bird, in: s)
    var said: String
    switch tip.showClass {
    case .breed(let breed):
        let looks = "\(colourText(bird.phenotype)) \(breed.definition.displayName)"
        said =
            "Oh hey, I notice that \(n) is a beautiful \(looks)! \(show) I think you should enter \(her) "
            + "in the \(breed.definition.displayName) class."
    default:
        let kind = kindWord(bird, s)
        let opener =
            bird.friendliness >= .friendly
            ? "Oh hey, \(n) is such a sweet, friendly \(kind)!"
            : "Oh hey, I've been watching \(n). What a character!"
        said = "\(opener) \(show) I think you should enter \(her) in the pet class."
        if bird.friendliness >= .friendly {
            said += " The judges love a bird that's happy to be held."
        } else {
            said += " A cuddle every day until then, and \(she)'ll be a different bird on the day."
        }
        if classes.count > 1 { said += " The \(classes[0].name) class is a tough crowd this year." }
    }
    let command = tip.showClass == .pet && classes.count > 1 ? "enter \(n) pet" : "enter \(n)"
    return "Hazel leans over the fence with a poster. \"\(said)\" \(showThemeLine(theme)) (\(command))"
}
