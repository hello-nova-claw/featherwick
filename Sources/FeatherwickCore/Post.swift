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
    /// Every note that can come in the post. Append, never insert: the seeded pick reads list order.
    public static let pool: [Note] = []

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
