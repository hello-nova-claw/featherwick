import Foundation
import Testing

@testable import FeatherwickCore

struct FriendlinessTests {
    /// A game in play with one bird of the given age in the right home, fed, on a spring day.
    static func game(
        age: Int, home: WritableKeyPath<GameState, [Bird]> = \.coop, tameness: Double? = nil,
        calmPlus: Int? = nil
    ) -> (GameState, UUID) {
        var rng = SeededRNG(seed: 1)
        var s = GameState(rules: .standard, phase: .playing)
        s.day = 25
        var g = Breed.orpington.purebred(.hen)
        if let calmPlus {
            var left = calmPlus
            for locus in QuantitativeTrait.calm.loci {
                let a = left > 0 ? "+" : "-"
                left -= left > 0 ? 1 : 0
                let b = left > 0 ? "+" : "-"
                left -= left > 0 ? 1 : 0
                g.setAlleles([a, b], at: locus)
            }
        }
        var bird = Bird(
            id: makeID(using: &rng), name: "Pip", breed: .orpington, genome: g,
            hatchDay: s.day - age, origin: "t", revealed: true)
        bird.tameness = tameness
        s[keyPath: home].append(bird)
        return (s, bird.id)
    }

    static func tameness(_ s: GameState, _ id: UUID) -> Double { s.bird(id)?.currentTameness ?? -1 }

    static func apply(_ c: Command, _ s: inout GameState) -> [GameEvent] {
        var rng = SeededRNG(seed: 2)
        return Engine.apply(c, to: &s, using: &rng)
    }

    // MARK: - Handling

    @Test func pettingCountsOnceADay() {
        var (s, id) = Self.game(age: 30, tameness: 0)
        #expect(Self.apply(.pet(id), &s) == [.handled(id, .pet)])
        let after = Self.tameness(s, id)
        #expect(after > 0)
        #expect(Self.apply(.pet(id), &s) == [.rejected(.alreadyPettedToday)])
        #expect(Self.tameness(s, id) == after)
        s.day += 1
        #expect(Self.apply(.pet(id), &s).first == .handled(id, .pet))
        #expect(Self.tameness(s, id) > after)
    }

    @Test func chicksLearnTrustFastest() {
        let gain = { (age: Int) -> Double in
            var (s, id) = Self.game(age: age, tameness: 0)
            _ = Self.apply(.pet(id), &s)
            return Self.tameness(s, id)
        }
        let chick = gain(2)
        let grower = gain(10)
        let adult = gain(30)
        #expect(chick > grower && grower > adult)
        #expect(abs(chick - 3 * adult) < 1e-9)
    }

    @Test func aMotherHenKeepsHerChicksWary() {
        var (brooder, a) = Self.game(age: 2, home: \.brooder, tameness: 0)
        var (withHen, b) = Self.game(age: 2, home: \.henChicks, tameness: 0)
        _ = Self.apply(.pet(a), &brooder)
        _ = Self.apply(.pet(b), &withHen)
        #expect(abs(Self.tameness(withHen, b) - Self.tameness(brooder, a) / 2) < 1e-9)
    }

    @Test func treatsCostATreatAndCountOnceADay() {
        var (s, id) = Self.game(age: 30, tameness: 0)
        #expect(Self.apply(.giveTreat(id), &s) == [.rejected(.noTreats)])
        s.coins = 100
        #expect(Self.apply(.buy(.treats), &s) == [.boughtTreats(count: 10, cost: 5)])
        #expect(s.treats == 10 && s.coins == 95)
        #expect(Self.apply(.giveTreat(id), &s) == [.handled(id, .treat)])
        #expect(s.treats == 9)
        #expect(Self.apply(.giveTreat(id), &s) == [.rejected(.alreadyHadTreatToday)])
        #expect(s.treats == 9)
        // A cuddle and a treat on the same day both count.
        #expect(Self.apply(.pet(id), &s).first == .handled(id, .pet))
    }

