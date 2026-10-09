import Foundation
import Testing

@testable import FeatherwickCore

struct SaveFormatTests {
    static func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    static func busyGame() -> SaveGame {
        var rng = SeededRNG(seed: 77)
        var s = Engine.newGame(using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        for _ in 0..<40 {
            for c in [Command.feed, .collectEggs, .closeCoop] { _ = Engine.apply(c, to: &s, using: &rng) }
            sleepTonight(&s, &rng)
        }
        return SaveGame(state: s, rng: rng)
    }

    @Test func roundTripKeepsEverything() throws {
        let game = Self.busyGame()
        let loaded = try SaveFormat.decode(SaveFormat.encode(game))
        // Rules hold a breed-keyed dictionary, which JSON writes as an array in hash order. Compare it alone.
        #expect(loaded.state.rules.broodyChance == game.state.rules.broodyChance)
        // Sets are written in hash order too.
        #expect(loaded.state.introduced == game.state.introduced)
        #expect(loaded.state.notesSeen == game.state.notesSeen)
        var same = loaded.state
        same.rules = game.state.rules
        same.introduced = game.state.introduced
        same.notesSeen = game.state.notesSeen
        let sorted = JSONEncoder()
        sorted.outputFormatting = .sortedKeys
        #expect(try sorted.encode(same) == sorted.encode(game.state))
        #expect(loaded.state.ownedBirds == game.state.ownedBirds)
        #expect(loaded.rng == game.rng)
    }

    @Test func newSavesCarryTheVersion() throws {
        let json = try JSONSerialization.jsonObject(with: SaveFormat.encode(Self.busyGame())) as? [String: Any]
        #expect(json?["version"] as? Int == SaveFormat.currentVersion)
    }

    /// A real save written by the first CLI, before genes moved into the registry.
    @Test func aVersionZeroSaveLoadsWithTheSameBirds() throws {
        let data = try Self.fixture("save-v0")
        let game = try SaveFormat.decode(data)
        #expect(game.state.day == 25)
        #expect(game.rng == SeededRNG(seed: 17_026_080_509_101_393_278))  // big UInt64 survives
        let birds = game.state.ownedBirds
        #expect(birds.contains { $0.sex == .hen } && birds.contains { $0.sex == .rooster })
        // The starter rooster was a black Wyandotte: laced (hidden), brown egg genes.
        let wyandotte = try #require(birds.first { $0.breed == .wyandotte })
        #expect(wyandotte.genome.lacing.isHomozygous(for: .laced))
        #expect(wyandotte.genome.brownShell.isHomozygous(for: .brown))
        #expect(wyandotte.phenotype.colour == .black)
    }

    @Test func anOldSaveKeepsItsCandlingSkill() throws {
        #expect(try SaveFormat.decode(Self.fixture("save-v0")).state.canCandle)
    }

    @Test func aLoadedOldSaveKeepsPlaying() throws {
        var game = try SaveFormat.decode(Self.fixture("save-v0"))
        for _ in 0..<30 { _ = sleepTonight(&game.state, &game.rng) }
        #expect(!game.state.ownedBirds.isEmpty)
        #expect(InvariantTests.problems(in: game.state).isEmpty)
    }

    @Test func aSaveFromANewerGameIsRefused() throws {
        var json = try #require(
            JSONSerialization.jsonObject(with: SaveFormat.encode(Self.busyGame())) as? [String: Any])
        json["version"] = SaveFormat.currentVersion + 1
        let data = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: SaveFormat.LoadError.tooNew(version: SaveFormat.currentVersion + 1)) {
            try SaveFormat.decode(data)
        }
    }

    /// The game had Relaxed and Challenge settings once. Such a game now plays by the standard rules.
    @Test func anOldRelaxedGameSwitchesToTheStandardRules() throws {
        let game = Self.busyGame()
        var json = try #require(JSONSerialization.jsonObject(with: SaveFormat.encode(game)) as? [String: Any])
        var state = try #require(json["state"] as? [String: Any])
        var rules = try #require(state["rules"] as? [String: Any])
        rules["foxChance"] = 0.3
        rules["pulletPrice"] = 20
        rules["lostDaysCap"] = 10
        state["rules"] = rules
        json["state"] = state
        json["version"] = 1
        let loaded = try SaveFormat.decode(JSONSerialization.data(withJSONObject: json))
        #expect(loaded.state.rules.foxChance == Rules.standard.foxChance)
        #expect(loaded.state.rules.pulletPrice == Rules.standard.pulletPrice)
        #expect(loaded.state.rules.lostDaysCap == Rules.standard.lostDaysCap)
        #expect(loaded.state.rules.layChance == Rules.standard.layChance)
        // Birds, coins and progress stay.
        #expect(loaded.state.coins == game.state.coins)
        #expect(loaded.state.day == game.state.day)
        #expect(loaded.state.ownedBirds == game.state.ownedBirds)
    }

    @Test(arguments: ["", "[]", "{}", "{\"version\": 1}", "not json"])
    func junkIsNotASave(_ text: String) {
        #expect(throws: SaveFormat.LoadError.notASave) { try SaveFormat.decode(Data(text.utf8)) }
    }
}
