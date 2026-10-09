import Foundation

// The post: small notes from Featherwick's people, one some mornings.
//
// Each night (the "post" step, after the stories) a note may come, with `Rules.noteChance`. It is picked
// from the notes whose condition holds and that have not come before (`GameState.notesSeen`). The roll and
// the pick are seeded from `GameState.shopSeed` and the day, never from the game RNG, so the post
// changes no seeded game.
//
// Core holds note IDs and conditions only. The words live in FeatherwickText (`noteText`), by note ID.
// Rule 8: a condition reads only what the keeper can see.

/// When a note may come. Every condition reads only player-visible state.
public indirect enum NoteCondition: Hashable, Sendable {
    case always
    /// A hen has laid at least one egg.
    case hasEggs
    /// The county show is open and is at most `Rules.showNoticeDays` away.
    case showInWeek
    /// At least one bird has gone to a new home.
    case hasRehomed
    /// A bird on loan is here.
    case hasLoan
    /// The Egg Book has this colour.
    case eggBookHas(EggColour)
    /// At least this many birds at home are this friendly or friendlier.
    case bandCount(Friendliness, Int)
    /// It is this season.
    case season(Season)
    /// This storyline is finished.
    case afterStory(String)
    /// A bird on loan is in the coop now: not lost after a fright.
    case loanedBirdHome
    /// It is this day or later. Keeps the first days of a new game quiet.
    case dayAtLeast(Int)
    /// The keeper has met this feature (see EarlyGame.swift). A shop note names only stock that is open.
    case isOpen(Feature)
    /// At least this many chicks have hatched here.
    case chicksHatched(Int)
    /// The Breed Book has at least this many looks the keeper has owned. Looks only seen at a show do not count.
    case breedBookCount(Int)
    /// At least this many birds have gone to new homes.
    case rehomedCount(Int)
    /// The keeper has had an entry judged at a county show, placed or not.
    case enteredShow
    /// An entry placed 1st, 2nd or 3rd at a county show.
    case placedAtShow
    /// An entry placed 1st, 2nd or 3rd in this kind of class.
    case placedInClass(ShowKind)
    /// Every one of these holds.
    case all([NoteCondition])

    public func holds(in s: GameState) -> Bool {
        switch self {
        case .always: true
        case .hasEggs: !s.layRecords.isEmpty
        case .showInWeek: s.isOpen(.shows) && s.nextShowDay - s.day <= s.rules.showNoticeDays
        case .hasRehomed: !s.rehomed.isEmpty
        case .hasLoan: !s.loanedBirds.isEmpty
        case .eggBookHas(let colour): s.eggBook.contains { $0.colour == colour }
        case .bandCount(let band, let n): s.birdsAtHome.count(where: { $0.friendliness >= band }) >= n
        case .season(let season): s.season == season
        case .afterStory(let id): s.stories[id]?.rewarded == true
        case .loanedBirdHome: s.coop.contains(where: \.isOnLoan)
        case .dayAtLeast(let n): s.day >= n
        case .isOpen(let feature): s.isOpen(feature)
        case .chicksHatched(let n): s.chicksHatched >= n
        case .breedBookCount(let n): s.breedBook.count >= n
        case .rehomedCount(let n): s.rehomed.count >= n
        case .enteredShow: !s.showResults.isEmpty
        case .placedAtShow: s.showResults.contains { $0.isRibbon }
        case .placedInClass(let kind): s.showResults.contains { $0.isRibbon && $0.showClass.kind == kind }
        case .all(let conditions): conditions.allSatisfy { $0.holds(in: s) }
        }
    }
}

/// One note in the pool: who sends it, and when it may come.
public struct Note: Hashable, Sendable, Identifiable {
    public let id: String
    public let from: Person
    public let condition: NoteCondition

    public init(_ id: String, from: Person, when condition: NoteCondition = .always) {
        self.id = id
        self.from = from
        self.condition = condition
    }
}

public enum Notes {
    /// Every note that can come in the post. Append, never insert: the seeded pick reads list order. So a new
    /// note goes at the end of `added`, not in a person's list. Each person's notes follow their system.
    /// Every note waits a few days at least, so the first days of a new game stay quiet (`NotesTests`).
    /// The words are in FeatherwickText (`poolNoteText`).
    public static let pool: [Note] = wren + hazel + dot + teddy + okafor + bea + added

