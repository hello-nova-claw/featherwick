import Foundation

public enum Command: Hashable, Codable, Sendable {
    case chooseStarter(index: Int, name: String)
    case feed
    case collectEggs
    case sellEggs
    case closeCoop
    case passNight
    case buyIncubator
    /// Candle eggs from the carton and set the fertile ones in the incubator.
    case incubate(count: Int)
    /// Candle eggs from the carton and set the fertile ones under a broody hen.
    case sit(hen: UUID, count: Int)
    case rename(UUID, name: String)
    /// Hold every unchecked egg in the carton up to a light: shows which are fertile.
    case candle
    /// Sell every egg except the ones known to be fertile.
    case sellClearEggs
    /// A neighbour adopts the bird and pays for it. Rarer birds are worth more.
    case rehome(UUID)
    case upgradeCoop
    case buy(ShopItem)
    case acceptTrade
}

public enum Rejection: Hashable, Codable, Sendable {
    case chooseStarterFirst
    case alreadyStarted
    case noSuchChick
    case alreadyFed
    case nothingToFeed
    case noEggsInNest
    case cartonFull
    case cartonEmpty
    case notEnoughCoins(needed: Int, have: Int)
    case invalidAmount
    case coopAlreadyClosed
    case noSuchBird
    case noIncubator
    case alreadyHaveIncubator
    case incubatorBusy
    case notBroody
    case henAlreadySitting
    case clutchTooBig(max: Int)
    case notEnoughEggsInCarton(have: Int)
    case brooderFull(room: Int)
    case nothingToCandle
    case birdsBoarding
    case birdIsBusy
    case coopAtMax
    /// The player must always keep at least one bird, or the game could never continue.
    case lastBird
    case noFreePerch
    case noTradeOffer
}

public enum GameEvent: Hashable, Codable, Sendable {
    case rejected(Rejection)
    // Player actions
    case starterChosen(UUID)
    case fed(units: Int)
    case eggsCollected(count: Int, leftInNest: Int)
    case eggsSold(count: Int, coins: Int, stale: Int)
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
    /// A grown bird with no perch. It waits in the brooder until the player makes room.
    case needsHome(UUID)
    /// No perch and no brooder room: the neighbour keeps it. Hatching pauses until it has a home.
    case boardingWithNeighbour(UUID)
    case cameHomeFromBoarding(UUID)
    case noEggsHungry
    case eggLaid(UUID, by: UUID)
    case eggBroken(by: UUID)          // nest boxes full: laid on the floor and broke
    case newEggBookEntry(EggBookEntry)
    case wentBroody(UUID)
    case broodyEnded(UUID)
    /// Too many roosters for the hens: the hens are unsettled and lay less. Nobody is hurt.
    case roostersSquabbling(extra: Int)
    // Hatching
    case incubatorBought(cost: Int, size: Int)
    /// First fertile egg ever: the neighbour gives her old 1-egg incubator (and the CLI explains hatching).
    case neighbourGaveIncubator(size: Int)
    case candled(fertile: Int, clear: Int)
    case eggsSet(count: Int, hen: UUID?, hatchDay: Int)
    case chicksHatched([UUID], hen: UUID?)
    case renamed(UUID)
    case rehomed(UUID, coins: Int)
    case coopUpgraded(perches: Int, cost: Int)
    case boughtBird(UUID, item: ShopItem, cost: Int)
    case boughtEgg(cost: Int)
    case tradeOffered(rooster: UUID, hen: UUID)
    case tradeAccepted(rooster: UUID, hen: UUID)
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

        case .sellEggs, .sellClearEggs:
            let keepFertile = command == .sellClearEggs
            let selling = s.carton.filter { !(keepFertile && $0.isCandled && $0.isFertile) }
            if selling.isEmpty { return [.rejected(.cartonEmpty)] }
            let total = selling.reduce(0) { $0 + s.rules.price(of: $1, onDay: s.day) }
            let stale = selling.filter { s.rules.isStale($0, onDay: s.day) }.count
            let sold = Set(selling.map(\.id))
            s.coins += total
            s.carton.removeAll { sold.contains($0.id) }
            return [.eggsSold(count: selling.count, coins: total, stale: stale)]

