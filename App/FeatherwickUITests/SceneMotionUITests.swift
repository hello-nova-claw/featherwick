import XCTest

/// A UI test launch freezes the farm scene, so screenshots match from run to run. The unit tests check
/// the flag; this checks the app passes it to the scene.
@MainActor
final class SceneMotionUITests: XCTestCase {
    /// A brooder chick walks or pecks every 2–4 seconds while the scene moves. Frozen, it stays put.
    func testTheBrooderChickStaysPut() {
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
        let before = chick.frame
        // Long enough for at least two walks or pecks if the scene moved.
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "time passes")], timeout: 10)
        XCTAssertEqual(chick.frame, before, "Pip moved, so the scene is not frozen")
    }
}
