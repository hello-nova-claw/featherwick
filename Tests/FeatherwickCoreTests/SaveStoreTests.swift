import Foundation
import Testing

@testable import FeatherwickCore

/// Save robustness: atomic writes, rolling backups, and never losing an unreadable file.
struct SaveStoreTests {
    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fw-savetest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func sampleSave(_ seed: UInt64) throws -> Data {
        var rng = SeededRNG(seed: seed)
        return try SaveFormat.encode(SaveGame(state: Engine.newGame(using: &rng), rng: rng))
    }

    @Test func atomicWriteRoundTrips() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir, slot: "test")
        let data = try sampleSave(1)
        try store.write(data)
        let back = try #require(try store.read())
        #expect(try SaveFormat.decode(back).state == SaveFormat.decode(data).state)
    }

    @Test func aBadMainStillLeavesAGoodBackup() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir, slot: "test")
        let good = try sampleSave(2)
        try store.write(good)  // first save (no backup yet)
        try store.write(good)  // rotates the good copy into bak1
        try Data("not a save".utf8).write(to: store.url)  // main is now corrupt
        let backup = try #require(store.newestBackupData())
        #expect((try? SaveFormat.decode(backup)) != nil)  // the backup is still a real save
    }

    @Test func quarantineKeepsTheUnreadableFile() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir, slot: "test")
        try Data("garbage".utf8).write(to: store.url)
        let moved = try #require(store.quarantine())
        #expect(!store.exists)  // moved out of the way
        #expect(FileManager.default.fileExists(atPath: moved.path))  // but never deleted
    }

    @Test func listsNamedSlotsOnly() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let data = try sampleSave(3)
        try SaveStore(directory: dir, slot: "alpha").write(data)
        try SaveStore(directory: dir, slot: "alpha").write(data)  // makes alpha.bak1.json
        try SaveStore(directory: dir, slot: "beta").write(data)
        let slots = SaveStore.slots(in: dir)
        #expect(slots == ["alpha", "beta"])  // backups excluded
    }
}
