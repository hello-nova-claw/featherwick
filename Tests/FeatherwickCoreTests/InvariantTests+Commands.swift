import Foundation
import Testing

@testable import FeatherwickCore

/// The fuzzer's reach: every `Command` it can draw, and how it builds one from the game in hand.
extension InvariantTests {
    /// One case per `Command`, without its values. `kind(of:)` has no `default`, so a new command does
    /// not compile here until the fuzzer can draw it.
    enum CommandKind: CaseIterable {
        case chooseStarter, feed, collectEggs, sellEggs, closeCoop, passNight, buyIncubator, incubate, sit
        case rename, candle, sellClearEggs, rehome, upgradeCoop, buy, acceptTrade, pet, giveTreat, deliver
        case enterShow, enterEggs, feedPremium, incubateEggs, sitEggs, sellChosenEggs, candleEgg, enterShowIn
        case enterEggPlate, buySpecial, penBird, unpenBird, rest, openPlanner, nameKeeper, guessSex, choose
        case payDebt, giveHatchAlongEgg, fillCard, postCard, sellToBuyer
    }

    static func kind(of command: Command) -> CommandKind {
        switch command {
        case .chooseStarter: .chooseStarter
        case .feed: .feed
        case .collectEggs: .collectEggs
        case .sellEggs: .sellEggs
        case .closeCoop: .closeCoop
        case .passNight: .passNight
        case .buyIncubator: .buyIncubator
        case .incubate: .incubate
        case .sit: .sit
        case .rename: .rename
        case .candle: .candle
        case .sellClearEggs: .sellClearEggs
        case .rehome: .rehome
        case .upgradeCoop: .upgradeCoop
        case .buy: .buy
        case .acceptTrade: .acceptTrade
        case .pet: .pet
        case .giveTreat: .giveTreat
        case .deliver: .deliver
        case .enterShow: .enterShow
        case .enterEggs: .enterEggs
        case .feedPremium: .feedPremium
        case .incubateEggs: .incubateEggs
        case .sitEggs: .sitEggs
        case .sellChosenEggs: .sellChosenEggs
        case .candleEgg: .candleEgg
        case .enterShowIn: .enterShowIn
        case .enterEggPlate: .enterEggPlate
        case .buySpecial: .buySpecial
        case .penBird: .penBird
        case .unpenBird: .unpenBird
        case .rest: .rest
        case .openPlanner: .openPlanner
        case .nameKeeper: .nameKeeper
        case .guessSex: .guessSex
        case .choose: .choose
        case .payDebt: .payDebt
        case .giveHatchAlongEgg: .giveHatchAlongEgg
        case .fillCard: .fillCard
        case .postCard: .postCard
        case .sellToBuyer: .sellToBuyer
        }
    }

