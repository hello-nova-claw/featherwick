import UIKit

/// The player's sound and haptics switches (Settings). Both are on until the player turns them off.
enum FeedbackSettings {
    static let soundKey = "soundOn"
    static let hapticsKey = "hapticsOn"

    /// `@AppStorage` writes the same keys. A key that was never set reads as on.
    static func isOn(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
}

/// Small taps in the hand. Soft and few: a cozy game should not buzz.
@MainActor
enum Haptics {
    static var isOn: Bool { FeedbackSettings.isOn(FeedbackSettings.hapticsKey) }

    /// One stroke of a rub turned back.
    static func tick() { impact(.light, intensity: 0.45) }
    /// A bird was tapped open.
    static func tap() { impact(.light, intensity: 0.8) }
    /// A pet landed: the bird settles into your hand.
    static func petted() { impact(.soft, intensity: 1) }
    /// Already petted today: the bird only leans in.
    static func leanIn() { impact(.soft, intensity: 0.5) }
    /// Eggs collected, chicks hatched.
    static func success() { notify(.success) }
    /// The engine said no.
    static func warning() { notify(.warning) }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
        guard isOn else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: intensity)
    }

    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isOn else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
