import Foundation
import Testing

@testable import FeatherwickCore

/// The early game: a fixed timeline that introduces one thing at a time, and the neighbour's show tip.
struct EarlyGameTests {
    /// A new keeper's game, starter chosen, coop shut every night so the fox never interferes.
    static func newKeeper(seed: UInt64 = 1) -> (GameState, SeededRNG) {
        var rng = SeededRNG(seed: seed)
        var s = Engine.newGame(using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Basil"), to: &s, using: &rng)
        s.coins = 1000
        return (s, rng)
    }

    /// Feeds, shuts the coop and sleeps until the morning of `day`. Returns every event on the way.
    @discardableResult
    static func play(until day: Int, _ s: inout GameState, _ rng: inout SeededRNG) -> [GameEvent] {
        var ev: [GameEvent] = []
        while s.day < day {
            for c in [Command.feed, .closeCoop] { ev += Engine.apply(c, to: &s, using: &rng) }
            ev += sleepTonight(&s, &rng)
        }
        return ev
    }

    @Test func aNewKeeperStartsOnDay1WithOneChickAndTheFirstLesson() {
        let (s, _) = Self.newKeeper()
        #expect(s.day == 1)
        #expect(s.ownedBirds.count == 1)
        // Day 1 is a whole day: its lesson, jobs and season goal come with the starter.
        #expect(s.introduced == [.handling])
        #expect(!s.todaysJobs.isEmpty && s.seasonGoal != nil)
        #expect(s.nextFeature?.feature == .treats)
    }

    @Test func theKeeperGivesTheirNameBeforeOrAfterTheStarter() {
        var rng = SeededRNG(seed: 1)
        var s = Engine.newGame(using: &rng)
        #expect(s.keeperName == nil)
        #expect(Engine.apply(.nameKeeper("   "), to: &s, using: &rng) == [.rejected(.blankName)])
        let long = String(repeating: "a", count: NameBook.maxLength + 1)
        #expect(
            Engine.apply(.nameKeeper(long), to: &s, using: &rng) == [.rejected(.nameTooLong(max: NameBook.maxLength))])
        #expect(s.keeperName == nil)
        #expect(Engine.apply(.nameKeeper("  Anna "), to: &s, using: &rng) == [.keeperNamed("Anna")])
        #expect(s.keeperName == "Anna")
        _ = Engine.apply(.chooseStarter(index: 0, name: "Basil"), to: &s, using: &rng)
        // A new name later, from Settings. No daylight is spent.
        let slots = s.slotsLeft
        #expect(Engine.apply(.nameKeeper("Annie"), to: &s, using: &rng) == [.keeperNamed("Annie")])
        #expect(s.keeperName == "Annie" && s.slotsLeft == slots)
    }

    @Test func hazelAndWrenAreNeverSuggestedForABird() {
        let all = NameBook.neutral + NameBook.hens + NameBook.roosters
        #expect(!all.contains("Hazel") && !all.contains("Wren"))
    }

    @Test func oldSavesAndSkippedEarlyGamesHaveEverythingOpen() throws {
        let old = try SaveFormat.decode(SaveFormatTests.fixture("save-v0")).state
        #expect(old.introduced == Set(Feature.allCases))
        var rng = SeededRNG(seed: 1)
        #expect(Engine.newGame(earlyGame: false, using: &rng).introduced == Set(Feature.allCases))
    }

    @Test(arguments: [
        (Command.buy(.pullet), Feature.birdShop), (.buy(.cockerel), .birdShop), (.buy(.fertileEgg), .birdShop),
        (.buySpecial, .birdShop), (.upgradeCoop, .coopUpgrade),
        (.buyIncubator, .incubatorShop), (.buy(.treats), .treats), (.buy(.premiumFeed), .premiumFeed),
        (.enterEggs, .shows), (.enterEggPlate([]), .shows), (.penBird(UUID()), .breedingPen),
        (.unpenBird(UUID()), .breedingPen),
    ])
    func lockedCommandsWaitForTheirDay(_ command: Command, _ feature: Feature) {
        var (s, rng) = Self.newKeeper()
        let before = s
        #expect(Engine.apply(command, to: &s, using: &rng) == [.rejected(.notYet(feature))])
        #expect(s == before)  // a refused command changes nothing
        // The game's own day: a gift incubator on the way can push the shop's one later.
        while s.day < s.introductionDay(of: feature) { Self.play(until: s.introductionDay(of: feature), &s, &rng) }
        #expect(s.isOpen(feature))
        #expect(Engine.apply(command, to: &s, using: &rng) != [.rejected(.notYet(feature))])
    }

    @Test func showEntriesWaitForTheShowToOpen() {
        var (s, rng) = Self.newKeeper()
        let basil = s.brooder[0].id
        #expect(Engine.apply(.enterShow(basil), to: &s, using: &rng) == [.rejected(.notYet(.shows))])
        #expect(Engine.apply(.enterShowIn(basil, .pet), to: &s, using: &rng) == [.rejected(.notYet(.shows))])
    }

    @Test func featuresArriveOnTheTimelineOnceEachAndInOrder() {
        var (s, rng) = Self.newKeeper()
        let ev = Self.play(until: 40, &s, &rng)
        let order = ev.compactMap { e -> Feature? in
            if case .introduced(let f) = e { return f }
            return nil
        }
        // Day 1's lesson came with the starter, before the first night.
        let later = Feature.allCases.filter { s.introductionDay(of: $0) > 1 }
        #expect(order == later.sorted { s.introductionDay(of: $0) < s.introductionDay(of: $1) })
        #expect(s.introduced == Set(Feature.allCases))
        #expect(s.nextFeature == nil)
    }