    @Test func aBirdKnowsWhatItHadToday() {
        var (s, id) = Self.game(age: 30, tameness: 0)
        s.treats = 1
        #expect(s.bird(id)?.wasHandled(.pet, onDay: s.day) == false)
        #expect(s.bird(id)?.wasHandled(.treat, onDay: s.day) == false)
        _ = Self.apply(.pet(id), &s)
        #expect(s.bird(id)?.wasHandled(.pet, onDay: s.day) == true)
        #expect(s.bird(id)?.wasHandled(.treat, onDay: s.day) == false)
        _ = Self.apply(.giveTreat(id), &s)
        #expect(s.bird(id)?.wasHandled(.treat, onDay: s.day) == true)
        // A new day: both can be done again.
        #expect(s.bird(id)?.wasHandled(.pet, onDay: s.day + 1) == false)
        #expect(s.bird(id)?.wasHandled(.treat, onDay: s.day + 1) == false)
    }

    // MARK: - No gaming, no punishment

    @Test func dailyCareApproachesButNeverPassesFullTrust() {
        var (s, id) = Self.game(age: 0, tameness: 0)
        s.coins = 1000
        var last = 0.0
        for _ in 0..<400 {
            if s.treats == 0 { _ = Self.apply(.buy(.treats), &s) }
            _ = Self.apply(.pet(id), &s)
            _ = Self.apply(.giveTreat(id), &s)
            let t = Self.tameness(s, id)
            #expect(t >= last && t <= 1)
            last = t
            s.day += 1
        }
        #expect(last > 0.95)
        #expect(s.bird(id)?.friendliness == .lapChicken)
    }

    @Test func aGrowingUpBirdHandledEveryDayBecomesFriendly() {
        // Realistic play: a chick from the brooder, picked up once a day for its first 3 weeks.
        var (s, id) = Self.game(age: 0, home: \.brooder, tameness: Standard.rules.brooderChickTameness)
        for _ in 0..<21 {
            _ = Self.apply(.pet(id), &s)
            s.day += 1
        }
        #expect(s.bird(id)!.friendliness >= .friendly)
    }

    enum Standard { static let rules = Rules.standard }

    @Test func neglectNeverLowersTameness() {
        var rng = SeededRNG(seed: 4)
        var r = Rules.standard
        r.foxChance = 0
        var s = GameState(rules: r, phase: .playing)
        let bird = Bird(
            id: makeID(using: &rng), name: "a", breed: .orpington, genome: Breed.orpington.purebred(.hen),
            hatchDay: 0, origin: "t", revealed: true
        ).withTameness(0.6)
        s.coop.append(bird)
        for _ in 0..<60 { _ = Engine.apply(.passNight, to: &s, using: &rng) }
        #expect(s.bird(bird.id)?.tameness == 0.6)
    }

    @Test func aFoxFrightAndTimeLostMakeABirdWarier() {
        var rng = SeededRNG(seed: 5)
        var r = Rules.standard
        r.foxChance = 1
        var s = GameState(rules: r, phase: .playing)
        s.day = 30
        let bird = Bird(
            id: makeID(using: &rng), name: "a", breed: .orpington, genome: Breed.orpington.purebred(.hen),
            hatchDay: 0, origin: "t", revealed: true
        ).withTameness(0.9)
        s.coop.append(bird)
        _ = Engine.apply(.passNight, to: &s, using: &rng)  // door open: the fox comes
        let lost = try! #require(s.lost.first?.bird)
        let loss = 0.9 - lost.currentTameness
        #expect(loss >= r.foxFrightTamenessLoss + r.lostDayTamenessLoss - 1e-9)
        #expect(loss <= r.foxFrightTamenessLoss + r.maxLostTamenessLoss + 1e-9)
        #expect(Self.apply(.pet(lost.id), &s) == [.rejected(.birdNotHome)])
    }

    @Test func boardingBirdsAndStrangersCannotBeHandled() {
        var (s, id) = Self.game(age: 30)
        s.boarding = s.coop
        s.coop = []
        #expect(Self.apply(.pet(id), &s) == [.rejected(.birdNotHome)])
        #expect(Self.apply(.pet(UUID()), &s) == [.rejected(.noSuchBird)])
    }

    @Test func handlingWaitsForTheStarter() {
        var rng = SeededRNG(seed: 6)
        var s = Engine.newGame(using: &rng)
        #expect(Engine.apply(.pet(UUID()), to: &s, using: &rng) == [.rejected(.chooseStarterFirst)])
    }

