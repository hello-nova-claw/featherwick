import Foundation
import Testing

@testable import FeatherwickCore

/// The village's four people and their first arcs: Dot (shows), Teddy (friendliness), Mr Okafor (egg colours)
/// and Bea (rehoming). Each arc starts on its own event, each choice resolves both ways, and no arc waits on
/// another. The words are checked in `VillageTextTests`.
struct VillageTests {
    static let arcs = ["dotStandard", "teddyHelps", "okaforWindow", "beaPostcards"]

    static func game(seed: UInt64 = 5) -> (GameState, SeededRNG) {
        var r = calmRules()
        r.noteChance = 0
        return startedGame(sex: .hen, rules: r, seed: seed)
    }

    static func nights(_ n: Int, _ s: inout GameState, _ rng: inout SeededRNG) -> [GameEvent] {
        (0..<n).flatMap { _ in night(&s, &rng) }
    }

    /// Nights until the story waits at this step (at most 20).
    static func untilStep(
        _ story: String, _ step: String, _ s: inout GameState, _ rng: inout SeededRNG
    ) -> [GameEvent] {
        var ev: [GameEvent] = []
        for _ in 0..<20 {
            if let p = s.stories[story], let line = Storylines.story(story),
                p.step < line.steps.count, line.steps[p.step].id == step
            {
                return ev
            }
            ev += night(&s, &rng)
        }
        Issue.record("\(story) never reached \(step)")
        return ev
    }

    static func bird(
        _ breed: Breed, _ sex: Sex = .hen, name: String, revealed: Bool = true, _ rng: inout SeededRNG
    )
        -> Bird
    {
        Bird(
            id: makeID(using: &rng), name: name, breed: breed, genome: breed.purebred(sex), hatchDay: -200,
            origin: Bird.shopOrigin, revealed: revealed)
    }

    static func eggs(_ colour: EggColour, _ n: Int, _ s: inout GameState) {
        for _ in 0..<n {
            s.carton.append(Egg(id: UUID(), layDay: s.day, motherID: UUID(), colour: colour, speckled: false))
        }
    }

    static func notes(_ ev: [GameEvent]) -> [String] {
        ev.compactMap { if case .noteArrived(_, let id) = $0 { id } else { nil } }
    }

    // MARK: - Triggers

    @Test func eachArcStartsOnItsOwnEventAndNotBefore() {
        var (s, rng) = Self.game()
        _ = Self.nights(3, &s, &rng)
        #expect(Self.arcs.allSatisfy { s.stories[$0] == nil })

        s.eggBook.insert(EggBookEntry(colour: .brown, speckled: false))
        var ev = night(&s, &rng)
        // Not in a new keeper's first fortnight: Marigold lays brown from day 4.
        #expect(!ev.contains(.storyStarted("okaforWindow")))
        s.day = 14
        ev = night(&s, &rng)
        #expect(ev.contains(.storyStarted("okaforWindow")))
        #expect(s.stories["dotStandard"] == nil && s.stories["teddyHelps"] == nil && s.stories["beaPostcards"] == nil)

        s.rehomed.append(Self.bird(.orpington, name: "Clover", &rng))
        ev = night(&s, &rng)
        #expect(ev.contains(.storyStarted("beaPostcards")))
        #expect(s.stories["dotStandard"] == nil && s.stories["teddyHelps"] == nil)

        s.showEntries.append(ShowEntry(birdID: s.starterID, eggs: [], showClass: .pet))
        ev = night(&s, &rng)
        #expect(ev.contains(.storyStarted("dotStandard")))
        #expect(s.stories["teddyHelps"] == nil)

        // Teddy: a ribbon (top three) or day 30, whichever comes first. Fourth place is not a ribbon.
        s.showResults.append(Self.result(placing: 4, s))
        _ = night(&s, &rng)
        #expect(s.stories["teddyHelps"] == nil)
        s.showResults.append(Self.result(placing: 3, s))
        #expect(night(&s, &rng).contains(.storyStarted("teddyHelps")))
    }

    static func result(placing: Int, _ s: GameState) -> ShowResult {
        ShowResult(
            day: s.day, showClass: .pet, entrantName: "Pip", placing: placing, fieldSize: 8, score: 70, prize: 0,
            birdID: s.starterID, treats: 0, notes: nil, theme: nil, podium: nil)
    }

