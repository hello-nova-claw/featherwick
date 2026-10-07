import Foundation
import ImageIO
import SwiftUI

/// Where birds can walk on a scene panel, from its walk-mask PNG (`Art/Scene/scene-<key>-walk.png`,
/// made by `scripts/make_scene_art.py`). White is ground; black is sky, hill, pond and the spots kept
/// for buildings. Coordinates are unit points over the panel: (0, 0) top left, (1, 1) bottom right.
struct WalkMask: Sendable {
    let width: Int
    let height: Int
    /// One byte per pixel, row by row from the top. Above half is walkable.
    let pixels: [UInt8]

    /// Is this unit point on walkable ground? Outside the panel is not.
    func isWalkable(_ unit: CGPoint) -> Bool {
        guard unit.x >= 0, unit.x < 1, unit.y >= 0, unit.y < 1, width > 0, height > 0 else { return false }
        let x: Int = min(width - 1, Int(unit.x * CGFloat(width)))
        let y: Int = min(height - 1, Int(unit.y * CGFloat(height)))
        return pixels[y * width + x] > 127
    }

    /// A walkable unit point at most `maxStep` (unit distance) from `near`, for a bird's next walk.
    /// Tries a few random points in the circle; nil when none of them is walkable.
    func randomTarget(near: CGPoint, maxStep: CGFloat, using rng: inout some RandomNumberGenerator) -> CGPoint? {
        for _ in 0..<Self.tries {
            let angle: CGFloat = CGFloat.random(in: 0..<(2 * .pi), using: &rng)
            // The square root spreads the points evenly over the circle, not bunched in the middle.
            let reach: CGFloat = maxStep * CGFloat.random(in: 0...1, using: &rng).squareRoot()
            let point = CGPoint(x: near.x + cos(angle) * reach, y: near.y + sin(angle) * reach)
            if isWalkable(point) { return point }
        }
        return nil
    }

    /// Enough tries to find ground from almost anywhere walkable, few enough to stay cheap.
    static let tries = 12

    /// Reads a greyscale (or any) PNG into one byte per pixel. Nil if the file is missing or unreadable.
    static func load(url: URL) -> WalkMask? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        let width: Int = image.width
        let height: Int = image.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer -> Bool in
            let context: CGContext? = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
            guard let context else { return false }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? WalkMask(width: width, height: height, pixels: pixels) : nil
    }

    /// The walk mask of each scene panel, read once on first use.
    static let all: [FarmPanel: WalkMask] = {
        var out: [FarmPanel: WalkMask] = [:]
        for panel in FarmPanel.allCases {
            guard let key = SceneArtLayout.key(panel),
                let url = Bundle.main.url(forResource: "scene-\(key)-walk", withExtension: "png"),
                let mask = load(url: url)
            else { continue }
            out[panel] = mask
        }
        return out
    }()
}
