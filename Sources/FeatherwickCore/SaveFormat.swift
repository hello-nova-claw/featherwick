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
        // A save from before the record book: its egg history starts from the eggs it still holds.
        let hasLayRecords = (root["state"] as? [String: Any])?["layRecords"] != nil
        fillNewSettings(&root)
        let current = try JSONSerialization.data(withJSONObject: root)
        guard var envelope = try? JSONDecoder().decode(Envelope.self, from: current) else { throw LoadError.notASave }
        if !hasLayRecords { Records.backFill(&envelope.state) }
        return SaveGame(state: envelope.state, rng: envelope.rng)
    }

    /// A save made before a game-state field or a rule existed gets that field's starting value.
    /// So adding a field to GameState or Rules needs no migration.
    static func fillNewSettings(_ root: inout [String: Any]) {
        guard var state = root["state"] as? [String: Any],
            let fresh = try? JSONSerialization.jsonObject(
                with: JSONEncoder().encode(GameState(rules: .standard, phase: .playing))) as? [String: Any]
        else { return }
        for (key, value) in fresh where state[key] == nil { state[key] = value }
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
