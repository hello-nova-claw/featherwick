import FeatherwickCore
import FeatherwickText
import SwiftUI

struct RootView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        if case .choosingStarter(let chicks) = store.state.phase {
            StarterView(chicks: chicks)
        } else {
            TabView {
                YardView().tabItem { Label("Yard", systemImage: "sun.max") }
                FlockView().tabItem { Label("Flock", systemImage: "bird") }
                EggsView().tabItem { Label("Eggs", systemImage: "oval.portrait") }
                TownView().tabItem { Label("Town", systemImage: "house") }
                JournalView().tabItem { Label("Journal", systemImage: "book") }
                DebugView().tabItem { Label("Debug", systemImage: "wrench.and.screwdriver") }
            }
            .sheet(item: nameRequest) { bird in
                NameSheet(bird: bird)
                    .interactiveDismissDisabled()
            }
        }
    }

    /// New birds you hatch or buy need a name before play goes on, one at a time.
    private var nameRequest: Binding<Bird?> {
        Binding(get: { store.state.unnamedBirds.first }, set: { _ in })
    }
}

/// The neighbour's three chicks. Pick one and name it.
struct StarterView: View {
    @Environment(GameStore.self) private var store
    let chicks: [Bird]
    @State private var name = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("The neighbour keeps orpingtons, wyandottes and araucanas. She offers you one chick.")
                    TextField("Name your chick", text: $name)
                }
                Section("Choose one") {
                    ForEach(Array(chicks.enumerated()), id: \.element.id) { index, chick in
                        Button {
                            store.run(.chooseStarter(index: index, name: name))
                        } label: {
                            HStack {
                                BirdSwatch(bird: chick, state: store.state)
                                Text("A chick with \(downText(chick.phenotype.chickDown))")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Featherwick")
        }
    }
}

/// Asks for a new bird's name, with the game's suggestion ready to take.
struct NameSheet: View {
    @Environment(GameStore.self) private var store
    let bird: Bird
    @State private var typed = ""

    var body: some View {
        let suggestion = NameBook.suggestion(for: bird, in: store.state)
        NavigationStack {
            Form {
                HStack {
                    BirdSwatch(bird: bird, state: store.state, size: 56)
                    Text(what)
                }
                TextField(suggestion, text: $typed)
                    .textInputAutocapitalization(.words)
                Button("Name \(typed.isEmpty ? suggestion : typed)") {
                    store.run(.rename(bird.id, name: typed.isEmpty ? suggestion : typed))
                    typed = ""
                }
            }
            .navigationTitle("A new bird")
        }
        .presentationDetents([.medium])
    }

    private var what: String {
        let p = bird.phenotype
        return bird.revealed
            ? "Your new \(bird.varietyName) \(bird.sex == .hen ? "pullet" : "cockerel") (\(colourText(p)))"
            : "Your new chick (\(downText(p.chickDown)))"
    }
}
