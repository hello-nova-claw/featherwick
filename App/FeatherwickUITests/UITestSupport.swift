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
        // The rail marks the panel on screen as selected.
        let shown = NSPredicate(format: "isSelected == true")
        let wait = XCTNSPredicateExpectation(predicate: shown, object: dot)
        XCTAssertEqual(XCTWaiter.wait(for: [wait], timeout: 5), .completed, "The \(panel) panel did not show")
    }

    /// The first button whose label starts with a name. Doubled strings read "Settings Settings", and a place
    /// button adds its notices after the name, so an exact match would miss both.
    static func button(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    /// The place button in the bottom row. The Yard's rail dot starts with the same name, so this one is
    /// told apart by size: a dot is under 30 points wide.
    static func placeButton(_ name: String, in app: XCUIApplication) -> XCUIElement? {
        let named = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name))
        guard named.firstMatch.waitForExistence(timeout: 5) else { return nil }
        return named.allElementsBoundByIndex.first { $0.frame.width >= 30 }
    }

    /// Closes the sheet on top, then waits until one fewer Close button is on screen, so the next tap lands
    /// on what is under it. Counting matters: the market board opens over the farm gate sheet, so a Close
    /// button is still there once the top sheet has gone. A Close button still sliding away is not tapped.
    static func close(_ app: XCUIApplication) {
        let closes = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Close"))
        let close = closes.firstMatch
        guard close.waitForExistence(timeout: 2) else { return }
        let open = closes.count
        // On a slow runner the button can exist before it can be tapped, so wait for that first.
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: close)
        if XCTWaiter.wait(for: [hittable], timeout: 5) == .completed {
            close.tap()
        } else {
            app.swipeDown(velocity: .fast)
        }
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in closes.count < open }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 10), .completed, "The sheet did not close")
    }

    static func slug(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: " ", with: "-")
    }
}
