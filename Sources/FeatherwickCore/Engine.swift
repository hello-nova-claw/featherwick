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
    /// Pick a bird up and handle it gently. Counts once a day per bird.
    case pet(UUID)
    /// Give a bird a treat from your hand. Uses one treat. Counts once a day per bird.
    case giveTreat(UUID)
    /// Hand over what a storyline step asks for (for example, fertile eggs).
    case deliver(story: String)
    /// Enter a bird in the next county show in its default class: its breed class, or the pet class.
    case enterShow(UUID)
    /// Enter your best matched plate of eggs in the next county show.
    case enterEggs
    /// Feed the flock premium feed for the day: feeds them AND lifts laying a little. Uses one portion.
    case feedPremium
    /// Set these exact eggs from the carton in the incubator. Setting never candles them: a clear egg sits
    /// the full time and comes back on hatch day. Eggs already known to be clear are refused.
    case incubateEggs([UUID])
    /// Set these exact eggs from the carton under a broody hen.
    case sitEggs(hen: UUID, eggs: [UUID])
    /// Sell these exact eggs from the carton.
    case sellChosenEggs([UUID])
    /// Hold one egg up to a light: shows if it is fertile. Needs the candling lesson.
    case candleEgg(UUID)
    /// Enter a bird in the next county show in a chosen class (see `Engine.eligibleClasses`).
    case enterShowIn(UUID, ShowClass)
    /// Enter exactly these carton eggs as a plate in the next county show: a matched plate of 3.
    case enterEggPlate([UUID])
    /// Buy Speckle & Down's daily special (see Shop.swift). One a day.
    case buySpecial
    /// Put a coop bird in the breeding pen (see BreedingPen.swift). Its perch stays in the coop.
    case penBird(UUID)
    /// Take a bird out of the breeding pen. It stays on its coop perch.
    case unpenBird(UUID)
    /// Sit a while: spends one slot of daylight and does nothing else (see Daylight.swift).
    case rest
    /// The keeper opened the "What might hatch" panel (see Planner.swift). Clears the pen's "New" notice.
    /// Costs no daylight and says nothing. Does nothing before the keeper has met the planner.
    case openPlanner
    /// The keeper's own name, for the neighbour and the shop to use. Any time, even before the starter.
    case nameKeeper(String)
    /// "Hen or roo?": guess a chick's sex before it shows (see SexGuess.swift). Once per chick, free.
    case guessSex(UUID, Sex)
    /// Pick an option at a story's choice step (see Story.swift). Free: it is a word over the fence.
    case choose(story: String, option: String)
    /// Pay a debt in full (see Loans.swift). Any time the keeper has the coins. Free.
    case payDebt(String)
    /// Bring a known-fertile egg to the Hatch-along (see HatchAlong.swift). Nil: the first known-fertile
    /// egg in the carton. A chick comes back `Rules.hatchAlongReturnNights` later.
    case giveHatchAlongEgg(UUID?)
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
    case birdNotHome
    case alreadyPettedToday
    case alreadyHadTreatToday
    case noTreats
    case nothingToDeliver
    case needFertileEggs(need: Int, have: Int)
    case nameTaken
    case nameTooLong(max: Int)
    /// A chick cannot be shown, and a bird may enter only the classes it is eligible for.
    case notShowEligible
    /// That bird is already entered in the next show.
    case alreadyEntered
    /// No matched plate of 3 eggs in the carton to enter, or the chosen eggs do not make one.
    case noMatchedPlate
    case noPremiumFeed
    case alreadyFedPremium
    /// A chosen egg is not in the carton.
    case noSuchEgg
    /// A chosen egg is already known to be clear, so it can never hatch.
    case eggIsClear
    /// The incubator has room for only this many more eggs.
    case incubatorFull(room: Int)
    /// The player has not learned to candle yet.
    case cannotCandleYet
    /// That egg has already been held up to the light.
    case alreadyCandled
    /// Today's special is already sold. A new one comes tomorrow.
    case specialSoldOut
    /// The early game has not reached this feature yet (see EarlyGame.swift).
    case notYet(Feature)
    /// The breeding pen already holds this many hens.
    case penFull(hens: Int)
    /// The breeding pen already holds a rooster. One at a time.
    case penHasRooster
    /// That bird is not in the breeding pen.
    case notInPen
    /// That bird is already in the breeding pen.
    case alreadyInPen
    /// Only coop birds can go in the pen.
    case notInCoop
    /// The bird's sex does not show yet. The words must not say which it is.
    case tooYoungForPen
    /// No daylight left for an errand of this kind today (see Daylight.swift). It waits for the morning.
    case noTimeLeft(Errand)
    /// Sleep waits until the day's daylight is spent.
    case notEveningYet(slotsLeft: Int)
    /// A rest with no daylight left: it is time for bed.
    case timeForBed
    /// A keeper's name needs at least one letter.
    case blankName
    /// The chick's sex shows already, or it is past the age for a guess. Fires on age, never on sex.
    case tooLateToGuess
    /// The keeper has already guessed hen or roo for this chick.
    case alreadyGuessed
    /// No story is waiting for that choice, or that option is not one of its options.
    case noSuchChoice
    /// The keeper owes no debt by that ID.
    case noSuchDebt
    /// The bird is on loan: she cannot be rehomed, penned or renamed (see Loans.swift).
    case onLoan
    /// A story asks for this many eggs of this colour, and the carton has fewer.
    case needEggs(EggColour, need: Int, have: Int)
    /// A story asks for this many eggs of one colour new to the Egg Book (one of these), and the carton
    /// has at most `have` of any of them.
    case needEggsOfNewColour([EggColour], need: Int, have: Int)
    /// The Hatch-along can't take an egg now (see HatchAlong.swift).
    case hatchAlong(HatchAlongRefusal)
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
    /// No perch came free in time, so the neighbour found the bird a good home. The keeper is paid.
    case rehomedByNeighbour(UUID, coins: Int)
    /// A new bird kept no name for a while, so it took its suggested name. It can be renamed.
    case namedForYou(UUID)
    case cameHomeFromBoarding(UUID)
    case noEggsHungry
    case eggLaid(UUID, by: UUID)
    case eggBroken(by: UUID)  // nest boxes full: laid on the floor and broke
    case newEggBookEntry(EggBookEntry)
    case wentBroody(UUID)
    case broodyEnded(UUID)
    /// Too many roosters for the hens: the hens are unsettled and lay less. Nobody is hurt.
    case roostersSquabbling(extra: Int)
    // Hatching
    case incubatorBought(cost: Int, size: Int)
    /// First fertile egg ever: the neighbour gives her old 1-egg incubator (and the words explain hatching).
    /// `ownRooster`: a hen laid it. False when the egg came from elsewhere (bought at Speckle & Down).
    case neighbourGaveIncubator(size: Int, ownRooster: Bool)
    case candled(fertile: Int, clear: Int)
    case eggsSet(count: Int, hen: UUID?, hatchDay: Int)
    case chicksHatched([UUID], hen: UUID?)
    /// Clear eggs that were set without being candled first. They sit the full time, never hatch, and go back
    /// to the carton (or the nest boxes if the carton is full), now known to be clear.
    case eggsDidNotHatch(count: Int, hen: UUID?)
    /// A chick hatched looking like neither parent, and the neighbour says why (see `HatchWhy.swift`).
    /// Comes after the chick's `chicksHatched`. At most `Rules.hatchWhyNotesPerDay` a day.
    case hatchSurprise(chick: UUID, reason: HatchReason)
    /// The neighbour shows the keeper how to candle eggs.
    case learnedCandling
    case renamed(UUID)
    case rehomed(UUID, coins: Int)
    case coopUpgraded(perches: Int, cost: Int)
    case boughtBird(UUID, item: ShopItem, cost: Int)
    case boughtEgg(cost: Int)
    case tradeOffered(rooster: UUID, hen: UUID)
    case tradeAccepted(rooster: UUID, hen: UUID)
    case boughtTreats(count: Int, cost: Int)
    case storyStarted(String)
    case storyStep(String, step: String)
    case delivered(String)
    case storyGiftWaitingForRoom(String)
    case storyGift(String, UUID)
    case shopUnlocked(Breed)
    case storyFinished(String)
    case handled(UUID, Handling)
    /// The bird moved up a friendliness band.
    case friendlierNow(UUID, Friendliness)
    // County show (see ShowEvent.swift)
    /// Entered in the next show. Bird id (nil for eggs) and the class it will compete in.
    case enteredInShow(UUID?, ShowClass)
    case showDay(day: Int)
    case showNoEntries
    /// The top three in a class the keeper entered, rivals included, best first. Before its placings.
    case showPodium(ShowClass, [PodiumPlace])
    case showPlacing(ShowResult)
    /// A rival bird on a podium showed a look the keeper has never owned or seen: a "seen" Breed Book entry.
    case breedBookEntrySeen(BreedBookEntry, ShowTheme)
    case showPrizesWon(coins: Int)
    case boughtPremiumFeed(count: Int, cost: Int)
    case fedPremium(units: Int)
    /// A hen reached retirement age today: a beloved non-layer from now on.
    case birdRetired(UUID)
    /// The flock free-ranged overnight (door left open) and came back fed and foraged.
    case birdsForaged(count: Int)
    /// First time rooster tension bites: a one-off tip on how to fix it (rehome a spare, or trade).
    case roosterAdvice
    /// A goal-ladder milestone was reached this night (see Milestone.swift). Awarded once.
    case milestoneReached(String)
    /// Treats won at the county show (the pet class pays treats). Added to the bag.
    case showTreatsWon(treats: Int)
    /// Bought Speckle & Down's daily special. The bird is in the coop, waiting for a name.
    case boughtSpecial(UUID, cost: Int)
    /// The early game introduced a lesson or opened a part of the game (see EarlyGame.swift).
    case introduced(Feature)
    /// The county show opened. The neighbour suggests a bird and a class (nil when no bird can be shown yet).
    case showAnnounced(ShowTip?)
    /// This morning's jobs are set (see Jobs.swift). The jobs are in `GameState.todaysJobs`.
    case jobsSet(count: Int)
    /// One of today's jobs is done.
    case jobDone(JobKind)
    /// Every job today is done. The keeper is paid a small reward, once a day.
    case allJobsDone(coins: Int)
    /// A new season goal. `previous` is last season's goal if it was not reached: it simply makes way.
    case seasonGoalSet(GoalKind, previous: GoalKind?)
    /// The season goal moved on overnight.
    case seasonGoalProgress(GoalKind, progress: Int, target: Int)
    /// The season goal is reached. The keeper is paid a bigger reward, once.
    case seasonGoalReached(GoalKind, coins: Int)
    /// The bird is in the breeding pen now (see BreedingPen.swift).
    case birdPenned(UUID)
    /// The bird left the breeding pen. It stays on its coop perch.
    case birdUnpenned(UUID)
    /// A slot of daylight is spent: on an errand, or on a rest (nil). `left` is what remains today.
    case slotSpent(Errand?, left: Int)
    /// The keeper sat a while. The time of day the rest was taken in, for the words.
    case rested(TimeOfDay)
    /// The first hatch-day "why" note also showed the keeper that hatches can be worked out ahead of
    /// time: "What might hatch" is open now (see Planner.swift). Right after that `hatchSurprise`. Once a game.
    case plannerIntroduced
    /// The keeper gave their name.
    case keeperNamed(String)
    /// The breeding pen is open, and "What might hatch" with it, for a keeper who has not had a surprise
    /// chick yet (see `EarlyGame.swift`). Once a game, like `plannerIntroduced`.
    case plannerShownAtPen
    /// The keeper guessed hen or roo for a chick (see SexGuess.swift).
    case sexGuessed(UUID, Sex)
    /// The morning the chick's sex showed: the keeper's guess and the truth. A right guess paid
    /// `Rules.sexGuessTreats`. Comes after the chick's `revealed`.
    case sexGuessResolved(UUID, guessed: Sex, actual: Sex)
    /// The keeper picked an option at a story's choice step (see Story.swift).
    case chose(String, String)
    /// A story gave coins.
    case storyCoins(String, Int)
    /// A story gave mealworms.
    case storyTreats(String, Int)
    /// A story gave an egg of this breed. It is in the carton, candled.
    case storyGiftEgg(String, Breed)
    /// A bird came to stay on loan (see Loans.swift).
    case loanArrived(UUID, from: Person)
    /// A loaned bird went home to her owner. Her family-tree record stays.
    case loanReturned(UUID, to: Person)
    /// The keeper kept a loaned bird. She is the keeper's now.
    case loanKept(UUID, from: Person)
    /// The keeper owes a debt now. No interest, no deadline.
    case debtOwed(String, to: Person, coins: Int)
    /// The owner mentions a debt, kindly. At most once a season.
    case debtReminder(String, to: Person)
    case debtPaid(String, to: Person, coins: Int)
    /// A note came in the post (see Post.swift). The words come from the note's ID.
    case noteArrived(Person, String)
    /// A village day is this many days away (see VillageDay.swift).
    case villageDayComing(VillageDay, inDays: Int)
    /// Today is a village day.
    case villageDay(VillageDay)
    /// A person named a newly hatched chick, as a story promised (`StoryReward.namesNextChick`).
    /// Comes after the chick's `chicksHatched`. The keeper can rename it.
    case chickNamed(UUID, by: Person)
    /// What a village day brings, in that year's words (year 0 is the first). After `.villageDay`.
    case villageDayScene(VillageDay, year: Int)
    /// A village day's gift, in the purse and the bag now: Moult Week treats, Midwinter Lights coins.
    case villageDayGift(VillageDay, coins: Int, treats: Int)
    /// The keeper brought an egg to the Hatch-along. A chick comes back on `returnsOnDay`.
    case hatchAlongEggGiven(returnsOnDay: Int)
    /// The Hatch-along chick is ready, but there is no room yet: it waits with Hazel. Once per wait.
    case hatchAlongChickWaiting
    /// The Hatch-along chick came home to the brooder. Its breed and sex show as it grows.
    case hatchAlongChickArrived(UUID)
}

