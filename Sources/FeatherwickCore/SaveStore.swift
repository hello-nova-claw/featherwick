import Foundation

/// Where save games live on disk, with atomic writes and rolling backups so a crash or a bad write
/// can never destroy the only copy. One store points at one slot; a game can keep many slots.
///
/// - Atomic write: the new file is written whole then swapped in, so a crash mid-write leaves the
///   previous save intact (a half-written file is never seen).
/// - Rolling backups: the current good copy is rotated into `…bak1`, `…bak2` before each write, so a
///   write that completes but holds bad content still leaves an earlier good save to fall back to.
/// - Quarantine: an unreadable save is moved aside, never deleted, so nothing is ever lost silently.
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
    public var corruptURL: URL { directory.appendingPathComponent("\(slot).corrupt.json") }

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
    /// Returns where it was moved, if anything was moved.
    @discardableResult
    public func quarantine() -> URL? {
        guard exists else { return nil }
        let fm = FileManager.default
        try? fm.removeItem(at: corruptURL)
        do { try fm.moveItem(at: url, to: corruptURL); return corruptURL } catch { return nil }
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
