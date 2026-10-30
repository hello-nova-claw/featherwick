import Foundation
import Testing

@testable import FeatherwickCore
@testable import FeatherwickText

/// The words at the top of Text.swift (bird labels, stories, the tree, shows) read the same after they
/// moved into the String Catalog (#58).
struct BirdAndShowTextTests {
    /// A bird with its genes fixed, so its label never depends on a seed.
    static func bird(
        _ name: String, _ breed: Breed, _ sex: Sex, variety: ColourVariety, hatchDay: Int, revealed: Bool = true
    ) -> Bird {
        Bird(
            id: UUID(), name: name, breed: breed, genome: breed.purebred(sex, variety: variety), hatchDay: hatchDay,
            origin: "test", revealed: revealed)
    }

    @Test func birdLabelsReadTheSameWords() {
        var rng = SeededRNG(seed: 1)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        s.day = 600
        let adult = s.day - s.rules.adultAge
        var hen = Self.bird("Dot", .orpington, .hen, variety: .buff, hatchDay: adult)
        #expect(birdLabel(hen, s) == "Dot: orpington hen, buff, lays brown, skittish (day 21)")
        hen.noLayUntilDay = s.day + 2
        hen.broodyUntilDay = s.day + 3
        #expect(
            birdLabel(hen, s)
                == "Dot: orpington hen, buff, lays brown, shaken, not laying yet, broody, skittish (day 21)")
        let old = Self.bird("Nan", .orpington, .hen, variety: .buff, hatchDay: s.day - s.rules.retirementAgeDays)
        #expect(birdLabel(old, s) == "Nan: orpington hen, buff, retired, skittish (day 504)")
        let roo = Self.bird("Rex", .wyandotte, .rooster, variety: .buff, hatchDay: adult)
        #expect(birdLabel(roo, s) == "Rex: wyandotte rooster, gold laced, skittish (day 21)")
        let grower = Self.bird("Tib", .silkie, .rooster, variety: .buff, hatchDay: s.day - s.rules.growerAge)
        #expect(birdLabel(grower, s) == "Tib: silkie cockerel, buff, skittish (day 7)")
        let chick = Self.bird("Bud", .silkie, .hen, variety: .buff, hatchDay: s.day - 1)
        #expect(birdLabel(chick, s) == "Bud: silkie hen chick, buff, skittish (day 1)")
        let hidden = Self.bird("Wisp", .silkie, .hen, variety: .buff, hatchDay: s.day - 1, revealed: false)
        #expect(birdLabel(hidden, s) == "Wisp: chick, yellow down, breed ?, sex ?, skittish (day 1)")
        #expect(downText(.darkWithHeadSpot) == "dark down with a white head spot")
        #expect(friendlyText(.lapChicken) == "a lap chicken")
        #expect(relatedText(.close) == "closely related (like siblings, or parent and chick)")
        #expect(handledToastText(UUID(), .pet, s) == "The bird liked that")
        #expect(birdName(UUID(), s) == "a bird")
    }

    @Test func storiesReadTheSameWords() {
        #expect(
            storyText("broodySilkie", step: nil) == """
                Hazel leans over the fence, laughing. "My old Silkie has gone broody again. She's sitting on a golf \
                ball! My mother hatched her whole lavender line under Silkies, you know. If you could spare 3 eggs \
                you know are fertile, she'd hatch them for you." (Candle your eggs, then: give eggs)
                """)
        #expect(
            storyText("marigold", step: "decide") == """
                Hazel is home, and at the fence first thing. "Has Marigold been good? She can come home with me, \
                and I'll give you an egg from my flock to hatch. Or keep her, if you like. Pay me when you can."
                """)
        #expect(
            storyText("lacedGift", step: nil) == """
                The Wyandotte keeper two doors down stops to admire your flock over the fence. "You've a proper \
                little henhaven going. Give me a few days — I've a girl who'd be happier with you." Hazel smiles. \
                "That's how my mother's lavender line began: one hen, handed over a fence."
                """)
        #expect(storyText("nobody", step: nil) == "Something is happening in Featherwick. Type: story")
    }

    @Test func theTreeReadsTheSameWords() {
        guard let (_, s) = TextTests.play(seed: 9, days: 60).last,
            let chick = s.ownedBirds.first(where: { $0.motherID != nil })
        else {
            Issue.record("no chick")
            return
        }
        #expect(
            treeLines(chick.id, s) == [
                "Pip (araucana hen, hatched day 0)",
                "├ Mother: Marigold (araucana hen, hatched day -109, from Neighbour)",
                "└ Father: Marigold's mate (araucana rooster, hatched day -109, from Neighbour) · carries lavender and blue eggs",
                "Parents: not related",
            ])
        let parent = s.pedigree.keys.sorted { $0.uuidString < $1.uuidString }
            .first { !Pedigree.offspring(of: $0, in: s).isEmpty }
        #expect(
            treeLines(parent ?? UUID(), s) == [
                "Marigold's mate (araucana rooster, hatched day -109, from Neighbour) · carries lavender and blue eggs",
                "Parents: not related", "Chicks (1): Pip",
            ])
    }

    @Test func showWordsReadTheSame() {
        #expect(showThemeName(.winterChampionship) == "Winter Championship")
        #expect(showKindName(.eggs) == "egg classes")
        #expect(showThemeLine(.summerFete) == "The pet class pays extra coins.")
        #expect(
            showThemeLine(.winterChampionship)
                == "The breed classes pay extra coins. The rivals are the strongest of the year.")
        #expect(showThemeLine(.springEggFair) == "The egg classes pay extra coins.")
        #expect(
            judgingText(.pet)
                == "Judged on condition \(ShowPoints.petCondition) · friendliness \(ShowPoints.petFriendliness)")
        #expect(
            judgingText(.breed)
                == "Judged on type (size, shape and carriage) 50 · a standard colour and feathering 30 · condition 20")
        #expect(judgingText(.eggs) == "Judged on a matched plate 30 · shape 30 · shells 20 · freshness 20")
        #expect(forecastText(.broody) == "broody: a broody hen loses condition")
        #expect(forecastText(.moulting) == "moulting")
        #expect(prizeWords(coins: 1, treats: 0) == "1 coin")
        #expect(prizeWords(coins: 8, treats: 3) == "8 coins and 3 treats")
        #expect(prizeWords(coins: 0, treats: 1) == "1 treat")
        #expect(prizeWords(coins: 0, treats: 0) == "")
        #expect(placingText(23) == "23rd")
        #expect(noteText(.plateNeeds(6)) == "a plate needs 6 eggs")
        #expect(noteText(.notAStandardColour("blue")) == "blue is not a standard colour for this breed")
        #expect(noteText(.type(.good)) == "type good: a good size and shape")
        #expect(noteText(.feathering(silkie: true)) == "true silkie feathering, soft as down")
        #expect(noteText(.staleEggs(2)) == "2 stale")
        #expect(noteText(.friendliness(.skittish)) == "skittish")
        let card = JudgeCard(showClass: .pet, score: 72, grade: .veryGood, notes: [.inFineCondition, .foraged])
        #expect(cardText(card) == "  Pet chicken: Very good (72/100) · in fine condition, well-foraged")
        let none = JudgeCard(showClass: .eggs(.brown), score: 0, grade: .disqualified, notes: [.plateNeeds(3)])
        #expect(cardText(none) == "  Brown eggs: not judged (0/100) · a plate needs 3 eggs")
        #expect(
            hatchReasonText(.recessiveFromBothParents(Lavender.locus))
                == "Both parents must carry lavender out of sight, and this one got a copy from each!")
        #expect(
            hatchReasonText(.whiteHidIt)
                == "White hides every other colour, so a white bird can pass on a colour it never shows!")
        let special = ShopSpecial(breed: .orpington, sex: .rooster, colour: .buff, price: 30, isRare: false)
        #expect(shopSpecialText(special) == "Buff Orpington cockerel 30 coins")
    }

    @Test func thePodiumAndReadinessReadTheSameWords() {
        var rng = SeededRNG(seed: 1)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        let hen = TextTests.plainHen(s)
        let podium = [
            PodiumPlace(placing: 1, entrant: .rivalBird(owner: 0, bird: hen), score: 80, notes: [.inFineCondition]),
            PodiumPlace(
                placing: 2, entrant: .rivalPlate(owner: 1, colour: .brown, speckled: true), score: 70,
                notes: [.notMatched, .staleEggs(1)]),
            PodiumPlace(placing: 3, entrant: .keeper(name: "Pip", birdID: nil), score: 60, notes: []),
        ]
        #expect(
            podiumLines(.eggs(.brown), podium) == [
                "1st: Mrs Pennywhistle's buff Orpington hen, 80 of 100 — in fine condition",
                "2nd: Mr Hollyoak's plate of speckled brown eggs, 70 of 100 — the eggs do not match; 1 stale",
                "3rd: your plate of brown eggs, 60 of 100 — ",
            ])
        #expect(
            podiumWhoText(podium[1], owner: nil, in: .eggs(.brown)) == "a visitor's plate of speckled brown eggs")
        #expect(
            seenText(SeenBreedBookEntry(entry: BreedBookEntry(hen), day: 4, theme: .harvestShow))
                == "Seen at the Harvest Show")
        s.coop.append(hen)
        #expect(showReadinessText(hen, s) == "In fine condition for day 28.")
        var broody = hen
        broody.broodyUntilDay = s.nextShowDay + 1
        #expect(showReadinessText(broody, s) == "On day 28: broody: a broody hen loses condition.")
    }

    @Test func aWaitingBirdIsToldItsDeadline() {
        var rng = SeededRNG(seed: 1)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        var hen = TextTests.plainHen(s)
        hen.waitingSinceDay = s.day
        s.coop.append(hen)
        #expect(homeDeadline(hen.id, s) == " If no perch is free in 3 nights, Hazel will find Dot a new home.")
        s.day += s.rules.homeWaitNights - 1
        #expect(homeDeadline(hen.id, s) == " If no perch is free by tomorrow, Hazel will find Dot a new home.")
        #expect(homeDeadline(UUID(), s) == "")
    }

    // MARK: - The rarer words, each read once

    @Test func everyStageAndSexHasItsLabel() {
        var rng = SeededRNG(seed: 1)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        s.day = 600
        let roosterChick = Self.bird("Bo", .silkie, .rooster, variety: .buff, hatchDay: s.day - 1)
        #expect(birdLabel(roosterChick, s) == "Bo: silkie rooster chick, buff, skittish (day 1)")
        let pullet = Self.bird("Fern", .orpington, .hen, variety: .buff, hatchDay: s.day - s.rules.growerAge)
        #expect(birdLabel(pullet, s) == "Fern: orpington pullet, buff, skittish (day 7)")
        var genome = Breed.orpington.purebred(.hen, variety: .buff)
        genome.speckle = AllelePair(.speckled, .speckled)
        let speckled = Bird(
            id: UUID(), name: "Freckle", breed: .orpington, genome: genome, hatchDay: s.day - s.rules.adultAge,
            origin: "test", revealed: true)
        #expect(birdLabel(speckled, s) == "Freckle: orpington hen, buff, lays speckled brown, skittish (day 21)")
        #expect(handledToastText(UUID(), .treat, s) == "The bird enjoyed the mealworm")
        #expect(
            ChickDown.allCases.map(downText) == [
                "black down", "slate-grey down", "pale grey down", "silvery down", "yellow down",
                "dark down with a white head spot",
            ])
        #expect(Friendliness.allCases.map(friendlyText) == ["wild", "skittish", "friendly", "a lap chicken"])
        #expect(
            [Relatedness.unrelated, .distant, .cousins, .halfSiblings, .close].map(relatedText) == [
                "not related", "distantly related", "related like cousins", "related like half-siblings",
                "closely related (like siblings, or parent and chick)",
            ])
    }

    @Test func everyStoryStepHasItsWords() {
        #expect(
            storyText("broodySilkie", step: "sitting")
                == "The Silkie settles onto your eggs with a happy grumble. Check back in a few days.")
        #expect(
            storyText("heritageBreed", step: nil) == """
                A travelling keeper is retiring her heritage Australorp line. "They're grand layers, gentle as \
                anything. Bring me 4 eggs you know are fertile, so I know they'll be in good hands." Hazel nods. \
                "My mother found homes for her lavender birds the same way, when she retired." (candle, then: give eggs)
                """)
        #expect(
            storyText("heritageBreed", step: "settling")
                == "The Australorp hen is settling in. Give her a few days to find her feet.")
        #expect(
            storyText("marigold", step: nil) == """
                Hazel leans over the fence. "I'm off to my sister's soon, for a few days. Could Marigold stay \
                with you while I'm gone? She's your chick's mother, and a good layer. She brings her own box."
                """)
        #expect(
            storyText("marigold", step: "staying") == """
                Hazel lifts Marigold over the fence, box and all. "Her eggs are yours. Shut the door at night. \
                I'll be back before you know it!"
                """)
    }

    /// Four generations by hand: an unnamed chick with no known mother, a father with one unknown
    /// parent, and grandparents further back than the tree shows.
    @Test func everyKindOfTreeLineHasItsWords() {
        var rng = SeededRNG(seed: 1)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        func record(_ name: String, _ sex: Sex, day: Int, mother: UUID? = nil, father: UUID? = nil) -> Bird {
            Bird(
                id: UUID(), name: name, breed: .orpington, genome: Breed.orpington.purebred(sex, variety: .buff),
                hatchDay: day, motherID: mother, fatherID: father, origin: Bird.neighbourOrigin)
        }
        let greatGranny = record("Hetty", .hen, day: -300)
        let greatGrandad = record("Ned", .rooster, day: -300)
        let granny = record("Maud", .hen, day: -200, mother: greatGranny.id, father: greatGrandad.id)
        let father = record("Alf", .rooster, day: -100, mother: granny.id, father: UUID())
        for b in [greatGranny, greatGrandad, granny, father] { s.pedigree[b.id] = PedigreeRecord(b) }
        let chick = record("", .hen, day: 0, father: father.id)
        s.coop.append(chick)
        #expect(
            treeLines(chick.id, s) == [
                "unnamed (orpington hen, hatched day 0)", "├ Mother: unknown",
                "└ Father: Alf (orpington rooster, hatched day -100)",
                "  ├ Mother: Maud (orpington hen, hatched day -200)", "  │ ├ Mother: further back",
                "  │ └ Father: further back", "  └ Father: unknown", "Parents: not related",
            ])
    }

    @Test func everyShowWordIsReadOnce() {
        #expect(
            ShowTheme.allCases.map(showThemeName) == [
                "Spring Egg Fair", "Summer Fete", "Harvest Show", "Winter Championship",
            ])
        #expect([ShowKind.pet, .eggs, .breed].map(showKindName) == ["pet class", "egg classes", "breed classes"])
        #expect(
            [JudgeNote.stressed, .broody, .hungry, .lacksVigour].map(forecastText) == [
                "still nervous after a fright", "broody: a broody hen loses condition",
                "hungry unless you feed the flock today", "closely bred, so lacks a little vigour",
            ])
        #expect(prizeWords(coins: 1, treats: 1) == "1 coin and 1 treat")
        #expect(prizeWords(coins: 2, treats: 0) == "2 coins")
        #expect(prizeWords(coins: 0, treats: 2) == "2 treats")
        #expect(
            [1, 2, 3, 4, 11, 13, 101, 112].map(placingText) == [
                "1st", "2nd", "3rd", "4th", "11th", "13th", "101st", "112th",
            ])
        let notes: [JudgeNote] = [
            .tooYoung, .notPurebred, .wrongBreedClass, .notAStandardColour("blue"), .wrongFeathering, .notMatched,
            .plateNeeds(6), .standardColour("buff"), .feathering(silkie: false), .type(.poor), .moulting,
            .stressed, .broody, .hungry, .inFineCondition, .foraged, .lacksVigour, .friendliness(.wild),
            .shape(.fair), .shell(.excellent), .staleEggs(3),
        ]
        #expect(
            notes.map(noteText) == [
                "too young to show", "a cross: crosses can enter the pet class", "wrong class for this bird",
                "blue is not a standard colour for this breed", "wrong feathering for the breed",
                "the eggs do not match", "a plate needs 6 eggs", "buff, a standard colour", "smooth, tight feathering",
                "type poor: small, and not the breed's shape", "moulting", "still nervous after a fright",
                "broody and out of condition", "not fed today", "in fine condition", "well-foraged",
                "lacks vigour (closely bred)", "wild", "shape fair", "shells excellent", "3 stale",
            ])
        #expect(
            JudgeNote.Band.allCases.map(typeWords) == [
                "small, and not the breed's shape", "a little small or narrow for the breed", "a good size and shape",
                "a fine size and shape, carried proudly",
            ])
        let grades = Grade.allCases.map { grade in
            cardText(JudgeCard(showClass: .breed(.silkie), score: 50, grade: grade, notes: [.moulting]))
        }
        #expect(
            grades == [
                "  Silkie: not judged (50/100) · moulting", "  Silkie: Fair (50/100) · moulting",
                "  Silkie: Good (50/100) · moulting", "  Silkie: Very good (50/100) · moulting",
                "  Silkie: Excellent (50/100) · moulting",
            ])
        #expect(
            hatchReasonText(.recessiveFromBothParents(BaseColour.locus))
                == "Both parents must carry buff out of sight, and this one got a copy from each!")
        #expect(
            hatchReasonText(.recessiveFromBothParents(Speckle.locus))
                == "Both parents must carry that colour out of sight, and this one got a copy from each!")
        #expect(
            hatchReasonText(.blueSplitsThreeWays)
                == "Blue never breeds true: two blues hatch black, blue and splash, and black with splash hatches all blue!"
        )
        let specials = [(Sex.hen, false), (.hen, true), (.rooster, true), (.rooster, false)].map { sex, rare in
            shopSpecialText(ShopSpecial(breed: .orpington, sex: sex, colour: .buff, price: 40, isRare: rare))
        }
        #expect(
            specials == [
                "Buff Orpington pullet 40 coins", "Buff Orpington pullet — rare! 40 coins",
                "Buff Orpington cockerel — rare! 40 coins", "Buff Orpington cockerel 40 coins",
            ])
    }

    @Test func everyPodiumEntrantHasItsWords() {
        var rng = SeededRNG(seed: 1)
        let s = Engine.newGame(earlyGame: false, using: &rng)
        let hen = TextTests.plainHen(s)
        let cock = BirdAndShowTextTests.bird("Rex", .silkie, .rooster, variety: .black, hatchDay: -100)
        let place = { (entrant: PodiumEntrant) in PodiumPlace(placing: 1, entrant: entrant, score: 1, notes: []) }
        #expect(showBirdText(cock) == "black Silkie cock")
        #expect(
            podiumWhoText(place(.rivalBird(owner: 0, bird: hen)), owner: nil, in: .pet)
                == "a visitor's buff Orpington hen")
        #expect(
            podiumWhoText(place(.rivalBird(owner: 0, bird: cock)), owner: "Mr Quince", in: .pet)
                == "Mr Quince's black Silkie cock")
        let plain = place(.rivalPlate(owner: 0, colour: .blue, speckled: false))
        #expect(podiumWhoText(plain, owner: nil, in: .eggs(.blue)) == "a visitor's plate of blue eggs")
        #expect(podiumWhoText(plain, owner: "Mrs Dimity", in: .eggs(.blue)) == "Mrs Dimity's plate of blue eggs")
        let speckled = place(.rivalPlate(owner: 0, colour: .olive, speckled: true))
        #expect(
            podiumWhoText(speckled, owner: "Mrs Dimity", in: .eggs(.olive))
                == "Mrs Dimity's plate of speckled olive eggs")
        #expect(
            podiumWhoText(place(.keeper(name: "Pip", birdID: UUID())), owner: nil, in: .eggs(.blue)) == "your Pip")
        #expect(
            showKeeperNames == [
                "Mrs Pennywhistle", "Mr Hollyoak", "Miss Thistlewood", "Old Tom Furrow", "Mrs Bramble", "Mr Ashdown",
                "Auntie Clover", "the Misses Wren", "Mr Pippin", "Mrs Goodacre", "Farmer Lark", "Mrs Honeysett",
                "Mr Mossop", "Granny Fennel", "Mr Quince", "Mrs Dimity",
            ])
    }
}