/// The game engine: command in, events out. No I/O, no system clock, no global random.
public enum Engine {
    /// A new game: the neighbour offers 3 chicks. With `earlyGame` (the default) the keeper learns one
    /// thing at a time (EarlyGame.swift); without it, every feature is open from day 0.
    public static func newGame<R: RandomNumberGenerator>(
        rules: Rules = .standard, earlyGame: Bool = true, using rng: inout R
    ) -> GameState {
        var chicks: [Bird] = []
        for breed in Breed.starters.shuffled(using: &rng) {
            let sex: Sex = Bool.random(using: &rng) ? .hen : .rooster
            let colour = breed.definition.varieties.randomElement(using: &rng)!
            let barred = Double.roll(0.25, using: &rng)
            chicks.append(
                Bird(
                    id: makeID(using: &rng), name: "", breed: breed,
                    genome: breed.purebred(sex, variety: colour, barred: barred),
                    hatchDay: 0, origin: Bird.neighbourOrigin
                ).withFounderQuality().withTameness(rules.brooderChickTameness))
        }
        var s = GameState(rules: rules, phase: .choosingStarter(chicks))
        // The game starts on day 1. The chicks hatched the day before, so ages and the timeline stay as
        // they were when games started on day 0: only the empty first night is gone.
        s.day = 1
        s.canCandle = false  // learned from the neighbour after the first hatch, or for a story
        if earlyGame { s.introduced = [] }  // introduced one thing at a time (EarlyGame.swift)
        s.shopSeed = chicks.first.map { ShopSpecial.seed(from: $0.id) } ?? 0  // no extra RNG draw
        return s
    }

