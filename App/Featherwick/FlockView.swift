import FeatherwickCore
import FeatherwickText
import SwiftUI

/// Every bird you own, by where it is. Tap a bird for its actions.
struct FlockView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.state
        NavigationStack {
            List {
                group("Brooder (\(s.brooder.count)/\(s.brooderSize))", s.brooder)
                group("Chicks with their mother", s.henChicks)
                group("Coop (\(s.coop.count)/\(s.perches) perches)", s.coop)
                group("Lost (they always come home)", s.lost.map(\.bird))
                group("Staying with the neighbour", s.boarding)
                if let offer = s.tradeOffer {
                    Section("Trade offer") {
                        Text("A young hen (\(birdLabel(offer.hen, s))) for \(birdName(offer.roosterID, s)).")
                        Button("Accept the trade") { store.run(.acceptTrade) }
                    }
                }
            }
            .navigationTitle("Flock")
            .navigationDestination(for: UUID.self) { id in BirdDetailView(id: id) }
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ birds: [Bird]) -> some View {
        if !birds.isEmpty {
            Section(title) {
                ForEach(birds) { bird in
                    NavigationLink(value: bird.id) {
                        HStack {
                            BirdSwatch(bird: bird, state: store.state)
                            Text(birdLabel(bird, store.state))
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
    }
}

/// One bird: what it is, and everything you can do with it.
struct BirdDetailView: View {
    @Environment(GameStore.self) private var store
    let id: UUID
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmRehome = false
    @State private var eggsToSit = 3

    var body: some View {
        let s = store.state
        if let bird = s.bird(id), !s.rehomed.contains(where: { $0.id == id }) {
            List {
                Section {
                    HStack(spacing: 16) {
                        BirdSwatch(bird: bird, state: s, size: 72)
                        Text(birdLabel(bird, s))
                    }
                    LabeledContent("Friendliness", value: friendlyText(bird.friendliness))
                    LabeledContent("Inbreeding", value: "\(Int(((bird.inbreeding ?? 0) * 100).rounded()))%")
                    LabeledContent(
                        "A neighbour would pay", value: "\(s.rules.rehomeValue(of: bird, onDay: s.day)) coins")
                    LabeledContent("Show class", value: Engine.showClass(for: bird, in: s).name)
                }
                Section("Care") {
                    Button("Pick up and hold") { store.run(.pet(id)) }
                    Button("Give a treat (\(s.treats) left)") { store.run(.giveTreat(id)) }
                    Button("Rename") {
                        newName = bird.name
                        renaming = true
                    }
                }
                if bird.isBroody(onDay: s.day), s.clutch(under: id) == nil {
                    Section("She's broody") {
                        Stepper("Sit on \(eggsToSit) eggs", value: $eggsToSit, in: 1...s.rules.maxClutch)
                        Button("Set the eggs under her") { store.run(.sit(hen: id, count: eggsToSit)) }
                    }
                }
                Section("Show") {
                    Button("Enter in the next show (day \(s.nextShowDay))") { store.run(.enterShow(id)) }
                    if bird.isPurebred {
                        Text(cardText(Judge.judge(bird, in: .breed(bird.breed), state: s)))
                            .font(.footnote)
                    }
                    Text(cardText(Judge.judge(bird, in: .pet, state: s)))
                        .font(.footnote)
                }
                Section("Family tree") {
                    Text(treeLines(id, s).joined(separator: "\n"))
                        .font(.system(.footnote, design: .monospaced))
                }
                Section("Art parts (for the artist)") {
                    Text(partsText(bird.look(onDay: s.day, rules: s.rules)))
                        .font(.system(.caption, design: .monospaced))
                }
                Section {
                    Button("Rehome \(bird.name)", role: .destructive) { confirmRehome = true }
                }
            }
            .navigationTitle(bird.name)
            .alert("Rename \(bird.name)", isPresented: $renaming) {
                TextField("Name", text: $newName)
                Button("Save") { store.run(.rename(id, name: newName)) }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Rehome \(bird.name)?", isPresented: $confirmRehome, titleVisibility: .visible) {
                Button("Rehome for \(s.rules.rehomeValue(of: bird, onDay: s.day)) coins", role: .destructive) {
                    store.run(.rehome(id))
                }
            }
        } else {
            ContentUnavailableView("This bird has a new home", systemImage: "house")
        }
    }

    private func partsText(_ look: Look) -> String {
        var lines = ["\(look.stage.rawValue), scale \(look.scale.formatted(.number.precision(.fractionLength(2))))"]
        for placed in look.parts {
            let fills = placed.part.masks.map { "\($0.rawValue) \(placed.fills[$0]?.rawValue ?? "?")" }
            lines.append("\(placed.part): " + fills.joined(separator: ", "))
        }
        for o in look.overlays {
            lines.append("+ \(o.pattern.rawValue) in \(o.tone.rawValue)")
        }
        return lines.joined(separator: "\n")
    }
}
