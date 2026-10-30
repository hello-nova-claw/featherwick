import QuartzCore
import SwiftUI

/// A live frame rate for the frame budget stage, so a phone can be checked without Instruments. It counts
/// display frames each second and the longest frame in that second. A frame that takes more than one and a
/// half of the display link's frame times is a dropped frame. Instruments (Animation Hitches) stays the real
/// measure: this sees the main thread's frames, not the render server's.
@MainActor @Observable final class FrameMeter {
    /// Frames in the last whole second.
    private(set) var fps: Int = 0
    /// The longest frame in the last whole second, in milliseconds.
    private(set) var worstMilliseconds: Double = 0
    /// Frames dropped since the meter started.
    private(set) var dropped: Int = 0
    /// The screen's top rate (60, or 120 with ProMotion). From the app's window scene, as `UIScreen.main` is
    /// deprecated; 60 if no scene is connected yet.
    let target: Int =
        UIApplication.shared.connectedScenes.lazy.compactMap { ($0 as? UIWindowScene)?.screen }.first?
        .maximumFramesPerSecond ?? 60

    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var windowStart: CFTimeInterval = 0
    private var frames: Int = 0
    private var worst: CFTimeInterval = 0

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: Ticker(meter: self), selector: #selector(Ticker.tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: Float(target), preferred: Float(target))
        link.add(to: .main, forMode: .common)
        self.link = link
        last = 0
        dropped = 0
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    /// `expected` is the link's own frame time: a 120 Hz screen may run the link at 60.
    fileprivate func tick(at time: CFTimeInterval, frame expected: CFTimeInterval) {
        defer { last = time }
        guard last > 0 else {
            windowStart = time
            return
        }
        let frame: CFTimeInterval = time - last
        frames += 1
        worst = max(worst, frame)
        if expected > 0, frame > 1.5 * expected { dropped += Int((frame / expected).rounded()) - 1 }
        if time - windowStart >= 1 {
            fps = Int((Double(frames) / (time - windowStart)).rounded())
            worstMilliseconds = worst * 1000
            frames = 0
            worst = 0
            windowStart = time
        }
    }
}

/// The display link's target. A separate object, so the link (which keeps its target) does not keep the
/// meter.
private final class Ticker: NSObject {
    weak var meter: FrameMeter?

    init(meter: FrameMeter) { self.meter = meter }

    @MainActor @objc func tick(_ link: CADisplayLink) {
        meter?.tick(at: link.timestamp, frame: link.targetTimestamp - link.timestamp)
    }
}

/// The meter's numbers in a corner of a stage. A view of its own, so each second's update redraws only
/// these lines, not the stage under them.
struct FrameReadout: View {
    let meter: FrameMeter

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("\(meter.fps) / \(meter.target) fps")
            Text(String(format: "longest %.1f ms", meter.worstMilliseconds))
            Text("dropped \(meter.dropped)")
        }
        .font(Typeface.caption.monospacedDigit())
        .foregroundStyle(palette.ink)
        .padding(Space.xs)
        .background(palette.paper.opacity(0.85), in: RoundedRectangle(cornerRadius: Radius.control))
        .padding(Space.s)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("frameReadout")
    }
}
