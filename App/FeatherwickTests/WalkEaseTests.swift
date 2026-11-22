import Foundation
import Testing

@testable import Featherwick

/// A painted bird's walk eases in and out (`WalkEase`), and never jumps: not when it turns round part way, and
/// not in the frame SwiftUI draws before the task calls `begin` or `end`.
@Suite struct WalkEaseTests {
    private let over: Double = 0.2
    private let t0 = Date(timeIntervalSinceReferenceDate: 1000)

    private func at(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

    /// Standing still shows no walk; a walk eases in to a full walk, then eases out to none.
    @Test func aWalkEasesInAndOut() {
        var ease = WalkEase()
        #expect(ease.share(at: t0, walking: false, over: over) == 0)
        ease.begin(at: t0, over: over)
        #expect(ease.share(at: t0, walking: true, over: over) == 0)
        #expect(abs(ease.share(at: at(0.1), walking: true, over: over) - 0.5) < 1e-9)
        #expect(ease.share(at: at(0.3), walking: true, over: over) == 1)
        ease.end(at: at(1), over: over)
        #expect(ease.share(at: at(1), walking: false, over: over) == 1)
        #expect(abs(ease.share(at: at(1.1), walking: false, over: over) - 0.5) < 1e-9)
        #expect(ease.share(at: at(1.3), walking: false, over: over) == 0)
    }

    /// Walking again while easing out goes on from where the ease out had got to, in the frame before `begin`
    /// and after it.
    @Test func walkingAgainCarriesOnFromTheEaseOut() {
        var ease = WalkEase()
        ease.begin(at: t0, over: over)
        ease.end(at: at(1), over: over)
        let then: Double = ease.share(at: at(1.05), walking: false, over: over)
        #expect(then > 0.5 && then < 1)
        // SwiftUI draws the new activity first.
        #expect(abs(ease.share(at: at(1.05), walking: true, over: over) - then) < 1e-9)
        ease.begin(at: at(1.05), over: over)
        #expect(abs(ease.share(at: at(1.05), walking: true, over: over) - then) < 1e-9)
        #expect(ease.share(at: at(1.06), walking: true, over: over) > then)
        #expect(ease.share(at: at(1.3), walking: true, over: over) == 1)
    }

    /// Stopping while easing in goes back down from where the ease in had got to, in the frame before `end`
    /// and after it.
    @Test func stoppingWhileEasingInCarriesOn() {
        var ease = WalkEase()
        ease.begin(at: t0, over: over)
        let then: Double = ease.share(at: at(0.05), walking: true, over: over)
        #expect(then > 0 && then < 0.5)
        #expect(abs(ease.share(at: at(0.05), walking: false, over: over) - then) < 1e-9)
        ease.end(at: at(0.05), over: over)
        #expect(abs(ease.share(at: at(0.05), walking: false, over: over) - then) < 1e-9)
        #expect(ease.share(at: at(0.06), walking: false, over: over) < then)
        #expect(ease.share(at: at(0.3), walking: false, over: over) == 0)
    }

    /// A walk that has ended, before the task calls `end`, still shows in full; once home it shows none.
    @Test func aWalkJustEndedHoldsUntilItEases() {
        var ease = WalkEase()
        ease.begin(at: t0, over: over)
        #expect(ease.share(at: at(1), walking: false, over: over) == 1)
        #expect(ease.easing)
        ease.end(at: at(1), over: over)
        ease.stop = nil
        #expect(!ease.easing)
        #expect(ease.share(at: at(2), walking: false, over: over) == 0)
    }
}