    public static func apply<R: RandomNumberGenerator>(
        _ command: Command, to s: inout GameState, using rng: inout R
    ) -> [GameEvent] {
        let ev = perform(command, to: &s, using: &rng)
        datePages(after: ev, &s)
        // A bird that left the coop (rehomed, traded, scared off) leaves the pen too: no stale ids.
        leavePenIfGone(&s)
        // A guess goes with a bird that left, silently (see SexGuess.swift).
        dropStaleSexGuesses(&s)
        // Today's jobs tick off as the keeper does them. The night sets new ones itself.
        if command == .passNight { return ev }
        return ev + progressJobs(after: ev, &s)
    }

    /// Notes the day each new Breed Book look was found. A look found at night gets the new morning's day.
    static func datePages(after ev: [GameEvent], _ s: inout GameState) {
        for case .newBreedBookEntry(let entry) in ev where s.breedBookDays[entry] == nil {
            s.breedBookDays[entry] = s.day
        }
    }

    /// One command, without the job tracking that `apply` adds.
    static func perform<R: RandomNumberGenerator>(
        _ command: Command, to s: inout GameState, using rng: inout R
    ) -> [GameEvent] {
        if case .chooseStarter(let index, let name) = command {
            return chooseStarter(index: index, name: name, &s)
        }
        if case .nameKeeper(let name) = command { return nameKeeper(name, &s) }
        guard s.phase == .playing else { return [.rejected(.chooseStarterFirst)] }
        if let feature = feature(for: command), !s.isOpen(feature) { return [.rejected(.notYet(feature))] }
        if let refusal = daylightRefusal(for: command, in: s) { return [.rejected(refusal)] }
        let ev = carryOut(command, &s, &rng)
        return ev + spendDaylight(on: command, after: ev, &s)
    }

    /// The command itself, once the starter, early-game and daylight gates have let it through.
    static func carryOut<R: RandomNumberGenerator>(
        _ command: Command, _ s: inout GameState, _ rng: inout R
    ) -> [GameEvent] {
        switch command {
        case .chooseStarter, .nameKeeper:
            return []  // handled in `perform`
        case .feed:
            let needed = s.birdsAtHome.count
            if needed == 0 { return [.rejected(.nothingToFeed)] }
            if s.fedToday { return [.rejected(.alreadyFed)] }
            s.fedToday = true
            return [.fed(units: needed)]

        case .feedPremium:
            let needed = s.birdsAtHome.count
            if needed == 0 { return [.rejected(.nothingToFeed)] }
            if s.fedPremiumToday { return [.rejected(.alreadyFedPremium)] }
            if s.premiumFeed <= 0 { return [.rejected(.noPremiumFeed)] }
            s.premiumFeed -= 1
            s.fedPremiumToday = true
            s.fedToday = true  // premium feed covers the day's feeding too
            return [.fedPremium(units: needed)]

        case .collectEggs:
            if s.nest.isEmpty { return [.rejected(.noEggsInNest)] }
            let space = s.cartonCapacity - s.carton.count
            if space <= 0 { return [.rejected(.cartonFull)] }
            var moving = Array(s.nest.prefix(space))
            // An unhatched egg back in the nest keeps its first collected day, so its price stays the same.
            for i in moving.indices where moving[i].collectedDay == nil { moving[i].collectedDay = s.day }
            s.nest.removeFirst(moving.count)
            s.carton += moving
            return [.eggsCollected(count: moving.count, leftInNest: s.nest.count)]

        case .sellEggs, .sellClearEggs:
            let keepFertile = command == .sellClearEggs
            let selling = s.carton.filter { !(keepFertile && $0.isCandled && $0.isFertile) }
            if selling.isEmpty { return [.rejected(.cartonEmpty)] }
            return sell(selling, &s)

        case .sellChosenEggs(let ids):
            let (eggs, problem) = chosenEggs(ids, s)
            if let problem { return [.rejected(problem)] }
            return sell(eggs, &s)

        case .candleEgg(let id):
            if !s.canCandle { return [.rejected(.cannotCandleYet)] }
            guard let i = s.carton.firstIndex(where: { $0.id == id }) else { return [.rejected(.noSuchEgg)] }
            if s.carton[i].isCandled { return [.rejected(.alreadyCandled)] }
            s.carton[i].candled = true
            let fertile = s.carton[i].isFertile
            return [.candled(fertile: fertile ? 1 : 0, clear: fertile ? 0 : 1)]

        case .candle:
            if !s.canCandle { return [.rejected(.cannotCandleYet)] }
            let unchecked = s.carton.indices.filter { !s.carton[$0].isCandled }
            if unchecked.isEmpty { return [.rejected(s.carton.isEmpty ? .cartonEmpty : .nothingToCandle)] }
            for i in unchecked { s.carton[i].candled = true }
            let fertile = unchecked.count(where: { s.carton[$0].isFertile })
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
            if let r = incubatorBlocker(s) { return [.rejected(r)] }
            let space = incubatorSpace(s)
            if count > space { return [.rejected(.clutchTooBig(max: space))] }
            if let r = checkClutchSize(count, s) { return [.rejected(r)] }
            let room = brooderRoom(s)
            if count > room { return [.rejected(.brooderFull(room: room))] }
            return setEggs(hatchCandidates(s, count: count), hen: nil, hatchDay: incubatorHatchDay(s), &s)

        case .incubateEggs(let ids):
            if let r = incubatorBlocker(s) { return [.rejected(r)] }
            let (eggs, problem) = chosenEggs(ids, s)
            if let problem { return [.rejected(problem)] }
            if eggs.contains(where: { $0.isCandled && !$0.isFertile }) { return [.rejected(.eggIsClear)] }
            let space = incubatorSpace(s)
            if eggs.count > space { return [.rejected(.incubatorFull(room: space))] }
            let room = brooderRoom(s)
            if eggs.count > room { return [.rejected(.brooderFull(room: room))] }
            return setEggs(eggs, hen: nil, hatchDay: incubatorHatchDay(s), &s)

        case .sit(let henID, let count):
            if let r = sitBlocker(henID, s) { return [.rejected(r)] }
            if let r = checkClutchSize(count, s) { return [.rejected(r)] }
            return sit(henID, on: hatchCandidates(s, count: count), &s)

        case .sitEggs(let henID, let ids):
            if let r = sitBlocker(henID, s) { return [.rejected(r)] }
            let (eggs, problem) = chosenEggs(ids, s)
            if let problem { return [.rejected(problem)] }
            if eggs.contains(where: { $0.isCandled && !$0.isFertile }) { return [.rejected(.eggIsClear)] }
            if eggs.count > s.rules.maxClutch { return [.rejected(.clutchTooBig(max: s.rules.maxClutch))] }
            return sit(henID, on: eggs, &s)

        case .rename(let id, let name):
            // Any bird the player owns, any time: at home, boarding, or lost.
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return [.rejected(.invalidAmount)] }
            guard trimmed.count <= NameBook.maxLength else { return [.rejected(.nameTooLong(max: NameBook.maxLength))] }
            guard NameBook.flock(s).contains(where: { $0.id == id }) else { return [.rejected(.noSuchBird)] }
            if s.bird(id)?.isOnLoan == true { return [.rejected(.onLoan)] }  // her owner named her
            guard !NameBook.isTaken(trimmed, exceptID: id, in: s) else { return [.rejected(.nameTaken)] }
            if let (keyPath, i) = locate(id, in: s, groups: [\.brooder, \.henChicks, \.coop, \.boarding]) {
                s[keyPath: keyPath][i].name = trimmed
                s[keyPath: keyPath][i].needsName = nil
                s[keyPath: keyPath][i].unnamedSinceDay = nil
                return [.renamed(id)]
            }
            if let i = s.lost.firstIndex(where: { $0.bird.id == id }) {
                s.lost[i].bird.name = trimmed
                s.lost[i].bird.needsName = nil
                s.lost[i].bird.unnamedSinceDay = nil
                return [.renamed(id)]
            }
            return [.rejected(.noSuchBird)]

        case .rehome(let id):
            if let blocker = rehomeBlocker(id, in: s), blocker != .noSuchBird { return [.rejected(blocker)] }
            if let (keyPath, i) = locate(id, in: s, groups: [\.brooder, \.henChicks, \.coop, \.boarding]) {
                let bird = s[keyPath: keyPath].remove(at: i)
                return [.rehomed(id, coins: sendToNewHome(bird, &s, wasAway: keyPath == \.boarding))]
            }
            return [.rejected(.noSuchBird)]

        case .buy(let item):
            return buy(item, &s, &rng)

        case .pet(let id):
            return handle(id, .pet, &s)

        case .giveTreat(let id):
            return handle(id, .treat, &s)

        case .deliver(let story):
            return deliver(story, &s)

        case .acceptTrade:
            guard let offer = s.tradeOffer else { return [.rejected(.noTradeOffer)] }
            if let (keyPath, i) = locate(offer.roosterID, in: s, groups: [\.coop, \.brooder]) {
                let rooster = s[keyPath: keyPath][i]
                s[keyPath: keyPath][i] = offer.hen  // she takes his place
                s.rehomed.append(rooster.leavingSight(in: s, onDay: s.day))
                s.tradeOffer = nil
                if s.starterID == rooster.id { s.starterID = nil }
                var ev: [GameEvent] = [.tradeAccepted(rooster: rooster.id, hen: offer.hen.id)]
                ev += recordBreed(offer.hen, into: &s.breedBook)
                return ev
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

        case .enterShow(let id):
            return enterShow(id, in: nil, &s)

        case .enterShowIn(let id, let cls):
            return enterShow(id, in: cls, &s)

        case .enterEggs:
            return enterEggs(&s)

        case .enterEggPlate(let ids):
            return enterEggPlate(ids, &s)
        case .buySpecial:
            return buySpecial(&s, &rng)
        case .penBird(let id):
            return penBird(id, &s)
        case .unpenBird(let id):
            return unpenBird(id, &s)
        case .rest:
            return [.rested(s.timeOfDay)]  // the slot itself is spent by `spendDaylight`
        case .openPlanner:
            // Before the keeper has met the planner there is nothing to open, and the notice must wait.
            if s.plannerKnown { s.plannerOpened = true }
            return []
        case .guessSex(let id, let sex):
            return guessSex(id, sex, &s)
        case .choose(let story, let option):
            return choose(story, option, &s, &rng)
        case .payDebt(let id):
            return payDebt(id, &s)
        case .giveHatchAlongEgg(let id):
            return giveHatchAlongEgg(id, &s)
        }
    }

