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
}
