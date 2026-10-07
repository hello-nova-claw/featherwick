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

    @Test func aNewKeeperStartsWithOneChickAndNothingOpen() {
        let (s, _) = Self.newKeeper()
        #expect(s.ownedBirds.count == 1)
        #expect(s.introduced.isEmpty)
        #expect(s.nextFeature?.feature == .handling)
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
        #expect(order == Feature.allCases.sorted { s.introductionDay(of: $0) < s.introductionDay(of: $1) })
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

    @Test func theShowOpensAWeekBeforeTheFirstShowWithATipForYourBird() {
        var (s, rng) = Self.newKeeper()
        let ev = Self.play(until: s.rules.showIntervalDays - s.rules.showNoticeDays, &s, &rng)
        #expect(s.isOpen(.shows))
        #expect(s.nextShowDay - s.day == s.rules.showNoticeDays)
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
