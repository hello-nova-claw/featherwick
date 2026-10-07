import FeatherwickCore
import FeatherwickText
import SwiftUI

// MARK: - Breeding pen (in the coop)

/// The breeding pen: one rooster place and `Rules.penHens` hen places, then the coop birds that can go in.
/// The engine decides who may go in (`Engine.penBlocker`); this sheet only shows it and sends
/// `.penBird` and `.unpenBird`. A bird whose sex does not show yet is never listed, so nothing leaks.
struct BreedingPenSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    let open: (FarmSheet) -> Void

    var body: some View {
        let s = store.state
        let hens = s.pennedHens
        SheetPage(context: "In the coop") {
            Text("Breeding pen").font(Typeface.title)
            Text(
                "The rooster in the pen fathers the eggs of the hens in the pen, and only theirs. Pen birds keep their coop perch."
            )
            .font(Typeface.body).foregroundStyle(palette.inkSoft)
            Text("Rooster").font(Typeface.item)
            place(s.penRooster, empty: "No rooster. The pen hens' eggs won't be fertile.")
            if let day = s.penRoosterGrownDay {
                Text("Still young. The pen hens' eggs stay clear until day \(day).")
                    .font(Typeface.caption).foregroundStyle(palette.inkMuted)
            }
            Text("Hens · \(hens.count) of \(s.rules.penHens)").font(Typeface.item)
            ForEach(0..<max(s.rules.penHens, hens.count), id: \.self) { i in
                place(i < hens.count ? hens[i] : nil, empty: "An empty place")
            }
            StitchDivider()
            Text("From the coop").font(Typeface.item)
            let candidates = s.coop.filter { Engine.canOfferPen($0.id, in: s) }
            if candidates.isEmpty {
                Text("No coop bird can go in right now.")
                    .font(Typeface.body).foregroundStyle(palette.inkMuted)
            }
            ForEach(candidates) { bird in
                HStack(spacing: Space.m) {
                    birdButton(bird)
                    Button("Pen") { store.run(.penBird(bird.id)) }.buttonStyle(.secondary).frame(width: 90)
                }
                StitchDivider()
            }
            LastWords()
        }
        .presentationDetents([.large])
    }

    /// One place in the pen: the bird and "Take out", or a dashed empty box.
    @ViewBuilder
    private func place(_ bird: Bird?, empty: String) -> some View {
        if let bird {
            HStack(spacing: Space.m) {
                birdButton(bird)
                Button("Take out") { store.run(.unpenBird(bird.id)) }.buttonStyle(.textAction)
            }
        } else {
            Text(empty)
                .font(Typeface.label).foregroundStyle(palette.inkMuted)
                .frame(maxWidth: .infinity, minHeight: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tile).stroke(palette.unknownBox, style: Stitch.unknown))
        }
    }

    /// The bird's swatch and name. Tap opens its card.
    private func birdButton(_ bird: Bird) -> some View {
        Button {
            open(.bird(bird.id))
        } label: {
            HStack(spacing: Space.m) {
                BirdSwatch(bird: bird, state: store.state, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(bird.name).font(Typeface.item)
                    Text(birdLabel(bird, store.state).components(separatedBy: ": ").dropFirst().joined())
                        .font(Typeface.caption).foregroundStyle(palette.inkMuted).lineLimit(1)
                }
                Spacer()
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
