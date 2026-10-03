import Foundation
import Testing
@testable import FeatherwickCore

/// The county show as an event: entering, judging against a field, placings and prizes.
struct ShowEventTests {
    /// A state one day before a show, coop shut (no fox), fed, with plenty of coins.
    /// The next `passNight` lands exactly on a show day.
    static func eveOfShow(seed: UInt64 = 7) -> (GameState, SeededRNG) {
        var s = GameState(rules: .standard, phase: .playing)
        s.day = s.rules.showIntervalDays - 1
        s.coins = 100
        s.coopDoorOpen = false
        s.fedToday = true
        return (s, SeededRNG(seed: seed))
    }

    /// Sets exactly `plus` "+" alleles across the show-type genes.
    static func setType(_ g: inout Genome, plus: Int) {
        var left = plus
        for locus in QuantitativeTrait.showType.loci {
            let a = left > 0 ? "+" : "-"; left -= left > 0 ? 1 : 0
            let b = left > 0 ? "+" : "-"; left -= left > 0 ? 1 : 0
            g.setAlleles([a, b], at: locus)
        }
    }

    /// A black Orpington hen with perfect show type: unbeatable in the breed class.
    static func championOrpington(in s: GameState, rng: inout SeededRNG) -> Bird {
        var g = Breed.orpington.purebred(.hen, variety: .black)
        setType(&g, plus: QuantitativeTrait.showType.maxScore)
        return Bird(id: makeID(using: &rng), name: "Champion", breed: .orpington, genome: g,
                    hatchDay: s.day - s.rules.adultAge, origin: "test", revealed: true)
    }

    @Test func aShowFallsEverySeasonAndWeCanSeeTheNextOne() {
        var s = GameState(rules: .standard, phase: .playing)
        s.day = 10
        #expect(s.nextShowDay == s.rules.showIntervalDays)
        #expect(!s.isShowDay)
        s.day = s.rules.showIntervalDays
        #expect(s.isShowDay)
        #expect(s.nextShowDay == s.rules.showIntervalDays * 2)
    }

    @Test func maxTypePurebredWinsItsBreedClassAndIsPaid() {
        var (s, rng) = Self.eveOfShow()
        let champ = Self.championOrpington(in: s, rng: &rng)
        s.coop.append(champ)

        _ = Engine.apply(.enterShow(champ.id), to: &s, using: &rng)
        #expect(s.coins == 100 - s.rules.showEntryFee)   // the fee is a coin sink, paid on entry
        let afterEntry = s.coins

        _ = Engine.apply(.passNight, to: &s, using: &rng)
        #expect(s.isShowDay)

        let result = s.showResults.first { $0.showClass == .breed(.orpington) }
        #expect(result?.placing == 1)
        #expect(result?.fieldSize == s.rules.showCompetitors + 1)
        #expect(result?.prize == s.rules.showPrizeFirst)
        #expect(s.coins == afterEntry + s.rules.showPrizeFirst)   // prize paid on show day
        #expect(s.firstPlaceRibbons == 1)
        #expect(s.showEntries.isEmpty)                            // entries cleared after the show
    }

    @Test func placingsAreDeterministicUnderAFixedSeed() {
        func playOut() -> [ShowResult] {
            var (s, rng) = Self.eveOfShow(seed: 42)
            let champ = Self.championOrpington(in: s, rng: &rng)
            s.coop.append(champ)
            _ = Engine.apply(.enterShow(champ.id), to: &s, using: &rng)
            _ = Engine.apply(.passNight, to: &s, using: &rng)
            return s.showResults
        }
        #expect(playOut() == playOut())
    }

    @Test func aPerfectPlateWinsTheEggClass() {
        var (s, rng) = Self.eveOfShow()
        for _ in 0..<ShowPoints.eggPlate {
            var egg = Egg(id: makeID(using: &rng), layDay: s.day, motherID: makeID(using: &rng),
                          colour: .brown, speckled: false)
            egg.collectedDay = s.day
            egg.shape = QuantitativeTrait.eggShape.maxScore
            egg.shell = 1.0
            s.carton.append(egg)
        }
        _ = Engine.apply(.enterEggs, to: &s, using: &rng)
        #expect(s.carton.isEmpty)            // the plate goes to the show
        #expect(s.showEntries.count == 1)

        _ = Engine.apply(.passNight, to: &s, using: &rng)
        let eggResult = s.showResults.first { if case .eggs = $0.showClass { return true } else { return false } }
        #expect(eggResult != nil)
        #expect(eggResult?.placing == 1)
    }

    @Test func crossesAndGrowersEnterThePetClass() {
        var (s, rng) = Self.eveOfShow()
        var cross = Self.championOrpington(in: s, rng: &rng)
        cross.purebredFlag = false
        s.coop.append(cross)
        let ev = Engine.apply(.enterShow(cross.id), to: &s, using: &rng)
        #expect(ev.contains(.enteredInShow(cross.id, .pet)))
    }

    @Test func ineligibleEntriesAreRejected() {
        var (s, rng) = Self.eveOfShow()

        // A chick is too young.
        let g = Breed.orpington.purebred(.hen, variety: .black)
        let chick = Bird(id: makeID(using: &rng), name: "Peep", breed: .orpington, genome: g,
                         hatchDay: s.day, origin: "test", revealed: true)
        s.brooder.append(chick)
        #expect(Engine.apply(.enterShow(chick.id), to: &s, using: &rng).contains(.rejected(.notShowEligible)))

        // The same bird can't be entered twice.
        let champ = Self.championOrpington(in: s, rng: &rng)
        s.coop.append(champ)
        _ = Engine.apply(.enterShow(champ.id), to: &s, using: &rng)
        #expect(Engine.apply(.enterShow(champ.id), to: &s, using: &rng).contains(.rejected(.alreadyEntered)))

        // No matched plate of eggs in the carton.
        #expect(Engine.apply(.enterEggs, to: &s, using: &rng).contains(.rejected(.noMatchedPlate)))
    }
}
