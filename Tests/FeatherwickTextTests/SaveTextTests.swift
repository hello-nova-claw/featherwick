import FeatherwickCore
import Foundation
import Testing

@testable import FeatherwickText

/// The words after a load. The CLI printed these same lines before `SaveStore.load` (#59).
struct SaveTextTests {
    private let kept = URL(fileURLWithPath: "/saves/featherwick-save.corrupt2.json")

    @Test func aPlainLoadSaysNothing() {
        #expect(recoveryText(.loaded) == nil)
        #expect(recoveryText(.noSave) == nil)
    }

    @Test func eachRecoveryHasItsLine() {
        #expect(recoveryText(.restoredFromBackup) == "Main save was missing; restored from a backup.")
        #expect(
            recoveryText(.unreadable(keptAs: kept, restoredFromBackup: true))
                == "Your save couldn't be read (kept as featherwick-save.corrupt2.json). Restored from a backup.")
        #expect(
            recoveryText(.unreadable(keptAs: nil, restoredFromBackup: true))
                == "Your save couldn't be read. Restored from a backup.")
        #expect(
            recoveryText(.unreadable(keptAs: kept, restoredFromBackup: false))
                == "Your save couldn't be read (kept as featherwick-save.corrupt2.json). Starting a new game.")
        #expect(
            recoveryText(.unreadable(keptAs: nil, restoredFromBackup: false))
                == "Your save couldn't be read. Starting a new game.")
        #expect(
            recoveryText(.tooNew(version: 99))
                == "This save is from a newer version of Featherwick (save version 99). Update the game to load it.")
    }

    /// The app's note must be calm: the farm is safe, and no version number or file name shows.
    @Test func theAppNoteSaysTheFarmIsSafe() {
        #expect(SaveWords.tooNewTitle == "Your farm needs a newer Featherwick")
        #expect(SaveWords.tooNewBody.contains("It is safe"))
        let digits = SaveWords.tooNewBody.filter(\.isNumber)
        #expect(digits.isEmpty)
    }
}