    /// Why this bird can't go to a new home now, or nil if it can. Front ends hide "Rehome" when
    /// this is not nil, so the keeper never taps a button that does nothing.
    public static func rehomeBlocker(_ id: UUID, in s: GameState) -> Rejection? {
        if s.bird(id)?.isOnLoan == true { return .onLoan }
        if s.clutch(under: id) != nil || s.henChicks.contains(where: { $0.raisedBy == id }) { return .birdIsBusy }
        // A loaned bird goes home one day, so she does not count: the keeper keeps one bird of their own.
        let owned = s.ownBirds.count
        if owned <= 1, s.bird(id) != nil, !s.rehomed.contains(where: { $0.id == id }) { return .lastBird }
        let rehomable = s.birdsAtHome.contains { $0.id == id } || s.boarding.contains { $0.id == id }
        return rehomable ? nil : .noSuchBird
    }

    // MARK: - Shop and safety net

    /// A young bird from a local flock: a random starter breed and colour. Breed and sex are known once
    /// the keeper has it (the shop list does not name the breed: it is a surprise).
    static func youngBird<R: RandomNumberGenerator>(
        _ sex: Sex, origin: String, _ s: GameState, _ rng: inout R,
        breed chosen: Breed? = nil
    ) -> Bird {
        let breed = chosen ?? Breed.starters.randomElement(using: &rng)!
        let colour = breed.definition.varieties.randomElement(using: &rng)!
        return Bird(
            id: makeID(using: &rng), name: sex == .hen ? "New pullet" : "New cockerel", breed: breed,
            genome: breed.purebred(sex, variety: colour), hatchDay: s.day - s.rules.growerAge,
            origin: origin, revealed: true
        ).withFounderQuality().withTameness(s.rules.boughtBirdTameness)
    }

    static func buy<R: RandomNumberGenerator>(_ item: ShopItem, _ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        let cost =
            switch item {
            case .pullet: s.rules.pulletPrice
            case .cockerel: s.rules.cockerelPrice
            case .fertileEgg: s.rules.fertileEggPrice
            case .treats: s.rules.treatBagPrice
            case .premiumFeed: s.rules.premiumFeedPrice
            }
        if s.coins < cost { return [.rejected(.notEnoughCoins(needed: cost, have: s.coins))] }
        switch item {
        case .pullet, .cockerel:
            if !s.hasFreePerch { return [.rejected(.noFreePerch)] }
            let breed = s.surpriseBreeds.randomElement(using: &rng)!
            let sex: Sex = item == .pullet ? .hen : .rooster
            let bird = youngBird(sex, origin: Bird.shopOrigin, s, &rng, breed: breed).waitingForName()
            s.coins -= cost
            s.coop.append(bird)
            var ev: [GameEvent] = [.boughtBird(bird.id, item: item, cost: cost)]
            ev += recordBreed(bird, into: &s.breedBook)
            return ev
        case .treats:
            s.coins -= cost
            s.treats += s.rules.treatBagSize
            return [.boughtTreats(count: s.rules.treatBagSize, cost: cost)]
        case .premiumFeed:
            s.coins -= cost
            s.premiumFeed += s.rules.premiumFeedBagSize
            return [.boughtPremiumFeed(count: s.rules.premiumFeedBagSize, cost: cost)]
        case .fertileEgg:
            if s.carton.count >= s.cartonCapacity { return [.rejected(.cartonFull)] }
            // From a local flock: two purebred starter birds, maybe of different breeds.
            let mother = youngBird(.hen, origin: Bird.localFlockOrigin, s, &rng)
            let father = youngBird(.rooster, origin: Bird.localFlockOrigin, s, &rng)
            var egg = Breeding.layEgg(mother: mother, father: father, day: s.day, using: &rng)
            // Keep the parents on record, so the chick's family tree is not blank.
            // The keeper never sees them, so their records hold no look.
            s.pedigree[mother.id] = PedigreeRecord(mother, look: nil)
            s.pedigree[father.id] = PedigreeRecord(father, look: nil)
            egg.collectedDay = s.day
            egg.candled = true
            s.coins -= cost
            s.carton.append(egg)
            // A keeper with no incubator gets the neighbour's old one at once, so the egg can hatch.
            return [.boughtEgg(cost: cost)] + incubatorGiftForFertileEggs(&s)
        }
    }

    /// Where a bird lives among the given collections, as a keyPath and index. Groups are searched in order.
    static func locate(
        _ id: UUID, in s: GameState, groups: [WritableKeyPath<GameState, [Bird]>]
    ) -> (WritableKeyPath<GameState, [Bird]>, Int)? {
        for keyPath in groups {
            if let i = s[keyPath: keyPath].firstIndex(where: { $0.id == id }) { return (keyPath, i) }
        }
        return nil
    }

    /// Records a bird in the Breed Book. Returns the new-entry event if it was not already known.
    static func recordBreed(_ bird: Bird, into book: inout Set<BreedBookEntry>) -> [GameEvent] {
        let entry = BreedBookEntry(bird)
        return book.insert(entry).inserted ? [.newBreedBookEntry(entry)] : []
    }

