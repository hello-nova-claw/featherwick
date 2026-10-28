import Foundation

// Every word the player reads is looked up in Resources/Localizable.xcstrings with
// `String(localized:defaultValue:bundle:comment:)`. The key is fixed; the default value is the English.
//
// Linux Foundation has no `String(localized:)`. There the same call reads the English default, so the
// CLI and the tests read the same words on every platform. `swift build` does not compile the catalog
// either, so on macOS too only the app (built by Xcode) reads it.
#if !canImport(Darwin)
    /// Where Linux looks up a word: nowhere, so `bundle: .module` names this case, not `Bundle.module`.
    /// It is not a closure that never runs, so coverage counts the line as run, and the CLI never needs
    /// the resource bundle beside it.
    enum WordsBundle { case module }

    extension String {
        init(localized key: StaticString, defaultValue: String, bundle: WordsBundle, comment: StaticString? = nil) {
            self = defaultValue
        }
    }
#endif