    /// Wren: village news, the shop's stock (only stock that is open) and the weather.
    static let wren: [Note] = [
        Note("wren.mealworms", from: .wren, when: .all([.isOpen(.treats), .dayAtLeast(6)])),
        Note("wren.premiumFeed", from: .wren, when: .all([.isOpen(.premiumFeed), .dayAtLeast(7)])),
        Note("wren.specialPen", from: .wren, when: .isOpen(.birdShop)),
        Note("wren.surpriseBoxes", from: .wren, when: .all([.isOpen(.birdShop), .dayAtLeast(20)])),
        Note("wren.bigIncubator", from: .wren, when: .isOpen(.incubatorShop)),
        Note("wren.timber", from: .wren, when: .all([.isOpen(.coopUpgrade), .dayAtLeast(16)])),
        Note("wren.rain", from: .wren, when: .all([.season(.spring), .dayAtLeast(8)])),
        Note("wren.heat", from: .wren, when: .season(.summer)),
        Note("wren.leaves", from: .wren, when: .season(.autumn)),
        Note("wren.frost", from: .wren, when: .season(.winter)),
        Note("wren.showTalk", from: .wren, when: .showInWeek),
        Note("wren.hazelNews", from: .wren, when: .dayAtLeast(25)),
        Note("wren.newLoaf", from: .wren, when: .all([.hasEggs, .dayAtLeast(20)])),
        Note("wren.breedBook", from: .wren, when: .all([.breedBookCount(3), .dayAtLeast(10)])),
    ]

    /// Hazel: chicken lore, and the lessons of the early game recalled.
    static let hazel: [Note] = [
        Note("hazel.peckingOrder", from: .hazel, when: .dayAtLeast(9)),
        Note("hazel.handling", from: .hazel, when: .all([.isOpen(.handling), .dayAtLeast(6)])),
        Note("hazel.coopDoor", from: .hazel, when: .all([.isOpen(.coopDoor), .dayAtLeast(10)])),
        Note("hazel.moult", from: .hazel, when: .season(.autumn)),
        Note("hazel.winterLaying", from: .hazel, when: .all([.season(.winter), .hasEggs])),
        Note("hazel.broody", from: .hazel, when: .all([.hasEggs, .dayAtLeast(25)])),
        Note("hazel.firstPeep", from: .hazel, when: .all([.chicksHatched(1), .dayAtLeast(6)])),
        Note("hazel.notes", from: .hazel, when: .isOpen(.breedingPen)),
        Note("hazel.crosses", from: .hazel, when: .all([.breedBookCount(4), .dayAtLeast(10)])),
        Note("hazel.favouriteLook", from: .hazel, when: .all([.breedBookCount(2), .dayAtLeast(12)])),
        Note("hazel.oldHens", from: .hazel, when: .dayAtLeast(60)),
        Note("hazel.springAgain", from: .hazel, when: .all([.season(.spring), .dayAtLeast(100)])),
        Note("hazel.borrowed", from: .hazel, when: .all([.hasLoan, .dayAtLeast(6)])),
        Note("hazel.patience", from: .hazel, when: .all([.bandCount(.friendly, 2), .dayAtLeast(6)])),
    ]

    /// Dot: show hints, and what she noticed at a show.
    static let dot: [Note] = [
        Note("dot.ribbon", from: .dot, when: .placedAtShow),
        Note("dot.petClass", from: .dot, when: .placedInClass(.pet)),
        Note("dot.breedClass", from: .dot, when: .placedInClass(.breed)),
        Note("dot.eggClass", from: .dot, when: .placedInClass(.eggs)),
        Note("dot.firstEntry", from: .dot, when: .enteredShow),
        Note("dot.shutTheDoor", from: .dot, when: .showInWeek),
        Note("dot.friendliness", from: .dot, when: .all([.showInWeek, .enteredShow])),
        Note("dot.eggFair", from: .dot, when: .all([.season(.spring), .isOpen(.shows)])),
        Note("dot.fete", from: .dot, when: .all([.season(.summer), .isOpen(.shows)])),
        Note("dot.harvest", from: .dot, when: .all([.season(.autumn), .isOpen(.shows)])),
        Note("dot.championship", from: .dot, when: .all([.season(.winter), .isOpen(.shows)])),
        Note("dot.lapChicken", from: .dot, when: .all([.bandCount(.lapChicken, 1), .isOpen(.shows)])),
    ]

