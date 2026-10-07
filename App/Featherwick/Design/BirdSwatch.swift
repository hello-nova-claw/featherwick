import FeatherwickCore
import SwiftUI

/// A stand-in for real art: a body circle in the bird's feather colour, with its comb on top.
/// Colours come from the same `Look` tokens the painted art will use.
struct BirdSwatch: View {
    let bird: Bird
    let state: GameState
    var size: CGFloat = 36

    var body: some View {
        // Explicit types and small helpers keep the type checker fast. One big expression here
        // crashed the compiler's diagnostics in Xcode 27 ("Failed to produce diagnostic").
        let look = bird.look(onDay: state.day, rules: state.rules)
        let feathers: Tone = look.tone(.body) ?? look.tone(.down) ?? Tone.buff
        let pattern: FeatherwickCore.Pattern? = look.overlays.first?.pattern
        let comb: Tone? = look.tone(.comb)
        ZStack(alignment: .top) {
            bodyCircle(feathers, pattern: pattern)
            if let comb {
                Capsule()
                    .fill(color(comb))
                    .frame(width: size * 0.35, height: size * 0.2)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func bodyCircle(_ feathers: Tone, pattern: FeatherwickCore.Pattern?) -> some View {
        Circle()
            .fill(color(feathers))
            .overlay(Circle().strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1))
            .overlay { patternMark(pattern) }
            .padding(.top, size * 0.15)
    }

    @ViewBuilder
    private func patternMark(_ pattern: FeatherwickCore.Pattern?) -> some View {
        switch pattern {
        case .barring?:
            Image(systemName: "line.3.horizontal").foregroundStyle(Color.white.opacity(0.7))
        case .lacing?:
            Circle().strokeBorder(Color.black.opacity(0.7), lineWidth: size / 10)
        default:
            EmptyView()
        }
    }

    /// The shared placeholder colours (`Tone.artColour`), so the swatch and the chicken rig agree.
    private func color(_ tone: Tone) -> Color { tone.artColour }
}
