import FeatherwickCore
import SwiftUI
import UIKit

/// A 2.5D farm panel (the Yard and the Far yard): placeholder art built the way the paintings will be.
///
/// Three groups, back to front:
/// 1. Back: the landscape (sky, far hills, the yard), never sorted.
/// 2. Middle: trees, then the caller's `middle` content, all in one `ZStack`. Each thing sets
///    `.zIndex(depth.zIndex(forGroundY:))` from its ground point and scales by `depth.scale(atGroundY:)`,
///    so a bird walks behind a tree while its feet are above the tree's base.
/// 3. Front: grass tufts on the bottom edge, always on top.
///
/// Colour comes from the season ramp (`SeasonRamp`): the art holds only value and material.
/// Nothing here runs on a timer; only the trees' sway animates.
struct FarmScene<Middle: View>: View {
    @Environment(\.palette) private var palette
    let panel: FarmPanel
    let season: Season
    let middle: (SceneDepth, CGSize) -> Middle

    /// `middle` gets the panel's depth and size, and returns views for the middle group. Return them as a
    /// `ForEach` (or a `Group`), not inside another stack, so each one's `.zIndex` sorts against the trees.
    init(panel: FarmPanel, season: Season, @ViewBuilder middle: @escaping (SceneDepth, CGSize) -> Middle) {
        self.panel = panel
        self.season = season
        self.middle = middle
    }

    var body: some View {
        GeometryReader { geo in
            let size: CGSize = geo.size
            let depth = SceneDepth(panel: panel, size: size)
            ZStack(alignment: .topLeading) {
                SceneBackdrop(panel: panel, season: season, night: palette.isNight)
                    .frame(width: size.width, height: size.height)
                middleGroup(depth: depth, size: size)
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                GrassTufts(seed: SceneArt.seed(panel), season: season, night: palette.isNight)
                    .frame(width: size.width)
                    .offset(y: size.height - GrassTufts.height)
            }
            // Trees at the edges stop at the panel's edge, not over the next panel.
            .clipped()
        }
        .ignoresSafeArea()
    }

    /// Trees and the caller's content, sorted together by ground Y.
    private func middleGroup(depth: SceneDepth, size: CGSize) -> some View {
        let trees: [PlacedTree] = SceneArt.trees(for: panel)
        return ZStack(alignment: .topLeading) {
            ForEach(trees) { tree in
                treeView(tree, depth: depth, size: size)
            }
            middle(depth, size)
        }
    }

    private func treeView(_ tree: PlacedTree, depth: SceneDepth, size: CGSize) -> some View {
        let groundY: CGFloat = tree.base.y * size.height
        let height: CGFloat = tree.kind.height * tree.size * depth.scale(atGroundY: groundY) * size.height
        return SceneTree(tree: tree, season: season, night: palette.isNight, height: height)
            .position(x: tree.base.x * size.width, y: groundY - height / 2)
            .zIndex(depth.zIndex(forGroundY: groundY))
    }
}

extension FarmScene where Middle == EmptyView {
    /// A scene with nothing of the caller's in the middle group.
    init(panel: FarmPanel, season: Season) {
        self.init(panel: panel, season: season) { _, _ in EmptyView() }
    }

    /// Where birds can walk on a panel. Nil on a panel without a scene. Same as `SceneArt.walkMask(for:)`.
    static func walkMask(for panel: FarmPanel) -> WalkMask? {
        SceneArt.walkMask(for: panel)
    }
}

/// The back group: the landscape PNG, stretched to the panel, through the season ramp.
/// A panel without its PNG shows its flat stand-in colour.
private struct SceneBackdrop: View {
    let panel: FarmPanel
    let season: Season
    let night: Bool

    var body: some View {
        if let image = SceneArt.landscape(for: panel) {
            // Stretched, not cropped: the hill line and the walk mask are fractions of the panel.
            Image(uiImage: image)
                .resizable()
                .interpolation(.medium)
                .seasonRamp(season, set: .land, night: night)
                .accessibilityHidden(true)
        } else {
            panel.colour
        }
    }
}

/// The scene art and layout per panel, loaded once. Not generic, so bird code can reach it without
/// naming a `FarmScene` type.
enum SceneArt {
    /// Is there a scene for this panel? The Barn and the Shop have none yet.
    static func hasScene(_ panel: FarmPanel) -> Bool {
        SceneArtLayout.key(panel) != nil
    }

    /// Where birds can walk on a panel, in unit coordinates. Nil without a scene.
    static func walkMask(for panel: FarmPanel) -> WalkMask? {
        WalkMask.all[panel]
    }

    /// The depth of a panel of `size`: hill line from the art, bottom at the panel's bottom edge.
    static func depth(for panel: FarmPanel, size: CGSize) -> SceneDepth {
        SceneDepth(panel: panel, size: size)
    }

    /// The panel's own seed for trees and tufts. Fixed, so a panel looks the same every launch.
    static func seed(_ panel: FarmPanel) -> UInt64 {
        0xFEA7_4E2B_1C0D_0000 &+ UInt64(panel.rawValue)
    }

    /// The trees of a panel, placed once.
    static func trees(for panel: FarmPanel) -> [PlacedTree] {
        treeLines[panel] ?? []
    }

    private static let treeLines: [FarmPanel: [PlacedTree]] = {
        // The Yard and the Far yard are one landscape (see `scripts/make_scene_art.py`), so they share one
        // tree line that runs across the join. Any other scene panel gets its own.
        let joined: [FarmPanel] = [.yard, .farYard].filter { SceneArtLayout.hillLine($0) != nil }
        var out: [FarmPanel: [PlacedTree]] = [:]
        if let first = joined.first, let hill = SceneArtLayout.hillLine(first) {
            out = TreeLine.makeJoined(joined, seed: seed(first), hillY: hill)
        }
        for panel in FarmPanel.allCases where out[panel] == nil {
            guard let hill = SceneArtLayout.hillLine(panel) else { continue }
            out[panel] = TreeLine.make(panel: panel, seed: seed(panel), hillY: hill, mask: WalkMask.all[panel])
        }
        return out
    }()

    /// The landscape PNG of a panel (`Art/Scene/scene-<key>-land.png`). Nil without a scene.
    @MainActor static func landscape(for panel: FarmPanel) -> UIImage? {
        landscapes[panel]
    }

    @MainActor private static let landscapes: [FarmPanel: UIImage] = {
        var out: [FarmPanel: UIImage] = [:]
        for panel in FarmPanel.allCases {
            guard let key = SceneArtLayout.key(panel), let image = UIImage(named: "scene-\(key)-land.png") else {
                continue
            }
            out[panel] = image
        }
        return out
    }()
}
