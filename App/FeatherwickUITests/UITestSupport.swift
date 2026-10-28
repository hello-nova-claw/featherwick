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
        XCTAssertEqual(XCTWaiter.wait(for: [wait], timeout: 10), .completed, "The \(panel) panel did not show")
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
    /// button is still there once the top sheet has gone.
    static func close(_ app: XCUIApplication) {
        let closes = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Close"))
        let close = closes.firstMatch
        guard close.waitForExistence(timeout: 2) else { return }
        let open = closes.count
        // tap() itself waits for the button to be tappable. Asking isHittable first can throw while a
        // sheet is still moving, so it is not asked here.
        close.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in closes.count < open }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 10), .completed, "The sheet did not close")
    }

    /// Drags a sheet at its medium detent up to its large one, so the audit sees the whole page. At the medium
    /// detent the last line runs under the floating sheet's edge, and the audit reads it against the farm
    /// behind. A sheet that is already large is left alone: a drag would scroll its title under the clock.
    static func expandSheet(_ app: XCUIApplication) {
        // The sheet's page is the scroll view that holds its Close button. Its top is the sheet's top; the
        // Close button can sit lower, under a portrait.
        let closeLabel = NSPredicate(format: "label BEGINSWITH %@", "Close")
        let page = app.scrollViews.containing(closeLabel).firstMatch
        guard page.waitForExistence(timeout: 2) else { return }
        let top = page.frame.minY
        guard top > app.frame.height / 3 else { return }
        // Drag by the distance from the sheet's top to the large detent's, so the sheet grows and the page
        // does not scroll on past it.
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let startY = top + 120
        let start = origin.withOffset(CGVector(dx: app.frame.midX, dy: startY))
        let end = origin.withOffset(CGVector(dx: app.frame.midX, dy: startY - (top - 70)))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    static func slug(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: " ", with: "-")
    }
}
