import FeatherwickCore
import Foundation
import Testing

@testable import Featherwick

/// The launch arguments UI tests and screenshots use to start the app in a known game.
@Suite struct UITestLaunchTests {
    @Test func noArgumentsMeansANormalLaunch() {
        #expect(UITestLaunch(arguments: ["Featherwick"]) == nil)
        #expect(UITestLaunch(arguments: ["Featherwick", "-uiTestState"]) == nil)
        #expect(UITestLaunch(arguments: ["Featherwick", "-uiTestState", "nonsense"]) == nil)
    }

    @Test func theSeedDefaultsTo2026() {
        #expect(UITestLaunch(arguments: ["-uiTestState", "fresh"]) == UITestLaunch(start: .fresh, seed: 2026))
        #expect(
            UITestLaunch(arguments: ["-uiTestState", "farm", "-uiTestSeed", "7"]) == UITestLaunch(start: .farm, seed: 7)
        )
    }

    /// Screenshots compare runs, so the same arguments must give the same game every time. The state is
    /// compared, not the JSON: a `Set` encodes in hash order, which can differ between two encodes.
    @Test func theSameArgumentsGiveTheSameGame() throws {
        let launch = try #require(UITestLaunch(arguments: ["-uiTestState", "farm"]))
        #expect(launch.save().state == launch.save().state)
    }

    @Test func freshStartsBeforeTheKeeperIsNamed() throws {
        let save = try #require(UITestLaunch(arguments: ["-uiTestState", "fresh"])).save()
        #expect(save.state.keeperName == nil)
        #expect(save.state.day == 1)
    }

    @Test func farmIsAPlayedFarmWithAChick() throws {
        let save = try #require(UITestLaunch(arguments: ["-uiTestState", "farm"])).save()
        #expect(save.state.keeperName == "Robin")
        #expect(save.state.day > 1)
        guard case .playing = save.state.phase else {
            Issue.record("The farm fixture should be past the starter choice, not \(save.state.phase)")
            return
        }
    }

    /// Each launch gets its own empty folder, so one test never sees another's game.
    @MainActor @Test func eachStoreStartsInItsOwnFolder() throws {
        let launch = try #require(UITestLaunch(arguments: ["-uiTestState", "farm"]))
        let first = try launch.makeStore()
        let second = try launch.makeStore()
        #expect(first.saveLocation != second.saveLocation)
        #expect(first.slot != second.slot)
        #expect(first.state.day == launch.save().state.day)
    }
}
