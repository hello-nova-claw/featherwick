import Foundation

/// A whole saved game: the state and the random generator, so a loaded game continues exactly.
public struct SaveGame: Codable, Sendable {
    public var state: GameState
    public var rng: SeededRNG

    public init(state: GameState, rng: SeededRNG) {
        self.state = state
        self.rng = rng
    }
}

/// Save files: a version number, and migrations that bring old saves up to date.
///
/// A save is `{ "version": n, "state": …, "rng": … }`. Version 0 is the first CLI format, with no version key.
///
/// When to add a migration: only when existing data must CHANGE SHAPE (a field renamed or moved).
/// A new gene, a new breed or a new optional field needs no migration.
/// To add one: bump `currentVersion` and add `migrations[old]`, which edits the raw JSON of an `old` save.
public enum SaveFormat {
    public static let currentVersion = 2

    public enum LoadError: Error, Equatable, Sendable {
        /// The data is not a Featherwick save.
        case notASave
        /// The save is from a newer version of the game. Do not overwrite it.
        case tooNew(version: Int)
        /// No migration from this version (a bug: every old version needs one).
        case noMigration(from: Int)
    }

    public typealias Migration = @Sendable (inout [String: Any]) throws -> Void

    /// `migrations[n]` turns a version-n save into a version-(n+1) save.
    public static let migrations: [Int: Migration] = [
        0: migrateGenomesToRegistry,
        1: migrateToOneSetting,
    ]

    private struct Envelope: Codable {
        var version: Int
        var state: GameState
        var rng: SeededRNG
    }

    private struct Probe: Decodable {
        var version: Int?
    }

