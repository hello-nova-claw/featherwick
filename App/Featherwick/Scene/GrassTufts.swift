import FeatherwickCore
import SwiftUI

/// The front group of the scene: grass tufts along the bottom edge, always on top of the birds and
/// trees, so the nearest ground has something in front of it. Drawn in value + grass material, so
/// the season ramp colours them with the yard. Seeded per panel: the same tufts every time.
struct GrassTufts: View {
    let seed: UInt64
    let season: Season
    let night: Bool

    /// The strip's height, in points.
    static let height: CGFloat = 64
    /// Gap between tufts, in points.
    static let spacing: ClosedRange<CGFloat> = 14...30
    /// Blade length, in points: the back row, then the front row.
    static let backBlade: ClosedRange<CGFloat> = 16...30
    static let frontBlade: ClosedRange<CGFloat> = 26...46

    var body: some View {
        Canvas { context, size in
            var rng = SeededRNG(seed: seed)
            // The back row: darker, shorter, a little up from the edge.
            drawRow(in: &context, size: size, baseY: size.height - 14, blade: Self.backBlade, value: 0.3, rng: &rng)
            drawRow(in: &context, size: size, baseY: size.height + 4, blade: Self.frontBlade, value: 0.58, rng: &rng)
        }
        .frame(height: Self.height)
        .seasonRamp(season, set: .land, night: night)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// One row of tufts across the width. Each tuft is a fan of 3–5 blades; the outer blades lean out.
    private func drawRow(
        in context: inout GraphicsContext, size: CGSize, baseY: CGFloat, blade: ClosedRange<CGFloat>,
        value: Double, rng: inout SeededRNG
    ) {
        var x: CGFloat = CGFloat.random(in: -10...6, using: &rng)
        while x < size.width + 10 {
            let blades: Int = Int.random(in: 3...5, using: &rng)
            let shade: Double = value + Double.random(in: -0.08...0.12, using: &rng)
            var path = Path()
            for i in 0..<blades {
                let lean: CGFloat = (CGFloat(i) - CGFloat(blades - 1) / 2) * CGFloat.random(in: 5...9, using: &rng)
                let length: CGFloat = CGFloat.random(in: blade, using: &rng)
                let root: CGFloat = x + CGFloat(i) * 3
                path.move(to: CGPoint(x: root - 2.5, y: baseY))
                path.addQuadCurve(
                    to: CGPoint(x: root + lean, y: baseY - length),
                    control: CGPoint(x: root - 1, y: baseY - length * 0.6))
                path.addQuadCurve(
                    to: CGPoint(x: root + 2.5, y: baseY),
                    control: CGPoint(x: root + 1.5, y: baseY - length * 0.5))
                path.closeSubpath()
            }
            context.fill(path, with: .color(SeasonRamp.paint(.grass, value: min(1, max(0, shade)))))
            x += CGFloat.random(in: Self.spacing, using: &rng)
        }
    }
}
