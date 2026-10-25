import XCTest

/// What the accessibility audit and the screenshots share: how to launch a known game, and how to move
/// around the farm in any language or text size.
@MainActor
enum Farm {
    enum Start: String {
        case fresh, farm
    }

    /// The launch arguments for each language the tests run in. Doubled strings read "Settings Settings";
    /// right to left is forced, because the app has no Arabic strings yet.
    enum Language: String, CaseIterable {
        case english = "en"
        case rightToLeft = "ar"
        case doubled = "en-XA"

        var arguments: [String] {
            switch self {
            case .english: []
            case .rightToLeft:
                [
                    "-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA", "-NSForceRightToLeftWritingDirection", "YES",
                    "-AppleTextDirection", "YES",
                ]
            case .doubled: ["-NSDoubleLocalizedStrings", "YES"]
            }
        }
    }

    /// Day or night, pinned through the tester setting so the clock never decides.
    enum Light: String, CaseIterable {
        case day, night
    }

    static func launch(_ start: Start, light: Light = .day, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestState", start.rawValue, "-tester.timeOfDay", light.rawValue] + extra
        app.launch()
        return app
    }

    /// The panel that holds a place. The farm opens on the Yard.
    static func panel(for place: String) -> String {
        ["Coop": "Barn", "Yard": "Yard", "Back fence": "Far yard", "Farm gate": "Shop"][place] ?? "Yard"
    }

    /// Taps the panel's dot on the rail. Swipes would go the other way right to left; the dots do not.
    /// A dot is the narrow button whose label starts with the panel's name (the Yard place button shares it).
    static func show(panel: String, in app: XCUIApplication) {
        let named = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", panel))
        guard let dot = named.allElementsBoundByIndex.first(where: { $0.frame.width < 30 }) else {
            XCTFail("No rail dot for \(panel)")
            return
        }
        dot.tap()
    }

    /// The first button whose label starts with a name. Doubled strings read "Settings Settings", and a place
    /// button adds its notices after the name, so an exact match would miss both.
    static func button(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    static func close(_ app: XCUIApplication) {
        let close = button("Close", in: app)
        if close.exists {
            close.tap()
        } else {
            app.swipeDown(velocity: .fast)
        }
    }

    static func slug(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: " ", with: "-")
    }
}
