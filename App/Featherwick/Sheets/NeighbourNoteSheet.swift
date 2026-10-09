import FeatherwickCore
import FeatherwickText
import SwiftUI

/// What the neighbour said overnight: lessons and show news. It opens on its own, so a new keeper
/// never misses a lesson that would otherwise sit only in the log. When she asks the keeper to choose
/// (Marigold on day 10), each option is a button here. The choice also waits at the back fence.
struct NeighbourNoteSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let choices = store.state.pendingChoices
        SheetPage(context: "Over the back fence") {
            Text("A word from \(People.neighbour)").font(Typeface.title)
            ForEach(Array(store.neighbourNotes.enumerated()), id: \.offset) { item in
                Text(item.element).font(Typeface.body).foregroundStyle(palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if item.offset < store.neighbourNotes.count - 1 { StitchDivider() }
            }
            ForEach(choices, id: \.choice) { choice in
                ChoiceButtons(choice: choice)
            }
            if choices.isEmpty {
                Button("Thank you", action: close).buttonStyle(.primary)
            } else {
                // Nothing is lost by waiting: the choice waits at the back fence too.
                Button("Decide later", action: close).buttonStyle(.textAction).frame(maxWidth: .infinity)
            }
            LastWords()
        }
        .presentationDetents([.medium, .large])
        .onDisappear { store.readNeighbourNotes() }
    }

    private func close() {
        store.readNeighbourNotes()
        dismiss()
    }
}

/// One button for each option of a person's choice, with the option's words under it. No option is wrong.
struct ChoiceButtons: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    let choice: PendingChoice

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            ForEach(choice.options, id: \.self) { option in
                VStack(alignment: .leading, spacing: Space.xs) {
                    Button(choiceButtonText(story: choice.story, option: option)) {
                        store.run(.choose(story: choice.story, option: option))
                    }
                    .buttonStyle(.secondary)
                    Text(choiceDetailText(story: choice.story, option: option))
                        .font(Typeface.caption).foregroundStyle(palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
