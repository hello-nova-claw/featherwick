import Foundation
import Testing

@testable import FeatherwickCore

/// "Hen or roo?" (SexGuess.swift): one free guess per young chick, settled the morning its sex shows.
struct SexGuessTests {
    /// A started game on day 1 with the starter Pip (hatched day 0) of the given sex in the brooder.
    static func game(_ sex: Sex = .hen, seed: UInt64 = 1) -> (GameState, SeededRNG, UUID) {
        let (s, rng) = startedGame(sex: sex, rules: calmRules(), seed: seed)
        return (s, rng, s.brooder[0].id)
    }

    /// A chick of a known sex, hatched on `hatchDay`, added to the brooder. Its sex does not show yet.
    static func addChick(_ sex: Sex, hatchDay: Int, _ s: inout GameState, _ rng: inout SeededRNG) -> UUID {
        let chick = Bird(
            id: makeID(using: &rng), name: "Chick \(s.brooder.count + 1)", breed: .orpington,
            genome: Breed.orpington.purebred(sex), hatchDay: hatchDay, origin: "Test")
        s.brooder.append(chick)
        return chick.id
    }

    static func refusals(_ ev: [GameEvent]) -> [Rejection] {
        ev.compactMap { if case .rejected(let r) = $0 { r } else { nil } }
    }

    static func resolutions(_ ev: [GameEvent]) -> [GameEvent] {
        ev.filter { if case .sexGuessResolved = $0 { true } else { false } }
    }

    /// Nights until the given day. Returns each night's events.
    static func nights(until day: Int, _ s: inout GameState, _ rng: inout SeededRNG) -> [[GameEvent]] {
        var all: [[GameEvent]] = []
        while s.day < day { all.append(night(&s, &rng)) }
        return all
    }

    // MARK: - Guessing

    @Test func aYoungChickCanBeGuessedOnceAndAGrownBirdCannot() {
        var (s, rng, pip) = Self.game()
        #expect(Engine.sexGuessRefusal(pip, in: s) == nil)
        #expect(Engine.apply(.guessSex(pip, .hen), to: &s, using: &rng) == [.sexGuessed(pip, .hen)])
        #expect(s.sexGuesses[pip] == .hen)

        // One guess per chick: a second one, either way, is refused and changes nothing.
        let before = s
        #expect(Engine.apply(.guessSex(pip, .rooster), to: &s, using: &rng) == [.rejected(.alreadyGuessed)])
        #expect(Engine.apply(.guessSex(pip, .hen), to: &s, using: &rng) == [.rejected(.alreadyGuessed)])
        #expect(s == before)

        // A chick that has reached `growerAge` is past guessing, even before the night reveals it.
        let old = Self.addChick(.hen, hatchDay: s.day - s.rules.growerAge, &s, &rng)
        #expect(Engine.apply(.guessSex(old, .hen), to: &s, using: &rng) == [.rejected(.tooLateToGuess)])
        // A grown bird whose sex shows already is too.
        let hen = adult(.wyandotte, .hen, day: s.day, rules: s.rules, rng: &rng)
        s.coop.append(hen)
        #expect(Engine.apply(.guessSex(hen.id, .rooster), to: &s, using: &rng) == [.rejected(.tooLateToGuess)])
        // An unknown bird.
        #expect(Engine.apply(.guessSex(UUID(), .hen), to: &s, using: &rng) == [.rejected(.noSuchBird)])
    }

    /// Rule 8: the refusals hang on age and the guess only. A hen and a rooster chick of the same age
    /// get the same answers, whatever the guess.
    @Test func theRefusalsNeverDependOnSex() {
        var (s, rng, _) = Self.game()
        for age in [0, s.rules.growerAge - 1, s.rules.growerAge, s.rules.growerAge + 3] {
            let hen = Self.addChick(.hen, hatchDay: s.day - age, &s, &rng)
            let roo = Self.addChick(.rooster, hatchDay: s.day - age, &s, &rng)
            for guess in Sex.allCases {
                #expect(Engine.sexGuessRefusal(hen, in: s) == Engine.sexGuessRefusal(roo, in: s))
                var a = s
                var b = s
                let ea = Engine.apply(.guessSex(hen, guess), to: &a, using: &rng)
                let eb = Engine.apply(.guessSex(roo, guess), to: &b, using: &rng)
                #expect(Self.refusals(ea) == Self.refusals(eb))
            }
            #expect((Engine.sexGuessRefusal(hen, in: s) == nil) == (age < s.rules.growerAge))
        }
    }

    @Test func aGuessCostsNoDaylightAndWorksAtDusk() {
        var (s, rng, pip) = Self.game()
        #expect(s.isOpen(.daylight))
        #expect(Engine.errand(for: .guessSex(pip, .hen)) == nil)
        Engine.restUntilEvening(&s, using: &rng)
        #expect(s.slotsLeft == 0)
        let used = s.slotsUsed
        #expect(Engine.daylightRefusal(for: .guessSex(pip, .hen), in: s) == nil)
        #expect(Engine.apply(.guessSex(pip, .hen), to: &s, using: &rng) == [.sexGuessed(pip, .hen)])
        #expect(s.slotsUsed == used)
    }

    /// The guess draws nothing from the game's RNG, so a seed plays the same with or without one.
    @Test func aGuessLeavesTheSeededGameAsItWas() {
        var (plain, plainRNG, _) = Self.game(seed: 7)
        var (guessed, guessedRNG, pip) = Self.game(seed: 7)
        let rngBefore = guessedRNG
        _ = Engine.apply(.guessSex(pip, .rooster), to: &guessed, using: &guessedRNG)
        #expect(guessedRNG == rngBefore)
        _ = Self.nights(until: 20, &plain, &plainRNG)
        _ = Self.nights(until: 20, &guessed, &guessedRNG)
        #expect(plainRNG == guessedRNG)
        #expect(plain.ownedBirds.map(\.id) == guessed.ownedBirds.map(\.id))
        #expect(plain.nest.map(\.id) == guessed.nest.map(\.id))
    }