    /// Any command, picked evenly by kind. Its values come from the game when they can (a coop hen, a card
    /// on the board, a choice that waits), and are sometimes nonsense, so refusals are fuzzed too.
    static func anyCommand(_ s: GameState, _ pick: inout SeededRNG) -> Command {
        let birds = s.birdsAtHome + s.boarding
        let nonsense = Int.random(in: 0..<8, using: &pick) == 0
        let anyBird = nonsense ? UUID() : birds.randomElement(using: &pick)?.id ?? UUID()
        let coopBird = nonsense ? UUID() : s.coop.randomElement(using: &pick)?.id ?? anyBird
        let broody = s.coop.filter { $0.isBroody(onDay: s.day) }.randomElement(using: &pick)?.id
        let coopHen = nonsense ? UUID() : broody ?? s.coop.first { $0.sex == .hen }?.id ?? UUID()
        let someEggs = s.carton.shuffled(using: &pick).prefix(Int.random(in: 0...4, using: &pick)).map(\.id)
        let anEgg = nonsense ? UUID() : s.carton.randomElement(using: &pick)?.id ?? UUID()
        let names = ["Clover", "Pip", "", "  ", String(repeating: "Feather", count: 8), "Starter"]
        let name = names.randomElement(using: &pick) ?? "Clover"
        switch CommandKind.allCases.randomElement(using: &pick) ?? .feed {
        case .chooseStarter: return .chooseStarter(index: Int.random(in: -1...3, using: &pick), name: name)
        case .feed: return .feed
        case .collectEggs: return .collectEggs
        case .sellEggs: return .sellEggs
        case .closeCoop: return .closeCoop
        case .passNight: return .passNight
        case .buyIncubator: return .buyIncubator
        case .incubate: return .incubate(count: Int.random(in: -1...8, using: &pick))
        case .sit: return .sit(hen: coopHen, count: Int.random(in: 0...6, using: &pick))
        case .rename: return .rename(anyBird, name: name)
        case .candle: return .candle
        case .sellClearEggs: return .sellClearEggs
        case .rehome:
            // As in `randomCommand`: a keeper rehomes when the flock is crowded, not their first two birds.
            return birds.count(where: { !$0.isOnLoan }) >= 3 || nonsense ? .rehome(anyBird) : bedtime(s)
        case .upgradeCoop: return .upgradeCoop
        case .buy: return .buy(ShopItem.allCases.randomElement(using: &pick) ?? .treats)
        case .acceptTrade: return .acceptTrade
        case .pet: return .pet(anyBird)
        case .giveTreat: return .giveTreat(anyBird)
        case .deliver:
            let waiting = nonsense ? nil : Engine.storyAwaitingDelivery(s)
            return .deliver(story: waiting ?? Storylines.all.randomElement(using: &pick)?.id ?? "")
        case .enterShow: return .enterShow(anyBird)
        case .enterEggs: return .enterEggs
        case .feedPremium: return .feedPremium
        case .incubateEggs: return .incubateEggs(someEggs)
        case .sitEggs: return .sitEggs(hen: coopHen, eggs: someEggs)
        case .sellChosenEggs: return .sellChosenEggs(someEggs)
        case .candleEgg: return .candleEgg(anEgg)
        case .enterShowIn:
            let bird = s.bird(anyBird)
            let classes = bird.map { Engine.eligibleClasses(for: $0, in: s) } ?? []
            let chosen = classes.randomElement(using: &pick) ?? .eggs(.brown)
            return .enterShowIn(anyBird, nonsense ? .eggs(.blue) : chosen)
        case .enterEggPlate: return .enterEggPlate(Array(s.carton.shuffled(using: &pick).prefix(3).map(\.id)))
        case .buySpecial: return .buySpecial
        case .penBird: return .penBird(coopBird)
        case .unpenBird: return .unpenBird(nonsense ? anyBird : s.pen.randomElement(using: &pick) ?? coopBird)
        case .rest: return .rest
        case .openPlanner: return .openPlanner
        case .nameKeeper: return .nameKeeper(name)
        case .guessSex:
            let chick = s.brooder.filter { !$0.revealed }.randomElement(using: &pick)?.id ?? anyBird
            return .guessSex(chick, Bool.random(using: &pick) ? .hen : .rooster)
        case .choose:
            guard !nonsense, let choice = s.pendingChoices.randomElement(using: &pick) else {
                return .choose(story: "noSuchStory", option: "yes")
            }
            return .choose(story: choice.story, option: choice.options.randomElement(using: &pick) ?? "")
        case .payDebt: return .payDebt(nonsense ? "noSuchDebt" : s.debts.randomElement(using: &pick)?.id ?? "")
        case .giveHatchAlongEgg: return .giveHatchAlongEgg(Bool.random(using: &pick) ? nil : anEgg)
        case .fillCard:
            guard let card = s.marketBoard.cards.randomElement(using: &pick) else { return .fillCard("", bird: nil) }
            return .fillCard(card.id, bird: s.birdsFor(card).randomElement(using: &pick)?.id ?? anyBird)
        case .postCard:
            let breed = s.breedsForKeeperCard.randomElement(using: &pick)
            return .postCard(breed ?? Breed.starters.randomElement(using: &pick) ?? Breed.starters[0])
        case .sellToBuyer:
            let young = s.marketBoard.keeperCard.map { s.youngBirdsForSale(of: $0.breed) } ?? []
            return .sellToBuyer(young.randomElement(using: &pick)?.id ?? anyBird)
        }
    }

    /// Every command can come out of the fuzzer, so no command goes untested by the random games.
    @Test func theFuzzerDrawsEveryCommand() {
        var drawn: Set<CommandKind> = []
        for seed in UInt64(1)...6 {
            var rng = SeededRNG(seed: seed)
            var pick = SeededRNG(seed: seed &* 7919)
            var s = Engine.newGame(using: &rng)
            _ = Engine.apply(.chooseStarter(index: 0, name: "Starter"), to: &s, using: &rng)
            for _ in 0..<1500 {
                let command = Self.randomCommand(s, &pick)
                drawn.insert(Self.kind(of: command))
                _ = Engine.apply(command, to: &s, using: &rng)
            }
        }
        #expect(drawn == Set(CommandKind.allCases), "never drawn: \(Set(CommandKind.allCases).subtracting(drawn))")
    }
}
