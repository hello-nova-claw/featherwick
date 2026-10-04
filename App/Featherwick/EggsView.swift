import FeatherwickCore
import FeatherwickText
import SwiftUI

/// Nest, carton, candling, selling and hatching.
struct EggsView: View {
    @Environment(GameStore.self) private var store
    @State private var toIncubate = 1

    var body: some View {
        let s = store.state
        let fertile = s.carton.count(where: { $0.isCandled && $0.isFertile })
        let clear = s.carton.count(where: { $0.isCandled && !$0.isFertile })
        NavigationStack {
            List {
                Section("Nest and carton") {
                    LabeledContent("Nest", value: "\(s.nest.count)/\(s.nestCapacity)")
                    LabeledContent("Carton", value: "\(s.carton.count)/\(s.cartonCapacity)")
                    LabeledContent(
                        "Candled",
                        value: "\(fertile) fertile, \(clear) clear, \(s.carton.count - fertile - clear) not yet")
                    Button("Collect eggs") { store.run(.collectEggs) }
                    Button("Candle the carton") { store.run(.candle) }
                    Button("Sell every egg") { store.run(.sellEggs) }
                    Button("Sell all but the fertile ones") { store.run(.sellClearEggs) }
                }
                Section("Hatching") {
                    if s.hasIncubator {
                        if let c = s.incubatorClutch {
                            Text("Incubator: \(c.eggs.count) egg(s), hatching on day \(c.hatchDay).")
                        } else {
                            Stepper(
                                "Incubate \(toIncubate) egg(s)", value: $toIncubate, in: 1...max(1, s.incubatorSize))
                            Button("Set eggs in the incubator") { store.run(.incubate(count: toIncubate)) }
                        }
                    } else {
                        Text("No incubator yet. A broody hen can sit on eggs (see her page in Flock).")
                    }
                    if s.incubatorSize < s.rules.bigIncubatorSize {
                        Button("Buy a \(s.rules.bigIncubatorSize)-egg incubator (\(s.rules.incubatorPrice) coins)") {
                            store.run(.buyIncubator)
                        }
                    }
                    ForEach(s.clutches.filter { $0.henID != nil }, id: \.henID) { c in
                        Text("Under \(birdName(c.henID!, s)): \(c.eggs.count) egg(s), hatching on day \(c.hatchDay).")
                    }
                }
                Section("Egg show") {
                    Button("Enter my best plate of 3") { store.run(.enterEggs) }
                    ForEach(Array(Judge.bestPlates(from: s.carton, state: s).enumerated()), id: \.offset) { _, plate in
                        Text(cardText(plate.card)).font(.footnote)
                    }
                }
                Section("Carton") {
                    ForEach(s.carton) { egg in
                        Text(eggLine(egg, s))
                    }
                }
            }
            .navigationTitle("Eggs")
        }
    }

    private func eggLine(_ egg: Egg, _ s: GameState) -> String {
        var parts = ["\(egg.speckled ? "speckled " : "")\(egg.colour.rawValue)", "from \(birdName(egg.motherID, s))"]
        parts.append(egg.isCandled ? (egg.isFertile ? "fertile" : "clear") : "not candled")
        if s.rules.isStale(egg, onDay: s.day) { parts.append("stale") }
        parts.append("\(s.rules.price(of: egg, onDay: s.day)) coins")
        return parts.joined(separator: " · ")
    }
}