    // MARK: - The morning the sex shows

    @Test func aRightGuessPaysAMealwormOnTheMorningTheSexShows() {
        var (s, rng, pip) = Self.game(.hen)
        _ = Engine.apply(.guessSex(pip, .hen), to: &s, using: &rng)
        let treats = s.treats
        let early = Self.nights(until: s.rules.growerAge - 1, &s, &rng)
        #expect(early.allSatisfy { Self.resolutions($0).isEmpty })
        #expect(s.sexGuesses[pip] == .hen && s.treats == treats)

        let ev = night(&s, &rng)
        #expect(s.day == s.rules.growerAge)
        #expect(Self.resolutions(ev) == [.sexGuessResolved(pip, guessed: .hen, actual: .hen)])
        // Right after the reveal, so the words follow it.
        let reveal = ev.firstIndex { if case .revealed(pip, _, _) = $0 { true } else { false } }
        let resolved = ev.firstIndex { if case .sexGuessResolved = $0 { true } else { false } }
        #expect(reveal != nil && resolved != nil && reveal! < resolved!)
        #expect(s.treats == treats + s.rules.sexGuessTreats)
        #expect(s.sexGuesses.isEmpty)
        #expect(s.sexGuessesRight == 1)
        // Once settled, there is nothing more to guess.
        #expect(Engine.apply(.guessSex(pip, .hen), to: &s, using: &rng) == [.rejected(.tooLateToGuess)])
    }

    @Test func aWrongGuessCostsNothing() {
        var (s, rng, pip) = Self.game(.rooster)
        _ = Engine.apply(.guessSex(pip, .hen), to: &s, using: &rng)
        let coins = s.coins
        _ = Self.nights(until: s.rules.growerAge - 1, &s, &rng)
        let treats = s.treats
        let ev = night(&s, &rng)
        #expect(Self.resolutions(ev) == [.sexGuessResolved(pip, guessed: .hen, actual: .rooster)])
        #expect(s.treats == treats)
        #expect(s.coins >= coins)
        #expect(s.sexGuesses.isEmpty)
        #expect(s.sexGuessesRight == 0)
        #expect(!ev.contains(.milestoneReached("henOrRoo")))
    }

    @Test func aChickThatLeavesTakesItsGuessWithItSilently() {
        var (s, rng, pip) = Self.game()
        let other = Self.addChick(.hen, hatchDay: 0, &s, &rng)
        _ = Engine.apply(.guessSex(pip, .hen), to: &s, using: &rng)
        _ = Engine.apply(.guessSex(other, .hen), to: &s, using: &rng)
        #expect(s.sexGuesses.count == 2)

        let ev = Engine.apply(.rehome(other), to: &s, using: &rng)
        #expect(ev.contains { if case .rehomed(other, _) = $0 { true } else { false } })
        #expect(s.sexGuesses[other] == nil && s.sexGuesses[pip] == .hen)

        let all = Self.nights(until: s.rules.growerAge + 2, &s, &rng).flatMap { $0 }
        #expect(Self.resolutions(all) == [.sexGuessResolved(pip, guessed: .hen, actual: .hen)])
        #expect(s.sexGuesses.isEmpty)
    }

    @Test func theMilestoneComesOnceForTheFirstRightGuess() {
        var (s, rng, pip) = Self.game(.hen)
        let second = Self.addChick(.hen, hatchDay: 0, &s, &rng)
        let later = Self.addChick(.rooster, hatchDay: 3, &s, &rng)
        for id in [pip, second] { _ = Engine.apply(.guessSex(id, .hen), to: &s, using: &rng) }
        _ = Engine.apply(.guessSex(later, .rooster), to: &s, using: &rng)
        #expect(!s.milestonesReached.contains("henOrRoo"))
        let all = Self.nights(until: 14, &s, &rng).flatMap { $0 }
        #expect(Self.resolutions(all).count == 3)
        #expect(s.sexGuessesRight == 3)
        #expect(all.count(where: { $0 == .milestoneReached("henOrRoo") }) == 1)
        #expect(s.milestonesReached.contains("henOrRoo"))
        // Appended after the milestones that came before it, so old saves keep their ladder order.
        let ids = Milestones.all.map(\.id)
        #expect(ids.firstIndex(of: "henOrRoo")! > ids.firstIndex(of: "greenEgg")!)
    }

    @Test func theResolutionSitsWithTheGrowingNews() {
        let id = UUID()
        #expect(
            MorningReport.group(of: .sexGuessResolved(id, guessed: .hen, actual: .rooster))
                == MorningReport.group(of: .revealed(id, sex: .hen, breed: .orpington)))
    }

    // MARK: - Saves

    @Test func anOldSaveLoadsWithNoGuesses() throws {
        let s = try SaveFormat.decode(SaveFormatTests.fixture("save-v0")).state
        #expect(s.sexGuesses.isEmpty)
        #expect(s.sexGuessesRight == 0)
        #expect(s.rules.sexGuessTreats == 1)
    }

    @Test func aSaveKeepsTheGuess() throws {
        var (s, rng, pip) = Self.game()
        _ = Engine.apply(.guessSex(pip, .rooster), to: &s, using: &rng)
        let loaded = try SaveFormat.decode(SaveFormat.encode(SaveGame(state: s, rng: rng))).state
        #expect(loaded.sexGuesses == [pip: .rooster])
    }
}
