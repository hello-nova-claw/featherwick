import Foundation
import Testing

@testable import FeatherwickCore

struct NamingTests {
    static func game() -> (GameState, SeededRNG) {
        var rng = SeededRNG(seed: 11)
        var r = Rules.standard
        r.foxChance = 0
        var s = Engine.newGame(rules: r, earlyGame: false, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        return (s, rng)
    }

    static func apply(_ c: Command, _ s: inout GameState, _ rng: inout SeededRNG) -> [GameEvent] {
        Engine.apply(c, to: &s, using: &rng)
    }

    // MARK: - Who needs a name

    @Test func boughtBirdsNeedANameAndNamingClearsIt() {
        var (s, rng) = Self.game()
        s.coins = 100
        _ = Self.apply(.buy(.pullet), &s, &rng)
        let pullet = s.coop.last!
        #expect(pullet.needsName == true)
        #expect(s.unnamedBirds.map(\.id) == [pullet.id])
        #expect(Self.apply(.rename(pullet.id, name: "Clementine"), &s, &rng) == [.renamed(pullet.id)])
        #expect(s.bird(pullet.id)?.name == "Clementine" && s.bird(pullet.id)?.needsName == nil)
        #expect(s.unnamedBirds.isEmpty)
    }

    @Test func hatchedChicksNeedAName() {
        var (s, rng) = Self.game()
        let hen = Bird(
            id: makeID(using: &rng), name: "h", breed: .orpington, genome: Breed.orpington.purebred(.hen),
            hatchDay: 0, origin: "t", revealed: true)
        let rooster = Bird(
            id: makeID(using: &rng), name: "r", breed: .orpington, genome: Breed.orpington.purebred(.rooster),
            hatchDay: 0, origin: "t", revealed: true)
        let egg = Breeding.layEgg(mother: hen, father: rooster, day: s.day, using: &rng)
        s.clutches = [Clutch(henID: nil, eggs: [egg], hatchDay: s.day)]
        _ = Engine.hatchDue(&s, &rng)
        #expect(s.brooder.last?.needsName == true)
    }

    @Test func birdsFromPeopleArriveNamed() {
        // The neighbour's gift hen, for a rooster starter.
        var rng = SeededRNG(seed: 2)
        var found = false
        for seed in UInt64(1)...40 where !found {
            rng = SeededRNG(seed: seed)
            var r = Rules.standard
            r.foxChance = 0
            var s = Engine.newGame(rules: r, using: &rng)
            _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
            guard s.brooder[0].sex == .rooster else { continue }
            var ev: [GameEvent] = []
            for _ in 0..<s.rules.growerAge + 1 { ev += Engine.apply(.passNight, to: &s, using: &rng) }
            guard let id = ev.compactMap({ if case .neighbourGaveHen(let id) = $0 { id } else { nil } }).first else {
                continue
            }
            let hen = s.bird(id)!
            #expect(NameBook.hens.contains(hen.name) && hen.needsName == nil)
            found = true
        }
        #expect(found)
        // A trade hen is named by her keeper too.
        var (s, r2) = Self.game()
        s.coop.append(Engine.youngBird(.rooster, origin: "t", s, &r2))
        s.brooder = []
        s.coins = 0
        _ = Engine.updateTradeOffer(&s, &r2)
        #expect(NameBook.hens.contains(s.tradeOffer?.hen.name ?? "") && s.tradeOffer?.hen.needsName == nil)
    }

    // MARK: - Rename rules

    @Test func namesAreUniqueIgnoringCaseAndSpaces() {
        var (s, rng) = Self.game()
        s.coins = 100
        _ = Self.apply(.buy(.pullet), &s, &rng)
        let id = s.coop.last!.id
        #expect(Self.apply(.rename(id, name: "pip"), &s, &rng) == [.rejected(.nameTaken)])
        #expect(Self.apply(.rename(id, name: " P i p "), &s, &rng) == [.rejected(.nameTaken)])
        // Renaming a bird to its own name, in a new spelling, is fine.
        let pip = s.brooder[0].id
        #expect(Self.apply(.rename(pip, name: "PIP"), &s, &rng) == [.renamed(pip)])
    }

    @Test func nameLengthAndBlankNames() {
        var (s, rng) = Self.game()
        let pip = s.brooder[0].id
        #expect(
            Self.apply(.rename(pip, name: String(repeating: "a", count: 25)), &s, &rng) == [
                .rejected(.nameTooLong(max: 24))
            ])
        #expect(Self.apply(.rename(pip, name: String(repeating: "a", count: 24)), &s, &rng) == [.renamed(pip)])
        #expect(Self.apply(.rename(pip, name: "  "), &s, &rng) == [.rejected(.invalidAmount)])
    }

