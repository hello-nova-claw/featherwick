import SwiftUI

/// Test build of the game: plain lists, buttons and text, no art yet.
@main
struct FeatherwickApp: App {
    @State private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
