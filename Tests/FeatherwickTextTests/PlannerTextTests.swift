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
                "Hens from this pair will lay white, cream or brown eggs, unless one of them carries blue."
            ),
            (
                // Coarse cream holds white: a Leghorn pair lays white, a Silkie pair cream.
                .eggColours([.cream], sure: true, .look(bird: hen, locus: BlueShell.locus)),
                "Hens from this pair will lay white or cream eggs."
            ),
            (
                .certain(.eggColour(.cream), .look(bird: hen, locus: BlueShell.locus)),
                "Every hen from this pair will lay white or cream eggs."
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

    /// The sentences built from parts read the same once each shape is one whole string (#58).
    @Test func joinedFormsReadTheSame() {
        var (s, hen, rooster, chick) = Self.flock()
        let why = Reason.look(bird: rooster, locus: BlueDilution.locus)
        let lavender = Reason.look(bird: hen, locus: Lavender.locus)
        let eggs: [Forecast] = [
            .ratio(.eggColour(.blue), numerator: 1, denominator: 2, why),
            .ratio(.eggColour(.cream), numerator: 1, denominator: 2, lavender),
        ]
        #expect(
            pairLines(eggs, s)
                == [
                    "Hens from this pair: about 1 in 2 blue, 1 in 2 white or cream eggs. "
                        + "(Bramble is blue. Blue birds always carry one of each. "
                        + "Clover is lavender. Lavender birds always pass lavender on.)"
                ])
        #expect(pairLines([], s) == ["Nothing to say about this pair yet."])
        #expect(
            plannerText(.eggColours([.blue, .green, .olive], sure: false, .unknownFamily(locus: Speckle.locus)), s)
                == "Hens from this pair will lay blue, green or olive eggs, unless one of them carries speckles.")
        #expect(
            plannerText(.eggColours([.brown], sure: false, why), s)
                == "Hens from this pair will lay brown eggs, unless one of them is hiding another egg colour.")
        #expect(plannerText(.eggColours([], sure: true, why), s) == "Hens from this pair will lay plain eggs.")
        #expect(plannerText(.likely(.silkieFeathered, why), s) == "Some chicks will likely have silkie feathers.")
        #expect(
            plannerText(.likely(.laced, .manyChicks(bird: hen, count: 3, locus: Lacing.locus)), s)
                == "Likely no laced chicks.")
        #expect(
            plannerText(.possible(.speckledEggs, .unknownFamily(locus: Speckle.locus)), s)
                == "If one of them carries speckled eggs, you'll find out.")
        #expect(
            plannerText(.possible(.silkieFeathered, .unknownFamily(locus: Feathering.locus)), s)
                == "If one of them is hiding silkie feathers, you'll find out.")
        #expect(plannerText(.notPossible(.speckledEggs, why), s) == "No hens from this pair will lay speckled eggs.")
        #expect(
            plannerText(.typeOutlook(.fair, .excellent, .grades(hen: hen, rooster: rooster)), s)
                == "Clover judged fair for type, Bramble excellent. Some chicks should take after the better one.")
        #expect(
            plannerText(.typeOutlook(.poor, .fair, why), s)
                == "The hen judged poor for type, the rooster fair. A partner judged better for type would help.")
        #expect(
            plannerText(.kinship(.close, why), s)
                == "They are closely related (like siblings, or parent and chick).")

        // Counts: one and many.
        #expect(
            plannerReasonText(.manyChicks(bird: hen, count: 1, locus: BlueShell.locus), s)
                == "Clover has had 1 daughter, and she did not lay blue.")
        #expect(
            plannerReasonText(.manyChicks(bird: hen, count: 1, locus: Lavender.locus), s)
                == "Clover has had 1 chick, and it did not show lavender.")
        #expect(
            plannerReasonText(.manyChicks(bird: hen, count: 3, locus: Speckle.locus), s)
                == "Clover has had 3 daughters and none laid speckled eggs.")
        #expect(
            plannerReasonText(.manyChicks(bird: UUID(), count: 3, locus: Barring.locus), s)
                == "A bird has had 3 chicks and none showed barring.")

        // A bird's look, with he, she or a name.
        #expect(
            plannerReasonText(.look(bird: hen, locus: Barring.locus), s)
                == "Clover is not barred, so she has no barring to pass on.")
        #expect(
            plannerReasonText(.look(bird: rooster, locus: DominantWhite.locus), s)
                == "Bramble is not white, so he carries no white.")
        #expect(plannerReasonText(.look(bird: UUID(), locus: Lavender.locus), s) == "A bird's look settles it.")
        #expect(
            plannerReasonText(.breed(bird: rooster, .silkie), s) == "Bramble came from Hazel as a Silkie.")

        // Parents and chicks.
        let stranger = UUID()
        #expect(
            plannerReasonText(.parent(bird: chick, parent: stranger, locus: Lavender.locus), s)
                == "Lavender came down from Moss's parent.")
        #expect(
            plannerReasonText(.parent(bird: stranger, parent: hen, locus: Lavender.locus), s)
                == "A bird's parent, Clover, is lavender.")
        #expect(
            plannerReasonText(.chick(bird: hen, chick: stranger, locus: Lavender.locus), s)
                == "One of Clover's chicks shows that Clover carries lavender.")
        #expect(
            plannerReasonText(.chick(bird: hen, chick: chick, locus: Lavender.locus), s)
                == "Clover's chick, Moss, shows that Clover carries lavender.")

        // Carrier notes: a short list, and each kind of proof.
        func note(_ locus: LocusID, _ allele: String, _ e: Evidence = .look) -> ProvenAllele {
            ProvenAllele(locus: locus, allele: allele, copies: 1, isDefault: false, evidence: e)
        }
        let lav = note(Lavender.locus, "lav")
        let bar = note(Barring.locus, "B")
        let blueEggs = note(BlueShell.locus, BlueShell.blue.rawValue)
        #expect(carrierShortText([lav]) == "carries lavender")
        #expect(carrierShortText([lav, bar]) == "carries lavender and barring")
        #expect(carrierShortText([lav, bar, blueEggs]) == "carries lavender, barring and blue eggs")
        #expect(carrierReasonText(lav, bird: hen, s) == "Her own look shows it.")
        #expect(carrierReasonText(lav, bird: stranger, s) == "This bird's own look shows it.")
        #expect(
            carrierReasonText(note(Lavender.locus, "lav", .origin(.orpington)), bird: rooster, s)
                == "Bramble came from Hazel as an Orpington, and every one with that look carries it.")
        #expect(
            carrierReasonText(note(Lavender.locus, "lav", .outsideFlock), bird: rooster, s)
                == "Bramble came from Hazel, and every bird from there with that look carries it.")
        #expect(
            carrierReasonText(note(Lavender.locus, "lav", .parent(stranger)), bird: chick, s)
                == "It came from Moss's parent.")
        #expect(
            carrierReasonText(note(Lavender.locus, "lav", .parents(hen, rooster)), bird: chick, s)
                == "It came from Moss's parents, Clover and Bramble.")
        #expect(
            carrierReasonText(note(Lavender.locus, "lav", .parents(stranger, rooster)), bird: chick, s)
                == "It came from Moss's parents.")
        #expect(
            carrierReasonText(note(Lavender.locus, "lav", .child(chick)), bird: hen, s)
                == "Her chick Moss proves it.")
        #expect(
            carrierReasonText(note(Lavender.locus, "lav", .child(stranger)), bird: rooster, s)
                == "One of his chicks proves it.")
        #expect(carrierReasonText(note(Lavender.locus, "lav", .family), bird: hen, s) == "Her family tree proves it.")
        #expect(carrierNoneText(hen, s) == "Nothing hidden you can be sure of yet. Watch Clover's chicks.")

        // Pairs that cannot be planned.
        let birds = [hen, rooster, chick].compactMap { s.bird($0) }
        #expect(plannerPairProblemText(hen: birds[0], rooster: birds[1]) == nil)
        #expect(plannerPairProblemText(hen: birds[2], rooster: birds[1]) == "Moss is too young to tell yet.")
        #expect(
            plannerPairProblemText(hen: birds[1], rooster: birds[1])
                == "Bramble is not a hen. Use: plan <hen> <rooster>")
        #expect(
            plannerPairProblemText(hen: birds[0], rooster: birds[0])
                == "Clover is not a rooster. Use: plan <hen> <rooster>")

        // The whole panel.
        s.pen = [hen, rooster]
        let panel = plannerLines(s)
        #expect(panel.first == "What might hatch (rooster: Bramble)")
        #expect(panel.dropFirst().first == "With Clover:")
        #expect(panel.dropFirst(2).allSatisfy { $0.hasPrefix("  ") })
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

    /// Adds a grown bird the keeper owns, with the look the keeper saw. Its sex shows when `revealed`.
    static func owned(
        _ s: inout GameState, _ name: String, _ sex: Sex = .hen, look: SeenLook, revealed: Bool = true,
        mother: UUID? = nil, father: UUID? = nil, origin: String = Bird.homeOrigin
    ) -> UUID {
        var b = Bird(
            id: UUID(), name: name, breed: .orpington, genome: Breed.orpington.purebred(sex),
            hatchDay: s.day - s.rules.adultAge, motherID: mother, fatherID: father, origin: origin,
            revealed: revealed)
        b.lastSeenLook = look
        s.coop.append(b)
        return b.id
    }

    /// Adds a family record of a bird the keeper no longer has, with the look the keeper saw.
    static func record(_ s: inout GameState, _ name: String, look: SeenLook) -> UUID {
        let b = Bird(
            id: UUID(), name: name, breed: .orpington, genome: Breed.orpington.purebred(.hen), hatchDay: 0,
            origin: Bird.homeOrigin)
        s.pedigree[b.id] = PedigreeRecord(b, look: look)
        return b.id
    }

    static func look(
        _ colour: FeatherColour? = .black, barred: Bool? = false, laced: Bool? = false, silkie: Bool = false,
        egg: EggColour? = nil, speckled: Bool? = nil
    ) -> SeenLook {
        SeenLook(
            colour: colour, isBarred: barred, isLaced: laced, isSilkieFeathered: silkie, eggColour: egg,
            eggIsSpeckled: speckled)
    }

    /// Each look reason, for a hen, a rooster and a bird whose sex does not show yet.
    @Test func everyLookReasonReads() {
        var (s, _, _, _) = Self.flock()
        func says(_ name: String, sex: Sex = .hen, revealed: Bool = true, _ look: SeenLook, _ l: LocusID) -> String {
            plannerReasonText(.look(bird: Self.owned(&s, name, sex, look: look, revealed: revealed), locus: l), s)
        }
        let buff = Self.look(.buff)
        #expect(says("Pip", buff, Lavender.locus) == "Pip is buff, and buff hides lavender.")
        #expect(
            says("Pip", Self.look(.splash), BlueDilution.locus) == "Pip is splash. Splash birds always pass blue on.")
        #expect(says("Pip", Self.look(.black), BlueDilution.locus) == "Pip is black, so she carries no blue.")
        #expect(
            says("Pip", sex: .rooster, Self.look(.black), BlueDilution.locus) == "Pip is black, so he carries no blue.")
        #expect(
            says("pip", revealed: false, Self.look(.black), BlueDilution.locus)
                == "Pip is black, so pip carries no blue.")
        #expect(
            says("Pip", Self.look(.lavender), BlueDilution.locus) == "Pip is lavender, and lavender hides blue.")
        #expect(says("Pip", buff, BlueDilution.locus) == "Pip is buff, and buff hides blue.")
        #expect(
            says("Pip", Self.look(.white), BlueDilution.locus) == "Pip is white, and white hides what's underneath.")
        #expect(says("Pip", Self.look(.blue, barred: nil), "unknownGene") == "Pip's look settles it.")
        #expect(says("Pip", buff, BaseColour.locus) == "Pip is buff. Buff birds always pass buff on.")
        #expect(
            says("Pip", Self.look(laced: true), Lacing.locus) == "Pip is laced. Laced birds always pass lacing on.")
        #expect(says("Pip", buff, Barring.locus) == "Pip is buff, and buff hides barring.")
        #expect(says("Pip", Self.look(barred: true), Barring.locus) == "Pip is barred.")
        #expect(
            says("Pip", sex: .rooster, Self.look(), Barring.locus)
                == "Pip is not barred, so he has no barring to pass on.")
        #expect(
            says("Pip", revealed: false, Self.look(), Barring.locus)
                == "Pip is not barred, so Pip has no barring to pass on.")
        #expect(
            says("Pip", Self.look(silkie: true), Feathering.locus)
                == "Pip has silkie feathers. Silkie birds always pass them on.")
        #expect(says("Pip", Self.look(egg: .green), BlueShell.locus) == "Pip lays green eggs.")
        #expect(says("Pip", Self.look(egg: .white), BlueShell.locus) == "Pip lays white eggs, so she carries no blue.")
        #expect(says("Pip", Self.look(egg: .chocolate), BrownShell.locus) == "Pip lays chocolate eggs.")
        #expect(says("Pip", Self.look(egg: .blue), BrownShell.locus) == "Pip lays blue eggs, so she carries no brown.")
        #expect(says("Pip", Self.look(egg: .cream, speckled: true), Speckle.locus) == "Pip lays speckled eggs.")
        #expect(says("Pip", Self.look(egg: .cream, speckled: false), Speckle.locus) == "Pip lays plain eggs.")
        #expect(says("Pip", Self.look(.white), DominantWhite.locus) == "Pip is white.")
        #expect(says("Pip", Self.look(), DominantWhite.locus) == "Pip is not white, so she carries no white.")
        #expect(
            says("Pip", sex: .rooster, Self.look(), DominantWhite.locus) == "Pip is not white, so he carries no white.")
        #expect(
            says("Pip", revealed: false, Self.look(), DominantWhite.locus)
                == "Pip is not white, so Pip carries no white.")
    }

    /// What a parent showed, and what a chick showed, named or not.
    @Test func everyFamilyReasonReads() {
        var (s, hen, rooster, chick) = Self.flock()
        let shows: [(SeenLook, LocusID, String)] = [
            (Self.look(.lavender), Lavender.locus, "is lavender"),
            (Self.look(laced: true), Lacing.locus, "is laced"),
            (Self.look(barred: true), Barring.locus, "is barred"),
            (Self.look(silkie: true), Feathering.locus, "has silkie feathers"),
            (Self.look(egg: .olive), BlueShell.locus, "lays olive eggs"),
            (Self.look(egg: .cream, speckled: true), Speckle.locus, "lays speckled eggs"),
        ]
        for (look, locus, words) in shows {
            let gone = Self.record(&s, "Gone", look: look)
            #expect(plannerReasonText(.parent(bird: chick, parent: gone, locus: locus), s) == "Moss's parent \(words).")
            let kept = Self.owned(&s, "Pip", look: look, revealed: false)
            let son = Self.owned(&s, "Sol", .rooster, look: Self.look(), father: kept)
            #expect(
                plannerReasonText(.parent(bird: son, parent: kept, locus: locus), s) == "His father, Pip, \(words).")
        }
        #expect(
            plannerReasonText(.parent(bird: chick, parent: rooster, locus: Barring.locus), s)
                == "Barring came down from Moss's father, Bramble.")

        let chicks: [(SeenLook, LocusID, String, String)] = [
            (
                Self.look(egg: .blue), BlueShell.locus, "a daughter who lays blue eggs",
                "a daughter, Pip, who lays blue eggs"
            ),
            (
                Self.look(egg: .cream, speckled: true), Speckle.locus, "a daughter who lays speckled eggs",
                "a daughter, Pip, who lays speckled eggs"
            ),
            (Self.look(silkie: true), Feathering.locus, "a silkie-feathered chick", "a silkie-feathered chick, Pip"),
            (Self.look(.splash), BlueDilution.locus, "a splash chick", "a splash chick, Pip"),
            (Self.look(laced: true), Lacing.locus, "a laced chick", "a laced chick, Pip"),
            (Self.look(barred: true), Barring.locus, "a barred chick", "a barred chick, Pip"),
        ]
        for (look, locus, unnamed, named) in chicks {
            let gone = Self.record(&s, "Gone", look: look)
            #expect(plannerReasonText(.chick(bird: hen, chick: gone, locus: locus), s) == "Clover had \(unnamed).")
            let kept = Self.owned(&s, "Pip", look: look, mother: hen, father: rooster)
            #expect(
                plannerReasonText(.chick(bird: hen, chick: kept, locus: locus), s, pair: (hen, rooster))
                    == "They had \(named).")
        }
    }

    /// Where a bird came from, the rarer forecast lines, and every carrier note in full and short.
    @Test func everyOriginForecastAndCarrierNoteReads() {
        var (s, _, _, _) = Self.flock()
        let origins: [(String, String)] = [
            (Bird.localFlockOrigin, "a local flock"), (Bird.showOrigin, "the county show"),
            (Bird.villageOrigin, "a Featherwick neighbour"),
        ]
        for (origin, words) in origins {
            let b = Self.owned(&s, "Pip", look: Self.look(), origin: origin)
            #expect(plannerReasonText(.breed(bird: b, .orpington), s) == "Pip came from \(words) as an Orpington.")
            let p = ProvenAllele(
                locus: Lavender.locus, allele: "lav", copies: 1, isDefault: false, evidence: .origin(.silkie))
            #expect(
                carrierReasonText(p, bird: b, s)
                    == "Pip came from \(words) as a Silkie, and every one with that look carries it.")
        }
        #expect(
            plannerText(.eggColours([.cream], sure: false, .unknownFamily(locus: BrownShell.locus)), s)
                == "Hens from this pair will lay white or cream eggs, unless one of them carries brown.")
        let why = Reason.unknownFamily(locus: DominantWhite.locus)
        #expect(plannerReasonText(why, s) == "No one in their family has shown white yet.")
        #expect(
            plannerReasonText(.unknownFamily(locus: "unknownGene"), s) == "No one in their family has shown it yet.")
        #expect(plannerText(.kinship(.distant, why), s) == "They are distantly related.")
        #expect(plannerText(.kinship(.cousins, why), s) == "They are related like cousins.")

        let notes: [(LocusID, String, Int, String)] = [
            (Feathering.locus, "h", 1, "silkie feathers"), (Feathering.locus, "H", 1, "normal feathers"),
            (BaseColour.locus, "e", 1, "buff"), (BaseColour.locus, "E", 1, "black"),
            (BlueDilution.locus, "Bl", 2, "splash"), (BlueDilution.locus, "Bl", 1, "blue"),
            (BlueDilution.locus, "bl+", 1, "plain colour, not blue"), (Lavender.locus, "lav", 1, "lavender"),
            (Lavender.locus, "lav+", 1, "plain colour, not lavender"), (Lacing.locus, "lc", 1, "lacing"),
            (Lacing.locus, "lc+", 1, "plain feathers, not laced"), (Barring.locus, "B", 1, "barring"),
            (Barring.locus, "b+", 1, "plain feathers, not barred"), (BlueShell.locus, "O", 1, "blue eggs"),
            (BlueShell.locus, "o+", 1, "plain eggs, not blue"), (BrownShell.locus, "Br", 1, "brown eggs"),
            (BrownShell.locus, "br", 1, "pale eggs, not brown"), (Speckle.locus, "sp", 1, "speckled eggs"),
            (Speckle.locus, "sp+", 1, "plain eggs, not speckled"), (DominantWhite.locus, "I", 1, "white"),
            (DominantWhite.locus, "i+", 1, "colour under the white"),
            ("unknownGene", "x", 1, "something it does not show"),
        ]
        for (locus, allele, copies, words) in notes {
            let p = ProvenAllele(locus: locus, allele: allele, copies: copies, isDefault: false, evidence: .look)
            #expect(carrierText(p) == "Carries \(words)")
            #expect(carrierShortText([p]) == "carries \(words)")
        }
    }
}
