import CoreGraphics
import FeatherwickCore
import Testing

@testable import Featherwick

@Suite struct RippleReactionTests {
    @Test func everyBandHasItsOwnReaction() {
        let reactions: [RippleReaction] = Friendliness.allCases.map { RippleReaction(band: $0) }
        #expect(reactions.count == 4)
        #expect(Set(reactions).count == Friendliness.allCases.count)
        #expect(Set(reactions) == Set(RippleReaction.allCases))
    }

    @Test func bandsMapToTheirReactions() {
        #expect(RippleReaction(band: .wild) == .flee)
        #expect(RippleReaction(band: .skittish) == .stepAway)
        #expect(RippleReaction(band: .friendly) == .approach)
        #expect(RippleReaction(band: .lapChicken) == .nestle)
    }

    @Test func wildAndLapChickensRunTheOthersWalk() {
        #expect(RippleReaction.flee.runs)
        #expect(RippleReaction.nestle.runs)
        #expect(!RippleReaction.stepAway.runs)
        #expect(!RippleReaction.approach.runs)
    }

    @Test func awayReactionsMoveAwayFromTheTap() {
        let spot = CGPoint(x: 200, y: 300)
        let tap = CGPoint(x: 150, y: 300)
        for reaction in [RippleReaction.flee, .stepAway] {
            let target: CGPoint = reaction.target(
                from: spot, tap: tap, bodyLength: 40, panelWidth: 400, isWalkable: { _ in true })
            #expect(target.x > spot.x)
        }
        let far: CGPoint = RippleReaction.flee.target(
            from: spot, tap: tap, bodyLength: 40, panelWidth: 400, isWalkable: { _ in true })
        let near: CGPoint = RippleReaction.stepAway.target(
            from: spot, tap: tap, bodyLength: 40, panelWidth: 400, isWalkable: { _ in true })
        #expect(far.x > near.x)
    }

    @Test func noGroundAwayMeansTheBirdStays() {
        let spot = CGPoint(x: 200, y: 300)
        let target: CGPoint = RippleReaction.flee.target(
            from: spot, tap: CGPoint(x: 150, y: 300), bodyLength: 40, panelWidth: 400, isWalkable: { _ in false })
        #expect(target == spot)
    }

    @Test func friendlyStopsABodyLengthShort() {
        let tap = CGPoint(x: 100, y: 300)
        let target: CGPoint = RippleReaction.approach.target(
            from: CGPoint(x: 300, y: 300), tap: tap, bodyLength: 40, panelWidth: 400, isWalkable: { _ in true })
        #expect(abs(target.x - 140) < 0.001)
        #expect(abs(target.y - 300) < 0.001)
    }

    @Test func lapChickenSitsCloserThanFriendly() {
        let tap = CGPoint(x: 100, y: 300)
        let spot = CGPoint(x: 300, y: 300)
        let friendly: CGPoint = RippleReaction.approach.target(
            from: spot, tap: tap, bodyLength: 40, panelWidth: 400, isWalkable: { _ in true })
        let lap: CGPoint = RippleReaction.nestle.target(
            from: spot, tap: tap, bodyLength: 40, panelWidth: 400, isWalkable: { _ in true })
        #expect(lap.x < friendly.x)
        #expect(lap.x > tap.x)
    }
}