    /// Handling and treats. Birds at home only: lost and boarding birds are out of reach.
    static func handle(_ id: UUID, _ kind: Handling, _ s: inout GameState) -> [GameEvent] {
        let homes: [WritableKeyPath<GameState, [Bird]>] = [\.brooder, \.henChicks, \.coop]
        guard let home = homes.first(where: { s[keyPath: $0].contains { $0.id == id } }),
            let i = s[keyPath: home].firstIndex(where: { $0.id == id })
        else {
            let away = s.lost.contains { $0.bird.id == id } || s.boarding.contains { $0.id == id }
            return [.rejected(away ? .birdNotHome : .noSuchBird)]
        }
        var bird = s[keyPath: home][i]
        switch kind {
        case .pet:
            if bird.wasHandled(.pet, onDay: s.day) { return [.rejected(.alreadyPettedToday)] }
            bird.lastPettedDay = s.day
        case .treat:
            if bird.wasHandled(.treat, onDay: s.day) { return [.rejected(.alreadyHadTreatToday)] }
            if s.treats <= 0 { return [.rejected(.noTreats)] }
            s.treats -= 1
            bird.lastTreatDay = s.day
        }
        let before = bird.friendliness
        bird.changeTameness(
            by: Handling.gain(
                kind, for: bird, withMotherHen: home == \GameState.henChicks,
                day: s.day, rules: s.rules))
        s[keyPath: home][i] = bird
        var ev: [GameEvent] = [.handled(id, kind)]
        if bird.friendliness > before { ev.append(.friendlierNow(id, bird.friendliness)) }
        return ev
    }

    static func updateTradeOffer<R: RandomNumberGenerator>(_ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        let owned = s.ownBirds  // a loaned hen goes home, so she does not end the keeper's need
        let stuck = !owned.contains { $0.sex == .hen } && s.coins < s.rules.pulletPrice
        guard stuck else {
            s.tradeOffer = nil
            return []
        }
        // Keep an existing offer while its rooster is still at home.
        if let offer = s.tradeOffer, (s.coop + s.brooder).contains(where: { $0.id == offer.roosterID }) { return [] }
        // Only a rooster the player already knows is a rooster. Offering an unrevealed chick would
        // tell the player its sex early. An unrevealed rooster is revealed as it grows; the offer comes then.
        guard let rooster = (s.coop + s.brooder).first(where: { $0.sex == .rooster && $0.revealed && !$0.isOnLoan })
        else {
            s.tradeOffer = nil  // every known rooster is out; they come home, and the offer comes then
            return []
        }
        let hen = youngBird(.hen, origin: Bird.villageOrigin, s, &rng).namedByKeeper(in: s)
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

    /// The carton eggs with these IDs, in carton order, or why they can't be used.
    /// Every ID must be in the carton.
    static func chosenEggs(_ ids: [UUID], _ s: GameState) -> (eggs: [Egg], problem: Rejection?) {
        let wanted = Set(ids)
        if wanted.isEmpty { return ([], .invalidAmount) }
        let eggs = s.carton.filter { wanted.contains($0.id) }
        return (eggs, eggs.count == wanted.count ? nil : .noSuchEgg)
    }

    static func sell(_ eggs: [Egg], _ s: inout GameState) -> [GameEvent] {
        let total = eggs.reduce(0) { $0 + s.rules.price(of: $1, onDay: s.day) }
        let stale = eggs.count(where: { s.rules.isStale($0, onDay: s.day) })
        let sold = Set(eggs.map(\.id))
        s.coins += total
        s.carton.removeAll { sold.contains($0.id) }
        return [.eggsSold(count: eggs.count, coins: total, stale: stale)]
    }

    /// Why no eggs can go in the incubator right now, if anything stops it.
    static func incubatorBlocker(_ s: GameState) -> Rejection? {
        if !s.hasIncubator { return .noIncubator }
        if !s.boarding.isEmpty { return .birdsBoarding }
        // Eggs set on different days would hatch on different days, so a clutch from an earlier day blocks it.
        if let c = s.incubatorClutch, c.hatchDay != incubatorHatchDay(s) { return .incubatorBusy }
        if incubatorSpace(s) <= 0 { return .incubatorFull(room: 0) }
        if brooderRoom(s) <= 0 { return .brooderFull(room: 0) }
        return nil
    }

    static func incubatorHatchDay(_ s: GameState) -> Int { s.day + s.rules.incubatorHatchDays }

    /// Free places in the incubator. Eggs set earlier today still leave room for more.
    static func incubatorSpace(_ s: GameState) -> Int { s.incubatorSize - (s.incubatorClutch?.eggs.count ?? 0) }

    /// Every egg in the incubator will hatch into the brooder, so it needs room for all of them.
    static func brooderRoom(_ s: GameState) -> Int {
        s.brooderSize - s.brooder.count - (s.incubatorClutch?.eggs.count ?? 0)
    }

    static func sitBlocker(_ henID: UUID, _ s: GameState) -> Rejection? {
        guard let hen = s.coop.first(where: { $0.id == henID }) else { return .noSuchBird }
        if hen.isOnLoan { return .onLoan }  // her owner's to decide, and she would stay past her day
        if !s.boarding.isEmpty { return .birdsBoarding }
        // Her chicks may need the brooder when grown, so a full brooder blocks hatching here too.
        if brooderRoom(s) <= 0 { return .brooderFull(room: 0) }
        if !hen.isBroody(onDay: s.day) { return .notBroody }
        if s.clutch(under: henID) != nil { return .henAlreadySitting }
        return nil
    }

    static func sit(_ henID: UUID, on eggs: [Egg], _ s: inout GameState) -> [GameEvent] {
        let hatchDay = s.day + s.rules.broodyHatchDays
        let ev = setEggs(eggs, hen: henID, hatchDay: hatchDay, &s)
        if s.clutch(under: henID) != nil, let i = s.coop.firstIndex(where: { $0.id == henID }) {
            // She sits, then raises her chicks until they are big enough for the coop.
            s.coop[i].broodyUntilDay = hatchDay + s.rules.brooderDays
        }
        return ev
    }

    /// Sets every chosen egg. Setting never candles: candling is its own, deliberate step (`candleEgg`).
    /// So a clear egg that was not candled first sits the full time and comes back on hatch day
    /// (`hatchDue`). The keeper who candles first saves the space and the wait.
    /// Callers refuse eggs already known to be clear. Incubator eggs join a clutch set earlier the same day.
    /// Eggs from a penned pair add what the pen's forecast pins to the inheritance page.
    static func setEggs(_ chosen: [Egg], hen: UUID?, hatchDay: Int, _ s: inout GameState) -> [GameEvent] {
        InheritancePage.recordSetting(chosen, &s)
        let chosenIDs = Set(chosen.map(\.id))
        s.carton.removeAll { chosenIDs.contains($0.id) }
        addToClutch(chosen, hen: hen, hatchDay: hatchDay, &s)
        return [.eggsSet(count: chosen.count, hen: hen, hatchDay: hatchDay)]
    }

    static func addToClutch(_ eggs: [Egg], hen: UUID?, hatchDay: Int, _ s: inout GameState) {
        if hen == nil, let i = s.clutches.firstIndex(where: { $0.henID == nil && $0.hatchDay == hatchDay }) {
            s.clutches[i].eggs += eggs
        } else {
            s.clutches.append(Clutch(henID: hen, eggs: eggs, hatchDay: hatchDay))
        }
    }

    /// An egg that did not hatch goes back to the carton, now known to be clear. A full carton
    /// sends it to the nest boxes to collect later.
    static func returnUnhatched(_ egg: Egg, _ s: inout GameState) {
        var egg = egg
        egg.candled = true
        if s.carton.count < s.cartonCapacity {
            s.carton.append(egg)
        } else {
            s.nest.append(egg)
        }
    }

    /// The first hatch is the lesson: the neighbour shows the keeper how to candle.
    static func candlingLesson(_ s: inout GameState) -> [GameEvent] {
        guard !s.canCandle, s.chicksHatched >= s.rules.chicksToLearnCandling else { return [] }
        s.canCandle = true
        return [.learnedCandling]
    }

    static func hatchDue<R: RandomNumberGenerator>(_ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        var ev: [GameEvent] = []
        var waiting: [Clutch] = []
        // Chicks hatch only in this night step, so a local count keeps the daily limit.
        var whyNotes = 0
        for clutch in s.clutches {
            guard clutch.hatchDay <= s.day else {
                waiting.append(clutch)
                continue
            }
            var ids: [UUID] = []
            var notes: [GameEvent] = []
            var named: [GameEvent] = []
            var unhatched = 0
            for egg in clutch.eggs {
                guard
                    var chick = Breeding.hatch(
                        egg, name: "Chick \(s.chicksHatched + 1)", onDay: s.day,
                        origin: Bird.homeOrigin, using: &rng)
                else {
                    returnUnhatched(egg, &s)
                    unhatched += 1
                    continue
                }
                s.chicksHatched += 1
                chick.inbreeding = Pedigree.kinship(chick.motherID, chick.fatherID, in: s)
                chick.needsName = true
                if let namer = s.nextChickNamer {
                    // A story promised this person the next chick's name. No game randomness used.
                    chick.name = NameBook.name(by: namer, for: chick, in: s)
                    chick.needsName = nil
                    s.nextChickNamer = nil
                    named.append(.chickNamed(chick.id, by: namer))
                }
                if let hen = clutch.henID {
                    chick.raisedBy = hen
                    chick.tameness = s.rules.broodyChickTameness
                    s.henChicks.append(chick)
                } else {
                    chick.tameness = s.rules.brooderChickTameness
                    s.brooder.append(chick)
                }
                ids.append(chick.id)
                if whyNotes < s.rules.hatchWhyNotesPerDay, let note = hatchSurprise(chick, s) {
                    notes.append(note)
                    whyNotes += 1
                }
            }
            if !ids.isEmpty { ev.append(.chicksHatched(ids, hen: clutch.henID)) }
            ev += named
            // The first why note opens "What might hatch". No random draw: the same seed hatches the same chicks.
            if !notes.isEmpty, !s.plannerKnown {
                s.plannerKnown = true
                notes.insert(.plannerIntroduced, at: 1)
            }
            ev += notes
            if unhatched > 0 { ev.append(.eggsDidNotHatch(count: unhatched, hen: clutch.henID)) }
            // No chicks to raise: a hen whose eggs were all clear stops being broody and lays again.
            // A hen already raising chicks (fostered ones) stays broody for them.
            if ids.isEmpty, let hen = clutch.henID, let i = s.coop.firstIndex(where: { $0.id == hen }),
                s.coop[i].broodyUntilDay != nil, !s.henChicks.contains(where: { $0.raisedBy == hen })
            {
                s.coop[i].broodyUntilDay = nil
                ev.append(.broodyEnded(hen))
            }
        }
        s.clutches = waiting
        return ev + candlingLesson(&s)
    }

    // MARK: - Starter

    static func chooseStarter(index: Int, name: String, _ s: inout GameState) -> [GameEvent] {
        guard case .choosingStarter(let chicks) = s.phase else { return [.rejected(.alreadyStarted)] }
        guard chicks.indices.contains(index) else { return [.rejected(.noSuchChick)] }
        var chick = chicks[index]
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed.count <= NameBook.maxLength else { return [.rejected(.nameTooLong(max: NameBook.maxLength))] }
        chick.name = trimmed.isEmpty ? "Chick" : trimmed
        s.brooder.append(chick)
        s.starterID = chick.id
        s.phase = .playing
        return [.starterChosen(chick.id)] + firstMorning(&s)
    }

    /// Day 1 is a whole day: its lessons, its jobs and the season goal are there from the start, as on
    /// any other morning. Only the morning steps run: nothing grows, lays or hatches. No randomness.
    static func firstMorning(_ s: inout GameState) -> [GameEvent] {
        resetDaylight(&s)
        return introduceFeatures(&s) + advanceSeasonGoal(&s) + setTodaysJobs(&s)
    }

    static func nameKeeper(_ name: String, _ s: inout GameState) -> [GameEvent] {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return [.rejected(.blankName)] }
        guard trimmed.count <= NameBook.maxLength else { return [.rejected(.nameTooLong(max: NameBook.maxLength))] }
        s.keeperName = trimmed
        return [.keeperNamed(trimmed)]
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
        //    On the Longest Day's night the fox stays home: no roll at all (see VillageDay.swift).
        let canFlee = s.coop.filter { !$0.isBroody(onDay: s.day) }
        if s.coopDoorOpen, !canFlee.isEmpty, !s.foxStaysHome, Double.roll(r.foxChance, using: &rng) {
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
                // A fright and time living rough make a bird warier of people.
                let away = min(r.maxLostTamenessLoss, r.lostDayTamenessLoss * Double(days + 1))
                b.changeTameness(by: -(r.foxFrightTamenessLoss + away))
                s.lost.append(LostBird(bird: b.leavingSight(in: s, onDay: s.day), returnsOnDay: s.day + 1 + days))
            }
            ev.append(.foxVisited(scared: scared.map(\.id)))
            leavePenIfGone(&s)  // a scared bird leaves the pen; the keeper pens it again when it is home
        } else {
            ev.append(.quietNight)
        }

