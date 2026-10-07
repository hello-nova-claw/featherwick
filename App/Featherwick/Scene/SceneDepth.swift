import SwiftUI

/// Depth in the 2.5D farm scene comes from one number: the Y of a thing's ground point (its feet, a
/// trunk's base). Lower on screen is nearer. Nearer draws on top and draws bigger.
/// So a bird walks behind a tree while its feet are above the tree's base, and grows as it comes down
/// the yard. All values are in points, in the panel's own space.
struct SceneDepth: Equatable {
    /// Scale at the hill line, the farthest ground.
    static let farScale: CGFloat = 0.45
    /// Scale at the bottom edge of the panel, the nearest ground.
    static let nearScale: CGFloat = 1.0

    /// Where the hill meets the yard: the far edge of the ground.
    let hillY: CGFloat
    /// The bottom of the panel: the near edge of the ground.
    let groundBottomY: CGFloat

    init(hillY: CGFloat, groundBottomY: CGFloat) {
        self.hillY = hillY
        self.groundBottomY = max(groundBottomY, hillY + 1)
    }

    /// The depth for a panel of `size`, from the hill line baked into its art. A panel without a scene
    /// has its hill at the top, so everything on it is near.
    init(panel: FarmPanel, size: CGSize) {
        let hill: CGFloat = SceneArtLayout.hillLine(panel) ?? 0
        self.init(hillY: hill * size.height, groundBottomY: size.height)
    }

    /// 0 at the hill line, 1 at the bottom edge. Clamped: above the hill is as far as the hill.
    func nearness(atGroundY y: CGFloat) -> CGFloat {
        min(1, max(0, (y - hillY) / (groundBottomY - hillY)))
    }

    /// How big to draw something whose ground point is at `y`, against its full (nearest) size.
    func scale(atGroundY y: CGFloat) -> CGFloat {
        Self.farScale + (Self.nearScale - Self.farScale) * nearness(atGroundY: y)
    }

    /// The draw order for something whose ground point is at `y`: lower on screen draws on top.
    /// Use it on views in the scene's middle group (trees, buildings, birds), which share one stack.
    func zIndex(forGroundY y: CGFloat) -> Double {
        Double(y)
    }
}
