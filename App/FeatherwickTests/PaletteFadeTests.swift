import SwiftUI
import Testing

@testable import Featherwick

/// The evening crossfade from the day palette to the night palette (#125). Text must stay readable on
/// paper for the whole fade, not only at its two ends.
@MainActor
@Suite struct PaletteFadeTests {
    /// Every step of the fade, 0 to 1 in hundredths.
    static let steps = (0...100).map { Double($0) / 100 }

    /// WCAG 2 says 4.5:1 for body text.
    static let minimum = 4.5

    @Test func contrastMatchesWCAG() {
        #expect(abs(Palette.contrast(.white, .black) - 21) < 0.01)
        #expect(abs(Palette.contrast(.white, .white) - 1) < 0.01)
        #expect(abs(Palette.contrast(Palette.day.ink, Palette.day.paper) - 15.44) < 0.01)
    }

    @Test func textStaysReadableOnPaperThroughTheFade() {
        for t in Self.steps {
            let palette = Palette.between(.day, .night, t)
            for (name, text) in [("ink", palette.ink), ("inkSoft", palette.inkSoft), ("inkMuted", palette.inkMuted)] {
                let ratio = Palette.contrast(text, palette.paper)
                #expect(ratio >= Self.minimum, "\(name) on paper at t \(t): \(ratio)")
            }
        }
    }

    @Test func toastTextStaysReadableThroughTheFade() {
        for t in Self.steps {
            let palette = Palette.between(.day, .night, t)
            let ratio = Palette.contrast(palette.toastText, palette.toast)
            #expect(ratio >= Self.minimum, "toastText on toast at t \(t): \(ratio)")
        }
    }

    @Test func theEndsAreDayAndNight() {
        #expect(Palette.between(.day, .night, 0) == .day)
        #expect(Palette.between(.day, .night, 1) == .night)
    }

    /// The paper still moves on both sides of the turn, so the evening is a fade and not only a switch.
    @Test func paperDarkensOnBothSidesOfTheTurn() {
        func luminance(_ t: Double) -> Double {
            Palette.contrast(Palette.between(.day, .night, t).paper, .black)
        }
        #expect(luminance(0.49) < luminance(0))
        #expect(luminance(0.51) > luminance(1))
        #expect(luminance(0.49) > luminance(0.51))
    }
}
