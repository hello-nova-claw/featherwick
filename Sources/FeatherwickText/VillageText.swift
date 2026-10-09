import FeatherwickCore

// The words for Featherwick's people: their names and about lines, choices, loans and debts, the post,
// and the village calendar. Core holds the IDs; every ID has its words here.

extension People {
    /// A person's name. Never suggested for a bird (see `NameBook`).
    public static func name(_ p: Person) -> String {
        switch p {
        case .hazel: neighbour
        case .wren: shopkeeper
        case .dot: "Dot"
        case .teddy: "Teddy"
        case .okafor: "Mr Okafor"
        case .bea: "Bea"
        }
    }

    /// Who a person is, in one line.
    public static func about(_ p: Person) -> String {
        switch p {
        case .hazel: neighbourAbout
        case .wren: shopkeeperAbout
        case .dot: "Dot judges the county show. She has a sharp eye and a soft spot for a well-kept bird."
        case .teddy: "Teddy lives down the lane. He isn't allowed a chicken, so he visits yours."
        case .okafor: "Mr Okafor bakes the village bread and fills his window with eggs of every colour."
        case .bea: "Bea runs the hen rescue on the hill. Every bird she takes in finds a good garden."
        }
    }

    /// The person's part in the game, in a few words.
    public static func role(_ p: Person) -> String {
        switch p {
        case .hazel: "the neighbour: genetics and the breeding pen"
        case .wren: "Speckle & Down: the shop and the news"
        case .dot: "the judge: shows"
        case .teddy: "the kid down the lane: friendly birds"
        case .okafor: "the baker: egg colours"
        case .bea: "the rescue: rehoming"
        }
    }
}

/// The words for an option at a story's choice step. Every option of every story has words.
public func choiceText(story: String, option: String) -> String {
    switch (story, option) {
    default: peopleChoiceText(story: story, option: option) ?? option
    }
}

/// The words for a note in the post, by note ID (see `Notes.pool` and story `.note` rewards).
/// Nil for an unknown ID: `NotesTests` checks every note has words.
public func postNoteText(_ id: String, _ s: GameState) -> String? {
    switch id {
    default: peopleNoteText(id, s)
    }
}

/// A village day's name.
public func villageDayName(_ v: VillageDay) -> String {
    switch v {
    case .hatchAlong: "the Hatch-along"
    case .longestDay: "the Longest Day"
    case .moultWeek: "Moult Week"
    case .midwinterLights: "Midwinter Lights"
    }
}

/// What happens on a village day, in one line, for the calendar.
public func villageDayAbout(_ v: VillageDay) -> String {
    switch v {
    case .hatchAlong: "The village hatches eggs together."
    case .longestDay: "The longest day of the year. The fox stays home."
    case .moultWeek: "The flock drops its old feathers and grows new ones."
    case .midwinterLights: "Lanterns in every window, and a gift from the village."
    }
}

/// The words for the people, loan, debt, post and calendar events.
func villageEventText(_ e: GameEvent, _ s: GameState) -> String? {
    switch e {
    case .chose(let story, let option):
        return "You've decided: \(choiceText(story: story, option: option))."
    case .storyCoins(_, let n):
        return "You're given \(n) coin\(n == 1 ? "" : "s")."
    case .storyTreats(_, let n):
        return "You're given \(n) mealworm\(n == 1 ? "" : "s"). You have \(s.treats) treats."
    case .storyGiftEgg(_, let breed):
        return "A \(breed.definition.displayName) egg goes into your carton, already candled."
    case .loanArrived(let id, let owner):
        return "\(birdName(id, s)) comes to stay. She's \(People.name(owner))'s, and she brings her own box."
    case .loanReturned(let id, let owner):
        return "\(birdName(id, s)) goes home to \(People.name(owner))."
    case .loanKept(let id, let owner):
        return "\(birdName(id, s)) is yours now. \(People.name(owner)) is glad she's staying."
    case .debtOwed(_, let owner, let coins):
        return "You owe \(People.name(owner)) \(coins) coins. Pay when you can: there's no hurry."
    case .debtReminder(_, let owner):
        return "\(People.name(owner)) waves over the fence. \"No rush on those coins, mind. Whenever suits.\""
    case .debtPaid(_, let owner, let coins):
        return "You pay \(People.name(owner)) \(coins) coins. \"Thank you, love.\""
    case .noteArrived(let person, let id):
        return postNoteText(id, s).map { "A note from \(People.name(person)): \($0)" }
    case .villageDayComing(let v, let days):
        return "\(villageDayName(v).capitalizedFirst) is in \(days) days. \(villageDayAbout(v))"
    case .villageDay(let v):
        return "Today is \(villageDayName(v)). \(villageDayAbout(v))"
    default:
        return nil
    }
}

/// The people the keeper has met, one line each, with what they are waiting on. For the CLI `people`.
/// A person is met once one of their stories has started, or a note from them has come. Hazel and Wren
/// are met on day 1.
public func peopleLines(_ s: GameState) -> [String] {
    var out: [String] = []
    for person in Person.allCases where hasMet(person, s) {
        out.append("\(People.name(person)), \(People.role(person)). \(People.about(person))")
        for story in Storylines.all where story.person == person {
            guard let p = s.stories[story.id] else { continue }
            out.append("  \(p.rewarded ? "✓" : "•") \(story.id)")
        }
    }
    for c in s.pendingChoices {
        let options = c.options.map { "\($0) (\(choiceText(story: c.story, option: $0)))" }.joined(separator: ", ")
        out.append("\(People.name(c.person)) asks you to choose: \(options). Type: choose \(c.story) <option>")
    }
    for d in s.debts {
        out.append("You owe \(People.name(d.to)) \(d.coins) coins. No hurry. To pay: pay \(d.id)")
    }
    for b in s.loanedBirds {
        guard let loan = b.loan else { continue }
        out.append("\(b.name) is on loan from \(People.name(loan.owner)).")
    }
    return out
}

/// True once the keeper has met this person.
public func hasMet(_ p: Person, _ s: GameState) -> Bool {
    if p == .hazel || p == .wren { return true }
    if Storylines.all.contains(where: { $0.person == p && s.stories[$0.id] != nil }) { return true }
    if s.debts.contains(where: { $0.to == p }) || s.loanedBirds.contains(where: { $0.loan?.owner == p }) { return true }
    return Notes.pool.contains { $0.from == p && s.notesSeen.contains($0.id) }
}

/// The next village days, one line each. For the CLI `calendar`.
public func calendarLines(_ s: GameState, count: Int = 4) -> [String] {
    s.upcomingVillageDays(count).map { next in
        let days = next.date - s.day
        let when = days == 0 ? "today" : days == 1 ? "tomorrow" : "in \(days) days (day \(next.date))"
        return "\(villageDayName(next.day).capitalizedFirst), \(when). \(villageDayAbout(next.day))"
    }
}