        case .candle:
            let unchecked = s.carton.indices.filter { !s.carton[$0].isCandled }
            if unchecked.isEmpty { return [.rejected(s.carton.isEmpty ? .cartonEmpty : .nothingToCandle)] }
            for i in unchecked { s.carton[i].candled = true }
            let fertile = unchecked.filter { s.carton[$0].isFertile }.count
            return [.candled(fertile: fertile, clear: unchecked.count - fertile)]

        case .closeCoop:
            if !s.coopDoorOpen { return [.rejected(.coopAlreadyClosed)] }
            s.coopDoorOpen = false
            return [.coopClosed]

        case .passNight:
            return passNight(&s, &rng)

        case .buyIncubator:
            if s.incubatorSize >= s.rules.bigIncubatorSize { return [.rejected(.alreadyHaveIncubator)] }
            if s.incubatorClutch != nil { return [.rejected(.incubatorBusy)] }
            let cost = s.rules.incubatorPrice
            if s.coins < cost { return [.rejected(.notEnoughCoins(needed: cost, have: s.coins))] }
            s.coins -= cost
            s.incubatorSize = s.rules.bigIncubatorSize
            return [.incubatorBought(cost: cost, size: s.incubatorSize)]

        case .incubate(let count):
            if !s.hasIncubator { return [.rejected(.noIncubator)] }
            if !s.boarding.isEmpty { return [.rejected(.birdsBoarding)] }
            if s.incubatorClutch != nil { return [.rejected(.incubatorBusy)] }
            // Every egg set could hatch, so the brooder needs room for all of them.
            let room = s.brooderSize - s.brooder.count
            if room <= 0 { return [.rejected(.brooderFull(room: 0))] }
            if count > s.incubatorSize { return [.rejected(.clutchTooBig(max: s.incubatorSize))] }
            if let r = checkClutchSize(count, s) { return [.rejected(r)] }
            if count > room { return [.rejected(.brooderFull(room: room))] }
            return setEggs(count: count, hen: nil, hatchDay: s.day + s.rules.incubatorHatchDays, &s)

        case .sit(let henID, let count):
            guard let i = s.coop.firstIndex(where: { $0.id == henID }) else { return [.rejected(.noSuchBird)] }
            if !s.boarding.isEmpty { return [.rejected(.birdsBoarding)] }
            // Her chicks may need the brooder when grown, so a full brooder blocks hatching here too.
            if s.brooder.count >= s.brooderSize { return [.rejected(.brooderFull(room: 0))] }
            if !s.coop[i].isBroody(onDay: s.day) { return [.rejected(.notBroody)] }
            if s.clutch(under: henID) != nil { return [.rejected(.henAlreadySitting)] }
            if let r = checkClutchSize(count, s) { return [.rejected(r)] }
            let hatchDay = s.day + s.rules.broodyHatchDays
            let ev = setEggs(count: count, hen: henID, hatchDay: hatchDay, &s)
            if s.clutch(under: henID) != nil {
                // She sits, then raises her chicks until they are big enough for the coop.
                s.coop[i].broodyUntilDay = hatchDay + s.rules.brooderDays
            }
            return ev

