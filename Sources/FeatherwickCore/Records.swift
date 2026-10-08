import Foundation

// The flock record book: numbers the keeper already made, in one place.
//
// Most of it is read from state that already exists: birds' `origin`, the rehomed list, show results.
// Eggs are the exception. Sold, set and hatched eggs leave the nest and carton, so the egg lists keep
// no history. Each hen's laying is therefore counted as she lays (`GameState.layRecords`).
//
// Rule 8: eggs and ribbons are things the keeper saw. Nothing here reads a gene, inbreeding or a
// quantitative trait. A chick whose sex does not show yet is never listed as a hen.
// Recording draws nothing from the game RNG, so seeded games stay the same.

/// One hen's laying history. Kept after she is rehomed, so her total stays.
public struct HenLayRecord: Hashable, Codable, Sendable {
    public let henID: UUID
    /// Every egg she laid in the nest, sold and set eggs included. Broken floor eggs do not count.
    public var eggsLaid: Int
    public var firstEggDay: Int
    /// The days of her recent eggs, oldest first, trimmed to `Rules.recordWindowDays`.
    public var recentLayDays: [Int]

    public init(henID: UUID, eggsLaid: Int, firstEggDay: Int, recentLayDays: [Int]) {
        self.henID = henID
        self.eggsLaid = eggsLaid
        self.firstEggDay = firstEggDay
        self.recentLayDays = recentLayDays
    }
}

/// One line of the "Eggs" table.
public struct EggRecordRow: Hashable, Sendable {
    public let henID: UUID
    public let name: String
    /// Nil: a visible hen who has not laid yet ("none yet", not 0).
    public let total: Int?
    /// Eggs in the last `Rules.recordWindowDays` days. Nil when she has not laid yet.
    public let recent: Int?
    public let firstEggDay: Int?
    /// True when she lives in Featherwick now. Her eggs still count.
    public let rehomed: Bool
}

/// One line of the "Ribbons" table: a bird and its 1st, 2nd and 3rd places in bird classes.
public struct RibbonRecordRow: Hashable, Sendable {
    /// Nil for an old result that names a bird no longer on record.
    public let birdID: UUID?
    public let name: String
    public let firsts: Int
    public let seconds: Int
    public let thirds: Int
    public var total: Int { firsts + seconds + thirds }
}

/// The "The flock" table.
public struct FlockFacts: Hashable, Sendable {
    /// Every bird the keeper owns now, lost and boarding birds included.
    public let birdsNow: Int
    /// Birds that hatched at home, wherever they are now.
    public let hatchedHere: Int
    /// Birds bought at Speckle & Down.
    public let bought: Int
    public let rehomed: Int
    /// Hens at home past laying age.
    public let retired: Int
    public let firstHatchDay: Int?
    public let firstRibbonDay: Int?
    public let daysKept: Int
}

/// The whole record book, ready to show.
public struct FlockRecords: Hashable, Sendable {
    public let eggs: [EggRecordRow]
    public let ribbons: [RibbonRecordRow]
    public let flock: FlockFacts
    /// The window behind "last N days".
    public let windowDays: Int
}

public enum Records {
    // MARK: - Recording (called by the engine)

    /// Notes one egg laid by `henID` on `day`. No randomness.
    static func noteLaid(by henID: UUID, onDay day: Int, _ s: inout GameState) {
        let window = s.rules.recordWindowDays
        if let i = s.layRecords.firstIndex(where: { $0.henID == henID }) {
            s.layRecords[i].eggsLaid += 1
            s.layRecords[i].firstEggDay = min(s.layRecords[i].firstEggDay, day)
            s.layRecords[i].recentLayDays.append(day)
            s.layRecords[i].recentLayDays.removeAll { $0 <= day - window }
        } else {
            s.layRecords.append(HenLayRecord(henID: henID, eggsLaid: 1, firstEggDay: day, recentLayDays: [day]))
        }
    }

    /// A save from before the record book has no egg history. The eggs still in the nest, the carton and
    /// the clutches are the only history left, so they start each hen's record. Eggs from outside the
    /// flock (bought fertile eggs) have a mother the keeper never owned, and do not count.
    static func backFill(_ s: inout GameState) {
        let eggs = (s.nest + s.carton + s.clutches.flatMap(\.eggs)).sorted {
            ($0.layDay, $0.id.uuidString) < ($1.layDay, $1.id.uuidString)
        }
        for egg in eggs where s.bird(egg.motherID) != nil {
            noteLaid(by: egg.motherID, onDay: egg.layDay, &s)
        }
    }

