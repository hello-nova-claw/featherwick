import FeatherwickCore
import FeatherwickText
import SwiftUI

/// Speckle & Down, the neighbours' stories, and the county show.
struct TownView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.state
        let r = s.rules
        NavigationStack {
            List {
                Section("Speckle & Down (you have \(s.coins) coins)") {
                    buy("A young hen (pullet)", r.pulletPrice, .buy(.pullet))
                    buy("A young rooster (cockerel)", r.cockerelPrice, .buy(.cockerel))
                    buy("A fertile egg from a local flock", r.fertileEggPrice, .buy(.fertileEgg))
                    buy("\(r.treatBagSize) mealworm treats", r.treatBagPrice, .buy(.treats))
                    buy("\(r.premiumFeedBagSize) days of premium feed", r.premiumFeedPrice, .buy(.premiumFeed))
                    ForEach(s.shopBreeds.sorted { $0.rawValue < $1.rawValue }, id: \.self) { breed in
                        buy("A \(breed.definition.displayName) pullet", r.rareBreedPulletPrice, .buyBreed(breed))
                    }
                    Text("Basic feed is free.").font(.caption).foregroundStyle(.secondary)
                }
                Section("The coop") {
                    buy(
                        "Add \(r.perchesPerUpgrade) perches (now \(s.perches)/\(r.maxPerches))", r.coopUpgradePrice,
                        .upgradeCoop)
                }
                Section("Stories") {
                    ForEach(storyLines(s), id: \.self) { Text($0) }
                    if Engine.storyAwaitingDelivery(s) != nil {
                        Button("Give the eggs") {
                            if let story = Engine.storyAwaitingDelivery(store.state) {
                                store.run(.deliver(story: story))
                            }
                        }
                    }
                }
                Section("County show") {
                    ForEach(Array(showsLines(s).enumerated()), id: \.offset) { _, line in Text(line) }
                    Text("Enter birds from their page in Flock, and eggs from Eggs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Featherwick")
        }
    }

    private func buy(_ what: String, _ price: Int, _ command: Command) -> some View {
        Button {
            store.run(command)
        } label: {
            LabeledContent(what, value: "\(price) coins")
        }
    }
}

/// Milestones and the Breed Book.
struct JournalView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.state
        NavigationStack {
            List {
                Section("Milestones") {
                    ForEach(Milestones.all) { m in
                        let reached = s.milestonesReached.contains(m.id)
                        let words = milestoneText(m.id)
                        VStack(alignment: .leading) {
                            Text("\(reached ? "✓" : "○") \(words.title)")
                            if !reached {
                                Text(words.hint).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Breed Book and egg colours") {
                    ForEach(Array(bookLines(s).enumerated()), id: \.offset) { _, line in Text(line) }
                }
                Section("Everything that happened") {
                    LogList()
                }
            }
            .navigationTitle("Journal")
        }
    }
}

/// Tools for testing: the full yard as text, a new game, and the balance simulator.
struct DebugView: View {
    @Environment(GameStore.self) private var store
    @State private var difficulty = Difficulty.standard
    @State private var confirmNew = false
    @State private var report: String?
    @State private var simulating = false

    var body: some View {
        NavigationStack {
            List {
                Section("Yard as text (same as the CLI's look)") {
                    Text(yardLines(store.state).joined(separator: "\n"))
                        .font(.system(.caption, design: .monospaced))
                }
                Section("New game") {
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    Button("Start a new game", role: .destructive) { confirmNew = true }
                }
                Section("Balance simulator") {
                    Button(simulating ? "Simulating…" : "Simulate 20 games × 120 days") { simulate() }
                        .disabled(simulating)
                    if let report {
                        Text(report).font(.system(.caption, design: .monospaced))
                    }
                }
                Section("Save file") {
                    Text(store.saveLocation).font(.caption2).textSelection(.enabled)
                }
            }
            .navigationTitle("Debug")
            .confirmationDialog(
                "This replaces your current game.", isPresented: $confirmNew, titleVisibility: .visible
            ) {
                Button("Start a \(difficulty.rawValue) game", role: .destructive) { store.newGame(difficulty) }
            }
        }
    }

    private func simulate() {
        simulating = true
        let rules = store.state.rules
        Task {
            // Off the main thread: 20 games take a moment.
            let text = await Task.detached { Simulation.textReport(days: 120, games: 20, rules: rules) }.value
            report = text
            simulating = false
        }
    }
}
