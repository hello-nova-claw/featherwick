import FeatherwickCore
import FeatherwickText
import SwiftUI

// MARK: - Market board (by the bakery, off the farm gate)

/// The market board: this week's wanted cards, and the keeper's own card. The engine decides what fits a
/// card (`GameState.eggsFor`, `birdsFor`, `youngBirdsForSale`); this sheet only shows it and sends
/// `.fillCard`, `.postCard` and `.sellToBuyer`. A bird whose sex does not show yet never fits a card,
/// so nothing leaks.
struct MarketBoardSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    let open: (FarmSheet) -> Void

    var body: some View {
        let s = store.state
        SheetPage(context: "By the bakery") {
            HStack(spacing: Space.xs) {
                Spacer()
                CoinDisc()
                Text(s.coins.formatted()).font(Typeface.number).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            Text("Market board").font(Typeface.title)
            Text("“Pin what you want, bring what's asked. New cards every week.”")
                .font(Typeface.serifItalic(19)).foregroundStyle(palette.inkSoft)
            if s.isOpen(.marketBoard) {
                wanted(s)
                StitchDivider()
                keeperCard(s)
            } else {
                NotYetLine(feature: .marketBoard)
            }
            LastWords()
        }
        .presentationDetents([.large])
    }

    // MARK: Wanted cards

    @ViewBuilder
    private func wanted(_ s: GameState) -> some View {
        Text("Wanted").font(Typeface.item)
        if s.marketBoard.cards.isEmpty {
            Text("No cards up just now. New ones come each week.")
                .font(Typeface.body).foregroundStyle(palette.inkMuted)
        }
        ForEach(s.marketBoard.cards) { card in
            cardView(card, s)
            StitchDivider()
        }
    }

    private func cardView(_ card: MarketCard, _ s: GameState) -> some View {
        let closed = daylightRefusalText(.fillCard(card.id, bird: nil), in: s)
        return VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(People.name(card.from)).font(Typeface.item)
                Spacer()
                CoinDisc()
                Text("\(card.coins)").font(Typeface.number).monospacedDigit()
            }
            Text(marketCardLine(card, s))
                .font(Typeface.label).foregroundStyle(palette.inkSoft)
            if let note = marketCardNote(card.kind) {
                Text("“\(note)”").font(Typeface.serifItalic(16)).foregroundStyle(palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            switch card.want {
            case .eggs(let colour, let count):
                let have = s.eggsFor(card)?.count ?? 0
                HStack {
                    Text("\(min(have, count)) of \(count) \(colour.rawValue) eggs in your carton")
                        .font(Typeface.caption).foregroundStyle(palette.inkMuted)
                    Spacer()
                    Button("Bring them") { store.run(.fillCard(card.id, bird: nil)) }
                        .buttonStyle(.secondary).frame(width: 130)
                        .disabled(have < count || closed != nil)
                }
            case .bird:
                let birds = s.birdsFor(card)
                if birds.isEmpty {
                    Text("None of your birds fits this one yet.")
                        .font(Typeface.caption).foregroundStyle(palette.inkMuted)
                }
                ForEach(birds) { bird in
                    HStack(spacing: Space.m) {
                        birdButton(bird, s)
                        Button("Give") { store.run(.fillCard(card.id, bird: bird.id)) }
                            .buttonStyle(.secondary).frame(width: 90)
                            .disabled(closed != nil)
                    }
                }
            }
            if let closed, s.canFill(card) {
                Text(closed).font(Typeface.caption).foregroundStyle(palette.inkSoft)
            }
        }
        .padding(.vertical, Space.s)
        .accessibilityElement(children: .contain)
    }

    // MARK: The keeper's own card

    @ViewBuilder
    private func keeperCard(_ s: GameState) -> some View {
        Text("Your card").font(Typeface.item)
        if let mine = s.marketBoard.keeperCard {
            let name = mine.breed.definition.displayName
            if mine.buyerHere(onDay: s.day) {
                let left = mine.buyerLeavesDay - s.day
                Text("A buyer is here for a young \(name), for \(left) more day\(left == 1 ? "" : "s").")
                    .font(Typeface.body).foregroundStyle(palette.inkSoft)
                let closed = daylightRefusalText(.sellToBuyer(UUID()), in: s)
                ForEach(s.youngBirdsForSale(of: mine.breed)) { bird in
                    let price = s.rules.marketBuyerPrice(rehomeValue: s.rehomeValue(of: bird))
                    HStack(spacing: Space.m) {
                        birdButton(bird, s)
                        Button("Sell · \(price)") { store.run(.sellToBuyer(bird.id)) }
                            .buttonStyle(.secondary).frame(width: 110)
                            .disabled(closed != nil)
                    }
                }
                if let closed { Text(closed).font(Typeface.caption).foregroundStyle(palette.inkSoft) }
            } else {
                Text("“Young \(name)s, from my own flock.” No buyer yet. One may come any day now.")
                    .font(Typeface.body).foregroundStyle(palette.inkSoft)
            }
        } else {
            let breeds = s.breedsForKeeperCard
            Text("Pin a card for young birds you've bred. A buyer pays more than a new home would.")
                .font(Typeface.body).foregroundStyle(palette.inkSoft)
            if breeds.isEmpty {
                Text("No young purebreds to offer just now.")
                    .font(Typeface.caption).foregroundStyle(palette.inkMuted)
            }
            let closed = breeds.first.flatMap { daylightRefusalText(.postCard($0), in: s) }
            ForEach(breeds, id: \.self) { breed in
                let count = s.youngBirdsForSale(of: breed).count
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Young \(breed.definition.displayName)s").font(Typeface.item)
                        Text("\(count) free to go").font(Typeface.caption).foregroundStyle(palette.inkMuted)
                    }
                    Spacer()
                    Button("Pin a card") { store.run(.postCard(breed)) }
                        .buttonStyle(.secondary).frame(width: 130)
                        .disabled(closed != nil)
                }
                .frame(minHeight: 56)
            }
            if let closed { Text(closed).font(Typeface.caption).foregroundStyle(palette.inkSoft) }
        }
    }

    /// The bird's swatch and name. Tap opens its card.
    private func birdButton(_ bird: Bird, _ s: GameState) -> some View {
        Button {
            open(.bird(bird.id))
        } label: {
            HStack(spacing: Space.m) {
                BirdSwatch(bird: bird, state: s, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(bird.name).font(Typeface.item)
                    Text(birdLabel(bird, s).components(separatedBy: ": ").dropFirst().joined())
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
