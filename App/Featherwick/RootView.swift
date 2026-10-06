import FeatherwickCore
import FeatherwickText
import SwiftUI

/// Picks day or night from the device clock (checked each minute) and shows the starter choice or the farm.
/// A tester can pin day or night in Settings.
struct RootView: View {
    @Environment(GameStore.self) private var store
    @AppStorage(TimeOfDayPin.key) private var pinned: TimeOfDayPin = .clock

    var body: some View {
        TimelineView(.everyMinute) { context in
            let hour = Calendar.current.component(.hour, from: context.date)
            let palette = Palette.forHour(hour, pinned: pinned)
            Group {
                if case .choosingStarter(let chicks) = store.state.phase {
                    StarterView(chicks: chicks)
                } else {
                    FarmView()
                }
            }
            .environment(\.palette, palette)
            .preferredColorScheme(palette.isNight ? .dark : .light)
            .animation(.easeInOut(duration: 1.5), value: palette)
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
                Text("“I keep orpingtons, wyandottes and araucanas. Take whichever chick you like.”")
                    .font(Typeface.speech)
                Text("Mabel, over the fence").font(Typeface.label).foregroundStyle(palette.inkMuted)
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
