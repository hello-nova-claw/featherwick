import Foundation
import Testing

@testable import FeatherwickCore

/// Plays long random games (random but valid-looking commands, many nights) and checks after every
/// command that nothing impossible has happened. Each seed is a different game.
struct InvariantTests {
    static func problems(in s: GameState) -> [String] {
        var p: [String] = []
        if s.coop.count > s.perches { p.append("coop \(s.coop.count) > perches \(s.perches)") }
        if s.brooder.count > s.brooderSize { p.append("brooder \(s.brooder.count) > size \(s.brooderSize)") }
        if s.carton.count > s.cartonCapacity { p.append("carton over capacity") }
        if s.coins < 0 { p.append("negative coins") }
        if s.perches > s.rules.maxPerches { p.append("perches over max") }

        let everyone = s.brooder + s.henChicks + s.coop + s.lost.map(\.bird) + s.boarding + s.rehomed
        if Set(everyone.map(\.id)).count != everyone.count { p.append("a bird is in two places") }

        let eggs = s.nest + s.carton + s.clutches.flatMap(\.eggs)
        if Set(eggs.map(\.id)).count != eggs.count { p.append("an egg is in two places") }
        for e in eggs where (e.embryo == nil) != (e.fatherID == nil) { p.append("egg fertility mismatch") }

        let incubator = s.clutches.filter { $0.henID == nil }
        if incubator.count > 1 { p.append("two incubator clutches") }
        if let c = incubator.first, c.eggs.count > s.incubatorSize { p.append("incubator overfilled") }
        for c in s.clutches {
            if c.eggs.isEmpty { p.append("empty clutch") }
            // A new keeper can set clear eggs by mistake, but never one already known to be clear.
            if c.eggs.contains(where: { $0.isCandled && !$0.isFertile }) { p.append("known-clear egg being hatched") }
            if c.hatchDay < s.day { p.append("clutch past its hatch day") }
            if let hen = c.henID {
                guard let b = s.coop.first(where: { $0.id == hen }) else {
                    p.append("sitting hen not in coop")
                    continue
                }
                if !b.isBroody(onDay: s.day) { p.append("sitting hen not broody") }
                if c.eggs.count > s.rules.maxClutch { p.append("hen sitting on too many") }
            }
        }
        if Set(s.clutches.compactMap(\.henID)).count != s.clutches.compactMap(\.henID).count {
            p.append("hen with two clutches")
        }
        for chick in s.henChicks {
            guard let hen = chick.raisedBy, let b = s.coop.first(where: { $0.id == hen }) else {
                p.append("hen chick without the hen raising it in the coop")
                continue
            }
            if !b.isBroody(onDay: s.day) { p.append("hen raising chicks is not broody") }
        }
        // Coop birds are always old enough to have been revealed.
        if s.rules.growerAge <= s.rules.brooderDays {
            for b in s.coop where !b.revealed { p.append("unrevealed bird in coop: \(b.name)") }
        }
        if let id = s.starterID, s.bird(id) == nil { p.append("starter missing") }
        // Never zero birds: lost and boarding birds still belong to the player and always come back.
        if s.birdsAtHome.count + s.lost.count + s.boarding.count == 0 { p.append("the player has no birds") }
        if let offer = s.tradeOffer, !s.ownedBirds.contains(where: { $0.id == offer.roosterID }) {
            p.append("trade offer for a rooster the player doesn't own")
        }
        return p
    }

