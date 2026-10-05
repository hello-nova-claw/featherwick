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
            let a = left > 0 ? "+" : "-"
            left -= left > 0 ? 1 : 0
            let b = left > 0 ? "+" : "-"
            left -= left > 0 ? 1 : 0
            g.setAlleles([a, b], at: locus)
        }
    }

    /// A black Orpington hen with perfect show type: unbeatable in the breed class.
    static func championOrpington(in s: GameState, rng: inout SeededRNG) -> Bird {
        var g = Breed.orpington.purebred(.hen, variety: .black)
        setType(&g, plus: QuantitativeTrait.showType.maxScore)
        return Bird(
            id: makeID(using: &rng), name: "Champion", breed: .orpington, genome: g,
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
        #expect(s.coins == 100 - s.rules.showEntryFee)  // the fee is a coin sink, paid on entry
        let afterEntry = s.coins

        _ = Engine.apply(.passNight, to: &s, using: &rng)
        #expect(s.isShowDay)

        let theme = ShowTheme.forSeason(s.season)
        let first = Engine.prize(for: 1, in: .breed(.orpington), theme: theme, rules: s.rules).coins
        let result = s.showResults.first { $0.showClass == .breed(.orpington) }
        #expect(result?.placing == 1)
        #expect(result?.fieldSize == (s.rules.showCompetitorsByKind[.breed] ?? 0) + 1)
        #expect(result?.prize == first)
        #expect(result?.birdID == champ.id)
        #expect(result?.notes?.isEmpty == false)
        #expect(s.coins == afterEntry + first)  // prize paid on show day
        #expect(s.firstPlaceRibbons == 1)
        #expect(s.showEntries.isEmpty)  // entries cleared after the show
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
            var egg = Egg(
                id: makeID(using: &rng), layDay: s.day, motherID: makeID(using: &rng),
                colour: .brown, speckled: false)
            egg.collectedDay = s.day
            egg.shape = QuantitativeTrait.eggShape.maxScore
            egg.shell = 1.0
            s.carton.append(egg)
        }
        _ = Engine.apply(.enterEggs, to: &s, using: &rng)
        #expect(s.carton.isEmpty)  // the plate goes to the show
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
        let chick = Bird(
            id: makeID(using: &rng), name: "Peep", breed: .orpington, genome: g,
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

    // MARK: - Choosing a class

    /// A cross with the champion's looks: only the pet class will have it.
    static func cross(in s: GameState, rng: inout SeededRNG) -> Bird {
        var bird = championOrpington(in: s, rng: &rng)
        bird.purebredFlag = false
        return bird
    }

    /// Perfect, fresh, plain eggs in these colours.
    static func plate(_ colours: [EggColour], in s: GameState, rng: inout SeededRNG) -> [Egg] {
        var eggs: [Egg] = []
        for colour in colours {
            var egg = Egg(
                id: makeID(using: &rng), layDay: s.day, motherID: makeID(using: &rng),
                colour: colour, speckled: false)
            egg.collectedDay = s.day
            egg.shape = QuantitativeTrait.eggShape.maxScore
            egg.shell = 1.0
            eggs.append(egg)
        }
        return eggs
    }

    @Test func eligibleClassesFollowBreedingAndAge() {
        let (s, start) = Self.eveOfShow()
        var rng = start
        let champ = Self.championOrpington(in: s, rng: &rng)
        #expect(Engine.eligibleClasses(for: champ, in: s) == [.breed(.orpington), .pet])
        #expect(Engine.eligibleClasses(for: Self.cross(in: s, rng: &rng), in: s) == [.pet])
        let chick = plainBird(.orpington, .hen, hatchDay: s.day, rng: &rng)
        #expect(Engine.eligibleClasses(for: chick, in: s).isEmpty)
    }

    @Test func enterShowInRejectsAClassTheBirdCannotEnter() {
        var (s, rng) = Self.eveOfShow()
        let champ = Self.championOrpington(in: s, rng: &rng)
        let cross = Self.cross(in: s, rng: &rng)
        s.coop += [champ, cross]

        let wrong: [(UUID, ShowClass)] = [
            (cross.id, .breed(.orpington)), (champ.id, .breed(.wyandotte)), (champ.id, .eggs(.brown)),
        ]
        for (id, cls) in wrong {
            #expect(Engine.apply(.enterShowIn(id, cls), to: &s, using: &rng) == [.rejected(.notShowEligible)])
        }
        #expect(s.showEntries.isEmpty)
        #expect(s.coins == 100)  // no fee for a rejected entry
    }

    @Test func aPurebredMayEnterThePetClassInstead() {
        var (s, rng) = Self.eveOfShow()
        let champ = Self.championOrpington(in: s, rng: &rng)
        s.coop.append(champ)

        let ev = Engine.apply(.enterShowIn(champ.id, .pet), to: &s, using: &rng)
        #expect(ev == [.enteredInShow(champ.id, .pet)])
        #expect(s.showEntries.first?.showClass == .pet)
        // Once per show, whatever the class.
        let again = Engine.apply(.enterShowIn(champ.id, .breed(.orpington)), to: &s, using: &rng)
        #expect(again == [.rejected(.alreadyEntered)])

        _ = Engine.apply(.passNight, to: &s, using: &rng)
        let result = s.showResults.first { $0.birdID == champ.id }
        #expect(result?.showClass == .pet)
        #expect(result?.fieldSize == (s.rules.showCompetitorsByKind[.pet] ?? 0) + 1)
    }

    @Test func aChosenClassTheBirdNoLongerFitsFallsBackToItsDefault() {
        var (s, rng) = Self.eveOfShow()
        let champ = Self.championOrpington(in: s, rng: &rng)
        s.coop.append(champ)
        _ = Engine.apply(.enterShowIn(champ.id, .breed(.orpington)), to: &s, using: &rng)
        s.coop[0].purebredFlag = false  // no longer a purebred: the breed class will not have it

        _ = Engine.apply(.passNight, to: &s, using: &rng)
        #expect(s.showResults.first { $0.birdID == champ.id }?.showClass == .pet)
    }

    @Test func aChosenPlateIsEnteredAndLeavesTheCarton() {
        var (s, rng) = Self.eveOfShow()
        let eggs = Self.plate([.brown, .brown, .brown], in: s, rng: &rng)
        let spare = Self.plate([.brown], in: s, rng: &rng)
        s.carton = eggs + spare

        let ev = Engine.apply(.enterEggPlate(eggs.map(\.id)), to: &s, using: &rng)
        #expect(ev == [.enteredInShow(nil, .eggs(.brown))])
        #expect(s.carton.map(\.id) == spare.map(\.id))
        #expect(Set(s.showEntries.first?.eggs.map(\.id) ?? []) == Set(eggs.map(\.id)))
        #expect(s.coins == 100 - s.rules.showEntryFee)
    }

    @Test func aMixedOrShortPlateIsRejected() {
        var (s, rng) = Self.eveOfShow()
        let mixed = Self.plate([.brown, .brown, .blue], in: s, rng: &rng)
        s.carton = mixed
        let ids = mixed.map(\.id)
        let notInCarton = makeID(using: &rng)
        let tries: [[UUID]] = [ids, Array(ids.prefix(2)), [ids[0], ids[1], ids[0]], [ids[0], ids[1], notInCarton]]
        for chosen in tries {
            #expect(Engine.apply(.enterEggPlate(chosen), to: &s, using: &rng) == [.rejected(.noMatchedPlate)])
        }
        #expect(s.carton.count == 3)
        #expect(s.showEntries.isEmpty)
        #expect(s.coins == 100)
    }

    // MARK: - Prizes and difficulty

    /// A class of each kind, to look up prizes.
    static func sampleClass(_ kind: ShowKind) -> ShowClass {
        switch kind {
        case .pet: .pet
        case .eggs: .eggs(.brown)
        case .breed: .breed(.orpington)
        }
    }

    @Test func prizesDifferByKindAndTheFeaturedKindPaysABonus() {
        let r = Rules.standard
        func coins(_ kind: ShowKind, _ theme: ShowTheme, _ placing: Int = 1) -> Int {
            Engine.prize(for: placing, in: Self.sampleClass(kind), theme: theme, rules: r).coins
        }
        // Summer features the pet class, so eggs and breed pay their plain prizes.
        #expect(coins(.eggs, .summerFete) == r.showPrizeCoins[.eggs]?[0])
        #expect(coins(.breed, .summerFete) == r.showPrizeCoins[.breed]?[0])
        // Harder kinds pay more.
        #expect(coins(.pet, .harvestShow) < coins(.eggs, .harvestShow))
        #expect(coins(.eggs, .summerFete) < coins(.breed, .summerFete))
        // The featured kind pays the bonus.
        for theme in ShowTheme.allCases {
            for placing in 1...3 {
                let plain = r.showPrizeCoins[theme.featured]?[placing - 1] ?? 0
                let paid = coins(theme.featured, theme, placing)
                #expect(paid == Int((Double(plain) * r.showFeaturedBonus).rounded()))
                #expect(paid > plain)
            }
        }
        // Outside the ribbons nothing is paid.
        for placing in [0, 4, 8] {
            for kind in ShowKind.allCases {
                let won = Engine.prize(for: placing, in: Self.sampleClass(kind), theme: .summerFete, rules: r)
                #expect(won.coins == 0 && won.treats == 0)
            }
        }
    }

    @Test func thePetClassPaysTreats() {
        var (s, rng) = Self.eveOfShow()
        s.rules.showCompetitorsByKind[.pet] = 0  // no rivals: a sure first place
        s.treats = 0
        let cross = Self.cross(in: s, rng: &rng)
        s.coop.append(cross)
        _ = Engine.apply(.enterShow(cross.id), to: &s, using: &rng)

        let ev = Engine.apply(.passNight, to: &s, using: &rng)
        let won = Engine.prize(for: 1, in: .pet, theme: ShowTheme.forSeason(s.season), rules: s.rules)
        #expect(won.treats == s.rules.showPrizeTreats[.pet]?[0])
        #expect(won.treats > 0)
        #expect(ev.contains(.showTreatsWon(treats: won.treats)))
        #expect(s.treats == won.treats)
        #expect(s.showResults.first?.treats == won.treats)
        // Eggs and breed classes pay coins only.
        for kind in [ShowKind.eggs, .breed] {
            #expect(Engine.prize(for: 1, in: Self.sampleClass(kind), theme: .harvestShow, rules: s.rules).treats == 0)
        }
    }

    @Test func fieldSizeGrowsWithDifficulty() {
        var (s, rng) = Self.eveOfShow()
        let champ = Self.championOrpington(in: s, rng: &rng)
        let cross = Self.cross(in: s, rng: &rng)
        s.coop += [champ, cross]
        s.carton = Self.plate([.brown, .brown, .brown], in: s, rng: &rng)
        _ = Engine.apply(.enterShow(champ.id), to: &s, using: &rng)
        _ = Engine.apply(.enterShow(cross.id), to: &s, using: &rng)
        _ = Engine.apply(.enterEggs, to: &s, using: &rng)
        #expect(s.showEntries.count == 3)

        _ = Engine.apply(.passNight, to: &s, using: &rng)
        #expect(s.showResults.count == 3)
        for result in s.showResults {
            #expect(result.fieldSize == (s.rules.showCompetitorsByKind[result.showClass.kind] ?? 0) + 1)
        }
        let sizes = ShowKind.allCases.map { s.rules.showCompetitorsByKind[$0] ?? 0 }
        #expect(sizes == sizes.sorted())  // pet < eggs < breed
        #expect(Set(sizes).count == sizes.count)
    }

    @Test func eachSeasonHasItsTheme() {
        #expect(ShowTheme.forSeason(.spring) == .springEggFair)
        #expect(ShowTheme.forSeason(.summer) == .summerFete)
        #expect(ShowTheme.forSeason(.autumn) == .harvestShow)
        #expect(ShowTheme.forSeason(.winter) == .winterChampionship)
        #expect(ShowTheme.springEggFair.featured == .eggs)
        #expect(ShowTheme.summerFete.featured == .pet)
        #expect(ShowTheme.harvestShow.featured == .breed)
        #expect(ShowTheme.winterChampionship.featured == .breed)

        var s = GameState(rules: .standard, phase: .playing)
        for day in [0, 10, 27, 28, 60, 83, 84, 120] {
            s.day = day
            #expect(s.nextShowTheme == ShowTheme.forSeason(s.season(onDay: s.nextShowDay)))
        }
        s.day = 10  // the first show is on the first day of summer
        #expect(s.nextShowTheme == .summerFete)
        s.day = s.rules.daysPerSeason * 3 - 1
        #expect(s.nextShowTheme == .winterChampionship)
    }

    @Test func theWinterChampionshipDrawsTheStrongestField() {
        let r = Rules.standard
        for kind in ShowKind.allCases {
            let winter = Engine.rivalPicks(for: kind, theme: .winterChampionship, r)
            let autumn = Engine.rivalPicks(for: kind, theme: .harvestShow, r)
            #expect(winter == autumn + r.winterChampionshipExtraPicks)
        }
        let picks = ShowKind.allCases.map { Engine.rivalPicks(for: $0, theme: .summerFete, r) }
        #expect(picks == picks.sorted())  // pet < eggs < breed
    }

    @Test func showResultsCarryTheTheme() {
        var (s, rng) = Self.eveOfShow()
        let champ = Self.championOrpington(in: s, rng: &rng)
        s.coop.append(champ)
        let theme = s.nextShowTheme
        _ = Engine.apply(.enterShow(champ.id), to: &s, using: &rng)
        _ = Engine.apply(.passNight, to: &s, using: &rng)
        #expect(s.showResults.first?.theme == theme)
        #expect(theme == ShowTheme.forSeason(s.season))
    }

    @Test func anOldSaveLoadsWithTheNewShowRules() throws {
        let game = try SaveFormat.decode(SaveFormatTests.fixture("save-v0"))
        let r = game.state.rules
        #expect(r.showCompetitorsByKind == Rules.standard.showCompetitorsByKind)
        #expect(r.showRivalPicks == Rules.standard.showRivalPicks)
        #expect(r.showPrizeCoins == Rules.standard.showPrizeCoins)
        #expect(r.showPrizeTreats == Rules.standard.showPrizeTreats)
        #expect(r.showFeaturedBonus == Rules.standard.showFeaturedBonus)
        #expect(r.winterChampionshipExtraPicks == Rules.standard.winterChampionshipExtraPicks)
        #expect(game.state.showEntries.allSatisfy { $0.showClass == nil })
    }

    /// A result saved before results carried a bird, treats, notes and a theme still loads.
    @Test func anOldShowResultLoads() throws {
        let json = """
            {"day": 28, "showClass": {"pet": {}}, "entrantName": "Pip", "placing": 2,
             "fieldSize": 6, "score": 70, "prize": 10}
            """
        let result = try JSONDecoder().decode(ShowResult.self, from: Data(json.utf8))
        #expect(result.placing == 2)
        #expect(result.birdID == nil && result.treats == nil && result.notes == nil && result.theme == nil)
    }

    /// An entry saved before players could choose a class still loads, with the default class.
    @Test func anOldShowEntryLoads() throws {
        let id = UUID()
        let json = #"{"birdID": "\#(id.uuidString)", "eggs": []}"#
        let entry = try JSONDecoder().decode(ShowEntry.self, from: Data(json.utf8))
        #expect(entry.birdID == id)
        #expect(entry.showClass == nil)
    }
}
