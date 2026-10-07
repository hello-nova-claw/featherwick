import FeatherwickCore
import FeatherwickText
import Foundation
import Testing

/// Every front end shows these words, so no event or screen may crash or come out empty.
struct TextTests {
    /// Plays a simple keeper's day for `days` nights and returns each event with the state after it.
    static func play(seed: UInt64, days: Int) -> [(GameEvent, GameState)] {
        var rng = SeededRNG(seed: seed)
        var s = Engine.newGame(using: &rng)
        var seen: [(GameEvent, GameState)] = []
        func run(_ c: Command) {
            for e in Engine.apply(c, to: &s, using: &rng) { seen.append((e, s)) }
        }
        run(.chooseStarter(index: Int(seed % 3), name: "Pip"))
        for day in 0..<days {
            for b in s.unnamedBirds { run(.rename(b.id, name: NameBook.suggestion(for: b, in: s))) }
            run(.feed)
            run(.collectEggs)
            run(.candle)
            if let b = s.coop.first { run(.pet(b.id)) }
            if s.hasIncubator, s.incubatorClutch == nil { run(.incubate(count: 1)) }
            if s.carton.count > 6 { run(.sellClearEggs) }
            if let story = Engine.storyAwaitingDelivery(s) { run(.deliver(story: story)) }
            if s.coop.count >= s.perches { run(.upgradeCoop) }
            if let b = s.coop.first(where: { $0.stage(onDay: s.day, rules: s.rules) == .adult }) {
                run(.enterShow(b.id))
            }
            if day % 3 != 0 { run(.closeCoop) }  // some nights open: fox and foraging
            while s.isOpen(.daylight), s.slotsLeft > 0 { run(.rest) }  // sleep waits for evening
            run(.passNight)
        }
        return seen
    }

    @Test(arguments: [UInt64(1), 2, 3, 4, 5])
    func everyEventHasWords(seed: UInt64) {
        for (event, state) in Self.play(seed: seed, days: 120) {
            guard let words = eventText(event, state) else { continue }
            #expect(!words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(event)")
        }
    }

    @Test func screensHaveWords() {
        var rng = SeededRNG(seed: 9)
        let start = Engine.newGame(using: &rng)
        #expect(!yardLines(start).isEmpty)  // the starter choice
        guard let (_, s) = Self.play(seed: 9, days: 60).last else {
            Issue.record("no events")
            return
        }
        #expect(!yardLines(s).isEmpty)
        #expect(!journalLines(s).isEmpty)
        #expect(!bookLines(s).isEmpty)
        #expect(!showsLines(s).isEmpty)
        #expect(!jobsLines(s).isEmpty)
        for b in s.ownedBirds {
            #expect(birdLabel(b, s).contains(b.name))
            #expect(!treeLines(b.id, s).isEmpty)
        }
    }

    @Test func everyJobAndGoalHasWords() {
        guard let (_, s) = Self.play(seed: 2, days: 3).last else {
            Issue.record("no events")
            return
        }
        for kind in JobKind.allCases {
            #expect(!jobText(Job(kind: kind), s).isEmpty)
            #expect(jobText(Job(kind: kind, target: 3, progress: 1), s).hasSuffix("(1 of 3)"))
        }
        for kind in GoalKind.allCases {
            let goal = SeasonGoal(kind: kind, startDay: 0, endDay: 28, target: 3, baseline: 0)
            #expect(!seasonGoalText(goal, s).isEmpty)
            #expect(!goalName(kind).isEmpty)
        }
    }

