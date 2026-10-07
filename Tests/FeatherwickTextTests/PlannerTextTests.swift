import Foundation
import Testing

@testable import FeatherwickCore
@testable import FeatherwickText

/// The words for "What might hatch" and the carrier notes. Rule 8: they say no more than their enums,
/// name only birds the keeper has, and never give a sex that does not show yet.
@Suite struct PlannerTextTests {
    static let sexWords = ["she", "he", "her", "him", "his", "pullet", "cockerel", "hen", "rooster", "daughter", "son"]

    static func words(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
    }

    /// A keeper with a lavender hen (Clover), a blue rooster (Bramble), and their chick Moss, whose
    /// sex does not show yet. Moss is black, so Moss surely carries Clover's lavender.
    static func flock() -> (GameState, hen: UUID, rooster: UUID, chick: UUID) {
        var rng = SeededRNG(seed: 4)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Juniper"), to: &s, using: &rng)
        var henGenes = Breed.orpington.purebred(.hen)
        henGenes.lavender = .homozygous(.lavender)
        var roosterGenes = Breed.orpington.purebred(.rooster)
        roosterGenes.blue = AllelePair(.blue, .notBlue)
        let hen = Bird(
            id: UUID(), name: "Clover", breed: .orpington, genome: henGenes, hatchDay: s.day - s.rules.adultAge,
            origin: "Speckle & Down", revealed: true)
        let rooster = Bird(
            id: UUID(), name: "Bramble", breed: .orpington, genome: roosterGenes,
            hatchDay: s.day - s.rules.adultAge, origin: "Neighbour", revealed: true)
        var chickGenes = Breed.orpington.purebred(.rooster)
        chickGenes.lavender = AllelePair(.normal, .lavender)
        let chick = Bird(
            id: UUID(), name: "Moss", breed: .orpington, genome: chickGenes, hatchDay: s.day,
            motherID: hen.id, fatherID: rooster.id, origin: Bird.homeOrigin)
        s.coop += [hen, rooster]
        s.brooder.append(chick)
        s.plannerKnown = true
        return (s, hen.id, rooster.id, chick.id)
    }