    @Test func theSexIsKnownBeforeTheShopSellsBirds() {
        let r = Rules.standard
        for f in [Feature.birdShop, .coopUpgrade, .shows, .incubatorShop, .breedingPen] {
            #expect(r.introductionDay(of: f) > r.growerAge, "\(f)")
        }
    }

    /// The big incubator comes to the shop at least `incubatorShopAfterGiftDays` after the neighbour's gift.
    @Test func theShopIncubatorWaitsAfterTheNeighboursGift() {
        var (s, rng) = Self.newKeeper()
        let shopDay = s.rules.introductionDay(of: .incubatorShop)
        let giftDay = shopDay - 3
        s.incubatorGiftDay = giftDay
        let later = giftDay + s.rules.incubatorShopAfterGiftDays
        #expect(s.introductionDay(of: .incubatorShop) == later)
        Self.play(until: shopDay, &s, &rng)
        #expect(!s.isOpen(.incubatorShop))
        #expect(Engine.apply(.buyIncubator, to: &s, using: &rng) == [.rejected(.notYet(.incubatorShop))])
        Self.play(until: later, &s, &rng)
        #expect(s.isOpen(.incubatorShop))
        // With no gift, the shop day is the rules' day.
        var (t, _) = Self.newKeeper()
        t.incubatorGiftDay = nil
        #expect(t.introductionDay(of: .incubatorShop) == shopDay)
    }

    @Test func theNeighbourGivesTreatsWhenSheShowsYouThem() {
        var (s, rng) = Self.newKeeper()
        Self.play(until: s.rules.introductionDay(of: .treats), &s, &rng)
        #expect(s.treats == s.rules.welcomeTreats)
    }

    @Test func theShowOpensAWeekBeforeTheFirstShowWithATipForYourBird() throws {
        // A hen starter (no gift hen), and Marigold sent home on day 10: the starter is the only bird,
        // so the tip must name it.
        var seed: UInt64 = 1
        var rng = SeededRNG(seed: seed)
        var s = Engine.newGame(using: &rng)
        // The first seed that offers a hen chick.
        while case .choosingStarter(let chicks) = s.phase, !chicks.contains(where: { $0.sex == .hen }) {
            seed += 1
            rng = SeededRNG(seed: seed)
            s = Engine.newGame(using: &rng)
        }
        let offered: [Bird]? = if case .choosingStarter(let c) = s.phase { c } else { nil }
        let chicks = try #require(offered)
        let hen = try #require(chicks.firstIndex { $0.sex == .hen })
        _ = Engine.apply(.chooseStarter(index: hen, name: "Basil"), to: &s, using: &rng)
        s.coins = 1000
        Self.play(until: 10, &s, &rng)
        _ = Engine.apply(.choose(story: Storylines.marigold, option: "return"), to: &s, using: &rng)
        let ev = Self.play(until: s.rules.showIntervalDays - s.rules.showNoticeDays, &s, &rng)
        #expect(s.isOpen(.shows))
        #expect(s.nextShowDay - s.day == s.rules.showNoticeDays)
        #expect(s.birdsAtHome.map(\.id) == s.starterID.map { [$0] })
        let tip = s.showTip
        #expect(tip != nil)
        #expect(ev.contains(.showAnnounced(tip)))
        #expect(tip?.birdID == s.starterID)  // the only bird
        #expect(tip?.showDay == s.nextShowDay)
        // The tip is cleared once the show is over.
        Self.play(until: s.nextShowDay, &s, &rng)
        #expect(s.showTip == nil)
    }

    @Test func aGoodPurebredIsSentToItsBreedClass() {
        var (s, rng) = ShowEventTests.eveOfShow()
        s.day -= s.rules.showNoticeDays
        let champ = ShowEventTests.championOrpington(in: s, rng: &rng)
        s.coop.append(champ)
        #expect(
            Engine.showTip(in: s) == ShowTip(birdID: champ.id, showClass: .breed(.orpington), showDay: s.nextShowDay))
    }

    @Test func aCrossIsSentToThePetClass() {
        var (s, rng) = ShowEventTests.eveOfShow()
        let cross = ShowEventTests.cross(in: s, rng: &rng)
        s.coop.append(cross)
        #expect(Engine.showTip(in: s)?.showClass == .pet)
    }

    @Test func aPlainPurebredIsSentToThePetClassInstead() {
        var (s, rng) = ShowEventTests.eveOfShow()
        var plain = ShowEventTests.championOrpington(in: s, rng: &rng)
        ShowEventTests.setType(&plain.genome, plus: 0)
        s.coop.append(plain)
        #expect(Engine.eligibleClasses(for: plain, in: s).contains(.breed(.orpington)))
        #expect(Engine.showTip(in: s)?.showClass == .pet)
    }

    @Test func withSeveralBirdsTheBestBreedCandidateIsChosen() {
        var (s, rng) = ShowEventTests.eveOfShow()
        let cross = ShowEventTests.cross(in: s, rng: &rng)
        let champ = ShowEventTests.championOrpington(in: s, rng: &rng)
        s.coop += [cross, champ]
        #expect(Engine.showTip(in: s)?.birdID == champ.id)
    }

    @Test func chicksAreNeverTipped() {
        var (s, rng) = ShowEventTests.eveOfShow()
        let chick = Bird(
            id: makeID(using: &rng), name: "Chick", breed: .orpington, genome: Breed.orpington.purebred(.hen),
            hatchDay: s.day, origin: "test")
        s.brooder.append(chick)
        #expect(Engine.showTip(in: s) == nil)
    }

    @Test func askingForATipChangesNothing() {
        var (s, rng) = ShowEventTests.eveOfShow()
        s.coop.append(ShowEventTests.championOrpington(in: s, rng: &rng))
        let before = s
        #expect(Engine.showTip(in: s) == Engine.showTip(in: s))
        #expect(s == before)
    }
}
