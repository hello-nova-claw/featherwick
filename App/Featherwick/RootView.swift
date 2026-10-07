import FeatherwickCore
import FeatherwickText
import SwiftUI

/// Picks day or night from game time and shows the starter choice or the farm. Morning and afternoon
/// are day; evening crossfades to night over 30 minutes (checked each minute); Sleep is night until the
/// morning. A tester can pin day or night in Settings.
struct RootView: View {
    @Environment(GameStore.self) private var store
    @AppStorage(TimeOfDayPin.key) private var pinned: TimeOfDayPin = .clock

    var body: some View {
        TimelineView(.everyMinute) { context in
            let evening = store.eveningSince.map { max(0, context.date.timeIntervalSince($0)) }
            let palette = Palette.forGame(evening: evening, asleep: store.asleep, pinned: pinned)
            Group {
                if case .choosingStarter(let chicks) = store.state.phase {
                    // Day 1: Hazel says hello and asks the keeper's name, then offers a chick.
                    if store.state.keeperName == nil {
                        WelcomeView()
                    } else {
                        StarterView(chicks: chicks)
                    }
                } else {
                    FarmView()
                }
            }
            .environment(\.palette, palette)
            .preferredColorScheme(palette.isNight ? .dark : .light)
            // A rest eases the light over the whole rest scene.
            .animation(.easeInOut(duration: store.restSeconds ?? 1.5), value: palette)
        }
    }
}

/// The neighbour's three chicks. Pick one and name it.
struct StarterView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    let chicks: [Bird]
    @State private var name = ""
    @State private var picked = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("Henhaven").font(Typeface.title)
                Text("“\(People.chickOffer(store.state.keeperName ?? ""))”").font(Typeface.speech)
                Text("\(People.neighbour), over the fence").font(Typeface.label).foregroundStyle(palette.inkMuted)
                HStack(spacing: Space.m) {
                    ForEach(Array(chicks.enumerated()), id: \.element.id) { index, chick in
                        Button {
                            picked = index
                        } label: {
                            VStack(spacing: Space.s) {
                                ArtPlaceholder(label: "chick").aspectRatio(1, contentMode: .fit)
                                Text(downText(chick.phenotype.chickDown)).font(Typeface.caption)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(Space.s)
                            .overlay {
                                if picked == index {
                                    RoundedRectangle(cornerRadius: Radius.tile).stroke(palette.ink, lineWidth: 1.5)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("A chick with \(downText(chick.phenotype.chickDown))")
                        .accessibilityAddTraits(picked == index ? .isSelected : [])
                    }
                }
                Text("What shall we call this chick?").font(Typeface.title2)
                TextField("A name", text: $name)
                    .font(Typeface.serif(30, relativeTo: .title))
                    .textInputAutocapitalization(.words)
                    .background(alignment: .bottom) {
                        HLine().stroke(palette.ink.opacity(0.5), style: Stitch.underline).frame(height: 2).offset(y: 4)
                    }
                Button("Take this chick home") {
                    store.run(.chooseStarter(index: picked, name: name))
                }
                .buttonStyle(.primary)
            }
            .padding(.horizontal, Space.sheetSide)
            .padding(.vertical, Space.xxl)
        }
        .foregroundStyle(palette.ink)
        .background(palette.paper)
    }
}

/// Day 1, first screen: Hazel leans over the back fence and asks the keeper's name.
struct WelcomeView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @State private var name = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("Henhaven").font(Typeface.title)
                ArtPlaceholder(label: "Hazel", radius: 36).frame(width: 72, height: 72)
                ForEach(People.welcome, id: \.self) { line in
                    Text("“\(line)”").font(Typeface.speech).fixedSize(horizontal: false, vertical: true)
                }
                Text("\(People.neighbour), over the fence").font(Typeface.label).foregroundStyle(palette.inkMuted)
                TextField("Your name", text: $name)
                    .font(Typeface.serif(30, relativeTo: .title))
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit(sayName)
                    .background(alignment: .bottom) {
                        HLine().stroke(palette.ink.opacity(0.5), style: Stitch.underline).frame(height: 2).offset(y: 4)
                    }
                Button("That's me", action: sayName)
                    .buttonStyle(.primary)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, Space.sheetSide)
            .padding(.vertical, Space.xxl)
        }
        .foregroundStyle(palette.ink)
        .background(palette.paper)
    }

    private func sayName() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        store.run(.nameKeeper(name))
    }
}
