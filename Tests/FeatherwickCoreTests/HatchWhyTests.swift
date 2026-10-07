import Foundation
import Testing

@testable import FeatherwickCore

/// The hatch-day "why" note: a chick that looks like neither parent gets one line from the neighbour.
struct HatchWhyTests {
    /// A black Orpington genome, changed by `edit`.
    static func genome(_ sex: Sex, _ edit: (inout Genome) -> Void = { _ in }) -> Genome {
        var g = Breed.orpington.purebred(sex)
        edit(&g)
        return g
    }

    static func parent(_ genome: Genome, _ s: GameState, _ rng: inout SeededRNG) -> Bird {
        Bird(
            id: makeID(using: &rng), name: "Parent", breed: .orpington, genome: genome,
            hatchDay: s.day - s.rules.adultAge, origin: "Test", revealed: true)
    }

    /// Puts both parents in the coop and hatches the given chick genomes tonight, as one clutch.
    /// Returns the night's events.
    static func hatch(
        mother: Genome, father: Genome, chicks: [Genome], keepParents: Bool = true
    ) -> [GameEvent] {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        let hen = parent(mother, s, &rng)
        let rooster = parent(father, s, &rng)
        if keepParents { s.coop += [hen, rooster] }
        let eggs = chicks.map { embryo in
            var e = Egg(
                id: makeID(using: &rng), layDay: s.day, motherID: hen.id, colour: .brown, speckled: false,
                collectedDay: s.day, motherBreed: .orpington)
            e.fatherID = rooster.id
            e.embryo = embryo
            return e
        }
        s.clutches.append(Clutch(henID: nil, eggs: eggs, hatchDay: s.day + 1))
        return night(&s, &rng)
    }

    static func reasons(_ events: [GameEvent]) -> [HatchReason] {
        events.compactMap { if case .hatchSurprise(_, let r) = $0 { r } else { nil } }
    }

    static func lavCarrier(_ g: inout Genome) { g.lavender = AllelePair(.normal, .lavender) }

    @Test func twoBlacksWithHiddenLavenderGiveTheLavenderReason() {
        let ev = Self.hatch(
            mother: Self.genome(.hen, Self.lavCarrier), father: Self.genome(.rooster, Self.lavCarrier),
            chicks: [Self.genome(.hen) { $0.lavender = .homozygous(.lavender) }])
        #expect(Self.reasons(ev) == [.recessiveFromBothParents(Lavender.locus)])
        // The note follows its chicksHatched event.
        let hatched = ev.firstIndex { if case .chicksHatched = $0 { true } else { false } }
        let note = ev.firstIndex { if case .hatchSurprise = $0 { true } else { false } }
        #expect(hatched != nil && note != nil && hatched! < note!)
    }

    @Test func buffFromTwoBlacksIsRecessiveToo() {
        let carrier: (inout Genome) -> Void = { $0.baseColour = AllelePair(.black, .buff) }
        let ev = Self.hatch(
            mother: Self.genome(.hen, carrier), father: Self.genome(.rooster, carrier),
            chicks: [Self.genome(.rooster) { $0.baseColour = .homozygous(.buff) }])
        #expect(Self.reasons(ev) == [.recessiveFromBothParents(BaseColour.locus)])
    }

    @Test func blueSplitsThreeWays() {
        let blue: (inout Genome) -> Void = { $0.blue = AllelePair(.blue, .notBlue) }
        let splash: (inout Genome) -> Void = { $0.blue = .homozygous(.blue) }
        // Blue x blue: a splash chick (and a black one) look like neither parent.
        let ev = Self.hatch(
            mother: Self.genome(.hen, blue), father: Self.genome(.rooster, blue),
            chicks: [Self.genome(.hen, splash)])
        #expect(Self.reasons(ev) == [.blueSplitsThreeWays])
        let black = Self.hatch(
            mother: Self.genome(.hen, blue), father: Self.genome(.rooster, blue), chicks: [Self.genome(.rooster)])
        #expect(Self.reasons(black) == [.blueSplitsThreeWays])
        // Black x splash: every chick is blue.
        let allBlue = Self.hatch(
            mother: Self.genome(.hen), father: Self.genome(.rooster, splash), chicks: [Self.genome(.hen, blue)])
        #expect(Self.reasons(allBlue) == [.blueSplitsThreeWays])
    }

    @Test func whiteHidTheColour() {
        let white: (inout Genome) -> Void = { $0.dominantWhite = AllelePair(.white, .wildType) }
        // White (I/i+) x white: an i+/i+ chick shows the colour both parents hid.
        let black = Self.hatch(
            mother: Self.genome(.hen, white), father: Self.genome(.rooster, white), chicks: [Self.genome(.hen)])
        #expect(Self.reasons(black) == [.whiteHidIt])
        // White wins over the other reasons: lavender from white x black is still "white hid it".
        let lavender = Self.hatch(
            mother: Self.genome(.hen) {
                white(&$0)
                Self.lavCarrier(&$0)
            },
            father: Self.genome(.rooster, Self.lavCarrier),
            chicks: [Self.genome(.rooster) { $0.lavender = .homozygous(.lavender) }])
        #expect(Self.reasons(lavender) == [.whiteHidIt])
    }

    /// Rule 8: a barred hen (Z^B W) and a barred rooster carrying plain (B/b+) hatch plain chicks only
    /// as pullets. Any note would tell the chick's sex before the grower stage, so there is none.
    @Test func twoBarredParentsAndAPlainChickGiveNoNote() {
        let ev = Self.hatch(
            mother: Self.genome(.hen) { $0.sexChromosomes = .hen(z: .barred) },
            father: Self.genome(.rooster) { $0.sexChromosomes = .rooster(z: AllelePair(.barred, .plain)) },
            chicks: [Self.genome(.hen)])
        #expect(Self.reasons(ev).isEmpty)
        #expect(ev.contains { if case .chicksHatched = $0 { true } else { false } })
    }

