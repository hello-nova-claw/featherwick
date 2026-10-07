import FeatherwickCore
import SwiftUI

/// A tree design, drawn as simple shapes until the painted trees exist. The trunk and the canopy are
/// separate parts in separate materials, so the season ramp colours leaves and bark apart.
/// A new panel gets a new tree line from these few designs (`TreeLine`), with no new painting.
enum TreeKind: Int, CaseIterable {
    case oak, poplar, pine, apple, birch

    /// Width over height of the drawing.
    var aspect: CGFloat {
        switch self {
        case .oak: 0.86
        case .poplar: 0.4
        case .pine: 0.56
        case .apple: 1.05
        case .birch: 0.6
        }
    }

    /// Height at full size (at the bottom edge of the panel), as a fraction of the panel height.
    var height: CGFloat {
        switch self {
        case .oak: 0.36
        case .poplar: 0.42
        case .pine: 0.38
        case .apple: 0.26
        case .birch: 0.34
        }
    }

    /// The parts, back to front, in unit space over the drawing: (0, 0) top left, (0.5, 1) the trunk base.
    var parts: [TreePart] {
        switch self {
        case .oak: Self.oakParts
        case .poplar: Self.poplarParts
        case .pine: Self.pineParts
        case .apple: Self.appleParts
        case .birch: Self.birchParts
        }
    }

    private static let oakParts: [TreePart] = [
        .trunk(0.5, top: 0.5, width: 0.13, value: 0.45),
        .blob(0.5, 0.4, 0.46, 0.3, .leaves, value: 0.25),
        .blob(0.32, 0.4, 0.2, 0.17, .leaves, value: 0.5),
        .blob(0.64, 0.33, 0.24, 0.2, .leaves, value: 0.55),
        .blob(0.46, 0.22, 0.23, 0.18, .leaves, value: 0.62),
        .blob(0.4, 0.17, 0.11, 0.08, .leaves, value: 0.85),
        .blob(0.62, 0.24, 0.09, 0.07, .leaves, value: 0.8),
    ]

    private static let poplarParts: [TreePart] = [
        .trunk(0.5, top: 0.72, width: 0.12, value: 0.4),
        .blob(0.5, 0.42, 0.44, 0.4, .leaves, value: 0.28),
        .blob(0.45, 0.38, 0.3, 0.32, .leaves, value: 0.55),
        .blob(0.42, 0.26, 0.16, 0.16, .leaves, value: 0.8),
    ]

    private static let pineParts: [TreePart] = [
        .trunk(0.5, top: 0.75, width: 0.1, value: 0.35),
        .cone(0.5, top: 0.38, bottom: 0.86, width: 1.0, .evergreen, value: 0.3),
        .cone(0.5, top: 0.18, bottom: 0.64, width: 0.78, .evergreen, value: 0.5),
        .cone(0.5, top: 0.0, bottom: 0.42, width: 0.54, .evergreen, value: 0.72),
    ]

    private static let appleParts: [TreePart] = [
        .trunk(0.5, top: 0.55, width: 0.12, value: 0.5),
        .blob(0.5, 0.38, 0.48, 0.34, .leaves, value: 0.32),
        .blob(0.38, 0.33, 0.24, 0.22, .leaves, value: 0.58),
        .blob(0.63, 0.36, 0.22, 0.2, .leaves, value: 0.6),
        .blob(0.45, 0.2, 0.14, 0.1, .leaves, value: 0.85),
    ]

    private static let birchParts: [TreePart] = [
        .trunk(0.5, top: 0.2, width: 0.08, value: 0.9),
        .blob(0.38, 0.32, 0.22, 0.14, .leaves, value: 0.4),
        .blob(0.64, 0.24, 0.2, 0.13, .leaves, value: 0.45),
        .blob(0.5, 0.12, 0.2, 0.11, .leaves, value: 0.62),
        .blob(0.42, 0.28, 0.12, 0.07, .leaves, value: 0.82),
        .blob(0.62, 0.2, 0.1, 0.06, .leaves, value: 0.8),
    ]
}

/// One shape of a tree drawing, in unit space over the drawing. Its fill is value + material
/// (`SeasonRamp.paint`), not a colour.
enum TreePart {
    /// A trunk from the base (bottom centre at `x`) up to `top`, narrowing as it rises.
    case trunk(CGFloat, top: CGFloat, width: CGFloat, value: Double)
    /// An ellipse: centre x, centre y, radius x, radius y.
    case blob(CGFloat, CGFloat, CGFloat, CGFloat, SeasonRamp.Material, value: Double)
    /// A triangle: centre x, apex y, base y, base width.
    case cone(CGFloat, top: CGFloat, bottom: CGFloat, width: CGFloat, SeasonRamp.Material, value: Double)