    /// "Cuddle Juniper and Pip": the job names its birds. An unnamed bird gives nothing away.
    @Test func cuddleJobsNameTheirBirds() {
        var rng = SeededRNG(seed: 4)
        var s = Engine.newGame(using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        let pip = s.brooder[0].id
        func hen(_ name: String) -> Bird {
            Bird(
                id: UUID(), name: name, breed: .orpington, genome: Breed.orpington.purebred(.hen), hatchDay: 0,
                origin: "Neighbour", revealed: true)
        }
        let juniper = hen("Juniper")
        let hazel = hen("Hazel")
        // A rooster chick with no name yet: its words must not say so.
        var chick = Bird(
            id: UUID(), name: "Chick 1", breed: .orpington, genome: Breed.orpington.purebred(.rooster), hatchDay: 0,
            origin: "Henhaven")
        chick.needsName = true
        s.coop = [juniper, hazel]
        s.brooder.append(chick)

        let two = Job(kind: .petBirds, target: 2, birdIDs: [juniper.id, pip])
        #expect(jobText(two, s) == "Cuddle Juniper and Pip")
        let three = Job(kind: .petBirds, target: 3, birdIDs: [juniper.id, pip, hazel.id])
        #expect(jobText(three, s) == "Cuddle Juniper, Pip and Hazel")
        let started = Job(kind: .petBirds, target: 3, progress: 1, birdIDs: [juniper.id, pip, hazel.id])
        #expect(jobText(started, s) == "Cuddle Juniper, Pip and Hazel (1 of 3)")
        let withChick = Job(kind: .petBirds, target: 2, birdIDs: [juniper.id, chick.id])
        #expect(jobText(withChick, s) == "Cuddle Juniper and the new chick")
        #expect(jobText(Job(kind: .petBird, birdID: pip), s) == "Cuddle Pip")
        #expect(jobText(Job(kind: .petBird, birdID: chick.id), s) == "Cuddle the new chick")
        // A job from a save made before jobs named their birds.
        #expect(jobText(Job(kind: .petBirds, target: 2), s) == "Cuddle 2 birds")
    }

    /// The family tree says how related a bird's parents are in words, never as an inbreeding number.
    @Test func theTreeShowsNoInbreedingNumber() {
        guard let (_, s) = Self.play(seed: 9, days: 60).last else {
            Issue.record("no events")
            return
        }
        for b in s.ownedBirds {
            let lines = treeLines(b.id, s).joined(separator: "\n")
            #expect(!lines.contains("%") && !lines.lowercased().contains("inbre"))
        }
    }

    /// An unfinished goal is never failed: the new goal's words say the last one can rest.
    @Test func anUnfinishedGoalIsLetGoKindly() {
        guard var (_, s) = Self.play(seed: 3, days: 3).last else {
            Issue.record("no events")
            return
        }
        s.seasonGoal = SeasonGoal(kind: .newFriend, startDay: s.day, endDay: s.day + 20, target: 1, baseline: 0)
        let words = eventText(.seasonGoalSet(.newFriend, previous: .hatchChicks), s) ?? ""
        #expect(words.contains("can rest"))
        #expect(!words.lowercased().contains("fail"))
    }

    @Test func everyMilestoneHasATitleAndHint() {
        for m in Milestones.all {
            let t = milestoneText(m.id)
            #expect(t.title != m.id, "\(m.id) has no title")
            #expect(!t.hint.isEmpty)
        }
    }

    /// 4th, 5th and 6th used to show as "3rd" in the app. Every placing needs its own word.
    @Test func placingsHaveTheirOwnOrdinals() {
        #expect(placingText(0) == "not placed")
        #expect(placingText(1) == "1st")
        #expect(placingText(2) == "2nd")
        #expect(placingText(3) == "3rd")
        #expect(placingText(4) == "4th")
        #expect(placingText(6) == "6th")
        #expect(placingText(11) == "11th")
        #expect(placingText(12) == "12th")
        #expect(placingText(21) == "21st")
        #expect(placingText(22) == "22nd")
    }

    /// A cuddle or a treat that made a bird tamer gets a gentle note that names the bird.
    @Test func handlingHasGentleWords() {
        var rng = SeededRNG(seed: 5)
        var s = Engine.newGame(using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Juniper"), to: &s, using: &rng)
        guard let id = s.ownedBirds.first?.id else {
            Issue.record("no bird")
            return
        }
        #expect(handledToastText(id, .pet, s) == "Juniper liked that")
        #expect(handledToastText(id, .treat, s) == "Juniper enjoyed the mealworm")
        #expect(!handledToastText(UUID(), .pet, s).isEmpty)
        #expect(eventText(.friendlierNow(id, .friendly), s) == "Juniper seems friendly now.")
    }

    /// A clear egg that sat the full time: a warm surprise, singular and plural, never a loss.
    @Test func unhatchedEggsGetAGentleSurprise() {
        var rng = SeededRNG(seed: 5)
        var s = Engine.newGame(using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Juniper"), to: &s, using: &rng)
        guard let id = s.ownedBirds.first?.id else {
            Issue.record("no bird")
            return
        }
        #expect(
            eventText(.eggsDidNotHatch(count: 1, hen: nil), s)
                == "Hm, 1 egg didn't hatch. It mustn't have been fertile. It's back in the carton.")
        #expect(
            eventText(.eggsDidNotHatch(count: 2, hen: id), s)
                == "Juniper's clutch: 2 eggs didn't hatch. They mustn't have been fertile. They're back in the carton.")
        s.cartons = 0  // a full carton sends them to the nest boxes
        let full = eventText(.eggsDidNotHatch(count: 3, hen: nil), s) ?? ""
        #expect(full.hasPrefix("Hm, 3 eggs didn't hatch.") && full.contains("nest boxes"))
        for n in 1...3 {
            let words = eventText(.eggsDidNotHatch(count: n, hen: nil), s) ?? ""
            #expect(!words.contains("died") && !words.contains("dead"))
        }
    }

    /// The hatch-day "why" note: one sentence in the neighbour's voice for every reason, never the chick's sex.
    @Test func hatchSurpriseNotesAreOneSentenceAndSexless() {
        var rng = SeededRNG(seed: 5)
        var s = Engine.newGame(using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Juniper"), to: &s, using: &rng)
        guard let id = s.ownedBirds.first?.id else {
            Issue.record("no bird")
            return
        }
        let reasons: [HatchReason] = [
            .recessiveFromBothParents(Lavender.locus), .recessiveFromBothParents(BaseColour.locus),
            .blueSplitsThreeWays, .whiteHidIt,
        ]
        for reason in reasons {
            let words = eventText(.hatchSurprise(chick: id, reason: reason), s) ?? ""
            #expect(words.hasPrefix("The neighbour peers at Juniper: \""))
            #expect(words.count(where: { $0 == "." || $0 == "!" || $0 == "?" }) == 1)
            let lower = words.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
            for sexWord in [
                "she", "he", "her", "him", "his", "pullet", "cockerel", "hen", "rooster", "daughter", "son",
            ] {
                #expect(!lower.contains(sexWord), "\(reason) says \(sexWord)")
            }
        }
        #expect(
            eventText(.hatchSurprise(chick: id, reason: .recessiveFromBothParents(Lavender.locus)), s)?.contains(
                "lavender") == true)
        #expect(
            eventText(.hatchSurprise(chick: id, reason: .recessiveFromBothParents(BaseColour.locus)), s)?.contains(
                "buff") == true)
    }

