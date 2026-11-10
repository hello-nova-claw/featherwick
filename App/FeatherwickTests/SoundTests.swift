import Foundation
import Testing

@testable import Featherwick

/// Settings shows the Sound switch only when a sound file is bundled. A switch that changes nothing
/// would confuse the keeper and an App Store reviewer.
@Suite struct SoundTests {
    /// A folder read as a bundle, with the given files in it.
    private func bundle(with files: [String]) throws -> Bundle {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        for file in files {
            let url = folder.appendingPathComponent(file)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: url)
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try #require(Bundle(url: folder))
    }

    /// No sound, or only files the game cannot play, keeps the switch hidden.
    @Test func noSoundFilesMeansNoSwitch() throws {
        #expect(!Sound.hasFiles(in: try bundle(with: [])))
        #expect(!Sound.hasFiles(in: try bundle(with: ["moo.caf", "cluck.wav"])))
    }

    /// One `.caf` or `.m4a`, at the top or in `Sounds/`, shows the switch again.
    @Test func oneSoundFileBringsTheSwitchBack() throws {
        #expect(Sound.hasFiles(in: try bundle(with: ["cluck.caf"])))
        #expect(Sound.hasFiles(in: try bundle(with: ["coins.m4a"])))
        #expect(Sound.hasFiles(in: try bundle(with: ["Sounds/hatch.caf"])))
    }
}