    @Test func teddyComesOnDayThirtyWithoutARibbon() {
        var (s, rng) = Self.game()
        s.day = 28
        _ = night(&s, &rng)
        #expect(s.day == 29 && s.stories["teddyHelps"] == nil)
        #expect(night(&s, &rng).contains(.storyStarted("teddyHelps")))
    }

    @Test func noArcWaitsOnAnotherAndAllRunAtOnce() {
        for id in Self.arcs { #expect(Storylines.story(id)?.after == []) }
        // Append, never insert: Hazel's three stories keep their places.
        #expect(Storylines.all.map(\.id) == ["broodySilkie", "lacedGift", "heritageBreed"] + Self.arcs + ["marigold"])
        #expect(Storylines.all.map(\.person) == [.hazel, .hazel, .hazel, .dot, .teddy, .okafor, .bea, .hazel])

        var (s, rng) = Self.game()
        s.day = 29
        s.eggBook.insert(EggBookEntry(colour: .brown, speckled: false))
        s.rehomed.append(Self.bird(.orpington, name: "Clover", &rng))
        s.showEntries.append(ShowEntry(birdID: s.starterID, eggs: [], showClass: .pet))
        let ev = night(&s, &rng)
        for id in Self.arcs { #expect(ev.contains(.storyStarted(id)), "\(id)") }
        _ = Self.nights(8, &s, &rng)
        // Every choice waits at once, each for its own person.
        #expect(Set(s.pendingChoices.map(\.person)) == [.dot, .teddy, .okafor])
    }

    // MARK: - Dot

    @Test func dotOffersTwoOfTheFlocksBreedsAndHerPageGoesToTheChosenOne() throws {
        for pick in 0..<2 {
            var (s, rng) = Self.game()
            s.coop.append(Self.bird(.araucana, name: "Bluebell", &rng))
            s.coop.append(Self.bird(.wyandotte, name: "Clover", &rng))
            s.showEntries.append(ShowEntry(birdID: s.starterID, eggs: [], showClass: .pet))
            _ = Self.untilStep("dotStandard", "standard", &s, &rng)
            let choice = try #require(s.pendingChoices.first { $0.story == "dotStandard" })
            #expect(choice.person == .dot && choice.choice == Storylines.dotStandardChoice)
            #expect(choice.options == [Breed.wyandotte.rawValue, Breed.araucana.rawValue])
            #expect(s.dotStandardBreed == nil)

            let option = choice.options[pick]
            let ev = Engine.apply(.choose(story: "dotStandard", option: option), to: &s, using: &rng)
            let breed = Breed(rawValue: option)
            #expect(Self.notes(ev) == [Storylines.dotStandardNote(breed)])
            #expect(ev.contains(.storyFinished("dotStandard")))
            #expect(s.dotStandardBreed == breed)
            // Only the chosen breed's page gains her notes.
            let other = Breed(rawValue: choice.options[1 - pick])
            #expect(s.dotStandardBreed != other)
        }
    }

    @Test func dotNeverOffersADeadEndOrAHiddenBreed() {
        var (s, rng) = Self.game()
        // One breed in the flock whose breed shows, and a chick whose breed has not shown yet.
        s.coop = [Self.bird(.australorp, name: "Coal", &rng)]
        s.brooder = []
        s.breedBook = []
        let breeds = s.breedsToChooseFrom()
        #expect(breeds == [.australorp, .orpington])  // then a breed the shop sells
        #expect(breeds.allSatisfy { $0.definition.isInGame })
        // Rule 8: a chick whose breed is still hidden changes nothing.
        for breed in BreedTable.inGame.map(\.id) {
            s.brooder = [Self.bird(breed, name: "Fluff", revealed: false, &rng)]
            #expect(s.breedsToChooseFrom() == breeds)
        }

        // No bird shows its breed at all: Dot still offers two breeds, Breed Book first.
        s.coop = []
        s.breedBook.insert(BreedBookEntry(Self.bird(.wyandotte, name: "W", &rng)))
        #expect(s.breedsToChooseFrom().count == 2)
        #expect(s.breedsToChooseFrom().first == .wyandotte)
    }

    @Test func dotsOfferIsFixedWhenTheStepStarts() throws {
        var (s, rng) = Self.game()
        s.coop.append(Self.bird(.araucana, name: "Bluebell", &rng))
        s.showEntries.append(ShowEntry(birdID: s.starterID, eggs: [], showClass: .pet))
        _ = Self.untilStep("dotStandard", "standard", &s, &rng)
        let before = try #require(s.pendingChoices.first { $0.story == "dotStandard" }).options
        s.coop.append(Self.bird(.silkie, name: "Fluff", &rng))
        _ = night(&s, &rng)
        #expect(s.pendingChoices.first { $0.story == "dotStandard" }?.options == before)
        // An option she did not offer is refused.
        let ev = Engine.apply(.choose(story: "dotStandard", option: Breed.silkie.rawValue), to: &s, using: &rng)
        #expect(!before.contains(Breed.silkie.rawValue))
        #expect(ev == [.rejected(.noSuchChoice)])
    }

    @Test func whatAStepOfferedIsClearedWhenItFinishes() throws {
        var (s, rng) = Self.game()
        s.coop.append(Self.bird(.araucana, name: "Bluebell", &rng))
        s.showEntries.append(ShowEntry(birdID: s.starterID, eggs: [], showClass: .pet))
        _ = Self.untilStep("dotStandard", "standard", &s, &rng)
        let offered = try #require(s.stories["dotStandard"]?.options)
        _ = Engine.apply(.choose(story: "dotStandard", option: offered[0]), to: &s, using: &rng)
        // The pick stays in `chosen`; the offer is gone.
        #expect(s.stories["dotStandard"]?.options == nil)
        #expect(s.stories["dotStandard"]?.chosen == [Storylines.dotStandardChoice: offered[0]])

        Self.okaforAtWindow(&s, &rng)
        _ = Engine.apply(.choose(story: "okaforWindow", option: "wait"), to: &s, using: &rng)
        #expect(s.stories["okaforWindow"]?.wantedColours != nil)
        s.carton = []
        Self.eggs(.blue, 3, &s)
        _ = Engine.apply(.deliver(story: "okaforWindow"), to: &s, using: &rng)
        #expect(s.stories["okaforWindow"]?.wantedColours == nil)
        #expect(s.stories["okaforWindow"]?.chosen == ["window": "wait"])
    }

    // MARK: - Teddy

    static func teddyAtHelp(_ s: inout GameState, _ rng: inout SeededRNG) {
        s.showResults.append(Self.result(placing: 1, s))
        _ = Self.untilStep("teddyHelps", "help", &s, &rng)
    }

    @Test func teddyNamesTheNextChickAndGivesTreats() throws {
        var (s, rng) = Self.game()
        Self.teddyAtHelp(&s, &rng)
        let treats = s.treats
        let ev = Engine.apply(.choose(story: "teddyHelps", option: "name"), to: &s, using: &rng)
        #expect(ev.contains(.storyTreats("teddyHelps", 3)) && s.treats == treats + 3)
        #expect(s.nextChickNamer == .teddy)

        // The next chick to hatch takes one of Teddy's names. No sex word: the chick's sex is hidden.
        s.coins += 100
        func hatchOne() -> [GameEvent] {
            _ = Engine.apply(.buy(.fertileEgg), to: &s, using: &rng)
            _ = Engine.apply(.incubate(count: 1), to: &s, using: &rng)
            return night(&s, &rng)
        }
        let hatch = hatchOne()
        let named = hatch.compactMap { if case .chickNamed(let id, let p) = $0 { (id, p) } else { nil } }
        #expect(named.count == 1)
        let (id, person) = try #require(named.first)
        #expect(person == .teddy)
        let chick = try #require(s.bird(id))
        #expect(NameBook.teddy.contains(chick.name) && chick.needsName == nil)
        #expect(s.nextChickNamer == nil)
        // Only that one chick: the next waits for the keeper's name, as usual.
        let next = hatchOne()
        #expect(next.contains { if case .chicksHatched = $0 { true } else { false } })
        #expect(!next.contains { if case .chickNamed = $0 { true } else { false } })
        #expect(s.brooder.filter { $0.needsName == true }.count == 1)
        // The keeper can still rename it.
        #expect(Engine.apply(.rename(id, name: "Mine"), to: &s, using: &rng).first == .renamed(id))
    }

    @Test func aDrawingDayGivesTreatsAndADrawing() {
        var (s, rng) = Self.game()
        Self.teddyAtHelp(&s, &rng)
        let ev = Engine.apply(.choose(story: "teddyHelps", option: "drawing"), to: &s, using: &rng)
        #expect(ev.contains(.storyTreats("teddyHelps", 3)))
        #expect(Self.notes(ev) == ["teddy-drawing"])
        #expect(s.nextChickNamer == nil)
    }

    @Test func teddysLastBeatWaitsForALapChicken() {
        var (s, rng) = Self.game()
        Self.teddyAtHelp(&s, &rng)
        _ = Engine.apply(.choose(story: "teddyHelps", option: "drawing"), to: &s, using: &rng)
        _ = Self.nights(5, &s, &rng)
        #expect(s.stories["teddyHelps"]?.rewarded == false)
        #expect(!s.birdsAtHome.isEmpty)
        for i in s.brooder.indices { s.brooder[i].tameness = 1 }
        for i in s.coop.indices { s.coop[i].tameness = 1 }
        #expect(s.birdsAtHome.contains { $0.friendliness == .lapChicken })
        let ev = night(&s, &rng)
        #expect(Self.notes(ev) == ["teddy-lapChicken"])
        #expect(ev.contains(.storyFinished("teddyHelps")))
    }

    // MARK: - Mr Okafor

    static func okaforAtWindow(_ s: inout GameState, _ rng: inout SeededRNG) {
        s.eggBook.insert(EggBookEntry(colour: .brown, speckled: false))
        _ = Self.untilStep("okaforWindow", "window", &s, &rng)
    }

    @Test func sixBrownEggsNowEarnTwelveCoins() {
        var (s, rng) = Self.game()
        Self.okaforAtWindow(&s, &rng)
        _ = Engine.apply(.choose(story: "okaforWindow", option: "now"), to: &s, using: &rng)
        #expect(Engine.storiesAwaitingDelivery(s).map(\.id) == ["okaforWindow"])
        s.carton = []
        Self.eggs(.brown, 2, &s)
        Self.eggs(.blue, 4, &s)
        #expect(
            Engine.apply(.deliver(story: "okaforWindow"), to: &s, using: &rng)
                == [.rejected(.needEggs(.brown, need: 6, have: 2))])
        Self.eggs(.brown, 4, &s)
        let given = Engine.apply(.deliver(story: "okaforWindow"), to: &s, using: &rng)
        #expect(given.contains(.delivered("okaforWindow")))
        #expect(s.carton.map(\.colour) == [.blue, .blue, .blue, .blue])
        let coins = s.coins
        let ev = night(&s, &rng)
        #expect(ev.contains(.storyCoins("okaforWindow", 30)))
        #expect(!Self.notes(ev).contains("okafor-window"))
        #expect(s.coins >= coins + 30)
        // Well above what the six eggs sell for.
        #expect(30 >= 2 * 6 * s.rules.brownEggPrice)
        let later = Self.nights(3, &s, &rng)
        #expect(Self.notes(later) == ["okafor-marketBoard"])
        #expect(later.contains(.storyFinished("okaforWindow")))
    }

    @Test func waitingForANewColourEarnsFiftyCoinsAndANote() throws {
        var (s, rng) = Self.game()
        s.eggBook.insert(EggBookEntry(colour: .cream, speckled: false))
        Self.okaforAtWindow(&s, &rng)
        _ = Engine.apply(.choose(story: "okaforWindow", option: "wait"), to: &s, using: &rng)
        let wanted = try #require(s.stories["okaforWindow"]?.wantedColours)
        #expect(!wanted.contains(.brown) && !wanted.contains(.cream) && wanted.contains(.blue))
        s.carton = []
        Self.eggs(.brown, 6, &s)
        Self.eggs(.cream, 3, &s)
        Self.eggs(.blue, 2, &s)
        #expect(
            Engine.apply(.deliver(story: "okaforWindow"), to: &s, using: &rng)
                == [.rejected(.needEggsOfNewColour(wanted, need: 3, have: 2))])
        // A colour that comes into the Egg Book while he waits still counts: the wanted list is fixed.
        s.eggBook.insert(EggBookEntry(colour: .blue, speckled: false))
        Self.eggs(.blue, 1, &s)
        #expect(Engine.apply(.deliver(story: "okaforWindow"), to: &s, using: &rng).contains(.delivered("okaforWindow")))
        #expect(s.carton.count(where: { $0.colour == .blue }) == 0 && s.carton.count == 9)
        let ev = night(&s, &rng)
        #expect(ev.contains(.storyCoins("okaforWindow", 50)))
        #expect(Self.notes(ev) == ["okafor-window"])
    }

