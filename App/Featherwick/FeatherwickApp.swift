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
            if let launch = UITestLaunch(arguments: ProcessInfo.processInfo.arguments),
                let store = try? launch.makeStore()
            {
                return store
            }
        #endif
        return GameStore()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                // Painted part kits load off the main thread, before the first painted bird shows.
                .task { await PartKit.preload() }
        }
    }
}