    /// The path in a drawing of `size`.
    func path(in size: CGSize) -> Path {
        let w: CGFloat = size.width
        let h: CGFloat = size.height
        var p = Path()
        switch self {
        case .trunk(let x, let top, let width, _):
            p.move(to: CGPoint(x: (x - width / 2) * w, y: h))
            p.addLine(to: CGPoint(x: (x + width / 2) * w, y: h))
            p.addLine(to: CGPoint(x: (x + width * 0.3) * w, y: top * h))
            p.addLine(to: CGPoint(x: (x - width * 0.3) * w, y: top * h))
            p.closeSubpath()
        case .blob(let x, let y, let rx, let ry, _, _):
            p.addEllipse(in: CGRect(x: (x - rx) * w, y: (y - ry) * h, width: 2 * rx * w, height: 2 * ry * h))
        case .cone(let x, let top, let bottom, let width, _, _):
            p.move(to: CGPoint(x: x * w, y: top * h))
            p.addLine(to: CGPoint(x: (x + width / 2) * w, y: bottom * h))
            p.addLine(to: CGPoint(x: (x - width / 2) * w, y: bottom * h))
            p.closeSubpath()
        }
        return p
    }

    /// The fill the season ramp reads.
    var paint: Color {
        switch self {
        case .trunk(_, _, _, let value): SeasonRamp.paint(.trunk, value: value)
        case .blob(_, _, _, _, let material, let value): SeasonRamp.paint(material, value: value)
        case .cone(_, _, _, _, let material, let value): SeasonRamp.paint(material, value: value)
        }
    }
}

/// One tree standing in a scene panel.
struct PlacedTree: Identifiable {
    let id: Int
    let kind: TreeKind
    /// The trunk base, its ground point, in unit coordinates over the panel.
    let base: CGPoint
    /// Size against the design's full size, before depth scales it.
    let size: CGFloat
    /// Drawn mirrored left to right.
    let flipped: Bool
    /// Turns the leaves' hue a little (radians), so trees of one kind differ, most of all in autumn.
    let hueShift: Double
    /// Sway: degrees each way, seconds per swing, and a delay so no two trees move together.
    let swayDegrees: Double
    let swaySeconds: Double
    let swayDelay: Double
}

/// Places trees along a panel's hill line, and one or two lower in the yard. Seeded per panel (never
/// the game's dice), so a panel always has the same trees and the game is unchanged.
enum TreeLine {
    /// Gap between trees on the hill line, as a fraction of the panel width.
    static let spacing: ClosedRange<CGFloat> = 0.16...0.32
    /// Size against the design, before depth.
    static let size: ClosedRange<CGFloat> = 0.8...1.2
    /// How far a hill-line tree stands from the line: a little up the slope, or just on it.
    static let hillJitter: ClosedRange<CGFloat> = -0.014...0.004
    /// Lower trees: how many, and how far below the hill line (fraction of the panel height).
    static let lowerCount: ClosedRange<Int> = 1...2
    static let lowerDrop: ClosedRange<CGFloat> = 0.12...0.3
    /// Most a leaf hue turns, in radians.
    static let hueRange: ClosedRange<Double> = -0.28...0.28

    /// The trees of one panel. `hillY` is the hill line as a fraction of the panel height. With a walk
    /// mask, a lower tree stands only on walkable ground (so its trunk base is on the yard).
    static func make(panel: FarmPanel, seed: UInt64, hillY: CGFloat, mask: WalkMask? = nil) -> [PlacedTree] {
        var rng = SeededRNG(seed: seed &+ UInt64(panel.rawValue) &* 0x9E37_79B9)
        var trees: [PlacedTree] = []
        var x: CGFloat = CGFloat.random(in: -0.04...0.1, using: &rng)
        while x < 1.04 {
            let y: CGFloat = hillY + CGFloat.random(in: hillJitter, using: &rng)
            trees.append(tree(id: trees.count, at: CGPoint(x: x, y: y), using: &rng))
            x += CGFloat.random(in: spacing, using: &rng)
        }
        let lower: Int = Int.random(in: lowerCount, using: &rng)
        for _ in 0..<lower {
            if let spot = lowerSpot(panel: panel, hillY: hillY, mask: mask, using: &rng) {
                trees.append(tree(id: trees.count, at: spot, using: &rng))
            }
        }
        return trees
    }

    /// How far past a panel edge a tree may stand and still show on that panel (its canopy reaches in).
    static let edgeReach: CGFloat = 0.15

