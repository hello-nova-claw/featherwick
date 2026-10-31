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

    // MARK: - Loading and recovery (#59)

    /// Every file in the folder and its bytes, to show a load changed nothing.
    private func contents(of dir: URL) throws -> [String: Data] {
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        return try Dictionary(
            uniqueKeysWithValues: names.map { ($0, try Data(contentsOf: dir.appendingPathComponent($0))) })
    }

    @Test func aSaveFromANewerGameIsLeftExactlyAsItIs() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir, slot: "test")
        let future = try SaveFormatTests.fixture("save-v99")
        try future.write(to: store.url)
        try future.write(to: store.backupURL(1))
        try Data("an old quarantine".utf8).write(to: store.corruptURL())
        let before = try contents(of: dir)
        let (save, recovery) = store.load()
        #expect(save == nil)
        #expect(recovery == .tooNew(version: 99))
        #expect(try contents(of: dir) == before)  // nothing moved, rotated or written
    }

    /// A newer game's backup is as precious as its main save: the unreadable main stays put too.
    @Test func aNewerBackupStopsTheLoadBeforeAnyQuarantine() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir, slot: "test")
        try Data("garbage".utf8).write(to: store.url)
        try SaveFormatTests.fixture("save-v99").write(to: store.backupURL(2))
        try sampleSave(4).write(to: store.backupURL(1))
        let before = try contents(of: dir)
        #expect(store.load().recovery == .tooNew(version: 99))
        #expect(try contents(of: dir) == before)
    }

    /// A good main save does not hide a newer backup: the next write would rotate that backup out.
    @Test func aNewerBackupStopsTheLoadEvenWithAGoodMainSave() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir, slot: "test")
        try sampleSave(7).write(to: store.url)
        try SaveFormatTests.fixture("save-v99").write(to: store.backupURL(1))
        let before = try contents(of: dir)
        let (save, recovery) = store.load()
        #expect(save == nil)
        #expect(recovery == .tooNew(version: 99))
        #expect(try contents(of: dir) == before)
    }

    @Test func aGoodMainSaveLoads() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir, slot: "test")
        try store.write(try SaveFormatTests.fixture("save-v0"))  // the oldest save still loads
        let (save, recovery) = store.load()
        #expect(save != nil)
        #expect(recovery == .loaded)
    }

    @Test func anEmptySlotHasNoSave() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (save, recovery) = SaveStore(directory: dir, slot: "test").load()
        #expect(save == nil)
        #expect(recovery == .noSave)
    }

    @Test func aMissingMainSaveComesBackFromTheBackup() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir, slot: "test")
        try sampleSave(5).write(to: store.backupURL(2))
        let (save, recovery) = store.load()
        #expect(save != nil)
        #expect(recovery == .restoredFromBackup)
    }

    @Test func anUnreadableSaveIsKeptAndTheBackupLoads() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir, slot: "test")
        let good = try sampleSave(6)
        try store.write(good)
        try store.write(good)  // good copy in bak1
        try Data("not a save".utf8).write(to: store.url)
        let (save, recovery) = store.load()
        #expect(try save?.state == SaveFormat.decode(good).state)
        #expect(recovery == .unreadable(keptAs: store.corruptURL(), restoredFromBackup: true))
        #expect(try Data(contentsOf: store.corruptURL()) == Data("not a save".utf8))
    }

    @Test func anUnreadableSaveWithNoBackupStartsANewGame() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir, slot: "test", backupCount: 0)
        try Data("garbage".utf8).write(to: store.url)
        let (save, recovery) = store.load()
        #expect(save == nil)
        #expect(recovery == .unreadable(keptAs: store.corruptURL(), restoredFromBackup: false))
    }

    @Test func twoUnreadableSavesLeaveTwoQuarantineFiles() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir, slot: "test")
        try Data("first".utf8).write(to: store.url)
        _ = store.load()
        try Data("second".utf8).write(to: store.url)
        #expect(store.load().recovery == .unreadable(keptAs: store.corruptURL(2), restoredFromBackup: false))
        #expect(try Data(contentsOf: store.corruptURL()) == Data("first".utf8))
        #expect(try Data(contentsOf: store.corruptURL(2)) == Data("second".utf8))
        #expect(SaveStore.slots(in: dir).isEmpty)  // quarantines are not slots
    }

    // MARK: - Slot names (#69)

    /// A slot name from the CLI's `--slot`, the in-game `slot` command or the app is cleaned the same way,
    /// so no name can point outside the save folder.
    @Test(arguments: [
        ("../x", "x"), ("../../etc/passwd", "etcpasswd"), ("a/b", "ab"), ("/tmp/save", "tmpsave"),
        ("my save", "mysave"), ("hen-1_b", "hen-1_b"),
    ])
    func aSlotNameIsCleaned(_ raw: String, _ clean: String) {
        let store = SaveStore(directory: tempDir(), slot: raw)
        #expect(store.slot == clean)
        #expect(store.url.deletingLastPathComponent().standardizedFileURL == store.directory.standardizedFileURL)
    }

    @Test(arguments: ["", "..", "../", "/", ". ."])
    func aSlotNameWithNothingLeftIsTheDefault(_ raw: String) {
        #expect(SaveStore(directory: tempDir(), slot: raw).slot == SaveStore.defaultSlot)
    }

    @Test func aSlotThatClimbsOutStillWritesInsideTheFolder() throws {
        let parent = tempDir()
        defer { try? FileManager.default.removeItem(at: parent) }
        let dir = parent.appendingPathComponent("saves")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try SaveStore(directory: dir, slot: "../x").write(try sampleSave(5))
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("x.json").path))
        #expect(!FileManager.default.fileExists(atPath: parent.appendingPathComponent("x.json").path))
    }
}
