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
        #expect(loaded.state.hatchAlongYears == game.state.hatchAlongYears)
        var same = loaded.state
        same.rules = game.state.rules
        same.introduced = game.state.introduced
        same.notesSeen = game.state.notesSeen
        same.hatchAlongYears = game.state.hatchAlongYears
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

    // MARK: - Hand-edited saves (#69)

    /// `busyGame`'s save with some state fields and rules replaced, as a hand-edited file would have them.
    static func edited(state stateChanges: [String: Any] = [:], rules ruleChanges: [String: Any] = [:]) throws -> Data {
        var json = try #require(JSONSerialization.jsonObject(with: SaveFormat.encode(busyGame())) as? [String: Any])
        var state = try #require(json["state"] as? [String: Any])
        var rules = try #require(state["rules"] as? [String: Any])
        for (key, value) in ruleChanges { rules[key] = value }
        for (key, value) in stateChanges { state[key] = value }
        state["rules"] = rules
        json["state"] = state
        return try JSONSerialization.data(withJSONObject: json)
    }

    /// Thirty days with the door left open for the fox, eggs sold and the flock fed.
    static func play(_ game: inout SaveGame) {
        for _ in 0..<30 {
            for c in [Command.feed, .collectEggs, .sellEggs] { _ = Engine.apply(c, to: &game.state, using: &game.rng) }
            sleepTonight(&game.state, &game.rng)
        }
    }

    @Test func aRangeWithItsMaxBelowItsMinLoadsAndPlays() throws {
        let data = try Self.edited(rules: [
            "lostDaysMin": 9, "lostDaysMax": 2, "foxChance": 1, "fleeChance": 1,
            "marketCardsMin": 3, "marketCardsMax": 1, "marketBuyerMinDays": 5, "marketBuyerMaxDays": 0,
        ])
        var game = try SaveFormat.decode(data)
        let r = game.state.rules
        #expect(r.lostDaysMin <= r.lostDaysMax)
        #expect(r.marketCardsMin <= r.marketCardsMax)
        #expect(r.marketBuyerMinDays <= r.marketBuyerMaxDays)
        Self.play(&game)
        #expect(game.state.day > Self.busyGame().state.day)
    }

    @Test func aRuleOfZeroThatDividesLoadsAndPlays() throws {
        var game = try SaveFormat.decode(Self.edited(rules: ["daysPerSeason": 0, "hensPerRooster": 0]))
        #expect(game.state.rules.daysPerSeason >= 1)
        #expect(game.state.rules.hensPerRooster >= 1)
        Self.play(&game)
    }

    @Test func coinsAtIntMaxLoadAndPlay() throws {
        let data = try Self.edited(state: ["coins": Int.max, "treats": Int.max, "day": Int.max - 1])
        var game = try SaveFormat.decode(data)
        #expect(game.state.coins <= SaveFormat.maxStateNumber)
        #expect(game.state.treats <= SaveFormat.maxStateNumber)
        #expect(game.state.day <= SaveFormat.maxStateNumber)
        Self.play(&game)
        #expect(game.state.coins > 0)
    }

    @Test func aHugeOrNegativeRuleIsKeptInBounds() throws {
        let data = try Self.edited(
            state: ["coins": -Int.max],
            rules: [
                "showEntryFee": 1e30, "pulletPrice": -5, "rehomeStandardPurebredFactor": 1e300, "cartonSize": Int.max,
            ])
        var game = try SaveFormat.decode(data)
        let r = game.state.rules
        #expect(r.showEntryFee == SaveFormat.maxRuleNumber)
        #expect(r.pulletPrice == 0)
        #expect(r.rehomeStandardPurebredFactor == Double(SaveFormat.maxRuleNumber))
        #expect(r.cartonSize == SaveFormat.maxRuleNumber)
        #expect(game.state.coins >= 0)
        Self.play(&game)
    }

    /// A show class of a million rivals would make a million birds on show day, so loading caps it.
    @Test func aHugeShowClassIsCappedOnLoad() throws {
        var game = Self.busyGame()
        game.state.rules.showCompetitorsByKind = [.pet: 1_000_000, .eggs: 5, .breed: 7]
        game.state.rules.showRivalPicks = [.pet: 1_000_000, .eggs: 2, .breed: 3]
        let loaded = try SaveFormat.decode(SaveFormat.encode(game))
        #expect(loaded.state.rules.showCompetitorsByKind[.pet] == SaveFormat.maxShowEntrants)
        #expect(loaded.state.rules.showRivalPicks[.pet] == SaveFormat.maxShowEntrants)
        #expect(loaded.state.rules.showCompetitorsByKind[.eggs] == 5)
    }

    /// The bounds only catch hand edits: a played save, and its big shop seed, load as they were written.
    @Test func boundsLeaveARealSaveAlone() throws {
        let game = Self.busyGame()
        #expect(game.state.shopSeed > UInt64(SaveFormat.maxStateNumber))
        let loaded = try SaveFormat.decode(SaveFormat.encode(game))
        #expect(loaded.state.shopSeed == game.state.shopSeed)
        #expect(loaded.state.rules == game.state.rules)
        #expect(loaded.state.coins == game.state.coins)
    }
}
