import Foundation

// Every word the player reads is looked up in Resources/Localizable.xcstrings with
// `String(localized:defaultValue:bundle:comment:)`. The key is fixed; the default value is the English.
//
// Linux Foundation has no `String(localized:)`. There the same call reads the English default, so the
// CLI and the tests read the same words on every platform. `swift build` does not compile the catalog
// either, so on macOS too only the app (built by Xcode) reads it.
#if !canImport(Darwin)
    extension String {
        init(
            localized key: StaticString, defaultValue: String, bundle: @autoclosure () -> Bundle? = nil,
            comment: StaticString? = nil
        ) {
            self = defaultValue
        }
    }
#endif
