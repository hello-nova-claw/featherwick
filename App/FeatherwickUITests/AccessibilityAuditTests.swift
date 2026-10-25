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
        XCTAssertTrue(Farm.button("Settings", in: app).waitForExistence(timeout: 10))
        for panel in ["Yard", "Far yard", "Shop", "Barn"] {
            Farm.show(panel: panel, in: app)
            try audit(app, screen: "farm-\(Farm.slug(panel))")
        }
    }

    func testBottomRowSheets() throws {
        let app = launch(.farm)
        XCTAssertTrue(Farm.button("Settings", in: app).waitForExistence(timeout: 10))
        for (button, screen) in [("Books", "books"), ("Settings", "settings")] {
            Farm.button(button, in: app).tap()
            try audit(app, screen: screen)
            Farm.close(app)
        }
    }

    func testPlaceSheets() throws {
        let app = launch(.farm)
        XCTAssertTrue(Farm.button("Settings", in: app).waitForExistence(timeout: 10))
        for place in ["Yard", "Back fence", "Farm gate", "Coop"] {
            Farm.show(panel: Farm.panel(for: place), in: app)
            let button = Farm.button(place, in: app)
            guard button.waitForExistence(timeout: 5) else {
                XCTFail("No \(place) button on the farm")
                continue
            }
            button.tap()
            try audit(app, screen: "place-\(Farm.slug(place))")
            Farm.close(app)
        }
    }

    // MARK: - Helpers

    private func launch(_ start: Farm.Start) -> XCUIApplication {
        Farm.launch(start, extra: Self.variant)
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
    override class var variant: [String] { Farm.Language.rightToLeft.arguments }
    override class var variantName: String { "right to left" }
}

final class AccessibilityAuditLongStringsTests: AccessibilityAuditTests {
    override class var variant: [String] { Farm.Language.doubled.arguments }
    override class var variantName: String { "long strings" }
}
