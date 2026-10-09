import FeatherwickCore
import FeatherwickText
import SwiftUI

/// Books ▸ People: one entry per person the keeper has met (`hasMet`), with their about line and their
/// arcs. A choice they wait on is answered here, and eggs they asked for are handed over here.
/// Words come from FeatherwickText (`People`, `storyTitle`, `rememberedText`, `PeopleWords`).
struct PeopleBook: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        let s = store.state
        VStack(alignment: .leading, spacing: Space.l) {
            Text(PeopleWords.title).font(Typeface.title)
            ForEach(Person.allCases.filter { hasMet($0, s) }, id: \.self) { person in
                entry(person, s)
                StitchDivider()
            }
            LastWords()
        }
    }

    private func entry(_ person: Person, _ s: GameState) -> some View {
        let stories = Storylines.all.filter { $0.person == person && s.stories[$0.id] != nil }
        let finished = stories.filter { s.stories[$0.id]?.rewarded == true }
        let underWay = stories.filter { s.stories[$0.id]?.rewarded != true }
        let choices = s.pendingChoices.filter { $0.person == person }
        let deliveries = Engine.storiesAwaitingDelivery(s).filter { $0.person == person }
        return VStack(alignment: .leading, spacing: Space.s) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(People.name(person)).font(Typeface.item)
                Text(People.role(person)).font(Typeface.label).foregroundStyle(palette.inkMuted)
            }
            .accessibilityElement(children: .combine)
            Text(People.about(person)).font(Typeface.body).fixedSize(horizontal: false, vertical: true)
            if !finished.isEmpty { arcs(PeopleWords.finished, finished, s) }
            if !underWay.isEmpty { arcs(PeopleWords.underWay, underWay, s) }
            ForEach(choices, id: \.story) { choice in
                VStack(alignment: .leading, spacing: Space.s) {
                    Text(PeopleWords.asks(person)).font(Typeface.note).foregroundStyle(palette.inkSoft)
                    ForEach(choice.options, id: \.self) { option in
                        Button(sentenceCase(choiceText(story: choice.story, option: option))) {
                            store.run(.choose(story: choice.story, option: option))
                        }
                        .buttonStyle(.secondary)
                    }
                }
            }
            ForEach(deliveries) { story in
                Button(PeopleWords.handOver) { store.run(.deliver(story: story.id)) }
                    .buttonStyle(.secondary)
            }
        }
    }

    /// A short list of arcs under a small heading, each with what the keeper chose, in words.
    private func arcs(_ heading: String, _ stories: [Storyline], _ s: GameState) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(heading).font(Typeface.label).foregroundStyle(palette.inkMuted)
            ForEach(stories) { story in
                VStack(alignment: .leading, spacing: 2) {
                    Text(storyTitle(story.id)).font(Typeface.rowName)
                    if let remembered = rememberedText(story.id, s) {
                        Text(remembered).font(Typeface.note).foregroundStyle(palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