        // 1b. Foraging: if the door was left open and birds stayed out, they free-ranged overnight.
        //     They come back fed (no feeding needed) and a little the better for it — the upside that
        //     makes leaving the coop open a real choice against the fox. No luck involved; broody hens
        //     are sitting, so they don't forage.
        let foragers = s.coop.filter { !$0.isBroody(onDay: s.day) }
        if s.coopDoorOpen, !foragers.isEmpty {
            s.foragedToday = true
            s.fedToday = true  // a night's foraging counts as feeding for this night's lay
            ev.append(.birdsForaged(count: foragers.count))
        } else {
            s.foragedToday = false
        }

        // 2. New day.
        let oldSeason = s.season
        s.day += 1
        ev.append(.dayStarted(day: s.day, season: s.season))
        if s.season != oldSeason { ev.append(.seasonChanged(s.season)) }

        // 2b. Daylight resets: a fresh day of errands (see Daylight.swift).
        resetDaylight(&s)

        // 3. Lost birds come home if their day has come and a perch is free. A lost bird has no perch.
        var stillLost: [LostBird] = []
        for lb in s.lost.sorted(by: { $0.returnsOnDay < $1.returnsOnDay }) {
            guard lb.returnsOnDay <= s.day else {
                stillLost.append(lb)
                continue
            }
            // A loaned bird needs no perch: she has her own box.
            if lb.bird.isOnLoan || s.hasFreePerch {
                var b = lb.bird
                b.noLayUntilDay = s.day + r.scaredNoLayDays
                b.lastSeenLook = nil  // home again: the keeper sees it as it is now
                s.coop.append(b)
                ev.append(.birdReturned(b.id))
            } else {
                stillLost.append(lb)
                ev.append(.birdWaitingForPerch(lb.bird.id))
            }
        }
        s.lost = stillLost

        // 4. Growth and reveals.
        var brooder = s.brooder
        var henChicks = s.henChicks
        var coop = s.coop
        var growth = grow(&brooder, day: s.day, rules: r, book: &s.breedBook)
        growth += grow(&henChicks, day: s.day, rules: r, book: &s.breedBook)
        growth += grow(&coop, day: s.day, rules: r, book: &s.breedBook)
        s.brooder = brooder
        s.henChicks = henChicks
        s.coop = coop
        ev += growth
        // 4a. "Hen or roo?": the sex shows today, so the keeper's guess is settled (see SexGuess.swift).
        ev += resolveSexGuesses(after: growth, &s)
        ev += neighbourGiftIfNeeded(&s, &rng)