    /// One tree line across panels that join (the Yard, then the Far yard to its right), so the hill
    /// line runs on without a seam. A tree near the join shows on both panels, each copy clipped at
    /// its edge. Lower trees stand only by a panel's outer edge, never at the join.
    static func makeJoined(_ panels: [FarmPanel], seed: UInt64, hillY: CGFloat) -> [FarmPanel: [PlacedTree]] {
        var rng = SeededRNG(seed: seed)
        var line: [PlacedTree] = []
        var x: CGFloat = CGFloat.random(in: -0.04...0.1, using: &rng)
        while x < CGFloat(panels.count) + 0.04 {
            let y: CGFloat = hillY + CGFloat.random(in: hillJitter, using: &rng)
            line.append(tree(id: line.count, at: CGPoint(x: x, y: y), using: &rng))
            x += CGFloat.random(in: spacing, using: &rng)
        }
        var out: [FarmPanel: [PlacedTree]] = [:]
        for (index, panel) in panels.enumerated() {
            let left: CGFloat = CGFloat(index)
            let near: [PlacedTree] = line.filter { $0.base.x >= left - edgeReach && $0.base.x <= left + 1 + edgeReach }
            var trees: [PlacedTree] = []
            for t in near { trees.append(moved(t, by: -left, id: trees.count)) }
            // Lower trees by the outer edge only: the first panel's left, the last panel's right.
            var sides: [ClosedRange<CGFloat>] = []
            if index == 0 { sides.append(0.02...0.12) }
            if index == panels.count - 1 { sides.append(0.88...0.98) }
            let lower: Int = Int.random(in: lowerCount, using: &rng)
            for _ in 0..<lower where !sides.isEmpty {
                let mask: WalkMask? = WalkMask.all[panel]
                if let spot = lowerSpot(panel: panel, hillY: hillY, mask: mask, sides: sides, using: &rng) {
                    trees.append(tree(id: trees.count, at: spot, using: &rng))
                }
            }
            out[panel] = trees
        }
        return out
    }

    /// The same tree, its base moved across by `dx` panel widths, with a new id.
    private static func moved(_ t: PlacedTree, by dx: CGFloat, id: Int) -> PlacedTree {
        PlacedTree(
            id: id, kind: t.kind, base: CGPoint(x: t.base.x + dx, y: t.base.y), size: t.size,
            flipped: t.flipped, hueShift: t.hueShift, swayDegrees: t.swayDegrees, swaySeconds: t.swaySeconds,
            swayDelay: t.swayDelay)
    }

    /// A spot near the left or right edge, below the hill line, clear of the building ground.
    private static func lowerSpot(
        panel: FarmPanel, hillY: CGFloat, mask: WalkMask?,
        sides: [ClosedRange<CGFloat>] = [0.02...0.12, 0.88...0.98], using rng: inout SeededRNG
    ) -> CGPoint? {
        for _ in 0..<8 {
            guard let side: ClosedRange<CGFloat> = sides.randomElement(using: &rng) else { return nil }
            let spot = CGPoint(
                x: CGFloat.random(in: side, using: &rng), y: hillY + CGFloat.random(in: lowerDrop, using: &rng))
            // Keep clear of the building ground, with room for the building to show.
            let building: CGRect? = SceneArtLayout.reserved(panel)?.insetBy(dx: -0.05, dy: -0.03)
            if let building, building.contains(spot) { continue }
            if let mask, !mask.isWalkable(spot) { continue }
            return spot
        }
        return nil
    }

    private static func tree(id: Int, at base: CGPoint, using rng: inout SeededRNG) -> PlacedTree {
        PlacedTree(
            id: id,
            kind: TreeKind.allCases.randomElement(using: &rng) ?? .oak,
            base: base,
            size: CGFloat.random(in: size, using: &rng),
            flipped: Bool.random(using: &rng),
            hueShift: Double.random(in: hueRange, using: &rng),
            swayDegrees: Double.random(in: 0.8...2.0, using: &rng),
            swaySeconds: Double.random(in: 2.8...4.6, using: &rng),
            swayDelay: Double.random(in: 0...2, using: &rng))
    }
}

/// The shapes of one tree design, in value + material. The season ramp colours it.
struct TreeDrawing: View {
    let kind: TreeKind

    var body: some View {
        Canvas { context, size in
            for part in kind.parts {
                context.fill(part.path(in: size), with: .color(part.paint))
            }
        }
    }
}

/// One tree in the scene: its drawing through the season ramp, mirrored if placed so, swaying slowly
/// about its trunk base. The sway is one repeating animation (no timer and no redraw of the scene).
/// With Reduce Motion on, the tree stands still.
struct SceneTree: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tree: PlacedTree
    let season: Season
    let night: Bool
    /// The tree's height on screen, in points, after depth.
    let height: CGFloat
    @State private var swaying = false

    var body: some View {
        TreeDrawing(kind: tree.kind)
            .frame(width: height * tree.kind.aspect, height: height)
            .seasonRamp(season, set: .trees, hueShift: tree.hueShift, night: night)
            .scaleEffect(x: tree.flipped ? -1 : 1, y: 1)
            // Scoped to the rotation only, so the repeating animation never catches a layout change.
            .animation(sway) { content in
                content.rotationEffect(.degrees(angle), anchor: .bottom)
            }
            .onAppear { swaying = !reduceMotion }
            .onChange(of: reduceMotion) { _, still in swaying = !still }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var angle: Double {
        if reduceMotion { return 0 }
        return swaying ? tree.swayDegrees : -tree.swayDegrees
    }

    private var sway: Animation? {
        if reduceMotion { return nil }
        return .easeInOut(duration: tree.swaySeconds).repeatForever(autoreverses: true).delay(tree.swayDelay)
    }
}
