import FeatherwickCore

// MARK: - Loading a save (SaveStore.load)

/// What the keeper reads after a save loads with trouble, or nil when it loaded plainly or there was none.
/// The CLI prints it; the app logs it.
public func recoveryText(_ recovery: SaveStore.Recovery) -> String? {
    switch recovery {
    case .loaded, .noSave:
        return nil
    case .restoredFromBackup:
        return String(
            localized: "save.restoredMissing", defaultValue: "Main save was missing; restored from a backup.",
            bundle: .module, comment: "On load: the save file was gone, and a backup copy loaded.")
    case .unreadable(let kept?, true):
        return String(
            localized: "save.unreadableKeptRestored",
            defaultValue: "Your save couldn't be read (kept as \(kept.lastPathComponent)). Restored from a backup.",
            bundle: .module,
            comment:
                "On load: the save was damaged and moved aside, and a backup loaded. The placeholder is the file name it was moved to."
        )
    case .unreadable(nil, true):
        return String(
            localized: "save.unreadableRestored", defaultValue: "Your save couldn't be read. Restored from a backup.",
            bundle: .module, comment: "On load: the save was damaged, and a backup loaded.")
    case .unreadable(let kept?, false):
        return String(
            localized: "save.unreadableKeptNew",
            defaultValue: "Your save couldn't be read (kept as \(kept.lastPathComponent)). Starting a new game.",
            bundle: .module,
            comment:
                "On load: the save was damaged and moved aside, with no good backup. The placeholder is the file name it was moved to."
        )
    case .unreadable(nil, false):
        return String(
            localized: "save.unreadableNew", defaultValue: "Your save couldn't be read. Starting a new game.",
            bundle: .module, comment: "On load: the save was damaged, with no good backup.")
    case .tooNew(let version):
        return String(
            localized: "save.tooNew",
            defaultValue:
                "This save is from a newer version of Featherwick (save version \(version)). Update the game to load it.",
            bundle: .module,
            comment:
                "Text game, on load: the save came from a newer game, so it is left alone. The placeholder is the save's version number."
        )
    }
}

/// The app's screen for a save from a newer game. The farm is left alone, so the words say it is safe.
public enum SaveWords {
    public static var tooNewTitle: String {
        String(
            localized: "save.tooNewTitle", defaultValue: "Your farm needs a newer Featherwick", bundle: .module,
            comment: "App screen title, shown instead of the farm when the save came from a newer version.")
    }
    public static var tooNewBody: String {
        String(
            localized: "save.tooNewBody",
            defaultValue:
                "Your farm was saved by a newer version of the game. It is safe, and nothing has been changed. Update Featherwick to carry on where you left off.",
            bundle: .module, comment: "App screen text, under the title, when the save came from a newer version.")
    }
}
