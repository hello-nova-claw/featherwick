import SwiftUI

/// How much the farm scene moves. Set once at the root (`sceneMotion(frozen:)`) and read by every view in
/// the scene that moves on its own: the trees, the yard birds and the brooder chicks.
enum SceneMotion: Equatable, Sendable {
    /// Trees sway. Birds stroll between the yards, walk, peck, blink and glance.
    case full
    /// Reduce Motion: the trees and birds stand still. Blinks stay.
    case reduced
    /// A UI test launch: nothing moves, not even a blink, so screenshots match from run to run.
    case frozen

    init(reduceMotion: Bool, frozen: Bool) {
        if frozen {
            self = .frozen
        } else {
            self = reduceMotion ? .reduced : .full
        }
    }

    /// No strolls, walks, pecks, glances or sway. The birds stand at their seeded starting places.
    var isStill: Bool { self != .full }

    /// The birds still blink now and then.
    var blinks: Bool { self != .frozen }
}

extension EnvironmentValues {
    @Entry var sceneMotion: SceneMotion = .full
}

extension View {
    /// Sets the scene's motion from Reduce Motion, frozen whatever it says when `frozen` is true.
    func sceneMotion(frozen: Bool) -> some View {
        modifier(SceneMotionSetting(frozen: frozen))
    }
}

/// Reads Reduce Motion here, so it follows the setting when the player changes it.
private struct SceneMotionSetting: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let frozen: Bool

    func body(content: Content) -> some View {
        content.environment(\.sceneMotion, SceneMotion(reduceMotion: reduceMotion, frozen: frozen))
    }
}
