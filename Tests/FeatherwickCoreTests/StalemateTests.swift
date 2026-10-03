import Foundation
import Testing
@testable import FeatherwickCore

/// Design rule: the player can never get stuck. Every game must always have a way forward to
/// eggs (an adult hen) and to hatching (a hen and a rooster).
/// Known gaps are marked `withKnownIssue` until the design decides how to close them.
struct StalemateTests {
    func owned(_ s: GameState) -> [Bird] { s.birdsAtHome + s.lost.map(\.bird) + s.boarding }

    @Test func aRoosterStarterAlwaysGetsAHen() {
        var (s, rng) = startedGame(sex: .rooster, rules: calmRules())
        for _ in 0..<s.rules.growerAge { night(&s, &rng) }
        #expect(owned(s).contains { $0.sex == .hen })
    }

    @Test func aHenStarterCanEventuallyHatch() {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        for _ in 0..<200 { night(&s, &rng) }
        withKnownIssue("No way yet to get a rooster with a hen start: needs a shop or a neighbour safety net") {
            #expect(owned(s).contains { $0.sex == .rooster })
        }
    }

    @Test func rehomingTheOnlyHenLeavesNoWayToEggs() {
        var (s, rng) = startedGame(sex: .rooster, rules: calmRules())
        for _ in 0..<s.rules.growerAge { night(&s, &rng) }
        let hen = owned(s).first { $0.sex == .hen }!
        _ = Engine.apply(.rehome(hen.id), to: &s, using: &rng)
        withKnownIssue("A rooster-only flock can never lay or hatch: needs a shop or a neighbour safety net") {
            #expect(owned(s).contains { $0.sex == .hen })
        }
    }
}
