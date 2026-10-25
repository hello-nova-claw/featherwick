import XCTest

/// The screenshot catalogue: every screen, by day and by night, in each language, on the device the tests
/// run on. Each shot is an attachment named `<screen>--<state>--<locale>--<device>`; CI exports them from
/// the result bundle and compares them with `main`. A shot never fails a test: it is for the reviewer.
/// Add a screen or a state here when you add one to the app.
@MainActor
final class ScreenshotTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = true
    }

    func testEnglish() { catalogue(.english) }
    func testRightToLeft() { catalogue(.rightToLeft) }
    func testDoubledStrings() { catalogue(.doubled) }

    private func catalogue(_ language: Farm.Language) {
        for light in Farm.Light.allCases {
            let fresh = Farm.launch(.fresh, light: light, extra: language.arguments)
            if fresh.textFields.firstMatch.waitForExistence(timeout: 10) {
                shoot(fresh, "welcome", light, language)
            }

            let app = Farm.launch(.farm, light: light, extra: language.arguments)
            guard Farm.button("Settings", in: app).waitForExistence(timeout: 10) else {
                XCTFail("The farm did not open")
                continue
            }
            for panel in ["Yard", "Far yard", "Shop", "Barn"] {
                Farm.show(panel: panel, in: app)
                shoot(app, "farm-\(Farm.slug(panel))", light, language)
            }
            for place in ["Coop", "Yard", "Back fence", "Farm gate"] {
                Farm.show(panel: Farm.panel(for: place), in: app)
                let button = Farm.button(place, in: app)
                guard button.waitForExistence(timeout: 5) else { continue }
                button.tap()
                shoot(app, "place-\(Farm.slug(place))", light, language)
                Farm.close(app)
            }
            for (button, screen) in [("Books", "books"), ("Today", "today"), ("Settings", "settings")] {
                Farm.button(button, in: app).tap()
                shoot(app, screen, light, language)
                Farm.close(app)
            }
        }
    }

    private func shoot(_ app: XCUIApplication, _ screen: String, _ light: Farm.Light, _ language: Farm.Language) {
        // Let sheets finish sliding in, so the shot is the same on every run.
        _ = app.wait(for: .runningForeground, timeout: 2)
        Thread.sleep(forTimeInterval: 0.8)
        let device = Farm.slug(UIDevice.current.name).filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(screen)--\(light.rawValue)--\(language.rawValue)--\(device)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
