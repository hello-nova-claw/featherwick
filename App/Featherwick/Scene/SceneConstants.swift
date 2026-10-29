import CoreGraphics

/// Presentation numbers for the farm scene that are not game rules. They change how the scene looks and
/// moves, never the game, so they live here and not in Core's `Rules`.
enum SceneConstants {
    // MARK: - The ripple (a tap on the ground)

    /// After a ripple, a bird stays where it went this long, in seconds, then wanders again.
    static let rippleHoldSeconds: Double = 3
    /// A ripple counts only this soon after the tap, in seconds. A bird that walks in later ignores it.
    static let rippleFreshSeconds: Double = 0.5
    /// Each bird looks up for a moment first, in seconds, so the flock does not move as one.
    static let rippleStartle: ClosedRange<Double> = 0.05...0.25
    /// Dashed rings in the ripple mark, and how long it spreads, in seconds.
    static let rippleRingCount = 3
    static let rippleDuration: Double = 0.6
    /// With Reduce Motion: one ring, quickly.
    static let rippleReducedRingCount = 1
    static let rippleReducedDuration: Double = 0.2
    /// With Reduce Motion a bird answers in place: it turns, or sits, over this long, in seconds.
    static let rippleReducedPoseSeconds: Double = 0.2
    /// Rings start this small and this strong, then spread and fade.
    static let rippleRingStartScale: CGFloat = 0.15
    static let rippleRingStartOpacity: Double = 0.9
    /// The last ring starts this far into the ripple (a fraction of its duration). The others start in between.
    static let rippleRingStagger: Double = 0.5
    /// The widest ring, in points at full size. Rings are flat on the ground, so they are this much as tall.
    static let rippleRadius: CGFloat = 40
    static let rippleFlatten: CGFloat = 0.4
    /// A wild bird runs this far away, as a fraction of the panel width.
    static let rippleFleeReach: CGFloat = 0.35
    /// A skittish bird walks this far away (a few steps), as a fraction of the panel width.
    static let rippleShyStep: CGFloat = 0.08
    /// A lap chicken sits this many body lengths from the tap: right by it.
    static let rippleNestleGap: CGFloat = 0.5
    /// A running bird moves this many times its amble.
    static let rippleRunFactor: CGFloat = 2.5
    /// A run lasts at least this long, and at most the upper bound, in seconds.
    static let rippleRunTime: ClosedRange<Double> = 0.4...2.5
    /// Steps along a way out before a bird gives up on it, from the full reach down.
    static let rippleTries = 6
    /// Ways out to try, in radians off straight away from the tap: straight first, then a little to
    /// each side, then more.
    static let rippleSideTurns: [CGFloat] = [0, 0.5, -0.5, 1, -1]
    /// A ripple never sends a bird closer than this to the left or right edge (a fraction of the panel).
    static let rippleEdge: CGFloat = 0.03

    // MARK: - Walking

    /// A walk cut short (a ripple, a resize) eases to a stop where the bird is drawn over this long, in seconds.
    static let settleSeconds: Double = 0.15

    // MARK: - Painted birds

    /// Slack round a skinned run's painted bounds, in bird heights: the shader draws nothing outside them,
    /// so this keeps a part that grows or turns at rest.
    static let skinPaintSlack: CGFloat = 0.05
}
