import Foundation

public enum Command: Hashable, Codable, Sendable {
    case chooseStarter(index: Int, name: String)
    case feed
    case collectEggs
    case sellEggs
    case buyFeed(bags: Int)
    case closeCoop
    case passNight
}

public enum Rejection: Hashable, Codable, Sendable {
    case chooseStarterFirst
    case alreadyStarted
    case noSuchChick
    case alreadyFed
    case nothingToFeed
    case notEnoughFeed(needed: Int, have: Int)
    case noEggsInNest
    case cartonFull
    case cartonEmpty
    case notEnoughCoins(needed: Int, have: Int)
    case invalidAmount
    case coopAlreadyClosed
}

public enum GameEvent: Hashable, Codable, Sendable {
    case rejected(Rejection)
    // Player actions
    case starterChosen(UUID)
    case fed(units: Int)
    case eggsCollected(count: Int, leftInNest: Int)
    case eggsSold(count: Int, coins: Int, stale: Int)
    case feedBought(units: Int, cost: Int)
    case coopClosed
    // Night
    case quietNight
    case foxVisited(scared: [UUID])
    // Morning
    case dayStarted(day: Int, season: Season)
    case seasonChanged(Season)
    case birdReturned(UUID)
    case birdWaitingForPerch(UUID)
    case grewUp(UUID, LifeStage)
    case revealed(UUID, sex: Sex, breed: Breed)
    case newBreedBookEntry(BreedBookEntry)
    case neighbourGaveHen(UUID)
    case movedToCoop(UUID)
    case stuckInBrooder(UUID)
    case noEggsHungry
    case eggLaid(UUID, by: UUID)
    case eggBroken(by: UUID)          // nest boxes full: laid on the floor and broke
    case newEggBookEntry(EggBookEntry)
    case wentBroody(UUID)
    case broodyEnded(UUID)
}

/// The game engine: command in, events out. No I/O, no system clock, no global random.
public enum Engine {
    public static func newGame<R: RandomNumberGenerator>(rules: Rules = .standard, using rng: inout R) -> GameState {
        var chicks: [Bird] = []
        for breed in Breed.starters.shuffled(using: &rng) {
            let sex: Sex = Bool.random(using: &rng) ? .hen : .rooster
            let colour = StarterColour.allCases.randomElement(using: &rng)!
            let barred = Double.roll(0.25, using: &rng)
            chicks.append(Bird(
                id: makeID(using: &rng), name: "", breed: breed,
                genome: breed.purebred(sex, colour: colour, barred: barred),
                hatchDay: 0, origin: "Neighbour"
            ))
        }
        return GameState(rules: rules, phase: .choosingStarter(chicks))
    }

    public static func apply<R: RandomNumberGenerator>(
        _ command: Command, to s: inout GameState, using rng: inout R
    ) -> [GameEvent] {
        if case .chooseStarter(let index, let name) = command {
            return chooseStarter(index: index, name: name, &s)
        }
        guard s.phase == .playing else { return [.rejected(.chooseStarterFirst)] }

        switch command {
        case .chooseStarter:
            return [] // handled above
        case .feed:
            let needed = s.birdsAtHome.count
            if needed == 0 { return [.rejected(.nothingToFeed)] }
            if s.fedToday { return [.rejected(.alreadyFed)] }
            if s.feedStock < needed { return [.rejected(.notEnoughFeed(needed: needed, have: s.feedStock))] }
            s.feedStock -= needed
            s.fedToday = true
            return [.fed(units: needed)]

        case .collectEggs:
            if s.nest.isEmpty { return [.rejected(.noEggsInNest)] }
            let space = s.cartonCapacity - s.carton.count
            if space <= 0 { return [.rejected(.cartonFull)] }
            var moving = Array(s.nest.prefix(space))
            for i in moving.indices { moving[i].collectedDay = s.day }
            s.nest.removeFirst(moving.count)
            s.carton += moving
            return [.eggsCollected(count: moving.count, leftInNest: s.nest.count)]

        case .sellEggs:
            if s.carton.isEmpty { return [.rejected(.cartonEmpty)] }
            let total = s.carton.reduce(0) { $0 + s.rules.price(of: $1, onDay: s.day) }
            let stale = s.carton.filter { s.rules.isStale($0, onDay: s.day) }.count
            let count = s.carton.count
            s.coins += total
            s.carton.removeAll()
            return [.eggsSold(count: count, coins: total, stale: stale)]

        case .buyFeed(let bags):
            if bags < 1 { return [.rejected(.invalidAmount)] }
            let cost = bags * s.rules.feedBagPrice
            if s.coins < cost { return [.rejected(.notEnoughCoins(needed: cost, have: s.coins))] }
            s.coins -= cost
            s.feedStock += bags * s.rules.feedBagUnits
            return [.feedBought(units: bags * s.rules.feedBagUnits, cost: cost)]

        case .closeCoop:
            if !s.coopDoorOpen { return [.rejected(.coopAlreadyClosed)] }
            s.coopDoorOpen = false
            return [.coopClosed]

        case .passNight:
            return passNight(&s, &rng)
        }
    }

