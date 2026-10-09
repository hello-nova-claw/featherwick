/// What happened overnight, sorted into groups for the morning report page. The app shows one section per
/// group that has events, with each event's words from `eventText`. No words here: IDs and events only.
///
/// Every event lands in exactly one group, so nothing the night said is silently dropped. `group(of:)` is an
/// exhaustive switch with no `default`: a new `GameEvent` case does not build until it picks a group.
public struct MorningReport: Hashable, Sendable {
    /// The report's groups, in the order the page shows them.
    public enum Group: Int, CaseIterable, Hashable, Sendable {
        /// The new day itself: the day and season lines, and a quiet night. The page shows these under its title.
        case morning
        /// Chicks that hatched, and eggs that did not.
        case hatched
        /// The fox, and lost birds still out (it scares birds away; nobody is hurt).
        case fox
        /// Lost birds back on a perch, and birds back from boarding with the neighbour.
        case cameHome
        /// What the neighbours said or brought: lessons, gifts, stories, trade offers, loans and debts.
        /// Mostly Hazel; a story's words name its person.
        case neighbour
        /// Notes in the post from Featherwick's people (see Post.swift).
        case post
        /// The village: a village day coming or today, and the stories of Dot, Teddy, Mr Okafor and Bea.
        case village
        /// Stock new at Speckle & Down this morning.
        case newStock
        /// The county show: the news, the podiums, the placings and the prizes.
        case shows
        /// Today's jobs.
        case jobs
        /// The season goal and goal-ladder milestones.
        case seasonGoal
        /// Eggs laid and broken, and hens going broody or getting up.
        case eggs
        /// Everything else: chicks growing up, birds moving to the coop, names, retirements.
        case other
    }

    /// The day the keeper wakes to.
    public let day: Int
    public let season: Season
    /// The night's events by group, each in the order the night told them. Empty groups are absent.
    public let groups: [Group: [GameEvent]]

    /// The groups with something in them, in page order.
    public var shownGroups: [Group] { Group.allCases.filter { !(groups[$0] ?? []).isEmpty } }

    public func events(in group: Group) -> [GameEvent] { groups[group] ?? [] }

    /// Every event in the report, in group order. The same events as the night, sorted by group.
    public var allEvents: [GameEvent] { Group.allCases.flatMap { events(in: $0) } }

    /// Sorts a night's events (from `Engine.apply(.passNight, ...)`) into groups. `state` is the state after
    /// the night: it gives the day and season when the night did not say.
    public static func from(events: [GameEvent], state: GameState) -> MorningReport {
        var groups: [Group: [GameEvent]] = [:]
        var day = state.day
        var season = state.season
        for event in events {
            if case .dayStarted(let d, let s) = event {
                day = d
                season = s
            }
            groups[group(of: event), default: []].append(event)
        }
        return MorningReport(day: day, season: season, groups: groups)
    }

    /// Early-game steps that bring new stock to Speckle & Down. The app uses the same list for "new in today".
    public static let newStockFeatures: [Feature] = [.treats, .premiumFeed, .birdShop, .coopUpgrade, .incubatorShop]

    /// The story a story event is about, or nil for any other event.
    static func storyID(of event: GameEvent) -> String? {
        switch event {
        case .storyStarted(let id), .storyStep(let id, _), .delivered(let id), .storyGiftWaitingForRoom(let id),
            .storyGift(let id, _), .storyFinished(let id), .storyCoins(let id, _), .storyTreats(let id, _),
            .storyGiftEgg(let id, _):
            id
        default: nil
        }
    }

    /// The one group an event belongs to. Player actions do not happen at night; they go in `.other` so the
    /// switch stays total.
    public static func group(of event: GameEvent) -> Group {
        // A story of someone other than Hazel (Dot, Teddy, Mr Okafor, Bea) is village news.
        if let id = storyID(of: event), let story = Storylines.story(id), story.person != .hazel { return .village }
        switch event {
        case .dayStarted, .seasonChanged, .quietNight:
            return .morning
        case .chicksHatched, .eggsDidNotHatch, .hatchSurprise, .plannerIntroduced, .chickNamed:
            return .hatched
        case .foxVisited, .birdWaitingForPerch:
            return .fox
        case .birdReturned, .cameHomeFromBoarding, .birdsForaged:
            return .cameHome
        case .introduced(let feature) where newStockFeatures.contains(feature):
            return .newStock
        case .shopUnlocked:
            return .newStock
        case .introduced, .plannerShownAtPen, .neighbourGaveHen, .neighbourGaveIncubator, .learnedCandling,
            .roosterAdvice,
            .tradeOffered, .storyStarted, .storyStep, .delivered, .storyGiftWaitingForRoom, .storyGift,
            .storyFinished, .storyCoins, .storyTreats, .storyGiftEgg, .loanArrived, .loanReturned, .loanKept,
            .debtOwed, .debtReminder:
            return .neighbour
        case .noteArrived:
            return .post
        case .villageDayComing, .villageDay, .villageDayScene, .villageDayGift, .hatchAlongEggGiven,
            .hatchAlongChickWaiting, .hatchAlongChickArrived:
            return .village
        case .showAnnounced, .showDay, .showNoEntries, .showPodium, .showPlacing, .breedBookEntrySeen,
            .showPrizesWon, .showTreatsWon, .enteredInShow:
            return .shows
        case .jobsSet, .jobDone, .allJobsDone:
            return .jobs
        case .seasonGoalSet, .seasonGoalProgress, .seasonGoalReached, .milestoneReached:
            return .seasonGoal
        case .eggLaid, .eggBroken, .noEggsHungry, .newEggBookEntry, .wentBroody, .broodyEnded,
            .roostersSquabbling:
            return .eggs
        case .grewUp, .revealed, .sexGuessResolved, .newBreedBookEntry, .movedToCoop, .needsHome,
            .boardingWithNeighbour,
            .rehomedByNeighbour, .namedForYou, .birdRetired, .friendlierNow, .handled,
            // Player actions: never at night.
            .rejected, .starterChosen, .fed, .eggsCollected, .eggsSold, .coopClosed, .incubatorBought,
            .candled, .eggsSet, .renamed, .rehomed, .coopUpgraded, .boughtBird, .boughtEgg, .tradeAccepted,
            .boughtTreats, .boughtPremiumFeed, .fedPremium, .boughtSpecial, .birdPenned, .birdUnpenned, .slotSpent,
            .rested, .keeperNamed, .sexGuessed, .chose, .debtPaid:
            return .other
        }
    }
}