    /// Teddy: drawings and questions, and the birds that let him near.
    static let teddy: [Note] = [
        Note("teddy.drawing", from: .teddy, when: .all([.bandCount(.skittish, 1), .dayAtLeast(8)])),
        Note("teddy.whichEgg", from: .teddy, when: .all([.hasEggs, .dayAtLeast(6)])),
        Note("teddy.handFed", from: .teddy, when: .all([.bandCount(.friendly, 1), .dayAtLeast(6)])),
        Note("teddy.lap", from: .teddy, when: .all([.bandCount(.lapChicken, 1), .dayAtLeast(6)])),
        Note("teddy.counted", from: .teddy, when: .all([.bandCount(.friendly, 3), .dayAtLeast(6)])),
        Note("teddy.dreams", from: .teddy, when: .dayAtLeast(12)),
        Note("teddy.snow", from: .teddy, when: .season(.winter)),
        Note("teddy.chickNames", from: .teddy, when: .all([.chicksHatched(1), .dayAtLeast(6)])),
        Note("teddy.ribbon", from: .teddy, when: .placedInClass(.pet)),
        Note("teddy.feather", from: .teddy, when: .all([.isOpen(.coopDoor), .dayAtLeast(15)])),
        Note("teddy.dustBath", from: .teddy, when: .dayAtLeast(20)),
        Note("teddy.visitor", from: .teddy, when: .all([.loanedBirdHome, .dayAtLeast(6)])),
    ]

    /// Mr Okafor: eggs, egg colours and bread.
    static let okafor: [Note] = [
        Note("okafor.laying", from: .okafor, when: .all([.hasEggs, .dayAtLeast(6)])),
        Note("okafor.blue", from: .okafor, when: .eggBookHas(.blue)),
        Note("okafor.olive", from: .okafor, when: .eggBookHas(.olive)),
        Note("okafor.chocolate", from: .okafor, when: .eggBookHas(.chocolate)),
        Note("okafor.green", from: .okafor, when: .eggBookHas(.green)),
        Note("okafor.white", from: .okafor, when: .eggBookHas(.white)),
        Note("okafor.brown", from: .okafor, when: .eggBookHas(.brown)),
        Note("okafor.window", from: .okafor, when: .all([.hasEggs, .dayAtLeast(30)])),
        Note("okafor.winterOven", from: .okafor, when: .all([.season(.winter), .hasEggs])),
        Note("okafor.custard", from: .okafor, when: .all([.season(.spring), .hasEggs])),
    ]

    /// Bea: how the rehomed birds are doing, by name.
    static let bea: [Note] = [
        Note("bea.settled", from: .bea, when: .all([.hasRehomed, .dayAtLeast(6)])),
        Note("bea.appleTree", from: .bea, when: .all([.hasRehomed, .dayAtLeast(8)])),
        Note("bea.storyTime", from: .bea, when: .all([.hasRehomed, .dayAtLeast(20)])),
        Note("bea.newFriend", from: .bea, when: .rehomedCount(2)),
        Note("bea.fridge", from: .bea, when: .all([.hasRehomed, .dayAtLeast(30)])),
        Note("bea.thanks", from: .bea, when: .rehomedCount(3)),
        Note("bea.winterCheck", from: .bea, when: .all([.season(.winter), .hasRehomed])),
        Note("bea.fence", from: .bea, when: .rehomedCount(2)),
        Note("bea.quietWeek", from: .bea, when: .all([.hasRehomed, .dayAtLeast(40)])),
    ]

    /// Notes added after the first pool, in the order they were added. New notes go here, at the end.
    static let added: [Note] = [
        Note("okafor.cream", from: .okafor, when: .eggBookHas(.cream))
    ]

    public static func note(_ id: String) -> Note? { pool.first { $0.id == id } }
}

extension Engine {
    /// The night's post: maybe one note, from the notes that fit and have not come before.
    /// Seeded from the shop seed and the day: no game RNG.
    static func deliverPost(_ s: inout GameState, pool: [Note] = Notes.pool) -> [GameEvent] {
        var rng = SeededRNG(seed: s.shopSeed ^ 0x504F_5354 ^ UInt64(truncatingIfNeeded: s.day))  // "POST"
        guard Double.roll(s.rules.noteChance, using: &rng) else { return [] }
        let fits = pool.filter { !s.notesSeen.contains($0.id) && $0.condition.holds(in: s) }
        guard let note = fits.randomElement(using: &rng) else { return [] }
        s.notesSeen.insert(note.id)
        return [.noteArrived(note.from, note.id)]
    }
}