    // MARK: - Starter

    static func chooseStarter(index: Int, name: String, _ s: inout GameState) -> [GameEvent] {
        guard case .choosingStarter(let chicks) = s.phase else { return [.rejected(.alreadyStarted)] }
        guard chicks.indices.contains(index) else { return [.rejected(.noSuchChick)] }
        var chick = chicks[index]
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        chick.name = trimmed.isEmpty ? "Chick" : trimmed
        s.brooder.append(chick)
        s.starterID = chick.id
        s.phase = .playing
        return [.starterChosen(chick.id)]
    }

    // MARK: - Night and morning

    static func lostDays<R: RandomNumberGenerator>(timesScared: Int, rules: Rules, _ rng: inout R) -> Int {
        let base = Int.random(in: rules.lostDaysMin...rules.lostDaysMax, using: &rng)
        let factor = 1 << min(timesScared, 10)
        return min(base * factor, rules.lostDaysCap)
    }

    static func passNight<R: RandomNumberGenerator>(_ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        var ev: [GameEvent] = []
        let r = s.rules

        // 1. Night: the fox visits only if the coop is open. It never kills; it scares birds away.
        if s.coopDoorOpen, !s.coop.isEmpty, Double.roll(r.foxChance, using: &rng) {
            var stay: [Bird] = []
            var scared: [Bird] = []
            for b in s.coop {
                if Double.roll(r.fleeChance, using: &rng) { scared.append(b) } else { stay.append(b) }
            }
            if scared.isEmpty {
                scared.append(stay.remove(at: Int.random(in: 0..<stay.count, using: &rng)))
            }
            s.coop = stay
            for var b in scared {
                let days = lostDays(timesScared: b.timesScared, rules: r, &rng)
                b.timesScared += 1
                s.lost.append(LostBird(bird: b, returnsOnDay: s.day + 1 + days))
            }
            ev.append(.foxVisited(scared: scared.map(\.id)))
        } else {
            ev.append(.quietNight)
        }

        // 2. New day.
        let oldSeason = s.season
        s.day += 1
        ev.append(.dayStarted(day: s.day, season: s.season))
        if s.season != oldSeason { ev.append(.seasonChanged(s.season)) }

        // 3. Lost birds come home if their day has come and a perch is free. A lost bird has no perch.
        var stillLost: [LostBird] = []
        for lb in s.lost.sorted(by: { $0.returnsOnDay < $1.returnsOnDay }) {
            guard lb.returnsOnDay <= s.day else { stillLost.append(lb); continue }
            if s.coop.count < s.perches {
                var b = lb.bird
                b.noLayUntilDay = s.day + r.scaredNoLayDays
                s.coop.append(b)
                ev.append(.birdReturned(b.id))
            } else {
                stillLost.append(lb)
                ev.append(.birdWaitingForPerch(lb.bird.id))
            }
        }
        s.lost = stillLost

        // 4. Growth and reveals.
        var brooder = s.brooder, coop = s.coop
        ev += grow(&brooder, day: s.day, rules: r, book: &s.breedBook)
        ev += grow(&coop, day: s.day, rules: r, book: &s.breedBook)
        s.brooder = brooder
        s.coop = coop
        ev += neighbourGiftIfNeeded(&s, &rng)

        // 5. Chicks leave the brooder when old enough and a perch is free.
        var stillInBrooder: [Bird] = []
        for b in s.brooder {
            if b.age(onDay: s.day) >= r.brooderDays {
                if s.coop.count < s.perches {
                    s.coop.append(b)
                    ev.append(.movedToCoop(b.id))
                } else {
                    stillInBrooder.append(b)
                    ev.append(.stuckInBrooder(b.id))
                }
            } else {
                stillInBrooder.append(b)
            }
        }
        s.brooder = stillInBrooder

        // 6. Broody hens that have sat long enough get up.
        for i in s.coop.indices {
            if let until = s.coop[i].broodyUntilDay, until <= s.day {
                s.coop[i].broodyUntilDay = nil
                ev.append(.broodyEnded(s.coop[i].id))
            }
        }

        // 7. Laying. Hens lay only if they were fed yesterday. Then a full nest may set a hen broody.
        ev += lay(&s, &rng)
        ev += maybeGoBroody(&s, &rng)

        // 8. Reset for the new day. The door is opened in the morning.
        s.fedToday = false
        s.coopDoorOpen = true
        return ev
    }