    @Test func aNewColourIsAlwaysWithinReach() {
        var (s, _) = Self.game()
        // Every colour in the book already: any colour but brown that Speckle & Down's breeds lay counts.
        for colour in EggColour.allCases { s.eggBook.insert(EggBookEntry(colour: colour, speckled: false)) }
        let shop = Set(s.surpriseBreeds.map(\.definition.eggColour))
        let wanted = s.newEggColoursWanted()
        #expect(!wanted.isEmpty && !wanted.contains(.brown))
        #expect(wanted.allSatisfy { shop.contains($0) })
        // A fresh book: every colour but the ones in it.
        s.eggBook = [EggBookEntry(colour: .brown, speckled: false)]
        #expect(s.newEggColoursWanted() == EggColour.allCases.filter { $0 != .brown })
    }

    @Test func handingOverKeepsKnownFertileEggsIfItCan() {
        var (s, _) = Self.game()
        s.carton = []
        var fertile = Egg(id: UUID(), layDay: 0, motherID: UUID(), colour: .brown, speckled: false)
        fertile.embryo = Breed.orpington.purebred(.hen)
        fertile.candled = true
        s.carton.append(fertile)
        Self.eggs(.brown, 3, &s)
        #expect(Engine.handOver(3, from: [.brown], &s))
        #expect(s.carton.map(\.id) == [fertile.id])
    }

