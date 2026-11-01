import FeatherwickCore
import Foundation
import Testing

@testable import Featherwick

/// The app's one game: it runs commands, logs the words, opens the right sheet and saves after each command.
/// Serialized: the morning report switch is one app-wide setting.
@MainActor @Suite(.serialized) struct GameStoreTests {
    /// A store on its own empty folder and slot, holding this save (or none).
    private static func store(_ save: SaveGame? = nil) throws -> (GameStore, URL, String) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fw-store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let slot = "store-\(UUID().uuidString)"
        if let save { try SaveStore(directory: dir, slot: slot).write(SaveFormat.encode(save)) }
        return (GameStore(directory: dir, slot: slot), dir, slot)
    }

    /// A seeded game with every feature open, past the starter choice.
    private static func openGame(seed: UInt64 = 7) -> SaveGame {
        var rng = SeededRNG(seed: seed)
        var state = Engine.newGame(earlyGame: false, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &state, using: &rng)
        return SaveGame(state: state, rng: rng)
    }

    /// A seeded game in the early game (one lesson at a time), on day 1 with the starter home.
    private static func earlyGame(seed: UInt64 = 7) -> SaveGame {
        var rng = SeededRNG(seed: seed)
        var state = Engine.newGame(using: &rng)
        for command: Command in [.nameKeeper("Robin"), .chooseStarter(index: 0, name: "Pip")] {
            _ = Engine.apply(command, to: &state, using: &rng)
        }
        return SaveGame(state: state, rng: rng)
    }

    private static func cleanUp(_ dir: URL, _ slot: String) {
        try? FileManager.default.removeItem(at: dir)
        UserDefaults.standard.removeObject(forKey: "seenNewStock.\(slot)")
    }

    /// Runs `body` with the morning report switch set, then puts the switch back as it was.
    private static func withMorningReport(_ on: Bool, _ body: () throws -> Void) rethrows {
        let key = MorningReportSetting.key
        let before = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.set(on, forKey: key)
        defer { UserDefaults.standard.set(before, forKey: key) }
        try body()
    }

    @Test func anEmptyFolderStartsANewGameAtTheStarterChoice() throws {
        let (store, dir, slot) = try Self.store()
        defer { Self.cleanUp(dir, slot) }
        #expect(store.saveTooNew == nil)
        guard case .choosingStarter = store.state.phase else {
            Issue.record("A new game should start at the starter choice, not \(store.state.phase)")
            return
        }
        #expect(store.log.count == 1)
    }

    /// Every command saves, so a store opened on the same slot finds the same game.
    @Test func everyCommandIsSaved() throws {
        let (store, dir, slot) = try Self.store()
        defer { Self.cleanUp(dir, slot) }
        store.run(.nameKeeper("Robin"))
        store.run(.chooseStarter(index: 1, name: "Pip"))
        store.run(.feed)
        let again = GameStore(directory: dir, slot: slot)
        #expect(again.state == store.state)
        #expect(again.save.rng == store.save.rng)
        #expect(again.state.keeperName == "Robin")
    }

    /// Day 1: once the chick is home, the tour opens.
    @Test func choosingTheStarterOpensTheTour() throws {
        let (store, dir, slot) = try Self.store()
        defer { Self.cleanUp(dir, slot) }
        store.run(.chooseStarter(index: 0, name: "Pip"))
        #expect(store.openRequest == .tour)
        #expect(store.state.starterID != nil)
    }

    @Test func aRefusalIsLoggedAsOneAndChangesNothing() throws {
        let (store, dir, slot) = try Self.store(Self.openGame())
        defer { Self.cleanUp(dir, slot) }
        let before = store.state
        let events = store.run(.chooseStarter(index: 0, name: "Again"))
        #expect(events.contains(.rejected(.alreadyStarted)))
        #expect(store.state == before)
        #expect(store.log.last?.isRejection == true)
        store.run(.feed)
        #expect(store.log.last?.isRejection == false)
    }

    /// Sleep with the switch on: the night passes, the report opens, and the night's toasts wait for it.
    @Test func sleepOpensTheMorningReport() throws {
        let (store, dir, slot) = try Self.store(Self.openGame())
        defer { Self.cleanUp(dir, slot) }
        store.restUntilEvening()
        #expect(store.state.slotsLeft == 0)
        let day = store.state.day
        Self.withMorningReport(true) { store.sleep() }
        #expect(store.state.day == day + 1)
        #expect(store.morningReport != nil)
        #expect(store.openRequest == .morningReport)
        #expect(store.toasts.isEmpty)
        store.finishMorningReport()
        #expect(store.morningReport == nil)
    }

    @Test func noMorningReportWhenTheSwitchIsOff() throws {
        let (store, dir, slot) = try Self.store(Self.openGame())
        defer { Self.cleanUp(dir, slot) }
        store.restUntilEvening()
        let day = store.state.day
        Self.withMorningReport(false) { store.sleep() }
        #expect(store.state.day == day + 1)
        #expect(store.morningReport == nil)
    }

    /// While the sun is up the engine says no. That "no" is the neighbour's note, not a morning report.
    @Test func sleepWithDaylightLeftIsANote() throws {
        let (store, dir, slot) = try Self.store(Self.openGame())
        defer { Self.cleanUp(dir, slot) }
        #expect(store.state.slotsLeft > 0)
        let day = store.state.day
        Self.withMorningReport(true) { store.sleep() }
        #expect(store.state.day == day)
        #expect(store.morningReport == nil)
        #expect(!store.neighbourNotes.isEmpty)
        #expect(store.openRequest == .neighbourNote)
        store.readNeighbourNotes()
        #expect(store.neighbourNotes.isEmpty)
    }

    @Test func fullDaysPassThatManyNights() throws {
        let (store, dir, slot) = try Self.store(Self.openGame())
        defer { Self.cleanUp(dir, slot) }
        let day = store.state.day
        store.fullDays(3)
        #expect(store.state.day == day + 3)
        store.fullDays(0)  // at least one day
        #expect(store.state.day == day + 4)
        // Fast forward makes no morning report, and at most two toasts show at once.
        #expect(store.morningReport == nil)
        #expect(store.toasts.count <= 2)
        for toast in store.toasts { store.dismissToast(toast.id) }
        #expect(store.toasts.isEmpty)
    }

    /// The early game's lessons come as the neighbour's notes, so a lesson is never only in the log.
    @Test func aLessonOvernightIsANeighbourNote() throws {
        let (store, dir, slot) = try Self.store(Self.earlyGame())
        defer { Self.cleanUp(dir, slot) }
        let lesson = try #require(Self.nextFeatureDay(after: store.state.day, store.state.rules.featureDays.keys))
        store.fullDays(lesson - store.state.day)
        #expect(store.state.day == lesson)
        #expect(!store.neighbourNotes.isEmpty)
        store.readNeighbourNotes()
        #expect(store.neighbourNotes.isEmpty)
    }

    /// New stock at the farm gate is new until the keeper shops, and the slot remembers it.
    @Test func newStockIsNewUntilTheKeeperShops() throws {
        let (store, dir, slot) = try Self.store(Self.earlyGame())
        defer { Self.cleanUp(dir, slot) }
        let shopDay = try #require(Self.nextFeatureDay(after: store.state.day, GameStore.shopFeatures))
        store.fullDays(shopDay - store.state.day)
        #expect(store.hasNewStock)
        store.sawNewStock()
        #expect(!store.hasNewStock)
        // Kept outside the save, per slot, so the next launch knows too.
        #expect(!GameStore(directory: dir, slot: slot).hasNewStock)
    }

    /// The first morning after `day` that the early game brings one of these features in.
    private static func nextFeatureDay(after day: Int, _ features: some Sequence<Feature>) -> Int? {
        features.map { Rules.standard.introductionDay(of: $0) }.filter { $0 > day }.min()
    }

    @Test func aNewGameStartsOverAndIsSaved() throws {
        let (store, dir, slot) = try Self.store(Self.openGame())
        defer { Self.cleanUp(dir, slot) }
        store.fullDays(2)
        store.newGame()
        guard case .choosingStarter = store.state.phase else {
            Issue.record("A new game should start at the starter choice, not \(store.state.phase)")
            return
        }
        #expect(store.log.count == 1)
        #expect(store.morningReport == nil)
        #expect(GameStore(directory: dir, slot: slot).state == store.state)
    }

    /// A save that cannot be read is kept aside, and the keeper is told. The app never crashes on it.
    @Test func anUnreadableSaveStartsANewGameAndSaysSo() throws {
        let (_, dir, slot) = try Self.store()
        defer { Self.cleanUp(dir, slot) }
        try Data("not a save".utf8).write(to: SaveStore(directory: dir, slot: slot).url)
        let store = GameStore(directory: dir, slot: slot)
        #expect(store.saveTooNew == nil)
        guard case .choosingStarter = store.state.phase else {
            Issue.record("An unreadable save should start a new game, not \(store.state.phase)")
            return
        }
        #expect(store.log.count == 2)  // the welcome, and what happened to the save
    }

    @Test func theLogKeepsTheNewest400Lines() throws {
        let (store, dir, slot) = try Self.store()
        defer { Self.cleanUp(dir, slot) }
        for i in 0..<450 { store.note("Line \(i)") }
        #expect(store.log.count == 400)
        #expect(store.log.last?.text == "Line 449")
        #expect(Set(store.log.map(\.id)).count == store.log.count)
        store.note("   ")  // blank words add no line
        #expect(store.log.last?.text == "Line 449")
    }
}
