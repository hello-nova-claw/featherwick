import FeatherwickCore
import SwiftUI

extension Tone {
    /// Placeholder colours for the art tokens, shared by every stand-in bird (`BirdSwatch`, `ChickenRig`).
    /// The art direction will choose the real ones.
    var artColour: Color {
        switch self {
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
        case .whiteFeather: Color(red: 0.96, green: 0.95, blue: 0.91)
        case .horn: Color(red: 0.75, green: 0.68, blue: 0.55)
        }
    }
}