    @Test func movingUpABandIsAnnounced() {
        var (s, id) = Self.game(age: 2, tameness: 0.55, calmPlus: 16)  // calm 1.0: score 0.4 + 0.33 = 0.73
        let ev = Self.apply(.pet(id), &s)
        #expect(ev == [.handled(id, .pet), .friendlierNow(id, .lapChicken)])
    }

    // MARK: - Where birds start

    @Test func brooderChicksStartTamerThanChicksRaisedByAHen() {
        var rng = SeededRNG(seed: 7)
        var r = Rules.standard
        r.foxChance = 0
        var s = GameState(rules: r, phase: .playing)
        s.day = 40
        let hen = Bird(
            id: makeID(using: &rng), name: "h", breed: .orpington, genome: Breed.orpington.purebred(.hen),
            hatchDay: 0, origin: "t", revealed: true)
        let rooster = Bird(
            id: makeID(using: &rng), name: "r", breed: .orpington, genome: Breed.orpington.purebred(.rooster),
            hatchDay: 0, origin: "t", revealed: true)
        s.coop = [hen]
        let egg1 = Breeding.layEgg(mother: hen, father: rooster, day: s.day, using: &rng)
        let egg2 = Breeding.layEgg(mother: hen, father: rooster, day: s.day, using: &rng)
        s.clutches = [
            Clutch(henID: hen.id, eggs: [egg1], hatchDay: s.day), Clutch(henID: nil, eggs: [egg2], hatchDay: s.day),
        ]
        _ = Engine.hatchDue(&s, &rng)
        #expect(s.henChicks.first?.tameness == r.broodyChickTameness)
        #expect(s.brooder.first?.tameness == r.brooderChickTameness)
    }

    @Test func starterAndShopBirdsStartWithSomeTrust() {
        var rng = SeededRNG(seed: 8)
        let s = Engine.newGame(using: &rng)
        guard case .choosingStarter(let chicks) = s.phase else {
            Issue.record("no starters")
            return
        }
        #expect(chicks.allSatisfy { $0.tameness == Rules.standard.brooderChickTameness })
        #expect(Engine.youngBird(.hen, origin: "t", s, &rng).tameness == Rules.standard.boughtBirdTameness)
    }

    @Test func calmBreedsAreCalmerOnAverage() {
        func meanCalm(_ breed: Breed) -> Double {
            var rng = SeededRNG(seed: 9)
            let birds = (0..<400).map { _ in
                Bird(
                    id: makeID(using: &rng), name: "", breed: breed, genome: breed.purebred(.hen),
                    hatchDay: 0, origin: "t"
                ).withFounderQuality()
            }
            return birds.map { QuantitativeTrait.calm.fraction($0.genome) }.reduce(0, +) / 400
        }
        #expect(meanCalm(.silkie) > meanCalm(.orpington))
        #expect(meanCalm(.orpington) > meanCalm(.wyandotte))
        #expect(meanCalm(.wyandotte) > meanCalm(.araucana))
        #expect(abs(meanCalm(.araucana) - 0.4) < 0.03)
    }

    @Test func olderBirdsWithoutTamenessAreAverage() throws {
        let json =
            #"{"id":"6B1E2A2C-0000-4000-8000-000000000001","name":"Old","breed":"orpington","genome":{"sex":"hen"},"hatchDay":0,"origin":"t","revealed":true,"timesScared":0,"noLayUntilDay":0}"#
        let bird = try JSONDecoder().decode(Bird.self, from: Data(json.utf8))
        #expect(bird.currentTameness == Bird.defaultTameness)
        #expect(bird.friendliness == .skittish)
    }

    // MARK: - What friendliness does

    @Test func lapChickensAreWorthMoreAndWinThePetClass() {
        let (s, id) = Self.game(age: 30, tameness: 1, calmPlus: 16)
        let (s2, id2) = Self.game(age: 30, tameness: 0, calmPlus: 0)
        let lap = s.bird(id)!
        let wild = s2.bird(id2)!
        #expect(lap.friendliness == .lapChicken && wild.friendliness == .wild)
        #expect(
            s.rules.rehomeValue(of: lap, onDay: s.day) == s.rules.rehomeValue(of: wild, onDay: s.day)
                + s.rules.lapChickenRehomeBonus)
        var show = s
        show.fedToday = true
        #expect(Judge.judge(lap, in: .pet, state: show).score == 100)
        #expect(Judge.judge(wild, in: .pet, state: show).score == 50)
    }
}