    /// The daily special names breed, sex and colour; basic stock never names its breed before purchase.
    @Test func theKeeperIsToldOfABroodySpellBeforeTheShow() {
        var rng = SeededRNG(seed: 3)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        s.day = s.rules.daysPerSeason * 2 - 5
        s.coins = 100
        let id = s.brooder[0].id
        #expect(showReadinessText(s.bird(id)!, s).hasPrefix("In fine condition"))
        s.brooder[0].broodyUntilDay = s.nextShowDay + 2
        #expect(showReadinessText(s.bird(id)!, s).contains("broody"))
        let words = Engine.apply(.enterShow(id), to: &s, using: &rng).compactMap { eventText($0, s) }
        #expect(words.contains { $0.contains("broody") }, "\(words)")
    }

    @Test func everyKindOfClassSaysWhatItIsJudgedOn() {
        #expect(judgingText(.breed).contains("type") && judgingText(.breed).contains("50"))
        #expect(judgingText(.pet).contains("friendliness"))
        #expect(judgingText(.eggs).contains("freshness"))
        for band in JudgeNote.Band.allCases { #expect(noteText(.type(band)).contains(":")) }
    }

    @Test func theShopSpecialHasWords() {
        let rare = ShopSpecial(breed: .silkie, sex: .hen, colour: .splash, price: 50, isRare: true)
        #expect(shopSpecialText(rare) == "Splash Silkie pullet — rare! 50 coins")
        let laced = ShopSpecial(breed: .wyandotte, sex: .rooster, colour: .buff, price: 20, isRare: false)
        #expect(shopSpecialText(laced) == "Gold laced Wyandotte cockerel 20 coins")

        var rng = SeededRNG(seed: 4)
        var s = Engine.newGame(using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        s.coins = 1000
        for e in Engine.apply(.buySpecial, to: &s, using: &rng) + Engine.apply(.buySpecial, to: &s, using: &rng) {
            let words = eventText(e, s) ?? ""
            #expect(!words.isEmpty, "\(e)")
        }
    }

    // MARK: - The show podium

    /// A buff Orpington hen with no show type: the rivals beat her.
    static func plainHen(_ s: GameState) -> Bird {
        Bird(
            id: UUID(uuidString: "6D0F1C2A-3B4C-4D5E-8F60-718293A4B5C6")!, name: "Dot", breed: .orpington,
            genome: Breed.orpington.purebred(.hen, variety: .buff), hatchDay: s.day - s.rules.adultAge,
            origin: "test", revealed: true)
    }

    @Test func thePodiumNamesRivalsAndSaysWhyTheyWon() {
        var rng = SeededRNG(seed: 3)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        s.day = s.rules.showIntervalDays - 1
        s.coins = 100
        s.coopDoorOpen = false
        let hen = Self.plainHen(s)
        s.coop.append(hen)
        _ = Engine.apply(.enterShow(hen.id), to: &s, using: &rng)
        _ = Engine.apply(.feed, to: &s, using: &rng)
        Engine.restUntilEvening(&s, using: &rng)
        let events = Engine.apply(.passNight, to: &s, using: &rng)

        let podiums = events.compactMap { e -> (ShowClass, [PodiumPlace])? in
            if case .showPodium(let cls, let podium) = e { return (cls, podium) }
            return nil
        }
        guard let first = podiums.first else {
            Issue.record("no podium")
            return
        }
        let (cls, podium) = first
        let lines = podiumLines(cls, podium)
        #expect(lines.count == 3)
        #expect(lines.first?.hasPrefix("1st: ") == true)
        for (line, place) in zip(lines, podium) {
            #expect(line.contains("\(place.score) of 100"))
            #expect(line.contains(podiumWhyText(place)))
            #expect(!podiumWhyText(place).isEmpty)
        }
        // Rivals are named after a village keeper, with breed, colour and sex.
        let rivalLines = zip(lines, podium).filter { !$0.1.isKeeper }.map { $0.0 }
        #expect(!rivalLines.isEmpty)
        for line in rivalLines {
            #expect(showKeeperNames.contains { line.contains("\($0)'s ") }, "\(line)")
            #expect(line.contains("Orpington hen"), "\(line)")
        }
        let words = eventText(.showPodium(cls, podium), s) ?? ""
        #expect(words.contains("the top three"))

        // Each new look seen on the podium is added to the Breed Book as seen.
        let seen = events.filter { if case .breedBookEntrySeen = $0 { true } else { false } }
        #expect(seen.count == s.seenAtShows.count)
        for e in seen { #expect(eventText(e, s)?.hasPrefix("Seen at the \(showThemeName(.summerFete))") == true) }
        if let first = s.breedBookSeenOnly.first {
            #expect(seenText(first) == "Seen at the Summer Fete")
            #expect(bookLines(s).contains("Seen at shows (\(s.breedBookSeenOnly.count)):"))
        }
    }

    /// Two rivals with the same owner number still get two different names.
    @Test func rivalsOnOnePodiumHaveDifferentOwners() {
        var rng = SeededRNG(seed: 1)
        let s = Engine.newGame(earlyGame: false, using: &rng)
        let hen = Self.plainHen(s)
        let plate = PodiumEntrant.rivalPlate(owner: 7, colour: .brown, speckled: false)
        let podium = [
            PodiumPlace(placing: 1, entrant: .rivalBird(owner: 7, bird: hen), score: 80, notes: [.inFineCondition]),
            PodiumPlace(placing: 2, entrant: plate, score: 70, notes: []),
            PodiumPlace(placing: 3, entrant: .keeper(name: "Pip", birdID: nil), score: 60, notes: []),
        ]
        let owners = podiumOwnerNames(podium)
        #expect(owners[0] != nil && owners[1] != nil && owners[0] != owners[1])
        #expect(owners[2] == nil)
        #expect(showBirdText(hen) == "buff Orpington hen")
        #expect(podiumWhoText(podium[2], owner: nil, in: .eggs(.brown)) == "your plate of brown eggs")
        #expect(podiumWhoText(podium[2], owner: nil, in: .pet) == "your Pip")
        #expect(podiumLines(.breed(.orpington), podium)[0].hasSuffix("— in fine condition"))
    }
}

/// The breeding pen's words: every refusal and event has words, and none names a hidden sex.
struct BreedingPenTextTests {
    @Test func everyPenEventHasWords() {
        var rng = SeededRNG(seed: 3)
        let s = Engine.newGame(earlyGame: false, using: &rng)
        let rejections: [Rejection] = [
            .penFull(hens: 3), .penHasRooster, .notInPen, .alreadyInPen, .notInCoop, .tooYoungForPen,
            .notYet(.breedingPen),
        ]
        for r in rejections { #expect(!(eventText(.rejected(r), s) ?? "").isEmpty, "\(r)") }
        #expect(!(eventText(.birdPenned(UUID()), s) ?? "").isEmpty)
        #expect(!(eventText(.birdUnpenned(UUID()), s) ?? "").isEmpty)
        #expect(!(introducedText(.breedingPen, s) ?? "").isEmpty)
        #expect(!penLines(s).isEmpty)
    }

    @Test func aYoungPenRoosterIsNotCalledTheWorkingSire() {
        var rng = SeededRNG(seed: 3)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        s.day = 60
        let born = s.day - s.rules.growerAge  // a cockerel: sex shows, not grown
        let cockerel = Bird(
            id: UUID(), name: "Rufus", breed: .orpington, genome: Breed.orpington.purebred(.rooster),
            hatchDay: born, origin: "Test", revealed: true)
        let hen = Bird(
            id: UUID(), name: "Hazel", breed: .orpington, genome: Breed.orpington.purebred(.hen),
            hatchDay: 0, origin: "Test", revealed: true)
        s.coop += [cockerel, hen]
        _ = Engine.apply(.penBird(cockerel.id), to: &s, using: &rng)
        let ev = Engine.apply(.penBird(hen.id), to: &s, using: &rng)
        let day = born + s.rules.adultAge
        let words = ev.compactMap { eventText($0, s) }.joined()
        #expect(words.contains("stay clear until day \(day)"))
        #expect(!words.hasSuffix("Her chicks will have Rufus for a father."))
        #expect(penLines(s).contains { $0.contains("stay clear until day \(day)") })
    }

    @Test func theTooYoungWordsDoNotNameASex() {
        var rng = SeededRNG(seed: 3)
        let s = Engine.newGame(earlyGame: false, using: &rng)
        let words = (eventText(.rejected(.tooYoungForPen), s) ?? "").lowercased()
        for sexWord in ["hen", "rooster", "cockerel", "pullet", " she ", " he ", "her ", "him"] {
            #expect(!words.contains(sexWord), "\(sexWord)")
        }
    }
}