        case .rename(let id, let name):
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return [.rejected(.invalidAmount)] }
            let groups: [WritableKeyPath<GameState, [Bird]>] = [\.brooder, \.henChicks, \.coop, \.boarding]
            for keyPath in groups {
                if let i = s[keyPath: keyPath].firstIndex(where: { $0.id == id }) {
                    s[keyPath: keyPath][i].name = trimmed
                    return [.renamed(id)]
                }
            }
            return [.rejected(.noSuchBird)]

        case .rehome(let id):
            if s.clutch(under: id) != nil || s.henChicks.contains(where: { $0.raisedBy == id }) {
                return [.rejected(.birdIsBusy)]
            }
            let owned = s.birdsAtHome.count + s.lost.count + s.boarding.count
            if owned <= 1, s.bird(id) != nil, !s.rehomed.contains(where: { $0.id == id }) {
                return [.rejected(.lastBird)]
            }
            let groups: [WritableKeyPath<GameState, [Bird]>] = [\.brooder, \.henChicks, \.coop, \.boarding]
            for keyPath in groups {
                if let i = s[keyPath: keyPath].firstIndex(where: { $0.id == id }) {
                    let bird = s[keyPath: keyPath].remove(at: i)
                    let coins = s.rules.rehomeValue(of: bird, onDay: s.day)
                    s.coins += coins
                    s.rehomed.append(bird)
                    if s.starterID == id { s.starterID = nil }
                    if s.tradeOffer?.roosterID == id { s.tradeOffer = nil }  // a new offer comes in the morning if needed
                    return [.rehomed(id, coins: coins)]
                }
            }
            return [.rejected(.noSuchBird)]

        case .buy(let item):
            return buy(item, &s, &rng)

        case .acceptTrade:
            guard let offer = s.tradeOffer else { return [.rejected(.noTradeOffer)] }
            let groups: [WritableKeyPath<GameState, [Bird]>] = [\.coop, \.brooder]
            for keyPath in groups {
                if let i = s[keyPath: keyPath].firstIndex(where: { $0.id == offer.roosterID }) {
                    let rooster = s[keyPath: keyPath][i]
                    s[keyPath: keyPath][i] = offer.hen   // she takes his place
                    s.rehomed.append(rooster)
                    s.tradeOffer = nil
                    if s.starterID == rooster.id { s.starterID = nil }
                    var ev: [GameEvent] = [.tradeAccepted(rooster: rooster.id, hen: offer.hen.id)]
                    let entry = BreedBookEntry(offer.hen)
                    if s.breedBook.insert(entry).inserted { ev.append(.newBreedBookEntry(entry)) }
                    return ev
                }
            }
            s.tradeOffer = nil  // that rooster is no longer at home; a new offer comes in the morning if needed
            return [.rejected(.noTradeOffer)]

        case .upgradeCoop:
            if s.perches >= s.rules.maxPerches { return [.rejected(.coopAtMax)] }
            let cost = s.rules.coopUpgradePrice
            if s.coins < cost { return [.rejected(.notEnoughCoins(needed: cost, have: s.coins))] }
            s.coins -= cost
            s.perches = min(s.rules.maxPerches, s.perches + s.rules.perchesPerUpgrade)
            return [.coopUpgraded(perches: s.perches, cost: cost)]
        }
    }

    // MARK: - Shop and safety net

    /// A young bird from a local flock: a starter breed, random colour, breed and sex known.
    static func youngBird<R: RandomNumberGenerator>(_ sex: Sex, origin: String, _ s: GameState, _ rng: inout R) -> Bird {
        let breed = Breed.starters.randomElement(using: &rng)!
        let colour = StarterColour.allCases.randomElement(using: &rng)!
        return Bird(
            id: makeID(using: &rng), name: sex == .hen ? "New pullet" : "New cockerel", breed: breed,
            genome: breed.purebred(sex, colour: colour), hatchDay: s.day - s.rules.growerAge,
            origin: origin, revealed: true
        )
    }

    static func buy<R: RandomNumberGenerator>(_ item: ShopItem, _ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        let cost = switch item {
        case .pullet: s.rules.pulletPrice
        case .cockerel: s.rules.cockerelPrice
        case .fertileEgg: s.rules.fertileEggPrice
        }
        if s.coins < cost { return [.rejected(.notEnoughCoins(needed: cost, have: s.coins))] }
        switch item {
        case .pullet, .cockerel:
            if s.coop.count >= s.perches { return [.rejected(.noFreePerch)] }
            let bird = youngBird(item == .pullet ? .hen : .rooster, origin: "Speckle & Down", s, &rng)
            s.coins -= cost
            s.coop.append(bird)
            var ev: [GameEvent] = [.boughtBird(bird.id, item: item, cost: cost)]
            let entry = BreedBookEntry(bird)
            if s.breedBook.insert(entry).inserted { ev.append(.newBreedBookEntry(entry)) }
            return ev
        case .fertileEgg:
            if s.carton.count >= s.cartonCapacity { return [.rejected(.cartonFull)] }
            let motherBreed = Breed.starters.randomElement(using: &rng)!
            let fatherBreed = Breed.starters.randomElement(using: &rng)!
            let mother = motherBreed.purebred(.hen, colour: StarterColour.allCases.randomElement(using: &rng)!)
            let father = fatherBreed.purebred(.rooster, colour: StarterColour.allCases.randomElement(using: &rng)!)
            let p = Phenotype(mother)
            var egg = Egg(id: makeID(using: &rng), layDay: s.day, motherID: makeID(using: &rng),
                          colour: p.eggColour ?? .cream, speckled: p.eggIsSpeckled,
                          collectedDay: s.day, motherBreed: motherBreed)
            egg.fatherID = makeID(using: &rng)
            egg.embryo = try? Breeding.cross(mother: mother, father: father, using: &rng)
            egg.candled = true
            s.coins -= cost
            s.carton.append(egg)
            return [.boughtEgg(cost: cost)]
        }
    }

    static func updateTradeOffer<R: RandomNumberGenerator>(_ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        let owned = s.ownedBirds
        let stuck = !owned.contains { $0.sex == .hen } && s.coins < s.rules.pulletPrice
        guard stuck else { s.tradeOffer = nil; return [] }
        // Keep an existing offer while its rooster is still at home.
        if let offer = s.tradeOffer, (s.coop + s.brooder).contains(where: { $0.id == offer.roosterID }) { return [] }
        guard let rooster = (s.coop + s.brooder).first(where: { $0.sex == .rooster }) else {
            s.tradeOffer = nil  // every rooster is out; they come home, and the offer comes then
            return []
        }
        var hen = youngBird(.hen, origin: "A Featherwick neighbour", s, &rng)
        hen.name = "Traded pullet"
        s.tradeOffer = TradeOffer(roosterID: rooster.id, hen: hen)
        return [.tradeOffered(rooster: rooster.id, hen: hen.id)]
    }

    // MARK: - Hatching

    /// Eggs worth trying to hatch, best first: known fertile, then unchecked. Known-clear eggs are skipped.
    static func hatchCandidates(_ s: GameState, count: Int) -> [Egg] {
        let known = s.carton.filter { $0.isCandled && $0.isFertile }
        let unchecked = s.carton.filter { !$0.isCandled }
        return Array((known + unchecked).prefix(count))
    }

    static func checkClutchSize(_ count: Int, _ s: GameState) -> Rejection? {
        if count < 1 { return .invalidAmount }
        if count > s.rules.maxClutch { return .clutchTooBig(max: s.rules.maxClutch) }
        let usable = hatchCandidates(s, count: Int.max).count
        if usable < count { return .notEnoughEggsInCarton(have: usable) }
        return nil
    }

    /// Candles the chosen eggs. Clear (infertile) eggs stay in the carton, now marked as clear.
    /// Only fertile eggs are set, so every egg that is set will hatch (cozy rule).
    static func setEggs(count: Int, hen: UUID?, hatchDay: Int, _ s: inout GameState) -> [GameEvent] {
        let chosen = hatchCandidates(s, count: count)
        let chosenIDs = Set(chosen.map(\.id))
        let fertile = chosen.filter(\.isFertile)
        s.carton.removeAll { chosenIDs.contains($0.id) && $0.isFertile }
        for i in s.carton.indices where chosenIDs.contains(s.carton[i].id) { s.carton[i].candled = true }
        let newlyChecked = chosen.filter { !$0.isCandled }
        let newlyFertile = newlyChecked.filter(\.isFertile).count
        var ev: [GameEvent] = []
        if !newlyChecked.isEmpty {
            ev.append(.candled(fertile: newlyFertile, clear: newlyChecked.count - newlyFertile))
        }
        if !fertile.isEmpty {
            s.clutches.append(Clutch(henID: hen, eggs: fertile, hatchDay: hatchDay))
            ev.append(.eggsSet(count: fertile.count, hen: hen, hatchDay: hatchDay))
        }
        return ev
    }

    static func hatchDue<R: RandomNumberGenerator>(_ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        var ev: [GameEvent] = []
        var waiting: [Clutch] = []
        for clutch in s.clutches {
            guard clutch.hatchDay <= s.day else { waiting.append(clutch); continue }
            var ids: [UUID] = []
            for egg in clutch.eggs {
                guard let genome = egg.embryo else { continue }
                s.chicksHatched += 1
                let chick = Bird(
                    id: makeID(using: &rng), name: "Chick \(s.chicksHatched)",
                    breed: egg.motherBreed ?? .orpington, genome: genome, hatchDay: s.day,
                    motherID: egg.motherID, fatherID: egg.fatherID, origin: "Henhaven"
                )
                if let hen = clutch.henID {
                    var raised = chick
                    raised.raisedBy = hen
                    s.henChicks.append(raised)
                } else {
                    s.brooder.append(chick)
                }
                ids.append(chick.id)
            }
            ev.append(.chicksHatched(ids, hen: clutch.henID))
        }
        s.clutches = waiting
        return ev
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
        //    Broody and mothering hens hold their ground, and their chicks stay hidden under them.
        let canFlee = s.coop.filter { !$0.isBroody(onDay: s.day) }
        if s.coopDoorOpen, !canFlee.isEmpty, Double.roll(r.foxChance, using: &rng) {
            var stay = s.coop.filter { $0.isBroody(onDay: s.day) }
            var calm: [Bird] = []
            var scared: [Bird] = []
            for b in canFlee {
                if Double.roll(r.fleeChance, using: &rng) { scared.append(b) } else { calm.append(b) }
            }
            if scared.isEmpty {
                scared.append(calm.remove(at: Int.random(in: 0..<calm.count, using: &rng)))
            }
            stay += calm
            s.coop = s.coop.filter { b in stay.contains { $0.id == b.id } }
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
        var brooder = s.brooder, henChicks = s.henChicks, coop = s.coop
        ev += grow(&brooder, day: s.day, rules: r, book: &s.breedBook)
        ev += grow(&henChicks, day: s.day, rules: r, book: &s.breedBook)
        ev += grow(&coop, day: s.day, rules: r, book: &s.breedBook)
        s.brooder = brooder
        s.henChicks = henChicks
        s.coop = coop
        ev += neighbourGiftIfNeeded(&s, &rng)

        // 5. Eggs due today hatch: incubator chicks go to the brooder, broody-hatched chicks stay with their mother.
        ev += hatchDue(&s, &rng)

        // 6. Grown chicks and boarding birds find homes (a free perch), or wait.
        ev += findHomes(&s)

        // 7. Broody hens that have sat (and mothered) long enough get up.
        for i in s.coop.indices {
            if let until = s.coop[i].broodyUntilDay, until <= s.day {
                s.coop[i].broodyUntilDay = nil
                ev.append(.broodyEnded(s.coop[i].id))
            }
        }

        // 8. Laying. Hens lay only if they were fed yesterday. Then a full nest may set a hen broody.
        ev += lay(&s, &rng)
        ev += maybeGoBroody(&s, &rng)

        // 9. Safety net: a rooster-only flock that can't afford a pullet gets a trade offer.
        ev += updateTradeOffer(&s, &rng)

        // 10. Reset for the new day. The door is opened in the morning.
        s.fedToday = false
        s.coopDoorOpen = true
        return ev
    }

    /// Perches go first to birds boarding with the neighbour, then grown brooder birds, then grown hen chicks.
    /// A grown bird with no perch waits in the brooder; if the brooder is full too, the neighbour boards it.
    static func findHomes(_ s: inout GameState) -> [GameEvent] {
        var ev: [GameEvent] = []
        let day = s.day, brooderDays = s.rules.brooderDays
        let grown = { (b: Bird) in b.age(onDay: day) >= brooderDays }

        var stillBoarding: [Bird] = []
        for b in s.boarding {
            if s.coop.count < s.perches { s.coop.append(b); ev.append(.cameHomeFromBoarding(b.id)) }
            else { stillBoarding.append(b) }
        }
        s.boarding = stillBoarding

        var inBrooder: [Bird] = []
        for b in s.brooder {
            guard grown(b) else { inBrooder.append(b); continue }
            if s.coop.count < s.perches { s.coop.append(b); ev.append(.movedToCoop(b.id)) }
            else { inBrooder.append(b); ev.append(.needsHome(b.id)) }
        }
        s.brooder = inBrooder

        var withMother: [Bird] = []
        for b in s.henChicks {
            guard grown(b) else { withMother.append(b); continue }
            if s.coop.count < s.perches { s.coop.append(b); ev.append(.movedToCoop(b.id)) }
            else if s.brooder.count < s.brooderSize { s.brooder.append(b); ev.append(.needsHome(b.id)) }
            else { s.boarding.append(b) }
        }
        s.henChicks = withMother

        for b in s.boarding { ev.append(.boardingWithNeighbour(b.id)) }
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
        let extra = s.rules.extraRoosters(inCoop: s.coop, onDay: s.day)
        if extra > 0 { ev.append(.roostersSquabbling(extra: extra)) }
        let calm = max(0, 1 - Double(extra) * s.rules.extraRoosterLayPenalty)
        let chance = (s.rules.layChance[s.season] ?? 0) * calm
        // Any adult rooster in the coop fertilises the hens' eggs. (A breeding pen comes later.)
        let roosters = s.coop.filter { $0.sex == .rooster && $0.stage(onDay: s.day, rules: s.rules) == .adult }
        for hen in hens where s.day >= hen.noLayUntilDay && !hen.isBroody(onDay: s.day) {
            guard Double.roll(chance, using: &rng) else { continue }
            // Nest boxes full: the hen lays on the floor, and the egg may break.
            if s.nest.count >= s.nestCapacity, Double.roll(s.rules.floorEggBreakChance, using: &rng) {
                ev.append(.eggBroken(by: hen.id))
                continue
            }
            let p = hen.phenotype
            var egg = Egg(id: makeID(using: &rng), layDay: s.day, motherID: hen.id,
                          colour: p.eggColour ?? .cream, speckled: p.eggIsSpeckled, motherBreed: hen.breed)
            if !roosters.isEmpty, Double.roll(s.rules.fertileChance, using: &rng) {
                let father = roosters[Int.random(in: 0..<roosters.count, using: &rng)]
                egg.fatherID = father.id
                egg.embryo = try? Breeding.cross(mother: hen.genome, father: father.genome, using: &rng)
            }
            s.nest.append(egg)
            ev.append(.eggLaid(egg.id, by: hen.id))
            if egg.isFertile, !s.incubatorGiftGiven {
                s.incubatorGiftGiven = true
                // Only offered if the player has no incubator yet (they may have bought the big one).
                if !s.hasIncubator {
                    s.incubatorSize = s.rules.giftIncubatorSize
                    ev.append(.neighbourGaveIncubator(size: s.rules.giftIncubatorSize))
                }
            }
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
