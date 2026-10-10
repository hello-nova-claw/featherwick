import Foundation
import Testing

@testable import FeatherwickCore

// MARK: - Unlock

/// "What might hatch" opens with the first hatch-day why note (or the breeding pen), and the pen's notice
/// waits for the first look.
extension PlannerTests {
    /// Two black parents in the coop, both carrying lavender, set to hatch `chicks` tonight.
    static func pairReadyToHatch(_ chicks: [Genome], plannerKnown: Bool = false) -> (GameState, SeededRNG) {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        // No pen yet: the pen opens the planner too (see `thePenOpensThePlanner`).
        s.introduced.remove(.breedingPen)
        s.plannerKnown = plannerKnown
        let hen = HatchWhyTests.parent(HatchWhyTests.genome(.hen, HatchWhyTests.lavCarrier), s, &rng)
        let rooster = HatchWhyTests.parent(HatchWhyTests.genome(.rooster, HatchWhyTests.lavCarrier), s, &rng)
        s.coop += [hen, rooster]
        let eggs = chicks.map { embryo in
            var e = Egg(
                id: makeID(using: &rng), layDay: s.day, motherID: hen.id, colour: .brown, speckled: false,
                collectedDay: s.day, motherBreed: .orpington)
            e.fatherID = rooster.id
            e.embryo = embryo
            return e
        }
        s.clutches.append(Clutch(henID: nil, eggs: eggs, hatchDay: s.day + 1))
        return (s, rng)
    }

    static let lavenderChick = HatchWhyTests.genome(.hen) { $0.lavender = .homozygous(.lavender) }

    static func introductions(_ ev: [GameEvent]) -> Int { ev.count { $0 == .plannerIntroduced } }

    @Test func theFirstWhyNoteOpensThePlannerOnce() {
        var (s, rng) = Self.pairReadyToHatch([Self.lavenderChick])
        #expect(!s.plannerKnown && !s.plannerOpened)
        #expect(Planner.panel(in: s) == .hidden)
        let ev = night(&s, &rng)
        #expect(s.plannerKnown)
        #expect(Self.introductions(ev) == 1)
        // Right after the why note it belongs to.
        let note = ev.firstIndex { if case .hatchSurprise = $0 { true } else { false } }
        let intro = ev.firstIndex(of: .plannerIntroduced)
        #expect(note != nil && intro == note.map { $0 + 1 })
        // A later why note does not introduce it again.
        let hen = s.coop.first { $0.name == "Parent" && $0.sex == .hen }!
        let rooster = s.coop.first { $0.name == "Parent" && $0.sex == .rooster }!
        var e = Egg(
            id: makeID(using: &rng), layDay: s.day, motherID: hen.id, colour: .brown, speckled: false,
            collectedDay: s.day, motherBreed: .orpington)
        e.fatherID = rooster.id
        e.embryo = Self.lavenderChick
        s.clutches.append(Clutch(henID: nil, eggs: [e], hatchDay: s.day + 1))
        let again = night(&s, &rng)
        #expect(again.contains { if case .hatchSurprise = $0 { true } else { false } })
        #expect(Self.introductions(again) == 0)
    }

    @Test func aChickLikeItsParentsOpensNothing() {
        var (s, rng) = Self.pairReadyToHatch([HatchWhyTests.genome(.hen)])
        let ev = night(&s, &rng)
        #expect(ev.contains { if case .chicksHatched = $0 { true } else { false } })
        #expect(!s.plannerKnown)
        #expect(Self.introductions(ev) == 0)
    }

    /// The unlock makes no random draw: the same seed hatches the same chicks and leaves the same RNG.
    @Test func theUnlockChangesNoDraws() {
        var (a, rngA) = Self.pairReadyToHatch([Self.lavenderChick, HatchWhyTests.genome(.rooster)])
        var (b, rngB) = Self.pairReadyToHatch([Self.lavenderChick, HatchWhyTests.genome(.rooster)], plannerKnown: true)
        let evA = night(&a, &rngA)
        let evB = night(&b, &rngB)
        #expect(rngA == rngB)
        #expect(evA.filter { $0 != .plannerIntroduced } == evB)
        a.plannerKnown = true
        #expect(a == b)
    }

    @Test func openingThePlannerClearsTheNotice() {
        var (s, rng) = startedGame(sex: .hen)
        s.plannerKnown = false  // as before the pen or a surprise chick
        let slots = s.slotsUsed
        // Before the keeper has met it, there is nothing to open.
        #expect(Engine.apply(.openPlanner, to: &s, using: &rng).isEmpty)
        #expect(!s.plannerOpened)
        s.plannerKnown = true
        #expect(Engine.apply(.openPlanner, to: &s, using: &rng).isEmpty)
        #expect(s.plannerOpened)
        #expect(s.slotsUsed == slots)  // no daylight
        #expect(Engine.errand(for: .openPlanner) == nil)
    }

    /// A keeper with no surprise chick meets the planner when the breeding pen opens. A game already past
    /// the pen's day meets it the next night. Once a game.
    @Test func thePenOpensThePlanner() {
        var (s, rng) = EarlyGameTests.newKeeper()
        let pen = s.introductionDay(of: .breedingPen)
        var ev = EarlyGameTests.play(until: pen - 1, &s, &rng)
        #expect(!s.plannerKnown)
        ev = EarlyGameTests.play(until: pen, &s, &rng)
        #expect(s.isOpen(.breedingPen) && s.plannerKnown)
        #expect(ev.count { $0 == .plannerShownAtPen } == 1)
        #expect(EarlyGameTests.play(until: pen + 3, &s, &rng).count { $0 == .plannerShownAtPen } == 0)
        // A save past the pen's day that never met the planner.
        s.plannerKnown = false
        #expect(EarlyGameTests.play(until: s.day + 1, &s, &rng).contains(.plannerShownAtPen))
        #expect(s.plannerKnown)
        #expect(MorningReport.group(of: .plannerShownAtPen) == .neighbour)
    }

    @Test func anOldSaveHasNotMetThePlanner() throws {
        let game = try SaveFormat.decode(SaveFormatTests.fixture("save-v0"))
        #expect(!game.state.plannerKnown)
        #expect(!game.state.plannerOpened)
    }

    @Test func theIntroductionIsInTheHatchedGroup() {
        let (s, _) = startedGame(sex: .hen)
        #expect(MorningReport.group(of: .plannerIntroduced) == .hatched)
        let report = MorningReport.from(events: [.plannerIntroduced], state: s)
        #expect(report.events(in: .hatched) == [.plannerIntroduced])
    }
}