    @Test func aChickThatLooksLikeAParentGetsNoNote() {
        let blue: (inout Genome) -> Void = { $0.blue = AllelePair(.blue, .notBlue) }
        // Black x blue: black and blue chicks both match a parent.
        let ev = Self.hatch(
            mother: Self.genome(.hen), father: Self.genome(.rooster, blue),
            chicks: [Self.genome(.hen), Self.genome(.rooster, blue)])
        #expect(Self.reasons(ev).isEmpty)
        #expect(ev.contains { if case .chicksHatched(let ids, _) = $0 { ids.count == 2 } else { false } })
    }

    /// Rule 8: the note compares what the keeper can see. Buff and white chicks both have yellow down,
    /// and barred down hides the colour under it, so neither gets a note at hatch.
    @Test func theNoteNeverTellsWhatTheDownHides() {
        let white: (inout Genome) -> Void = { $0.dominantWhite = AllelePair(.white, .wildType) }
        let buffCarrier: (inout Genome) -> Void = {
            white(&$0)
            $0.baseColour = AllelePair(.black, .buff)
        }
        let buff = Self.hatch(
            mother: Self.genome(.hen, buffCarrier), father: Self.genome(.rooster, buffCarrier),
            chicks: [Self.genome(.hen) { $0.baseColour = .homozygous(.buff) }])
        #expect(Self.reasons(buff).isEmpty)

        // A barred lavender chick from a buff barred rooster and a lavender-carrying black hen: its
        // down is barred, so its lavender is not shown yet.
        let barredLav = Self.hatch(
            mother: Self.genome(.hen, Self.lavCarrier),
            father: Self.genome(.rooster) {
                $0.baseColour = .homozygous(.buff)
                $0.lavender = AllelePair(.normal, .lavender)
                $0.sexChromosomes = .rooster(z: .homozygous(.barred))
            },
            chicks: [
                Self.genome(.rooster) {
                    $0.baseColour = AllelePair(.black, .buff)
                    $0.lavender = .homozygous(.lavender)
                    $0.sexChromosomes = .rooster(z: AllelePair(.barred, .plain))
                }
            ])
        #expect(Self.reasons(barredLav).isEmpty)
    }

    @Test func parentsMustBeOwned() {
        let ev = Self.hatch(
            mother: Self.genome(.hen, Self.lavCarrier), father: Self.genome(.rooster, Self.lavCarrier),
            chicks: [Self.genome(.hen) { $0.lavender = .homozygous(.lavender) }], keepParents: false)
        #expect(Self.reasons(ev).isEmpty)
    }

    @Test func atMostOneNoteADay() {
        let lav = Self.genome(.hen) { $0.lavender = .homozygous(.lavender) }
        let ev = Self.hatch(
            mother: Self.genome(.hen, Self.lavCarrier), father: Self.genome(.rooster, Self.lavCarrier),
            chicks: [lav, lav, lav])
        #expect(Rules.standard.hatchWhyNotesPerDay == 1)
        #expect(Self.reasons(ev).count == 1)
    }

    @Test func oldSavesGetTheDailyLimit() throws {
        let old = try SaveFormat.decode(SaveFormatTests.fixture("save-v0")).state
        #expect(old.rules.hatchWhyNotesPerDay == Rules.standard.hatchWhyNotesPerDay)
    }

    /// The note adds no random draws: a seeded game hatches the same chicks with or without it.
    @Test func seedsHatchTheSameChicks() {
        func play(notes: Int) -> (birds: [Bird], events: [GameEvent]) {
            var r = calmRules()
            r.fertileChance = 1
            r.broodyChance = [:]
            r.hatchWhyNotesPerDay = notes
            var (s, rng) = startedGame(sex: .hen, rules: r)
            s.coop += [
                Self.parent(Self.genome(.hen, Self.lavCarrier), s, &rng),
                Self.parent(Self.genome(.hen, Self.lavCarrier), s, &rng),
                Self.parent(Self.genome(.rooster, Self.lavCarrier), s, &rng),
            ]
            s.coins = 200
            var events: [GameEvent] = []
            for _ in 0..<40 {
                for b in s.unnamedBirds {
                    events += Engine.apply(.rename(b.id, name: NameBook.suggestion(for: b, in: s)), to: &s, using: &rng)
                }
                events += Engine.apply(.collectEggs, to: &s, using: &rng)
                if s.hasIncubator, s.incubatorClutch == nil {
                    events += Engine.apply(.incubate(count: 1), to: &s, using: &rng)
                }
                if s.carton.count > 6 { events += Engine.apply(.sellClearEggs, to: &s, using: &rng) }
                if s.coop.count >= s.perches { events += Engine.apply(.upgradeCoop, to: &s, using: &rng) }
                events += night(&s, &rng)
            }
            return (s.ownedBirds + s.rehomed, events)
        }
        let with = play(notes: 1)
        let without = play(notes: 0)
        #expect(!Self.reasons(with.events).isEmpty)
        #expect(Self.reasons(without.events).isEmpty)
        #expect(with.birds == without.birds)
        // The first note also opens "What might hatch" (`PlannerUnlockTests`): no draws either.
        let filtered = with.events.filter {
            if case .hatchSurprise = $0 { false } else { $0 != .plannerIntroduced }
        }
        #expect(filtered == without.events)
    }
}
