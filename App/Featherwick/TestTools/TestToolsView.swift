import SwiftUI

/// The plain test build's screens, kept for testing every action while the designed UI grows.
struct TestToolsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            YardView().tabItem { Label("Yard", systemImage: "sun.max") }
            FlockView().tabItem { Label("Flock", systemImage: "bird") }
            EggsView().tabItem { Label("Eggs", systemImage: "oval.portrait") }
            TownView().tabItem { Label("Town", systemImage: "house") }
            JournalView().tabItem { Label("Journal", systemImage: "book") }
            DebugView().tabItem { Label("Debug", systemImage: "wrench.and.screwdriver") }
        }
        .overlay(alignment: .topTrailing) {
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.trailing, 16)
                .padding(.top, 4)
        }
    }
}