    public static func encode(_ save: SaveGame) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Envelope(version: currentVersion, state: save.state, rng: save.rng))
    }

    public static func decode(_ data: Data) throws -> SaveGame {
        try decode(data, migrations: migrations, currentVersion: currentVersion)
    }

    /// Loads a save of any known version. Old saves are migrated step by step to `currentVersion`.
    static func decode(_ data: Data, migrations: [Int: Migration], currentVersion: Int) throws -> SaveGame {
        guard let probe = try? JSONDecoder().decode(Probe.self, from: data) else { throw LoadError.notASave }
        let version = probe.version ?? 0
        if version > currentVersion { throw LoadError.tooNew(version: version) }

        guard var root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            root["state"] is [String: Any]
        else { throw LoadError.notASave }
        for v in version..<currentVersion {
            guard let migrate = migrations[v] else { throw LoadError.noMigration(from: v) }
            try migrate(&root)
        }
        root["version"] = currentVersion
        // Read before `fillNewSettings`, which would fill the key with an empty list.
        let hasLayRecords = (root["state"] as? [String: Any])?["layRecords"] != nil
        fillNewSettings(&root)
        keepNumbersInBounds(&root)
        let current = try JSONSerialization.data(withJSONObject: root)
        guard var envelope = try? JSONDecoder().decode(Envelope.self, from: current) else { throw LoadError.notASave }
        mendRules(&envelope.state)
        if !hasLayRecords { backFillLayRecords(&envelope.state) }
        return SaveGame(state: envelope.state, rng: envelope.rng)
    }

    // MARK: - Hand-edited saves

    /// The largest number a rule may hold. Far above any real rule, and small enough that rules
    /// multiplied together or added up every day never overflow an `Int`.
    public static let maxRuleNumber = 1_000_000
    /// The largest number (either sign) anywhere else in the state: coins, days, counts.
    /// A game would take millions of years to reach it, so only a hand edit ever does.
    public static let maxStateNumber = 1_000_000_000
    /// The most rivals a show class may hold, and the most a judge may pick. Each rival is a whole bird
    /// made on show day, so a hand-edited million would stall the show. Far above any real class.
    public static let maxShowEntrants = 100
    /// State keys whose numbers are seeds, not amounts. Their whole 64-bit range is real.
    static let seedKeys: Set<String> = ["shopSeed"]
    /// Counts that are never below 0 in play.
    static let countKeys = [
        "day", "coins", "treats", "premiumFeed", "perches", "nestBoxes", "brooderSize", "cartons",
        "incubatorSize", "chicksHatched", "slotsUsed", "sexGuessesRight",
    ]

    /// A hand-edited save can hold any number, and the engine would trap on the next `+=` (coins at
    /// `Int.max`). So every number is kept in bounds before the state is decoded: rules to
    /// 0...`maxRuleNumber`, everything else to ±`maxStateNumber`, counts to 0 or more. A save written
    /// by the game never holds a number out of bounds, so this changes nothing in it.
    static func keepNumbersInBounds(_ root: inout [String: Any]) {
        guard var state = root["state"] as? [String: Any] else { return }
        for (key, value) in state where !seedKeys.contains(key) {
            if key == "rules" {
                state[key] = clampNumbers(in: value, to: 0...maxRuleNumber)
            } else {
                state[key] = clampNumbers(in: value, to: -maxStateNumber...maxStateNumber)
            }
        }
        for key in countKeys {
            if let number = state[key].flatMap(jsonNumber), number < 0 { state[key] = 0 }
        }
        root["state"] = state
    }

    /// Every JSON number in `value`, at any depth, kept in `bounds`. A number in bounds is left exactly as
    /// it is (so a `Bool`, which JSON may read as 0 or 1, is never changed).
    static func clampNumbers(in value: Any, to bounds: ClosedRange<Int>) -> Any {
        if let object = value as? [String: Any] { return object.mapValues { clampNumbers(in: $0, to: bounds) } }
        if let array = value as? [Any] { return array.map { clampNumbers(in: $0, to: bounds) } }
        guard let number = jsonNumber(value) else { return value }
        if number < Double(bounds.lowerBound) { return bounds.lowerBound }
        if number > Double(bounds.upperBound) { return bounds.upperBound }
        return value
    }

    /// A JSON number as a `Double`, near enough to compare with a bound. `as? Double` alone fails for a
    /// whole number a `Double` cannot hold exactly, such as `Int.max`, so read the `NSNumber`.
    static func jsonNumber(_ value: Any) -> Double? {
        if value is String { return nil }
        if let number = value as? NSNumber { return number.doubleValue }
        if let number = value as? Int { return Double(number) }
        return value as? Double
    }

    /// Rules that only make sense together. A hand edit can break them, and the engine would trap:
    /// a random range with its max below its min, or a division by 0.
    static func mendRules(_ state: inout GameState) {
        var r = state.rules
        r.lostDaysMax = max(r.lostDaysMin, r.lostDaysMax)
        r.marketCardsMax = max(r.marketCardsMin, r.marketCardsMax)
        r.marketBuyerMaxDays = max(r.marketBuyerMinDays, r.marketBuyerMaxDays)
        r.daysPerSeason = max(1, r.daysPerSeason)
        r.hensPerRooster = max(1, r.hensPerRooster)
        r.showCompetitorsByKind = r.showCompetitorsByKind.mapValues { min($0, maxShowEntrants) }
        r.showRivalPicks = r.showRivalPicks.mapValues { min($0, maxShowEntrants) }
        r.winterChampionshipExtraPicks = min(r.winterChampionshipExtraPicks, maxShowEntrants)
        state.rules = r
    }

    /// A save from before the record book has no `layRecords` key. Its egg history starts from the eggs
    /// it still holds (see `Records.backFill`). Runs only when the key is missing, so a save's own records
    /// are never changed. Not in `fillNewSettings`: that copies raw JSON values, and this needs typed eggs.
    /// Not in `migrations`: no existing data changes shape, so the save version stays the same.
    static func backFillLayRecords(_ state: inout GameState) {
        Records.backFill(&state)
    }

    /// A save made before a game-state field or a rule existed gets that field's starting value.
    /// So adding a field to GameState or Rules needs no migration.
    static func fillNewSettings(_ root: inout [String: Any]) {
        guard var state = root["state"] as? [String: Any],
            let fresh = try? JSONSerialization.jsonObject(
                with: JSONEncoder().encode(GameState(rules: .standard, phase: .playing))) as? [String: Any]
        else { return }
        for (key, value) in fresh where state[key] == nil { state[key] = value }
        // Story progress from before choices has no `chosen`: no choice made yet.
        if var stories = state["stories"] as? [String: Any] {
            for (id, value) in stories {
                guard var progress = value as? [String: Any], progress["chosen"] == nil else { continue }
                progress["chosen"] = [String: Any]()
                stories[id] = progress
            }
            state["stories"] = stories
        }
        if var rules = state["rules"] as? [String: Any], let freshRules = fresh["rules"] as? [String: Any] {
            for (key, value) in freshRules where rules[key] == nil { rules[key] = value }
            state["rules"] = rules
        }
        root["state"] = state
    }

    /// Calls `change` on every JSON object, at any depth, that `match` accepts.
    /// Use it in migrations: genomes, for example, sit inside birds, eggs, clutches and trade offers.
    public static func transformObjects(
        in value: Any, where match: ([String: Any]) -> Bool, _ change: (inout [String: Any]) -> Void
    ) -> Any {
        if var object = value as? [String: Any] {
            for (key, child) in object { object[key] = transformObjects(in: child, where: match, change) }
            if match(object) { change(&object) }
            return object
        }
        if let array = value as? [Any] { return array.map { transformObjects(in: $0, where: match, change) } }
        return value
    }

    // MARK: - Migrations

    /// v0 → v1: genomes had one field per gene. Now they are stored by locus name (see `Loci`).
    ///
    ///     v0: { "sexChromosomes": { "hen": { "z": "B" } }, "feathering": { "first": "H", "second": "h" }, … }
    ///     v1: { "sex": "hen", "z": { "barring": ["B"] }, "autosomal": { "feathering": { "first": "H", "second": "h" }, … } }
    ///
    /// The v0 field names are the v1 locus names, so autosomal genes move across unchanged.
    static func migrateGenomesToRegistry(_ root: inout [String: Any]) throws {
        let migrated = transformObjects(in: root, where: { $0["sexChromosomes"] != nil }) { genome in
            var z: [String: Any] = [:]
            var sex: String?
            let chromosomes = genome["sexChromosomes"] as? [String: Any] ?? [:]
            if let hen = chromosomes["hen"] as? [String: Any] {
                sex = "hen"
                if let b = hen["z"] as? String { z[Barring.locus.rawValue] = [b] }
            } else if let rooster = chromosomes["rooster"] as? [String: Any] {
                sex = "rooster"
                if let pair = rooster["z"] as? [String: Any],
                    let a = pair["first"] as? String, let b = pair["second"] as? String
                {
                    z[Barring.locus.rawValue] = [a, b]
                }
            }
            var autosomal: [String: Any] = [:]
            for (key, value) in genome where key != "sexChromosomes" { autosomal[key] = value }
            genome = ["autosomal": autosomal, "z": z]
            if let sex { genome["sex"] = sex }
        }
        guard let object = migrated as? [String: Any] else { throw LoadError.notASave }
        root = object
    }

    /// The rules that the old Relaxed and Challenge presets changed.
    static let oldPresetRules = [
        "layChance", "fertileChance", "foxChance", "fleeChance", "lostDaysMax", "lostDaysCap",
        "pulletPrice", "incubatorPrice", "coopUpgradePrice",
    ]

    /// v1 → v2: the game has one setting now. A game started on Relaxed or Challenge plays by the
    /// standard rules from here. Its birds, coins and progress stay.
    static func migrateToOneSetting(_ root: inout [String: Any]) throws {
        guard var state = root["state"] as? [String: Any] else { throw LoadError.notASave }
        guard var rules = state["rules"] as? [String: Any] else { return }
        let standard = try JSONEncoder().encode(Rules.standard)
        guard let fresh = try JSONSerialization.jsonObject(with: standard) as? [String: Any] else { return }
        for key in oldPresetRules { rules[key] = fresh[key] }
        state["rules"] = rules
        root["state"] = state
    }
}
