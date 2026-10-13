import SwiftUI

/// Featherwick: SwiftUI menus over the farm. The painted farm scene comes later.
@main
struct FeatherwickApp: App {
    @State private var store = GameStore()

    init() {
        Typeface.registerBundledFonts()
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
