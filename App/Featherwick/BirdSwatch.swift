import FeatherwickCore
import SwiftUI

/// A stand-in for real art: a body circle in the bird's feather colour, with its comb on top.
/// Colours come from the same `Look` tokens the painted art will use.
struct BirdSwatch: View {
    let bird: Bird
    let state: GameState
    var size: CGFloat = 36

    var body: some View {
        let look = bird.look(onDay: state.day, rules: state.rules)
        let feathers = look.tone(.body) ?? look.tone(.down) ?? .buff
        let pattern = look.overlays.first?.pattern
        ZStack(alignment: .top) {
            Circle()
                .fill(color(feathers))
                .overlay(Circle().strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1))
                .overlay {
                    if pattern == .barring {
                        Image(systemName: "line.3.horizontal").foregroundStyle(.white.opacity(0.7))
                    } else if pattern == .lacing {
                        Circle().strokeBorder(Color.black.opacity(0.7), lineWidth: size / 10)
                    }
                }
                .padding(.top, size * 0.15)
            if let comb = look.tone(.comb) {
                Capsule()
                    .fill(color(comb))
                    .frame(width: size * 0.35, height: size * 0.2)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Placeholder colours for the art tokens. The art direction will choose the real ones.
    private func color(_ tone: Tone) -> Color {
        switch tone {
        case .black, .blackDown: Color(white: 0.12)
        case .blue: Color(red: 0.42, green: 0.5, blue: 0.6)
        case .darkBlue: Color(red: 0.25, green: 0.3, blue: 0.4)
        case .splash: Color(red: 0.85, green: 0.87, blue: 0.9)
        case .lavender: Color(red: 0.75, green: 0.73, blue: 0.8)
        case .buff: Color(red: 0.88, green: 0.68, blue: 0.4)
        case .slateDown, .slate: Color(red: 0.4, green: 0.42, blue: 0.45)
        case .paleGreyDown: Color(white: 0.8)
        case .silverDown: Color(white: 0.9)
        case .yellowDown, .yellow: Color(red: 0.98, green: 0.85, blue: 0.4)
        case .red: Color(red: 0.8, green: 0.15, blue: 0.15)
        case .mulberry: Color(red: 0.45, green: 0.15, blue: 0.3)
        case .willow: Color(red: 0.55, green: 0.6, blue: 0.4)
        case .white: Color(white: 0.97)
        case .horn: Color(red: 0.75, green: 0.68, blue: 0.55)
        }
    }
}
