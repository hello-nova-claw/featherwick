import XCTest

/// Opens every screen and runs Apple's accessibility audit on it. Any issue fails, except the known ones
/// listed in `knownIssues` with the issue that will fix them. The subclasses below run the same tests at the
/// largest accessibility text size, right to left, and with every localised string doubled in length.
@MainActor
class AccessibilityAuditTests: XCTestCase {
    /// How the app is launched for this run of the tests.
    class var variant: [String] { [] }
    class var variantName: String { "standard" }

    override func setUp() async throws {
        continueAfterFailure = true
    }

    func testWelcome() throws {
        let app = launch(.fresh)
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 10))
        try audit(app, screen: "welcome")
    }

    func testFarmPanels() throws {
        let app = launch(.farm)
        XCTAssertTrue(button("Settings", in: app).waitForExistence(timeout: 10))
        for panel in ["Yard", "Far yard", "Shop", "Barn"] {
            show(panel: panel, in: app)
            try audit(app, screen: "farm-\(panel.lowercased().replacingOccurrences(of: " ", with: "-"))")
        }
    }

    func testBottomRowSheets() throws {
        let app = launch(.farm)
        XCTAssertTrue(button("Settings", in: app).waitForExistence(timeout: 10))
        for (button, screen) in [("Books", "books"), ("Settings", "settings")] {
            self.button(button, in: app).tap()
            try audit(app, screen: screen)
            close(app)
        }
    }

    func testPlaceSheets() throws {
        let app = launch(.farm)
        XCTAssertTrue(button("Settings", in: app).waitForExistence(timeout: 10))
        for place in ["Yard", "Back fence", "Farm gate", "Coop"] {
            show(panel: Self.panel(for: place), in: app)
            let button = self.button(place, in: app)
            guard button.waitForExistence(timeout: 5) else {
                XCTFail("No \(place) button on the farm")
                continue
            }
            button.tap()
            try audit(app, screen: "place-\(place.lowercased().replacingOccurrences(of: " ", with: "-"))")
            close(app)
        }
    }

    // MARK: - Helpers

    enum Start: String {
        case fresh, farm
    }

    private func launch(_ start: Start) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestState", start.rawValue, "-tester.timeOfDay", "day"] + Self.variant
        app.launch()
        return app
    }

    /// The panel that holds a place. The farm opens on the Yard.
    private static func panel(for place: String) -> String {
        ["Coop": "Barn", "Yard": "Yard", "Back fence": "Far yard", "Farm gate": "Shop"][place] ?? "Yard"
    }

    /// Taps the panel's dot on the rail. Swipes would go the other way right to left; the dots do not.
    /// A dot is the narrow button whose label starts with the panel's name (the Yard place button shares it).
    private func show(panel: String, in app: XCUIApplication) {
        let named = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", panel))
        let dot = named.allElementsBoundByIndex.first { $0.frame.width < 30 }
        guard let dot else {
            XCTFail("No rail dot for \(panel)")
            return
        }
        dot.tap()
    }

    /// The first button whose label starts with a name. Doubled strings read "Settings Settings", and a place
    /// button adds its notices after the name, so an exact match would miss both.
    private func button(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    private func close(_ app: XCUIApplication) {
        let close = button("Close", in: app)
        if close.exists {
            close.tap()
        } else {
            app.swipeDown(velocity: .fast)
        }
    }

    private func audit(_ app: XCUIApplication, screen: String) throws {
        try app.performAccessibilityAudit(for: .all) { issue in
            let known = Self.knownIssue(issue)
            if let known {
                print(
                    "Known accessibility issue on \(screen) (\(Self.variantName)), \(known): \(issue.compactDescription)"
                )
            }
            return known != nil
        }
    }

    /// Issues already filed. Each names the issue that fixes it; remove the line when it is fixed.
    /// Known by type, not by element: a missing label (`.sufficientElementDescription`) or any other type
    /// still fails at once.
    nonisolated static func knownIssue(_ issue: XCUIAccessibilityAuditIssue) -> String? {
        switch issue.auditType {
        case .contrast: "#88"
        case .hitRegion: "#89"
        case .elementDetection: "#90"
        case .textClipped, .dynamicType: "#66"
        default: nil
        }
    }
}

final class AccessibilityAuditLargestTextTests: AccessibilityAuditTests {
    override class var variant: [String] {
        ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    }
    override class var variantName: String { "largest text" }
}

final class AccessibilityAuditRightToLeftTests: AccessibilityAuditTests {
    override class var variant: [String] {
        [
            "-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA", "-NSForceRightToLeftWritingDirection", "YES",
            "-AppleTextDirection", "YES",
        ]
    }
    override class var variantName: String { "right to left" }
}

final class AccessibilityAuditLongStringsTests: AccessibilityAuditTests {
    override class var variant: [String] { ["-NSDoubleLocalizedStrings", "YES"] }
    override class var variantName: String { "long strings" }
}
