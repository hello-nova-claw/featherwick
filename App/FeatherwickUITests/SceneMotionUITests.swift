import XCTest

/// A UI test launch freezes the farm scene, so screenshots match from run to run. The unit tests check
/// the flag; this checks the app passes it to the scene.
@MainActor
final class SceneMotionUITests: XCTestCase {
    /// Each bird carries its scene's motion as its identifier. VoiceOver never reads an identifier.
    func testTheSceneIsFrozen() {
        let app = Farm.launch(.farm)
        guard Farm.button("Settings", in: app).waitForExistence(timeout: 10) else {
            XCTFail("The farm did not open")
            return
        }
        Farm.show(panel: "Barn", in: app)
        let chick = app.buttons["Pip"]
        guard chick.waitForExistence(timeout: 5) else {
            XCTFail("Pip is not in the Barn")
            return
        }
        XCTAssertEqual(chick.identifier, "scene-motion-frozen")
    }
}
