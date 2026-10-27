import Testing

@testable import Featherwick

/// How much the farm scene moves: fully, with Reduce Motion, or not at all for a UI test.
@Suite struct SceneMotionTests {
    @Test func playersSeeTheSceneMove() {
        let motion = SceneMotion(reduceMotion: false, frozen: false)
        #expect(motion == .full)
        #expect(!motion.isStill)
        #expect(motion.blinks)
    }

    /// Reduce Motion stills the walks, pecks and sway, but the birds still blink.
    @Test func reduceMotionStillsTheSceneButKeepsBlinks() {
        let motion = SceneMotion(reduceMotion: true, frozen: false)
        #expect(motion == .reduced)
        #expect(motion.isStill)
        #expect(motion.blinks)
    }

    /// Screenshots compare runs, so a frozen scene holds every pixel, blinks too.
    @Test func aFrozenSceneHoldsEverything() {
        for reduceMotion in [false, true] {
            let motion = SceneMotion(reduceMotion: reduceMotion, frozen: true)
            #expect(motion == .frozen)
            #expect(motion.isStill)
            #expect(!motion.blinks)
        }
    }

    @Test func aUITestLaunchFreezesTheScene() {
        #expect(UITestLaunch.freezesScene(arguments: ["Featherwick", "-uiTestState", "farm"]))
        #expect(UITestLaunch.freezesScene(arguments: ["Featherwick", "-uiTestState", "fresh", "-uiTestSeed", "7"]))
    }

    @Test func aNormalLaunchDoesNotFreezeTheScene() {
        #expect(!UITestLaunch.freezesScene(arguments: ["Featherwick"]))
        #expect(!UITestLaunch.freezesScene(arguments: ["Featherwick", "-uiTestState", "nonsense"]))
    }
}