    @Test func eachLineReadsPlainly() {
        let (s, hen, rooster, _) = Self.flock()
        let blue = Reason.look(bird: rooster, locus: BlueDilution.locus)
        let cases: [(Forecast, String)] = [
            (.notPossible(.barred, .look(bird: hen, locus: Barring.locus)), "No barred chicks from this pair."),
            (
                .possible(.colour(.lavender), .unknownFamily(locus: Lavender.locus)),
                "If one of them is hiding lavender, you'll find out."
            ),
            (
                .unknownUnderWhite(.white(bird: hen)),
                "White hides what's underneath. Anything either of them carries could show."
            ),
            (
                .sexLink(barredAre: .rooster, .look(bird: hen, locus: Barring.locus)),
                "Every barred chick will be a cockerel, every plain one a pullet."
            ),
            (
                .eggColours([.blue, .green], sure: true, .look(bird: hen, locus: BlueShell.locus)),
                "Hens from this pair will lay blue or green eggs."
            ),
            (
                .eggColours([.cream, .brown], sure: false, .unknownFamily(locus: BlueShell.locus)),
                "Hens from this pair will lay cream or brown eggs, unless one of them carries blue."
            ),
            (
                .likely(.eggColour(.blue), .manyChicks(bird: hen, count: 6, locus: BlueShell.locus)),
                "Likely no blue eggs."
            ),
            (
                .typeOutlook(.good, .good, .grades(hen: hen, rooster: rooster)),
                "Both judged good for type. Chicks should carry it."
            ),
            (.kinship(.halfSiblings, .family(hen: hen, rooster: rooster)), "They are related like half-siblings."),
            (.kinship(.unrelated, .family(hen: hen, rooster: rooster)), "They are not related."),
            (.certain(.colour(.blue), blue), "Every chick will be blue."),
            (.ratio(.barred, numerator: 1, denominator: 2, blue), "About 1 in 2 chicks will be barred."),
        ]
        for (line, words) in cases { #expect(plannerText(line, s) == words) }
    }

    @Test func ratiosForOneColourJoinInOneSentence() {
        let (s, _, rooster, _) = Self.flock()
        let why = Reason.look(bird: rooster, locus: BlueDilution.locus)
        let lines: [Forecast] = [
            .ratio(.colour(.black), numerator: 1, denominator: 4, why),
            .ratio(.colour(.blue), numerator: 2, denominator: 4, why),
            .ratio(.colour(.splash), numerator: 1, denominator: 4, why),
            .notPossible(.barred, why),
        ]
        let sentences = plannerSentences(lines, s)
        #expect(sentences.count == 2)
        #expect(sentences.first?.text == "About 1 in 4 black, 2 in 4 blue, 1 in 4 splash.")
        #expect(sentences.first?.reasons == ["Bramble is blue. Blue birds always carry one of each."])
        #expect(pairLines(lines, s).first?.hasSuffix("(Bramble is blue. Blue birds always carry one of each.)") == true)
    }

    @Test func reasonsSayWhatTheKeeperSaw() {
        let (s, hen, rooster, chick) = Self.flock()
        #expect(
            plannerReasonText(.manyChicks(bird: hen, count: 6, locus: BlueShell.locus), s)
                == "Clover has had 6 daughters and none laid blue.")
        #expect(plannerReasonText(.white(bird: hen), s) == "Clover is white, and white hides what's underneath.")
        #expect(
            plannerReasonText(.breed(bird: hen, .orpington), s) == "Clover came from Speckle & Down as an Orpington.")
        #expect(
            plannerReasonText(.unknownFamily(locus: Lavender.locus), s)
                == "No one in their family has shown lavender yet.")
        #expect(
            plannerReasonText(.parent(bird: chick, parent: hen, locus: Lavender.locus), s)
                == "Moss's mother, Clover, is lavender.")
        #expect(plannerReasonText(.look(bird: hen, locus: Lavender.locus), s).hasPrefix("Clover is lavender."))
        #expect(plannerReasonText(.chick(bird: rooster, chick: chick, locus: Lavender.locus), s).contains("Moss"))
    }

    /// Every reason renders, with no percentage, no decimal, and no number but the counts it was given.
    /// A bird the keeper never had is "a bird", never a name.
    @Test func everyReasonRendersAndNamesOnlyKnownBirds() {
        let (s, hen, rooster, chick) = Self.flock()
        let stranger = UUID()
        let known = ["Clover", "Bramble", "Moss", "Juniper"]
        for bird in [hen, rooster, chick, stranger] {
            for locus in Loci.mendelian.map(\.id) {
                let reasons: [Reason] = [
                    .look(bird: bird, locus: locus), .breed(bird: bird, .silkie),
                    .parent(bird: bird, parent: stranger, locus: locus),
                    .parent(bird: chick, parent: bird, locus: locus),
                    .chick(bird: bird, chick: stranger, locus: locus), .chick(bird: hen, chick: bird, locus: locus),
                    .unknownFamily(locus: locus), .manyChicks(bird: bird, count: 6, locus: locus),
                    .grades(hen: bird, rooster: rooster), .family(hen: hen, rooster: bird), .white(bird: bird),
                ]
                for r in reasons {
                    let text = plannerReasonText(r, s)
                    #expect(!text.isEmpty)
                    #expect(!text.contains("%") && !text.contains(stranger.uuidString))
                    let digits = text.split(whereSeparator: { !$0.isNumber }).map(String.init)
                    #expect(digits.allSatisfy { $0 == "6" }, "\(text)")
                    if bird == stranger, case .white = r { #expect(text.hasPrefix("A bird")) }
                    let named = known.filter { text.contains($0) }
                    let allowed = [bird, hen, rooster, chick].compactMap { s.bird($0)?.name }
                    #expect(named.allSatisfy(allowed.contains), "\(text)")
                }
            }
        }
    }

    @Test func noPlannerLineHasAPercentOrADecimal() {
        let (s, hen, rooster, _) = Self.flock()
        let why = Reason.look(bird: hen, locus: Lavender.locus)
        let traits: [FeatherwickCore.Trait] =
            FeatherColour.allCases.map { .colour($0) } + [.barred, .laced, .silkieFeathered, .speckledEggs]
            + EggColour.allCases.map { .eggColour($0) }
        var lines: [Forecast] = [
            .unknownUnderWhite(why), .sexLink(barredAre: .hen, why), .kinship(.close, why),
            .typeOutlook(.fair, .excellent, .grades(hen: hen, rooster: rooster)),
            .eggColours([.cream], sure: false, why),
        ]
        for t in traits {
            lines += [
                .certain(t, why), .ratio(t, numerator: 3, denominator: 4, why), .likely(t, why),
                .likely(t, .manyChicks(bird: hen, count: 3, locus: Lavender.locus)), .possible(t, why),
                .possible(t, .unknownFamily(locus: Lavender.locus)), .notPossible(t, why),
            ]
        }
        for line in lines {
            let text = plannerText(line, s)
            #expect(!text.isEmpty && text.hasSuffix("."))
            #expect(!text.contains("%"))
            let digits = text.split(whereSeparator: { !$0.isNumber }).map(String.init)
            #expect(digits.allSatisfy { ["3", "4"].contains($0) }, "\(text)")
        }
    }

    @Test func everyHiddenAlleleHasACarrierNote() {
        let (s, _, _, chick) = Self.flock()
        let evidence: [Evidence] = [
            .look, .origin(.orpington), .outsideFlock, .parent(UUID()), .parents(UUID(), UUID()), .child(UUID()),
            .family,
        ]
        for locus in Loci.mendelian {
            for allele in locus.alleles {
                for copies in [1, 2] {
                    for e in evidence {
                        let p = ProvenAllele(
                            locus: locus.id, allele: allele, copies: copies, isDefault: allele == locus.defaultAllele,
                            evidence: e)
                        let text = carrierText(p)
                        #expect(text.hasPrefix("Carries ") && !text.hasSuffix("does not show"), "\(locus.id) \(allele)")
                        let reason = carrierReasonText(p, bird: chick, s)
                        #expect(!reason.isEmpty)
                        // Moss's sex does not show yet: no word may give it.
                        for w in Self.words(text) + Self.words(reason) {
                            #expect(!Self.sexWords.contains(w), "\(text) \(reason)")
                        }
                    }
                }
            }
        }
        let lavender = ProvenAllele(locus: Lavender.locus, allele: "lav", copies: 1, isDefault: false, evidence: .look)
        #expect(carrierText(lavender) == "Carries lavender")
        let barring = ProvenAllele(locus: Barring.locus, allele: "B", copies: 1, isDefault: false, evidence: .look)
        #expect(carrierText(barring) == "Carries barring")
    }

    /// The family tree shows each bird's carrier notes in a few words, rehomed birds too, and none
    /// before the keeper knows the planner.
    @Test func theFamilyTreeShowsCarrierNotes() {
        var (s, hen, _, chick) = Self.flock()
        #expect(carrierShortText([]) == nil)
        let root = treeLines(chick, s).first ?? ""
        #expect(root.hasPrefix("Moss") && root.contains(" · carries lavender"), "\(root)")
        #expect(treeEntries(chick, s).first?.carries?.hasPrefix("carries lavender") == true)
        // Clover shows her lavender, so her line in Moss's tree carries no note for it.
        #expect(treeLines(chick, s).first { $0.contains("Mother: Clover") }?.contains("carries lavender") == false)
        // A rehomed bird keeps its notes in the tree.
        let moss = s.brooder.removeFirst()
        s.rehomed.append(moss)
        #expect(treeLines(chick, s).first?.contains("carries lavender") == true)
        #expect(treeLines(hen, s).isEmpty == false)
        s.plannerKnown = false
        #expect(treeEntries(chick, s).allSatisfy { $0.carries == nil })
        #expect(!treeLines(chick, s).contains { $0.contains("carries") })
    }

    /// "They" is only the pair the line is about. Any other pair is named.
    @Test func theyMeansThePairShown() {
        var (s, hen, rooster, _) = Self.flock()
        var lavender = Breed.orpington.purebred(.hen)
        lavender.lavender = .homozygous(.lavender)
        let fern = Bird(
            id: UUID(), name: "Fern", breed: .orpington, genome: lavender, hatchDay: s.day, motherID: hen,
            fatherID: rooster, origin: Bird.homeOrigin)
        s.brooder.append(fern)
        let other = UUID()
        let why = Reason.chick(bird: hen, chick: fern.id, locus: Lavender.locus)
        #expect(plannerReasonText(why, s, pair: (hen, rooster)) == "They had a lavender chick, Fern.")
        #expect(plannerReasonText(why, s, pair: (hen, other)) == "Clover and Bramble had a lavender chick, Fern.")
        #expect(plannerReasonText(why, s) == "Clover and Bramble had a lavender chick, Fern.")
        let lines = pairLines([.possible(.colour(.lavender), why)], s, pair: (hen, rooster))
        #expect(lines.first?.hasSuffix("(They had a lavender chick, Fern.)") == true, "\(lines)")
    }

    /// An unrevealed chick with a proven hidden allele: a note and a reason, and no sexed word.
    @Test func anUnrevealedChickGetsASexlessCarrierNote() {
        let (s, _, _, chick) = Self.flock()
        #expect(s.bird(chick)?.revealed == false)
        let lines = carrierLines(chick, s)
        #expect(lines.contains("Carries lavender. It came from Moss's mother, Clover."), "\(lines)")
        for line in lines {
            for w in Self.words(line) { #expect(!Self.sexWords.contains(w), "\(line)") }
        }
        var before = s
        before.plannerKnown = false
        #expect(carrierLines(chick, before).isEmpty)
    }

    @Test func thePanelAndTheNotice() {
        var (s, _, rooster, _) = Self.flock()
        #expect(plannerPanelText(.hidden, s) == nil)
        #expect(plannerPanelText(.needsHen, s) == "Pen a hen to see what might hatch.")
        #expect(plannerPanelText(.needsRooster, s) == "Pen a rooster to see what might hatch.")
        #expect(plannerPanelText(.forecast(rooster: rooster, []), s) == "What might hatch")
        #expect(plannerNoticeText(s) != nil)
        s.plannerOpened = true
        #expect(plannerNoticeText(s) == nil)
        s.plannerKnown = false
        s.plannerOpened = false
        #expect(plannerNoticeText(s) == nil)
        #expect(plannerLines(s) == [plannerNotYetText(s)])
        #expect(eventText(.plannerIntroduced, s)?.contains("You can work this out ahead of time, you know.") == true)
    }
}
