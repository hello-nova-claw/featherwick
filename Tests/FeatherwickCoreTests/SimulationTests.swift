import Foundation
import Testing

@testable import FeatherwickCore

/// The balance-sim harness: seeded games stay bounded and productive, and every difficulty is playable.
/// These are the guards that catch a tuning change making the economy or the flock run away (or die).
struct SimulationTests {
    @Test(arguments: [UInt64(1), 2, 3, 7, 42, 100])
    func gamesStayBoundedAndProductive(seed: UInt64) {
        let r = Simulation.run(seed: seed, days: 180)
        #expect(r.days == 180)
        #expect(r.finalFlock >= 1)  // never-zero-birds invariant holds under real play
        #expect(r.peakFlock <= 100)  // nothing explodes
        #expect(r.finalCoins >= 0)
        #expect(r.finalCoins < 1_000_000)  // the economy doesn't diverge
        #expect(r.eggsLaid > 0)  // the game actually gets somewhere
        #expect(r.chicksHatched > 0)
        #expect(r.breedBook >= 1)
    }

    @Test func reportsAreDeterministic() {
        #expect(Simulation.run(seed: 5, days: 90) == Simulation.run(seed: 5, days: 90))
    }

    @Test(arguments: Difficulty.allCases)
    func everyPresetIsPlayable(preset difficulty: Difficulty) {
        let rules = difficulty.rules
        for seed in UInt64(1)...6 {
            let r = Simulation.run(seed: seed, days: 150, rules: rules)
            #expect(r.finalFlock >= 1)
            #expect(r.finalCoins >= 0 && r.finalCoins < 1_000_000)
            #expect(r.eggsLaid > 0)
        }
    }

    /// A higher lay chance lays more eggs. Only the lay chance differs between the two runs: the full
    /// presets lay about the same, because their other settings change how big the flock grows.
    @Test func aHigherLayChanceLaysMore() {
        func meanEggs(_ preset: Rules) -> Double {
            // Standard rules with the preset's lay chance. Job and goal coins change what the keeper
            // buys, which hides the lay chance. Leave them out.
            var rules = Rules.standard
            rules.layChance = preset.layChance
            rules.jobsRewardCoins = 0
            rules.seasonGoalRewardCoins = 0
            let xs = Simulation.runMany(seeds: 1...12, days: 150, rules: rules).map { Double($0.eggsLaid) }
            return xs.reduce(0, +) / Double(xs.count)
        }
        // The relaxed lay chance is higher than the challenge one, so it should lay more over the same games.
        // (Final coins is a poor signal here: the keeper reinvests its coins into stock and upgrades.)
        #expect(meanEggs(.relaxed) > meanEggs(.challenge))
    }

    @Test func textReportRuns() {
        let report = Simulation.textReport(days: 60, games: 5)
        #expect(report.contains("Balance report"))
        #expect(report.contains("coins"))
    }
}

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
