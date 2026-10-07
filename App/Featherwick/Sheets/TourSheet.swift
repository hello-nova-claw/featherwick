import FeatherwickCore
import FeatherwickText
import SwiftUI

/// Day 1: Hazel walks the keeper round the farm. One stop per place, left to right. The farm moves
/// to each place under the sheet. "Skip the tour" ends it at any stop.
struct TourSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    /// Moves the farm to a place.
    let show: (Place) -> Void
    @State private var stop = 0

    var body: some View {
        let stops = People.tour(store.state)
        let here = stops[min(stop, stops.count - 1)]
        SheetPage(context: "A walk round with \(People.neighbour)") {
            Text(here.title).font(Typeface.title)
            Text("“\(here.words)”").font(Typeface.speech).fixedSize(horizontal: false, vertical: true)
            Text("\(People.neighbour) · \(stop + 1) of \(stops.count)")
                .font(Typeface.label).foregroundStyle(palette.inkMuted)
            Button(stop + 1 < stops.count ? "Next" : "Thank you, \(People.neighbour)") {
                if stop + 1 < stops.count {
                    stop += 1
                } else {
                    dismiss()
                }
            }
            .buttonStyle(.primary)
            if stop + 1 < stops.count {
                Button("Skip the tour") { dismiss() }.buttonStyle(.secondary)
            }
        }
        .presentationDetents([.fraction(0.45), .medium])
        .onAppear { show(Self.place(here.place)) }
        .onChange(of: stop) { _, new in show(Self.place(stops[min(new, stops.count - 1)].place)) }
    }

    static func place(_ p: TourPlace) -> Place {
        switch p {
        case .coop: .coop
        case .yard: .yard
        case .backFence: .backFence
        case .farmGate: .farmGate
        }
    }
}