    // MARK: - Reading

    public static func of(_ s: GameState) -> FlockRecords {
        FlockRecords(
            eggs: eggRows(s), ribbons: ribbonRows(s), flock: flockFacts(s), windowDays: s.rules.recordWindowDays)
    }

    /// Hens who laid (home or rehomed), most eggs first, then visible hens at home with none yet.
    public static func eggRows(_ s: GameState) -> [EggRecordRow] {
        let from = s.day - s.rules.recordWindowDays
        let rehomed = Set(s.rehomed.map(\.id))
        let laid: [EggRecordRow] = s.layRecords.compactMap { r in
            guard let hen = s.bird(r.henID) else { return nil }
            return EggRecordRow(
                henID: r.henID, name: hen.name, total: r.eggsLaid,
                recent: r.recentLayDays.count(where: { $0 > from }), firstEggDay: r.firstEggDay,
                rehomed: rehomed.contains(r.henID))
        }
        let haveLaid = Set(s.layRecords.map(\.henID))
        // Only hens whose sex shows. An unrevealed chick is never listed, so the table cannot tell her sex.
        let waiting = s.ownedBirds.filter { $0.revealed && $0.sex == .hen && !haveLaid.contains($0.id) }
            .map {
                EggRecordRow(henID: $0.id, name: $0.name, total: nil, recent: nil, firstEggDay: nil, rehomed: false)
            }
        let sortedLaid = laid.sorted {
            (-($0.total ?? 0), $0.name, $0.henID.uuidString) < (-($1.total ?? 0), $1.name, $1.henID.uuidString)
        }
        return sortedLaid + waiting.sorted { ($0.name, $0.henID.uuidString) < ($1.name, $1.henID.uuidString) }
    }

    /// Birds with at least one ribbon (1st to 3rd) in a bird class, most ribbons first.
    /// Egg plates have no bird, so they are not here (they still count for the first ribbon day).
    public static func ribbonRows(_ s: GameState) -> [RibbonRecordRow] {
        struct Key: Hashable {
            let id: UUID?
            let name: String
        }
        let everyBird = everOwned(s)
        var counts: [Key: [Int]] = [:]
        var order: [Key] = []
        for r in s.showResults where (1...3).contains(r.placing) {
            if case .eggs = r.showClass { continue }
            // Results from before `birdID` existed match by name, like `GameState.ribbons(for:)`.
            let id = r.birdID ?? everyBird.first { $0.name == r.entrantName }?.id
            // A bird on record is one row under its current name. Otherwise the result's name is the row.
            let key = Key(id: id, name: id == nil ? r.entrantName : "")
            if counts[key] == nil {
                counts[key] = [0, 0, 0]
                order.append(key)
            }
            counts[key]?[r.placing - 1] += 1
        }
        let rows = order.map { key -> RibbonRecordRow in
            let c = counts[key] ?? [0, 0, 0]
            let name = key.id.flatMap { s.bird($0)?.name } ?? key.name
            return RibbonRecordRow(birdID: key.id, name: name, firsts: c[0], seconds: c[1], thirds: c[2])
        }
        return rows.sorted {
            (-$0.firsts, -$0.seconds, -$0.thirds, $0.name) < (-$1.firsts, -$1.seconds, -$1.thirds, $1.name)
        }
    }

    public static func flockFacts(_ s: GameState) -> FlockFacts {
        let every = everOwned(s)
        let home = every.filter { $0.origin == Bird.homeOrigin }
        let ribbonDays = s.showResults.filter { (1...3).contains($0.placing) }.map(\.day)
        return FlockFacts(
            birdsNow: s.ownedBirds.count,
            hatchedHere: home.count,
            bought: every.count(where: { $0.origin == Bird.shopOrigin }),
            rehomed: s.rehomed.count,
            retired: s.ownedBirds.count(where: { $0.isRetired(onDay: s.day, rules: s.rules) }),
            firstHatchDay: home.map(\.hatchDay).min(),
            firstRibbonDay: ribbonDays.min(),
            daysKept: max(0, s.day))
    }

    /// Every bird the keeper has had: owned now, or rehomed (a traded rooster is rehomed too).
    static func everOwned(_ s: GameState) -> [Bird] { s.ownedBirds + s.rehomed }
}