    // MARK: - Bea

    @Test func beaWritesAboutTheRehomedBirdThenInvitesThenWritesAgainAtThree() throws {
        var (s, rng) = Self.game()
        let clover = Self.bird(.orpington, name: "Clover", &rng)
        s.coop.append(clover)
        #expect(
            Engine.apply(.rehome(clover.id), to: &s, using: &rng).contains {
                if case .rehomed = $0 { true } else { false }
            })
        var ev = night(&s, &rng)
        #expect(ev.contains(.storyStarted("beaPostcards")))
        ev = Self.nights(2, &s, &rng)
        #expect(Self.notes(ev) == ["bea-postcard"])
        ev = Self.nights(5, &s, &rng)
        #expect(Self.notes(ev) == ["bea-invite"])
        // No choice in Bea's arc.
        #expect(!s.pendingChoices.contains { $0.story == "beaPostcards" })
        ev = Self.nights(5, &s, &rng)
        #expect(Self.notes(ev).isEmpty)
        s.rehomed.append(Self.bird(.silkie, name: "Fluff", &rng))
        s.rehomed.append(Self.bird(.silkie, name: "Puff", &rng))
        ev = night(&s, &rng)
        #expect(Self.notes(ev) == ["bea-postcard-3"])
        #expect(ev.contains(.storyFinished("beaPostcards")))
    }

    @Test func theVillageArcsAreVillageNewsInTheMorningReport() {
        for id in Self.arcs {
            #expect(MorningReport.group(of: .storyStarted(id)) == .village)
            #expect(MorningReport.group(of: .storyCoins(id, 1)) == .village)
        }
        #expect(MorningReport.group(of: .storyStarted("broodySilkie")) == .neighbour)
        #expect(MorningReport.group(of: .chickNamed(UUID(), by: .teddy)) == .hatched)
    }

    // MARK: - Names and saves

    @Test func peoplesNamesAreNeverSuggestedForABird() {
        let lists = NameBook.neutral + NameBook.hens + NameBook.roosters + NameBook.teddy
        let keys = Set(lists.map(NameBook.key))
        for name in NameBook.peopleNames { #expect(!keys.contains(NameBook.key(name)), "\(name)") }
        #expect(NameBook.peopleNames.count == Person.allCases.count)
        // Teddy's names are his own: in no other list.
        let others = Set((NameBook.neutral + NameBook.hens + NameBook.roosters).map(NameBook.key))
        #expect(NameBook.teddy.allSatisfy { !others.contains(NameBook.key($0)) })
    }

    @Test func storyProgressFromAnOlderSaveLoadsWithNoOfferFixed() throws {
        let old = try SaveFormat.decode(SaveFormatTests.fixture("save-v0")).state
        #expect(old.nextChickNamer == nil)
        #expect(old.stories.values.allSatisfy { $0.options == nil && $0.wantedColours == nil })
        var (s, rng) = Self.game()
        Self.okaforAtWindow(&s, &rng)
        _ = Engine.apply(.choose(story: "okaforWindow", option: "wait"), to: &s, using: &rng)
        s.nextChickNamer = .teddy
        let data = try SaveFormat.encode(SaveGame(state: s, rng: rng))
        let back = try SaveFormat.decode(data).state
        #expect(back.stories["okaforWindow"] == s.stories["okaforWindow"])
        #expect(back.nextChickNamer == .teddy)
    }
}
