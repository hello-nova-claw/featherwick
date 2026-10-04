import FeatherwickCore
import FeatherwickText
import SwiftUI

/// The daily loop: status, the day's jobs, and what just happened.
struct YardView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.state
        NavigationStack {
            List {
                Section("Today") {
                    Text("Day \(s.day), \(s.season.rawValue) · \(s.coins) coins")
                        .font(.headline)
                    Text(statusLine(s))
                    if s.isShowDay || s.nextShowDay - s.day <= 3 {
                        Text("County show on day \(s.nextShowDay).")
                    }
                }
                Section("Jobs") {
                    Button("Feed the flock") { store.run(.feed) }
                    if s.premiumFeed > 0 {
                        Button("Feed premium (\(s.premiumFeed) days left)") { store.run(.feedPremium) }
                    }
                    Button("Collect eggs (\(s.nest.count) in the nest)") { store.run(.collectEggs) }
                    Button(s.coopDoorOpen ? "Close the coop door" : "Coop door is closed") { store.run(.closeCoop) }
                        .disabled(!s.coopDoorOpen)
                    Button("Sleep (pass the night)") { store.run(.passNight) }
                        .bold()
                }
                Section("Fast forward") {
                    HStack {
                        Button("1 day") { store.fullDays(1) }
                        Spacer()
                        Button("7 days") { store.fullDays(7) }
                        Spacer()
                        Button("28 days") { store.fullDays(28) }
                    }
                    .buttonStyle(.bordered)
                    Text("Feed, collect, sell if the carton is full, close, sleep.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("What happened") {
                    LogList(limit: 25)
                }
            }
            .navigationTitle("Henhaven")
        }
    }

    private func statusLine(_ s: GameState) -> String {
        var parts = ["Coop door \(s.coopDoorOpen ? "open" : "closed")"]
        parts.append(s.fedPremiumToday ? "premium-fed today" : s.fedToday ? "fed today" : "not fed yet")
        parts.append("\(s.treats) treats")
        return parts.joined(separator: " · ")
    }
}

/// The newest log lines first.
struct LogList: View {
    @Environment(GameStore.self) private var store
    var limit = 400

    var body: some View {
        ForEach(store.log.suffix(limit).reversed()) { line in
            VStack(alignment: .leading, spacing: 2) {
                Text(line.text)
                    .foregroundStyle(line.isRejection ? Color.orange : Color.primary)
                Text("Day \(line.day)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
