import FeatherwickCore
import Foundation
import Testing

@testable import Featherwick

/// A save from a newer Featherwick is never written over (#59).
@MainActor @Suite struct GameStoreSaveTests {
    private let future = Data(#"{"version": 99, "state": {}, "rng": {"state": 1}}"#.utf8)

    @Test func aNewerSaveShowsTheNoteAndIsNeverWritten() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fw-newer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let slot = "newer-\(UUID().uuidString)"
        let saves = SaveStore(directory: dir, slot: slot)
        try future.write(to: saves.url)

        let store = GameStore(directory: dir, slot: slot)
        #expect(store.saveTooNew == 99)
        store.run(.feed)
        store.newGame()
        #expect(try Data(contentsOf: saves.url) == future)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path) == ["\(slot).json"])
    }
}
