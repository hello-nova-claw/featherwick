import SwiftUI

/// Featherwick: SwiftUI menus over the farm. The painted farm scene comes later.
@main
struct FeatherwickApp: App {
    @State private var store: GameStore

    init() {
        Typeface.registerBundledFonts()
        _store = State(initialValue: Self.makeStore())
    }

    /// The player's game, or in a Debug build launched by a UI test, a known game on an empty folder.
    @MainActor private static func makeStore() -> GameStore {
        #if DEBUG
            if let launch = UITestLaunch(arguments: ProcessInfo.processInfo.arguments) {
                // Never fall back to the real save: a test that cannot get its own game must stop.
                do {
                    return try launch.makeStore()
                } catch {
                    fatalError("UI test launch could not write its fixture: \(error)")
                }
            }
        #endif
        return GameStore()
    }

    /// True in a Debug build launched by a UI test: the farm scene holds still for screenshots.
    private static var freezesScene: Bool {
        #if DEBUG
            UITestLaunch.freezesScene(arguments: ProcessInfo.processInfo.arguments)
        #else
            false
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .sceneMotion(frozen: Self.freezesScene)
                // The system shows the home indicator in some runs and not others, which changes every shot.
                .persistentSystemOverlays(Self.freezesScene ? .hidden : .automatic)
                // Painted part kits load off the main thread, before the first painted bird shows.
                .task { await PartKit.preload() }
        }
    }
}
