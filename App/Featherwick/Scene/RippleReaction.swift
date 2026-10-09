import CoreGraphics
import FeatherwickCore
import Foundation

/// How a bird answers a tap on the ground near it (the ripple), by its friendliness band. View only: a
/// ripple retargets a walk. It sends no command, saves nothing and changes no friendliness. It is not a pet.
enum RippleReaction: Hashable, Sendable, CaseIterable {
    /// Wild: runs to a far walkable point away from the tap.
    case flee
    /// Skittish: walks a few steps away.
    case stepAway
    /// Friendly: walks toward the tap and stops a body length short.
    case approach
    /// Lap chicken: runs to the tap and sits down by it for a while.
    case nestle

    init(band: Friendliness) {
        switch band {
        case .wild: self = .flee
        case .skittish: self = .stepAway
        case .friendly: self = .approach
        case .lapChicken: self = .nestle
        }
    }

    /// A run, not an amble.
    var runs: Bool { self == .flee || self == .nestle }

    /// Sits down where it stops (`ChickenActivity.sitting`), and gets up when the hold ends.
    var sits: Bool { self == .nestle }

    /// Where a bird at `spot` heads after a tap at `tap`. All points and lengths are in points on the
    /// panel. `isWalkable` tests a point in the same space. Away reactions try the straight way out first,
    /// then a little to each side, from the full reach down. With no ground that way, the bird stays.
    /// Toward reactions give a wish that the caller moves to walkable ground.
    func target(
        from spot: CGPoint, tap: CGPoint, bodyLength: CGFloat, panelWidth: CGFloat,
        isWalkable: (CGPoint) -> Bool
    ) -> CGPoint {
        let dx: CGFloat = spot.x - tap.x
        let dy: CGFloat = spot.y - tap.y
        let distance: CGFloat = (dx * dx + dy * dy).squareRoot()
        // Tapped right under the bird: any way out will do.
        let away: CGFloat = distance > 0.5 ? atan2(dy, dx) : 0
        switch self {
        case .flee, .stepAway:
            let reach: CGFloat =
                (self == .flee ? SceneConstants.rippleFleeReach : SceneConstants.rippleShyStep) * panelWidth
            let tries: Int = SceneConstants.rippleTries
            for turn: CGFloat in SceneConstants.rippleSideTurns {
                for k in 0..<tries {
                    let length: CGFloat = reach * CGFloat(tries - k) / CGFloat(tries)
                    let p = CGPoint(
                        x: spot.x + cos(away + turn) * length, y: spot.y + sin(away + turn) * length)
                    if isWalkable(p) { return p }
                }
            }
            return spot
        case .approach, .nestle:
            let gap: CGFloat = bodyLength * (self == .approach ? 1 : SceneConstants.rippleNestleGap)
            if distance <= gap { return spot }
            return CGPoint(x: tap.x + cos(away) * gap, y: tap.y + sin(away) * gap)
        }
    }
}