        // 4b. A known-fertile egg in the carton and no incubator (a save from before the gift came
        //     with bought eggs): the neighbour brings her old incubator.
        ev += incubatorGiftForFertileEggs(&s)

        // 5. Eggs due today hatch: incubator chicks go to the brooder, broody-hatched chicks stay with their mother.
        ev += hatchDue(&s, &rng)

        // 6. Grown chicks and boarding birds find homes (a free perch), or wait. A bird that has waited
        //    `homeWaitNights` goes to a new home through the neighbour.
        ev += findHomes(&s)

        // 6b. Birds left unnamed for `autoNameNights` take their suggested name.
        ev += autoName(&s)

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

        // 8a. Hens that reached retirement age today get a gentle send-off. They've already stopped
        //     laying above; from now on they keep their perch as beloved non-layers (cozy: no deaths).
        for b in s.coop where b.isRetired(onDay: s.day, rules: r) && !b.isRetired(onDay: s.day - 1, rules: r) {
            ev.append(.birdRetired(b.id))
        }

        // 9. Stories: loans whose day has come go home, stories move on, and debts are mentioned
        //    kindly (once a season at most). Then the safety net: a rooster-only flock that can't
        //    afford a pullet gets a trade offer.
        ev += returnLoans(&s)
        ev += advanceStories(&s, &rng)
        ev += mentionDebts(&s)
        ev += updateTradeOffer(&s, &rng)

        // 9a. The post: maybe a note (see Post.swift). Then the village calendar (see VillageDay.swift).
        //     The post is seeded from the shop seed and the day, not the game RNG.
        ev += deliverPost(&s)
        ev += villageCalendar(&s, &rng)

        // 9b. County show, on show days: entries are judged against a field and placed (see ShowEvent.swift).
        ev += runShowIfToday(&s, &rng)

        // 9c. Early game: introduce the features whose day has come (and the neighbour's show tip).
        ev += introduceFeatures(&s)

        // 9d. Goal ladder: award any milestone reached once the day's events have settled.
        ev += advanceMilestones(&s)

        // 9e. Today's jobs and the season goal (see Jobs.swift): check the goal, set a new one when the
        //     season turns, and pick today's jobs. Seeded from the shop seed, not the game RNG.
        ev += advanceSeasonGoal(&s)
        ev += setTodaysJobs(&s)

