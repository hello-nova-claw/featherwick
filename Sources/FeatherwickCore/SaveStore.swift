import Foundation

/// Where save games live on disk, with atomic writes and rolling backups so a crash or a bad write
/// can never destroy the only copy. One store points at one slot; a game can keep many slots.
///
/// - Atomic write: the new file is written whole then swapped in, so a crash mid-write leaves the
///   previous save intact (a half-written file is never seen).
/// - Rolling backups: the current good copy is rotated into `…bak1`, `…bak2` before each write, so a
///   write that completes but holds bad content still leaves an earlier good save to fall back to.
/// - Quarantine: an unreadable save is moved aside, never deleted, so nothing is ever lost silently.
///   Each one gets its own file, so a second bad load never replaces the first.
/// - Too new: a save from a newer game is never moved, rotated or written over (see `load()`).
public struct SaveStore: Sendable {
    public static let defaultSlot = "featherwick-save"

    public let directory: URL
    public let slot: String
    public let backupCount: Int

    public init(directory: URL, slot: String = SaveStore.defaultSlot, backupCount: Int = 2) {
        self.directory = directory
        self.slot = slot.isEmpty ? SaveStore.defaultSlot : slot
        self.backupCount = max(0, backupCount)
    }

    public var url: URL { directory.appendingPathComponent("\(slot).json") }
    public func backupURL(_ i: Int) -> URL { directory.appendingPathComponent("\(slot).bak\(i).json") }
    /// The n-th quarantined copy: `…corrupt.json`, then `…corrupt2.json`, `…corrupt3.json`.
    public func corruptURL(_ n: Int = 1) -> URL {
        directory.appendingPathComponent(n == 1 ? "\(slot).corrupt.json" : "\(slot).corrupt\(n).json")
    }

    public var exists: Bool { FileManager.default.fileExists(atPath: url.path) }

    public func read() throws -> Data? {
        guard exists else { return nil }
        return try Data(contentsOf: url)
    }

    /// Atomically replaces the save, after rotating the current good copy into the backups.
    public func write(_ data: Data) throws {
        rotateBackups()
        try data.write(to: url, options: .atomic)
    }

    private func rotateBackups() {
        guard backupCount > 0, exists else { return }
        let fm = FileManager.default
        // Shift bak(n-1) → bak(n), dropping the oldest.
        for i in stride(from: backupCount, through: 2, by: -1) {
            try? fm.removeItem(at: backupURL(i))
            try? fm.copyItem(at: backupURL(i - 1), to: backupURL(i))
        }
        // Current main → bak1.
        try? fm.removeItem(at: backupURL(1))
        try? fm.copyItem(at: url, to: backupURL(1))
    }

    /// Moves an unreadable save aside (never deletes it) so a fresh game can start without losing it.
    /// It goes to the first free quarantine name, so an earlier quarantined copy stays too.
    /// Returns where it was moved, if anything was moved.
    @discardableResult
    public func quarantine() -> URL? {
        guard exists else { return nil }
        let fm = FileManager.default
        var n = 1
        while fm.fileExists(atPath: corruptURL(n).path) { n += 1 }
        do {
            try fm.moveItem(at: url, to: corruptURL(n))
            return corruptURL(n)
        } catch { return nil }
    }

    /// What `load()` found, for the front end to turn into words.
    public enum Recovery: Equatable, Sendable {
        /// The main save loaded.
        case loaded
        /// No save in this slot: start a new game.
        case noSave
        /// The main save was missing. The newest backup that loads was used.
        case restoredFromBackup
        /// The main save could not be read. It was moved to `keptAs` (nil if the move failed). The newest
        /// backup that loads was used if there was one; otherwise a new game starts.
        case unreadable(keptAs: URL?, restoredFromBackup: Bool)
        /// A file in this slot is from a newer game. Nothing was touched, and the front end must not
        /// write to this slot: a new game here would rotate the newer save out of the backups.
        case tooNew(version: Int)
    }

    /// Reads the slot: the main save, else the newest backup that loads. Every front end loads through
    /// this, and only turns the `Recovery` into words. The save is nil for `.noSave`, `.tooNew`, and an
    /// unreadable save with no good backup.
    public func load() -> (save: SaveGame?, recovery: Recovery) {
        let main = attempt(url)
        if case .loaded(let save) = main { return (save, .loaded) }
        let backups = backupCount > 0 ? (1...backupCount).map { attempt(backupURL($0)) } : []
        // Checked before any quarantine, so a newer game's files stay exactly as they are.
        if let version = ([main] + backups).compactMap(\.tooNewVersion).max() {
            return (nil, .tooNew(version: version))
        }
        let restored = backups.lazy.compactMap(\.save).first
        if case .missing = main { return (restored, restored == nil ? .noSave : .restoredFromBackup) }
        return (restored, .unreadable(keptAs: quarantine(), restoredFromBackup: restored != nil))
    }

    /// One file, read without changing anything on disk.
    private enum Attempt {
        case missing, unreadable
        case loaded(SaveGame)
        case tooNew(Int)

        var save: SaveGame? { if case .loaded(let s) = self { s } else { nil } }
        var tooNewVersion: Int? { if case .tooNew(let v) = self { v } else { nil } }
    }

    private func attempt(_ file: URL) -> Attempt {
        guard FileManager.default.fileExists(atPath: file.path) else { return .missing }
        guard let data = try? Data(contentsOf: file) else { return .unreadable }
        do {
            return .loaded(try SaveFormat.decode(data))
        } catch SaveFormat.LoadError.tooNew(let version) {
            return .tooNew(version)
        } catch {
            return .unreadable
        }
    }

    /// The most recent readable backup's bytes, if any. Used when the main save is gone or unreadable.
    public func newestBackupData() -> Data? {
        guard backupCount > 0 else { return nil }
        for i in 1...backupCount {
            if let d = try? Data(contentsOf: backupURL(i)) { return d }
        }
        return nil
    }

    /// The names of slots that already have a save in this directory (backups and quarantines excluded).
    public static func slots(in directory: URL) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.compactMap { name in
            guard name.hasSuffix(".json"),
                !name.contains(".bak"), !name.contains(".corrupt"), !name.contains(".old")
            else { return nil }
            return String(name.dropLast(".json".count))
        }.sorted()
    }
}