    static func randomCommand(_ s: GameState, _ pick: inout SeededRNG) -> Command {
        let birds = s.birdsAtHome + s.boarding
        let anyBird = birds.randomElement(using: &pick)?.id ?? UUID()
        // Mostly sensible moves (so the game gets somewhere), with some nonsense mixed in.
        let broody = s.coop.filter { $0.isBroody(onDay: s.day) }.randomElement(using: &pick)?.id
        let coopHen = broody ?? s.coop.filter { $0.sex == .hen }.randomElement(using: &pick)?.id ?? UUID()
        let sensibleCount = Int.random(in: 1...max(1, s.incubatorSize), using: &pick)
        let roll = Int.random(in: 0..<100, using: &pick)
        switch roll {
        case 0..<30:
            // A mostly careful keeper: usually feeds and shuts the coop before bed, but not always.
            if !s.fedToday, Double.random(in: 0..<1, using: &pick) < 0.85 { return .feed }
            if s.coopDoorOpen, Double.random(in: 0..<1, using: &pick) < 0.9 { return .closeCoop }
            return .passNight
        case 30..<54: return .feed
        case 54..<58: return .collectEggs  // rarely, so nests fill up (broody hens, floor eggs)
        case 58..<61: return .sellEggs
        case 61..<63: return .sellClearEggs
        case 63..<67: return .candle
        case 67..<75: return .closeCoop
        case 75..<78: return .buyIncubator
        case 78..<84: return .incubate(count: sensibleCount)
        case 84..<85: return .incubate(count: Int.random(in: -1...8, using: &pick))
        case 85..<91: return .sit(hen: coopHen, count: Int.random(in: 1...6, using: &pick))
        case 91..<94:
            // A keeper rehomes when the flock is crowded, not their first two birds.
            if !s.boarding.isEmpty { return .rehome(s.boarding[0].id) }
            return birds.count >= 3 ? .rehome(anyBird) : .passNight
        case 94..<97: return .upgradeCoop
        case 97..<98:
            // Shopping and trades.
            switch Int.random(in: 0..<4, using: &pick) {
            case 0: return .buy(.pullet)
            case 1: return .buy(.cockerel)
            case 2: return .buy(.fertileEgg)
            default: return .acceptTrade
            }
        case 98..<99: return .sit(hen: UUID(), count: 3)
        default: return .rehome(UUID())
        }
    }

    /// Plays one random game, checking the rules after every command. Returns every event seen.
    @discardableResult
    static func play(seed: UInt64, steps: Int = 3000) -> [GameEvent] {
        var rules = Rules.standard
        // Busier games: more fertile eggs and more broody hens.
        rules.fertileChance = 0.9
        rules.broodyChance = [.silkie: 0.8, .orpington: 0.5, .wyandotte: 0.4, .araucana: 0.4]
        var rng = SeededRNG(seed: seed)
        var pick = SeededRNG(seed: seed &* 7919)
        var s = Engine.newGame(rules: rules, using: &rng)
        var all = Engine.apply(.chooseStarter(index: Int(seed % 3), name: "Starter"), to: &s, using: &rng)

        for step in 0..<steps {
            let command = randomCommand(s, &pick)
            let dayBefore = s.day
            all += Engine.apply(command, to: &s, using: &rng)
            if command == .passNight {
                #expect(s.day == dayBefore + 1)
                #expect(!s.fedToday && s.coopDoorOpen)
                // No dead ends: with no hen, the player can buy one, has an offer, or a rooster is still out.
                let hasHen = s.ownedBirds.contains { $0.sex == .hen }
                let roosterAtHome = (s.coop + s.brooder).contains { $0.sex == .rooster && $0.revealed }
                if !hasHen && s.coins < s.rules.pulletPrice && roosterAtHome && s.tradeOffer == nil {
                    Issue.record("seed \(seed), step \(step): dead end, no hen and no way to get one")
                    break
                }
            } else {
                #expect(s.day == dayBefore)
            }
            let p = problems(in: s)
            if !p.isEmpty {
                Issue.record("seed \(seed), step \(step), after \(command): \(p)")
                break
            }
        }
        return all
    }

    @Test(arguments: Array(UInt64(1)...200))
    func randomGamesNeverBreakTheRules(seed: UInt64) {
        Self.play(seed: seed)
    }

    /// Guards against a fuzz test that passes because nothing interesting ever happens.
    @Test func randomGamesReachEverySystem() {
        var all: [GameEvent] = []
        for seed in UInt64(1)...40 { all += Self.play(seed: seed) }
        func seen(_ match: (GameEvent) -> Bool) -> Bool { all.contains(where: match) }
        #expect(seen { if case .foxVisited = $0 { true } else { false } })
        #expect(seen { if case .birdReturned = $0 { true } else { false } })
        #expect(seen { if case .neighbourGaveHen = $0 { true } else { false } })
        #expect(seen { if case .neighbourGaveIncubator = $0 { true } else { false } })
        #expect(seen { if case .wentBroody = $0 { true } else { false } })
        #expect(seen { if case .chicksHatched(_, nil) = $0 { true } else { false } })
        #expect(seen { if case .chicksHatched(_, .some) = $0 { true } else { false } })
        #expect(seen { if case .needsHome = $0 { true } else { false } })
        #expect(seen { if case .rehomed = $0 { true } else { false } })
        #expect(seen { if case .coopUpgraded = $0 { true } else { false } })
        #expect(seen { if case .eggBroken = $0 { true } else { false } })
    }
}