        // 10. Reset for the new day. The door is opened in the morning.
        s.fedToday = false
        s.fedPremiumToday = false
        s.coopDoorOpen = true
        return ev
    }

    /// Perches go first to birds boarding with the neighbour, then grown brooder birds, then grown hen chicks.
    /// A grown bird with no perch waits in the brooder; if the brooder is full too, the neighbour boards it.
    /// After `homeWaitNights` of waiting, the neighbour finds it a new home, so the brooder and the
    /// incubator never stay blocked. The starter is never sent away.
    static func findHomes(_ s: inout GameState) -> [GameEvent] {
        var ev: [GameEvent] = []
        let day = s.day
        let brooderDays = s.rules.brooderDays
        let grown = { (b: Bird) in b.age(onDay: day) >= brooderDays }
        let wereBoarding = Set(s.boarding.map(\.id))  // only birds that newly board tonight get the notice
        func perch(_ b: Bird) {
            var b = b
            b.waitingSinceDay = nil
            b.lastSeenLook = nil  // home again, if it was boarding
            s.coop.append(b)
        }

        var stillBoarding: [Bird] = []
        for b in s.boarding {
            if s.hasFreePerch {
                perch(b)
                ev.append(.cameHomeFromBoarding(b.id))
            } else {
                stillBoarding.append(b)
            }
        }
        s.boarding = stillBoarding

        var inBrooder: [Bird] = []
        var waiting: Set<UUID> = []
        for b in s.brooder {
            if grown(b) && s.hasFreePerch {
                perch(b)
                ev.append(.movedToCoop(b.id))
            } else {
                inBrooder.append(b)
                if grown(b) { waiting.insert(b.id) }
            }
        }
        s.brooder = inBrooder

        var withMother: [Bird] = []
        for b in s.henChicks {
            guard grown(b) else {
                withMother.append(b)
                continue
            }
            if s.hasFreePerch {
                perch(b)
                ev.append(.movedToCoop(b.id))
            } else if brooderRoom(s) > 0 {  // leaves room for the chicks still in the incubator
                s.brooder.append(b)
                waiting.insert(b.id)
            } else {
                // Moved in the night: the keeper last saw it yesterday.
                s.boarding.append(b.leavingSight(in: s, onDay: day - 1))
            }
        }
        s.henChicks = withMother

        // Birds still without a perch: count the nights, and send on any that have waited long enough.
        func waitedTooLong(_ b: inout Bird) -> Bool {
            let since = b.waitingSinceDay ?? day
            b.waitingSinceDay = since
            return day - since >= s.rules.homeWaitNights && b.id != s.starterID
        }
        var keptInBrooder: [Bird] = []
        for var b in s.brooder {
            guard waiting.contains(b.id) else {
                keptInBrooder.append(b)
                continue
            }
            if waitedTooLong(&b) {
                ev.append(.rehomedByNeighbour(b.id, coins: sendToNewHome(b, &s, lastSeenOnDay: day - 1)))
            } else {
                keptInBrooder.append(b)
                ev.append(.needsHome(b.id))
            }
        }
        s.brooder = keptInBrooder
        var keptBoarding: [Bird] = []
        for var b in s.boarding {
            if waitedTooLong(&b) {
                ev.append(
                    .rehomedByNeighbour(b.id, coins: sendToNewHome(b, &s, lastSeenOnDay: day - 1, wasAway: true)))
            } else {
                keptBoarding.append(b)
                if !wereBoarding.contains(b.id) { ev.append(.boardingWithNeighbour(b.id)) }
            }
        }
        s.boarding = keptBoarding
        return ev
    }

    /// A bird leaves the flock for a good home in Featherwick. The keeper is paid what it is worth.
    /// The caller has already taken it out of its group.
    static func sendToNewHome(
        _ bird: Bird, _ s: inout GameState, lastSeenOnDay: Int? = nil, wasAway: Bool = false
    )
        -> Int
    {
        let coins = s.rehomeValue(of: bird)
        s.coins += coins
        var bird = bird
        bird.waitingSinceDay = nil
        // A rehome by the keeper is by day. One by the neighbour is in the night (`findHomes`), after
        // the new day began: the keeper last saw the bird the day before.
        s.rehomed.append(bird.leavingSight(in: s, onDay: lastSeenOnDay ?? s.day, wasAway: wasAway))
        if s.starterID == bird.id { s.starterID = nil }
        if s.tradeOffer?.roosterID == bird.id { s.tradeOffer = nil }  // a new offer comes in the morning if needed
        return coins
    }

    /// A bird left unnamed for `autoNameNights` takes its suggested name, so the naming prompt never
    /// waits forever. The suggestion is neutral while the sex is hidden.
    static func autoName(_ s: inout GameState) -> [GameEvent] {
        var ev: [GameEvent] = []
        for keyPath in [\GameState.brooder, \.henChicks, \.coop, \.boarding] {
            for i in s[keyPath: keyPath].indices where s[keyPath: keyPath][i].needsName == true {
                let since = s[keyPath: keyPath][i].unnamedSinceDay ?? s.day
                s[keyPath: keyPath][i].unnamedSinceDay = since
                guard s.day - since >= s.rules.autoNameNights else { continue }
                let name = NameBook.suggestion(for: s[keyPath: keyPath][i], in: s)
                s[keyPath: keyPath][i].name = name
                s[keyPath: keyPath][i].needsName = nil
                s[keyPath: keyPath][i].unnamedSinceDay = nil
                ev.append(.namedForYou(s[keyPath: keyPath][i].id))
            }
        }
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
                ev += recordBreed(birds[i], into: &book)
            }
        }
        return ev
    }

    /// If the starter turns out to be a rooster, the neighbour gives a younger hen.
    static func neighbourGiftIfNeeded<R: RandomNumberGenerator>(_ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        guard !s.giftHenGiven, let id = s.starterID, let starter = s.bird(id),
            starter.revealed, starter.sex == .rooster
        else { return [] }
        let breed = Breed.starters.randomElement(using: &rng)!
        let colour = breed.definition.varieties.randomElement(using: &rng)!
        let hen = Bird(
            id: makeID(using: &rng), name: "Gift hen", breed: breed,
            genome: breed.purebred(.hen, variety: colour),
            hatchDay: s.day - s.rules.giftHenAge, origin: Bird.neighbourOrigin,
            revealed: true  // the neighbour tells you her breed and sex
        ).withFounderQuality().withTameness(s.rules.boughtBirdTameness).namedByKeeper(in: s)
        s.giftHenGiven = true
        var ev: [GameEvent] = [.neighbourGaveHen(hen.id)]
        // The brooder if it has room, else a free perch; if both are full the neighbour boards her,
        // just like any grown bird with nowhere to go (see findHomes). Eggs in the incubator keep their places.
        if brooderRoom(s) > 0 {
            s.brooder.append(hen)
        } else if s.hasFreePerch {
            s.coop.append(hen)
        } else {
            s.boarding.append(hen.leavingSight(in: s, onDay: s.day - 1))  // the keeper has not seen her yet
            ev.append(.boardingWithNeighbour(hen.id))
        }
        ev += recordBreed(hen, into: &s.breedBook)
        return ev
    }

    static func lay<R: RandomNumberGenerator>(_ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        let hens = s.coop.filter {
            $0.sex == .hen && $0.stage(onDay: s.day, rules: s.rules) == .adult
                && !$0.isRetired(onDay: s.day, rules: s.rules)
        }
        guard !hens.isEmpty else { return [] }
        guard s.fedToday else { return [.noEggsHungry] }
        var ev: [GameEvent] = []
        // The breeding pen is its own little flock (see BreedingPen.swift). Its birds do not count
        // toward coop rooster tension, and its hens are not unsettled by the coop roosters.
        let penned = Set(s.pennedBirds.map(\.id))
        let coopFlock = s.coop.filter { !penned.contains($0.id) }
        let extra = s.rules.extraRoosters(inCoop: coopFlock, onDay: s.day)
        if extra > 0 {
            ev.append(.roostersSquabbling(extra: extra))
            // New-player nudge: the first time it bites, say how to fix it. Shown once.
            if !s.roosterAdviceGiven {
                s.roosterAdviceGiven = true
                ev.append(.roosterAdvice)
            }
        }
        let calm = max(0, 1 - Double(extra) * s.rules.extraRoosterLayPenalty)
        // Premium feed and a night of foraging each lift the whole day's laying a little.
        let premium = s.fedPremiumToday ? (1 + s.rules.premiumFeedLayBonus) : 1
        let forage = s.foragedToday ? (1 + s.rules.forageLayBonus) : 1
        let chance = min(1, (s.rules.layChance[s.season] ?? 0) * calm * premium * forage)
        let penChance = min(1, (s.rules.layChance[s.season] ?? 0) * premium * forage)
        // A coop hen's egg is fathered by any adult coop rooster. A penned hen's egg is fathered by the
        // penned rooster only; with no adult rooster in the pen her eggs are not fertile.
        let isAdultRooster = { (b: Bird) in b.sex == .rooster && b.stage(onDay: s.day, rules: s.rules) == .adult }
        let roosters = coopFlock.filter(isAdultRooster)
        let penRooster = s.pennedBirds.first(where: isAdultRooster)
        for hen in hens where s.day >= hen.noLayUntilDay && !hen.isBroody(onDay: s.day) {
            let inPen = penned.contains(hen.id)
            // Inbred hens lay a little less (real inbreeding depression), when that rule is on.
            // Older hens slow with age.
            let inbredLoss = s.rules.inbreedingMatters ? min(s.rules.maxInbreedingLayLoss, hen.inbreeding ?? 0) : 0
            let henChance =
                (inPen ? penChance : chance) * (1 - inbredLoss) * s.rules.layAgeFactor(ageDays: hen.age(onDay: s.day))
            guard Double.roll(henChance, using: &rng) else { continue }
            // Nest boxes full: the hen lays on the floor, and the egg may break.
            if s.nest.count >= s.nestCapacity, Double.roll(s.rules.floorEggBreakChance, using: &rng) {
                ev.append(.eggBroken(by: hen.id))
                continue
            }
            // Same draws as before the pen for a coop hen, so seeds with an empty pen do not change.
            var father: Bird?
            if inPen {
                if let penRooster, Double.roll(s.rules.fertileChance, using: &rng) { father = penRooster }
            } else if !roosters.isEmpty, Double.roll(s.rules.fertileChance, using: &rng) {
                father = roosters[Int.random(in: 0..<roosters.count, using: &rng)]
            }
            var egg = Breeding.layEgg(mother: hen, father: father, day: s.day, using: &rng)
            egg.shell = Judge.shellQuality(of: hen, in: s)
            s.nest.append(egg)
            ev.append(.eggLaid(egg.id, by: hen.id))
            Records.noteLaid(by: hen.id, onDay: s.day, &s)
            if egg.isFertile, !s.incubatorGiftGiven {
                s.incubatorGiftGiven = true
                // Only offered if the player has no incubator yet (they may have bought the big one).
                if !s.hasIncubator {
                    s.incubatorSize = s.rules.giftIncubatorSize
                    s.incubatorGiftDay = s.day
                    ev.append(.neighbourGaveIncubator(size: s.rules.giftIncubatorSize, ownRooster: true))
                }
            }
            let entry = EggBookEntry(colour: egg.colour, speckled: egg.speckled)
            if s.eggBook.insert(entry).inserted { ev.append(.newEggBookEntry(entry)) }
        }
        return ev
    }

    /// The neighbour's old incubator, for a keeper with a known-fertile egg in the carton (bought at
    /// Speckle & Down) and no incubator. Once a game, like the gift for the first laid fertile egg.
    /// No randomness.
    static func incubatorGiftForFertileEggs(_ s: inout GameState) -> [GameEvent] {
        let fertileEgg = s.carton.contains { $0.isCandled && $0.isFertile }
        guard fertileEgg, !s.incubatorGiftGiven, !s.hasIncubator else { return [] }
        s.incubatorGiftGiven = true
        s.incubatorSize = s.rules.giftIncubatorSize
        s.incubatorGiftDay = s.day
        return [.neighbourGaveIncubator(size: s.rules.giftIncubatorSize, ownRooster: false)]
    }

    /// A pile of uncollected eggs can set a hen broody (real behaviour). Some breeds go broody far more.
    static func maybeGoBroody<R: RandomNumberGenerator>(_ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        guard s.nest.count >= s.rules.broodyNestEggs else { return [] }
        var ev: [GameEvent] = []
        for i in s.coop.indices {
            let hen = s.coop[i]
            guard hen.sex == .hen, hen.stage(onDay: s.day, rules: s.rules) == .adult,
                !hen.isBroody(onDay: s.day)
            else { continue }
            if Double.roll(s.rules.broodyChance[hen.breed] ?? 0, using: &rng) {
                s.coop[i].broodyUntilDay = s.day + s.rules.broodyDays
                ev.append(.wentBroody(hen.id))
            }
        }
        return ev
    }
}
