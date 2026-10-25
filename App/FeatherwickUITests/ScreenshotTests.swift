import XCTest

/// The screenshot catalogue: the screens the accessibility audit covers, by day and by night, in each
/// language, on the device the tests run on. Each shot is an attachment named
/// `<screen>--<state>--<locale>--<device>`; CI exports them from the result bundle and compares them with
/// `main`. A shot never fails a test: it is for the reviewer. Add a screen or a state here when you add one
/// to the app. XCTest waits for the app to go idle before each screenshot, so a sheet has finished opening.
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
            dayOne(light, language)
            farm(light, language)
        }
    }

    /// Welcome, the starter choice and the tour.
    private func dayOne(_ light: Farm.Light, _ language: Farm.Language) {
        let app = Farm.launch(.fresh, light: light, extra: language.arguments)
        let name = app.textFields.firstMatch
        guard name.waitForExistence(timeout: 10) else {
            XCTFail("The welcome did not open")
            return
        }
        shoot(app, "welcome", light, language)
        name.tap()
        name.typeText("Robin")
        Farm.button("That's me", in: app).tap()
        let chick = app.textFields.firstMatch
        guard chick.waitForExistence(timeout: 10) else { return }
        shoot(app, "starter", light, language)
        chick.tap()
        chick.typeText("Pip")
        Farm.button("Take this chick home", in: app).tap()
        if Farm.button("Skip the tour", in: app).waitForExistence(timeout: 10) {
            shoot(app, "tour", light, language)
        }
    }

    /// The farm panels, the place sheets, the market board and the bottom-row sheets.
    private func farm(_ light: Farm.Light, _ language: Farm.Language) {
        let app = Farm.launch(.farm, light: light, extra: language.arguments)
        guard Farm.button("Settings", in: app).waitForExistence(timeout: 10) else {
            XCTFail("The farm did not open")
            return
        }
        for panel in ["Yard", "Far yard", "Shop", "Barn"] {
            Farm.show(panel: panel, in: app)
            shoot(app, "farm-\(Farm.slug(panel))", light, language)
        }
        for place in ["Coop", "Yard", "Back fence", "Farm gate"] {
            // TODO(#97): the Yard sheet never settles with doubled strings, so it cannot be shot.
            if place == "Yard" && language == .doubled { continue }
            Farm.show(panel: Farm.panel(for: place), in: app)
            guard let button = Farm.placeButton(place, in: app) else { continue }
            button.tap()
            guard Farm.button("Close", in: app).waitForExistence(timeout: 5) else { continue }
            shoot(app, "place-\(Farm.slug(place))", light, language)
            if place == "Farm gate" {
                Farm.button("Market board", in: app).tap()
                if Farm.button("Close", in: app).waitForExistence(timeout: 5) {
                    shoot(app, "market-board", light, language)
                    Farm.close(app)
                }
            }
            Farm.close(app)
        }
        for (button, screen) in [("Books", "books"), ("Today", "today"), ("Settings", "settings")] {
            Farm.button(button, in: app).tap()
            guard Farm.button("Close", in: app).waitForExistence(timeout: 5) else { continue }
            shoot(app, screen, light, language)
            Farm.close(app)
        }
    }

    private func shoot(_ app: XCUIApplication, _ screen: String, _ light: Farm.Light, _ language: Farm.Language) {
        let device = Farm.slug(UIDevice.current.name).filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(screen)--\(light.rawValue)--\(language.rawValue)--\(device)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