    @Test func anyOwnedBirdCanBeRenamedEvenWhenLostButNotOnceRehomed() {
        var (s, rng) = Self.game()
        var bird = s.brooder.removeFirst()
        bird.name = "Wanderer"
        s.lost = [LostBird(bird: bird, returnsOnDay: s.day + 5)]
        #expect(Self.apply(.rename(bird.id, name: "Homebody"), &s, &rng) == [.renamed(bird.id)])
        #expect(s.lost[0].bird.name == "Homebody")
        s.lost = []
        s.rehomed = [bird]
        #expect(Self.apply(.rename(bird.id, name: "Gone"), &s, &rng) == [.rejected(.noSuchBird)])
    }

    // MARK: - Suggestions

    @Test func suggestionsNeverGiveAwayAChicksSex() {
        var (s, _) = Self.game()
        let chick = s.brooder[0]
        #expect(!chick.revealed)
        #expect(NameBook.neutral.contains(NameBook.suggestion(for: chick, in: s)))
        var grown = chick
        grown.revealed = true
        let list = grown.sex == .hen ? NameBook.hens : NameBook.roosters
        #expect(list.contains(NameBook.suggestion(for: grown, in: s)))
        s.brooder[0] = grown
        _ = s
    }

    @Test func suggestionsAreStableAndAvoidTakenNames() {
        var (s, rng) = Self.game()
        s.coins = 1000
        s.perches = 40
        var names: Set<String> = []
        for _ in 0..<30 {
            _ = Self.apply(.buy(.pullet), &s, &rng)
            let bird = s.coop.last!
            let suggestion = NameBook.suggestion(for: bird, in: s)
            #expect(suggestion == NameBook.suggestion(for: bird, in: s))
            #expect(Self.apply(.rename(bird.id, name: suggestion), &s, &rng) == [.renamed(bird.id)])
            #expect(names.insert(suggestion).inserted)
        }
        #expect(names.count == 30)
    }

    @Test func aRehomedBirdsNameIsNotSuggestedAgain() {
        var (s, rng) = Self.game()
        s.coins = 1000
        s.perches = 40
        _ = Self.apply(.buy(.pullet), &s, &rng)
        let new = s.coop.last!
        let name = NameBook.suggestion(for: new, in: s)
        // Another bird had that name, and went to a new home.
        _ = Self.apply(.buy(.pullet), &s, &rng)
        let gone = s.coop.last!
        #expect(Self.apply(.rename(gone.id, name: name), &s, &rng) == [.renamed(gone.id)])
        _ = Self.apply(.rehome(gone.id), &s, &rng)
        #expect(s.rehomed.contains { $0.id == gone.id })
        #expect(NameBook.suggestion(for: new, in: s) != name)
        // The player may still choose the old name by hand.
        #expect(Self.apply(.rename(new.id, name: name), &s, &rng) == [.renamed(new.id)])
    }

    @Test func tryAnotherStepsThroughFreeNames() {
        var (s, rng) = Self.game()
        s.coins = 100
        _ = Self.apply(.buy(.pullet), &s, &rng)
        let bird = s.coop.last!
        let list = bird.sex == .hen ? NameBook.hens : NameBook.roosters
        let picks = (0..<10).map { NameBook.suggestion(for: bird, in: s, skipping: $0) }
        #expect(Set(picks).count == 10 && picks.allSatisfy(list.contains))
        #expect(picks[0] == NameBook.suggestion(for: bird, in: s))
    }

    @Test func whenEveryNameIsUsedSuggestionsGoOnWithNumbers() {
        var (s, rng) = Self.game()
        s.coins = 100
        _ = Self.apply(.buy(.pullet), &s, &rng)
        let bird = s.coop.last!
        let list = bird.sex == .hen ? NameBook.hens : NameBook.roosters
        s.rehomed = list.map { name in
            Bird(
                id: makeID(using: &rng), name: name, breed: bird.breed, genome: bird.genome, hatchDay: 0,
                origin: "t", revealed: true)
        }
        let suggestion = NameBook.suggestion(for: bird, in: s)
        #expect(suggestion.hasSuffix(" 2") && list.contains(String(suggestion.dropLast(2))))
    }

    @Test func nameListsAreLongAndDistinct() {
        let all = NameBook.neutral + NameBook.hens + NameBook.roosters
        #expect(Set(all.map(NameBook.key)).count == all.count)
        #expect([NameBook.neutral, NameBook.hens, NameBook.roosters].allSatisfy { $0.count >= 120 })
        #expect(all.allSatisfy { $0.count <= NameBook.maxLength })
    }
}
