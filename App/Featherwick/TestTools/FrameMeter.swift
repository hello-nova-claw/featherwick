import QuartzCore
import SwiftUI

/// A live frame rate for the frame budget stage, so a phone can be checked without Instruments. It counts
/// display frames each second and the longest frame in that second. A frame that takes more than one and a
/// half of the screen's frame times is a dropped frame. Instruments (Animation Hitches) stays the real
/// measure: this sees the main thread's frames, not the render server's.
@MainActor @Observable final class FrameMeter {
    /// Frames in the last whole second.
    private(set) var fps: Int = 0
    /// The longest frame in the last whole second, in milliseconds.
    private(set) var worstMilliseconds: Double = 0
    /// Frames dropped since the meter started.
    private(set) var dropped: Int = 0
    /// The screen's top rate (60, or 120 with ProMotion).
    let target: Int = UIScreen.main.maximumFramesPerSecond

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

    fileprivate func tick(at time: CFTimeInterval) {
        defer { last = time }
        guard last > 0 else {
            windowStart = time
            return
        }
        let frame: CFTimeInterval = time - last
        frames += 1
        worst = max(worst, frame)
        if frame > 1.5 / Double(target) { dropped += Int((frame * Double(target)).rounded()) - 1 }
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
        meter?.tick(at: link.targetTimestamp - link.duration)
    }
}