    static func grow(_ birds: inout [Bird], day: Int, rules: Rules, book: inout Set<BreedBookEntry>) -> [GameEvent] {
        var ev: [GameEvent] = []
        for i in birds.indices {
            let now = birds[i].stage(onDay: day, rules: rules)
            let before = birds[i].stage(onDay: day - 1, rules: rules)
            if now != before { ev.append(.grewUp(birds[i].id, now)) }
            if !birds[i].revealed && now >= .grower {
                birds[i].revealed = true
                ev.append(.revealed(birds[i].id, sex: birds[i].sex, breed: birds[i].breed))
                let entry = BreedBookEntry(birds[i])
                if book.insert(entry).inserted { ev.append(.newBreedBookEntry(entry)) }
            }
        }
        return ev
    }

    /// If the starter turns out to be a rooster, the neighbour gives a younger hen.
    static func neighbourGiftIfNeeded<R: RandomNumberGenerator>(_ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        guard !s.giftHenGiven, let id = s.starterID, let starter = s.bird(id),
              starter.revealed, starter.sex == .rooster else { return [] }
        let breed = Breed.starters.randomElement(using: &rng)!
        let colour = StarterColour.allCases.randomElement(using: &rng)!
        let hen = Bird(
            id: makeID(using: &rng), name: "Gift hen", breed: breed,
            genome: breed.purebred(.hen, colour: colour),
            hatchDay: s.day - s.rules.giftHenAge, origin: "Neighbour",
            revealed: true  // the neighbour tells you her breed and sex
        )
        s.giftHenGiven = true
        if s.brooder.count < s.brooderSize { s.brooder.append(hen) } else { s.coop.append(hen) }
        var ev: [GameEvent] = [.neighbourGaveHen(hen.id)]
        let entry = BreedBookEntry(hen)
        if s.breedBook.insert(entry).inserted { ev.append(.newBreedBookEntry(entry)) }
        return ev
    }

    static func lay<R: RandomNumberGenerator>(_ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        let hens = s.coop.filter { $0.sex == .hen && $0.stage(onDay: s.day, rules: s.rules) == .adult }
        guard !hens.isEmpty else { return [] }
        guard s.fedToday else { return [.noEggsHungry] }
        var ev: [GameEvent] = []
        let chance = s.rules.layChance[s.season] ?? 0
        for hen in hens where s.day >= hen.noLayUntilDay && !hen.isBroody(onDay: s.day) {
            guard Double.roll(chance, using: &rng) else { continue }
            // Nest boxes full: the hen lays on the floor, and the egg may break.
            if s.nest.count >= s.nestCapacity, Double.roll(s.rules.floorEggBreakChance, using: &rng) {
                ev.append(.eggBroken(by: hen.id))
                continue
            }
            let p = hen.phenotype
            let egg = Egg(id: makeID(using: &rng), layDay: s.day, motherID: hen.id,
                          colour: p.eggColour ?? .cream, speckled: p.eggIsSpeckled)
            s.nest.append(egg)
            ev.append(.eggLaid(egg.id, by: hen.id))
            let entry = EggBookEntry(colour: egg.colour, speckled: egg.speckled)
            if s.eggBook.insert(entry).inserted { ev.append(.newEggBookEntry(entry)) }
        }
        return ev
    }

    /// A pile of uncollected eggs can set a hen broody (real behaviour). Some breeds go broody far more.
    static func maybeGoBroody<R: RandomNumberGenerator>(_ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        guard s.nest.count >= s.rules.broodyNestEggs else { return [] }
        var ev: [GameEvent] = []
        for i in s.coop.indices {
            let hen = s.coop[i]
            guard hen.sex == .hen, hen.stage(onDay: s.day, rules: s.rules) == .adult,
                  !hen.isBroody(onDay: s.day) else { continue }
            if Double.roll(s.rules.broodyChance[hen.breed] ?? 0, using: &rng) {
                s.coop[i].broodyUntilDay = s.day + s.rules.broodyDays
                ev.append(.wentBroody(hen.id))
            }
        }
        return ev
    }
}
