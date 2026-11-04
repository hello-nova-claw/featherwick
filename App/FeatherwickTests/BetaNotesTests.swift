import FeatherwickCore
import Foundation
import Testing

@testable import Featherwick

/// A beta notes file that cannot be read is kept aside, never replaced by an empty one (#69).
@MainActor @Suite struct BetaNotesTests {
    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fw-beta-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func anUnreadableFileIsKeptAside() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("beta-notes.json")
        let broken = Data(#"{"answers": [{"moment": "firstHatch""#.utf8)
        try broken.write(to: file)

        let notes = BetaNotes.read(at: file)
        #expect(notes.answers.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(try Data(contentsOf: dir.appendingPathComponent("beta-notes.corrupt.json")) == broken)
    }

    @Test func aSecondUnreadableFileKeepsTheFirst() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("beta-notes.json")
        try Data("first".utf8).write(to: file)
        _ = BetaNotes.read(at: file)
        try Data("second".utf8).write(to: file)
        _ = BetaNotes.read(at: file)
        #expect(try Data(contentsOf: dir.appendingPathComponent("beta-notes.corrupt.json")) == Data("first".utf8))
        #expect(try Data(contentsOf: dir.appendingPathComponent("beta-notes.corrupt2.json")) == Data("second".utf8))
    }

    @Test func aGoodFileReadsAndStaysPut() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("beta-notes.json")
        let good = Data(#"{"asked": {"main": ["firstHatch"]}, "answers": []}"#.utf8)
        try good.write(to: file)
        #expect(BetaNotes.read(at: file).asked["main"] == [.firstHatch])
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path) == ["beta-notes.json"])
    }

    @Test func noFileIsNoNotes() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(BetaNotes.read(at: dir.appendingPathComponent("beta-notes.json")).answers.isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    }
}
