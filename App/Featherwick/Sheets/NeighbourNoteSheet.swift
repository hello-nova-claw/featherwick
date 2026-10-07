import FeatherwickText
import SwiftUI

/// What the neighbour said overnight: lessons and show news. It opens on its own, so a new keeper
/// never misses a lesson that would otherwise sit only in the log.
struct NeighbourNoteSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetPage(context: "Over the back fence") {
            Text("A word from \(People.neighbour)").font(Typeface.title)
            ForEach(Array(store.neighbourNotes.enumerated()), id: \.offset) { item in
                Text(item.element).font(Typeface.body).foregroundStyle(palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if item.offset < store.neighbourNotes.count - 1 { StitchDivider() }
            }
            Button("Thank you") {
                store.readNeighbourNotes()
                dismiss()
            }
            .buttonStyle(.primary)
        }
        .presentationDetents([.medium, .large])
        .onDisappear { store.readNeighbourNotes() }
    }
}
