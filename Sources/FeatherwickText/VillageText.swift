import FeatherwickCore

// The words for Featherwick's people: their names and about lines, choices, loans and debts, the post,
// and the village calendar. Core holds the IDs; every ID has its words here.

extension People {
    /// A person's name. Never suggested for a bird (see `NameBook`).
    public static func name(_ p: Person) -> String {
        switch p {
        case .hazel: neighbour
        case .wren: shopkeeper
        case .dot:
            String(
                localized: "village.name.dot", defaultValue: "Dot", bundle: .module,
                comment: "A person's name: the show judge.")
        case .teddy:
            String(
                localized: "village.name.teddy", defaultValue: "Teddy", bundle: .module,
                comment: "A person's name: the boy down the lane.")
        case .okafor:
            String(
                localized: "village.name.okafor", defaultValue: "Mr Okafor", bundle: .module,
                comment: "A person's name: the baker.")
        case .bea:
            String(
                localized: "village.name.bea", defaultValue: "Bea", bundle: .module,
                comment: "A person's name: she runs the hen rescue.")
        }
    }

    /// Who a person is, in one line.
    public static func about(_ p: Person) -> String {
        switch p {
        case .hazel: neighbourAbout
        case .wren: shopkeeperAbout
        case .dot:
            String(
                localized: "village.about.dot",
                defaultValue: "Dot judges the county show. She has a sharp eye and a soft spot for a well-kept bird.",
                bundle: .module, comment: "Who Dot is, in one line.")
        case .teddy:
            String(
                localized: "village.about.teddy",
                defaultValue: "Teddy lives down the lane. He isn't allowed a chicken, so he visits yours.",
                bundle: .module, comment: "Who Teddy is, in one line.")
        case .okafor:
            String(
                localized: "village.about.okafor",
                defaultValue: "Mr Okafor bakes the village bread and fills his window with eggs of every colour.",
                bundle: .module, comment: "Who Mr Okafor is, in one line.")
        case .bea:
            String(
                localized: "village.about.bea",
                defaultValue: "Bea runs the hen rescue on the hill. Every bird she takes in finds a good garden.",
                bundle: .module, comment: "Who Bea is, in one line.")
        }
    }

    /// The person's part in the game, in a few words.
    public static func role(_ p: Person) -> String {
        switch p {
        case .hazel:
            String(
                localized: "village.role.hazel", defaultValue: "the neighbour: genetics and the breeding pen",
                bundle: .module, comment: "Hazel's part in the game, after her name.")
        case .wren:
            String(
                localized: "village.role.wren", defaultValue: "Speckle & Down: the shop and the news", bundle: .module,
                comment: "Wren's part in the game, after her name. Speckle & Down is the shop's name.")
        case .dot:
            String(
                localized: "village.role.dot", defaultValue: "the judge: shows", bundle: .module,
                comment: "Dot's part in the game, after her name.")
        case .teddy:
            String(
                localized: "village.role.teddy", defaultValue: "the kid down the lane: friendly birds", bundle: .module,
                comment: "Teddy's part in the game, after his name.")
        case .okafor:
            String(
                localized: "village.role.okafor", defaultValue: "the baker: egg colours", bundle: .module,
                comment: "Mr Okafor's part in the game, after his name.")
        case .bea:
            String(
                localized: "village.role.bea", defaultValue: "the rescue: rehoming", bundle: .module,
                comment: "Bea's part in the game, after her name.")
        }
    }
}

/// The words for an option at a story's choice step. Every option of every story has words.
public func choiceText(story: String, option: String) -> String {
    switch (story, option) {
    case ("marigold", "return"):
        String(
            localized: "village.choice.marigold.return", defaultValue: "send Marigold home, with an egg for you",
            bundle: .module, comment: "A choice, lower case: send the borrowed hen back to Hazel.")
    case ("marigold", "keep"):
        String(
            localized: "village.choice.marigold.keep",
            defaultValue: "keep Marigold, and pay Hazel for her when you can",
            bundle: .module, comment: "A choice, lower case: keep the borrowed hen.")
    default: peopleChoiceText(story: story, option: option) ?? option
    }
}

/// For the CLI: how to answer a choice that waits. App words never carry command hints.
public func choiceHintText(_ c: PendingChoice) -> String {
    let commands = c.options.map { option in
        String(
            localized: "village.choiceHintCommand", defaultValue: "choose \(c.story) \(option)", bundle: .module,
            comment:
                "A command the player types in the CLI. Keep the word \"choose\" in English. Placeholders: story ID, option ID."
        )
    }
    let options = commands.dropFirst().reduce(commands.first ?? "") { list, next in
        String(
            localized: "village.choiceHintOr", defaultValue: "\(list), or \(next)", bundle: .module,
            comment: "Joins CLI commands the player may type. Placeholders: the commands so far, the next command.")
    }
    return String(
        localized: "village.choiceHint", defaultValue: "\(People.name(c.person)) asks you to choose. Type: \(options)",
        bundle: .module, comment: "CLI hint for a choice that waits. Placeholders: the person's name, the commands.")
}

/// What Hazel says at the back fence while the borrowed hen's story needs its own words, or nil.
/// While she is away, the fence is quiet. After a choice that waits (a perch to keep Marigold, or a hen
/// busy with eggs), she says what it waits for. Never a command hint: the app shows these words.
public func hazelFenceText(_ s: GameState) -> String? {
    if let home = s.hazelHomeDay {
        if home - s.day <= 1 {
            return String(
                localized: "village.hazelAwayTomorrow",
                defaultValue: "Hazel's house is quiet. She's at her sister's, and home tomorrow.", bundle: .module,
                comment: "At the back fence while Hazel is away. She is home tomorrow.")
        }
        return String(
            localized: "village.hazelAway",
            defaultValue: "Hazel's house is quiet. She's at her sister's, and home on day \(home).", bundle: .module,
            comment: "At the back fence while Hazel is away. The placeholder is the day she is home.")
    }
    guard s.loanedBird(tag: Storylines.marigold) != nil else { return nil }
    switch s.chosen(Storylines.marigold, in: Storylines.marigold) {
    case "keep"?:
        return String(
            localized: "village.hazelFenceKeep",
            defaultValue: "“She's yours as soon as there's a perch for her. Make room when you can, love.”",
            bundle: .module, comment: "Hazel at the back fence: the keeper kept Marigold but has no perch for her.")
    case "return"?:
        return String(
            localized: "village.hazelFenceReturn",
            defaultValue: "“Let her finish what she's busy with. I'll fetch her when she's free.”", bundle: .module,
            comment: "Hazel at the back fence: Marigold goes home once she is free.")
    default:
        return nil
    }
}

/// A short label for an option's button: "Send her home", "Keep her".
public func choiceButtonText(story: String, option: String) -> String {
    switch (story, option) {
    case ("marigold", "return"):
        String(
            localized: "village.choiceButton.marigold.return", defaultValue: "Send Marigold home", bundle: .module,
            comment: "Button: send the borrowed hen back to Hazel.")
    case ("marigold", "keep"):
        String(
            localized: "village.choiceButton.marigold.keep", defaultValue: "Keep Marigold", bundle: .module,
            comment: "Button: keep the borrowed hen.")
    default: choiceText(story: story, option: option).capitalizedFirst
    }
}

/// The option's words as a sentence, under its button: "Send Marigold home, with an egg for you."
public func choiceDetailText(story: String, option: String) -> String {
    let words = choiceText(story: story, option: option).capitalizedFirst
    return String(
        localized: "village.choiceDetail", defaultValue: "\(words).", bundle: .module,
        comment: "A choice's words as a sentence, under its button. The placeholder is the choice's words.")
}

/// What the person says when the keeper picks an option, or nil. Every option is a good one.
public func choiceReplyText(story: String, option: String) -> String? {
    switch (story, option) {
    case ("marigold", "return"):
        String(
            localized: "village.choiceReply.marigold.return",
            defaultValue: """
                Hazel tucks Marigold under her arm. "Thank you, love. She's had a lovely holiday. Here's an egg from \
                my flock, same breed as your chick, already candled."
                """,
            bundle: .module, comment: "Hazel's reply when the keeper sends Marigold home.")
    case ("marigold", "keep"):
        String(
            localized: "village.choiceReply.marigold.keep",
            defaultValue: "Hazel smiles. \"Pay me when you can. She likes you.\"",
            bundle: .module, comment: "Hazel's reply when the keeper keeps Marigold.")
    default: nil
    }
}

/// One debt, for the "You owe" list: "Hazel, 40 coins".
public func debtLineText(_ d: Debt) -> String {
    let name = People.name(d.to)
    return d.coins == 1
        ? String(
            localized: "village.debtLine.one", defaultValue: "\(name), \(d.coins) coin", bundle: .module,
            comment: "One debt in the \"You owe\" list, n == 1. Placeholders: the person's name, the coins.")
        : String(
            localized: "village.debtLine.other", defaultValue: "\(name), \(d.coins) coins", bundle: .module,
            comment: "One debt in the \"You owe\" list, n other than 1. Placeholders: the person's name, the coins.")
}

/// Under the "You owe" list.
public var debtsNoteText: String {
    String(
        localized: "village.debtsNote", defaultValue: "No hurry and no interest. Pay when you can.", bundle: .module,
        comment: "Under the \"You owe\" list.")
}

/// "Hazel's hen, staying 3 more days", or "… staying until tomorrow" for one day or less.
private func stayingText(owner: String, kind: String, left: Int) -> String {
    left <= 1
        ? String(
            localized: "village.loanStayingTomorrow", defaultValue: "\(owner)'s \(kind), staying until tomorrow",
            bundle: .module,
            comment: "A loaned bird's card: she goes home tomorrow. Placeholders: the owner's name, the kind of bird.")
        : String(
            localized: "village.loanStaying", defaultValue: "\(owner)'s \(kind), staying \(left) more days",
            bundle: .module,
            comment:
                "A loaned bird's card. Placeholders: the owner's name, the kind of bird, the days left (2 or more).")
}

/// One line about a bird on loan, for its card: whose she is and how long she stays. Nil for the keeper's own.
public func loanLineText(_ b: Bird, _ s: GameState) -> String? {
    guard let loan = b.loan else { return nil }
    let owner = People.name(loan.owner)
    let kind = kindWord(b, s)
    if loan.tag == Storylines.marigold {
        if let home = s.hazelHomeDay {
            return stayingText(owner: owner, kind: kind, left: max(0, home - s.day))
        }
        switch s.chosen(Storylines.marigold, in: Storylines.marigold) {
        case "keep"?:
            return String(
                localized: "village.loanKeep", defaultValue: "Yours once there's a perch for her", bundle: .module,
                comment: "Marigold's card: the keeper kept her and needs a perch for her.")
        case "return"?:
            return String(
                localized: "village.loanGoingHome", defaultValue: "\(owner)'s \(kind), going home once she's free",
                bundle: .module,
                comment: "Marigold's card: she goes home soon. Placeholders: the owner's name, the kind of bird.")
        default:
            return String(
                localized: "village.loanDecide",
                defaultValue: "\(owner)'s \(kind). \(owner) is home: keep her, or send her home?", bundle: .module,
                comment:
                    "Marigold's card: the keeper must choose. Placeholders: the owner's name, the kind of bird, the owner's name."
            )
        }
    }
    if let day = loan.returnDay {
        return stayingText(owner: owner, kind: kind, left: max(0, day - s.day))
    }
    return String(
        localized: "village.loanOnLoan", defaultValue: "\(owner)'s \(kind), on loan", bundle: .module,
        comment: "A loaned bird's card. Placeholders: the owner's name, the kind of bird.")
}

/// The words for a note in the post, by note ID (see `Notes.pool` and story `.note` rewards).
/// Nil for an unknown ID. A note in `Notes.pool` or in a story's `.note` reward must have words.
public func postNoteText(_ id: String, _ s: GameState) -> String? {
    switch id {
    default: peopleNoteText(id, s) ?? poolNoteText(id, s) ?? calendarNoteText(id, s)
    }
}

/// A village day's name.
public func villageDayName(_ v: VillageDay) -> String {
    switch v {
    case .hatchAlong:
        String(
            localized: "village.dayName.hatchAlong", defaultValue: "the Hatch-along", bundle: .module,
            comment: "A village day's name, in a sentence. Spring: the village hatches eggs together.")
    case .longestDay:
        String(
            localized: "village.dayName.longestDay", defaultValue: "the Longest Day", bundle: .module,
            comment: "A village day's name, in a sentence. Midsummer.")
    case .moultWeek:
        String(
            localized: "village.dayName.moultWeek", defaultValue: "Moult Week", bundle: .module,
            comment: "A village day's name, in a sentence. Autumn: the flock moults.")
    case .midwinterLights:
        String(
            localized: "village.dayName.midwinterLights", defaultValue: "Midwinter Lights", bundle: .module,
            comment: "A village day's name, in a sentence. Midwinter: lanterns in the windows.")
    }
}

/// What happens on a village day, in one line, for the calendar.
public func villageDayAbout(_ v: VillageDay) -> String {
    switch v {
    case .hatchAlong:
        String(
            localized: "village.dayAbout.hatchAlong", defaultValue: "The village hatches eggs together.",
            bundle: .module, comment: "What happens on the Hatch-along.")
    case .longestDay:
        String(
            localized: "village.dayAbout.longestDay", defaultValue: "The longest day of the year.", bundle: .module,
            comment: "What happens on the Longest Day.")
    case .moultWeek:
        String(
            localized: "village.dayAbout.moultWeek",
            defaultValue: "The flock drops its old feathers and grows new ones.", bundle: .module,
            comment: "What happens in Moult Week.")
    case .midwinterLights:
        String(
            localized: "village.dayAbout.midwinterLights", defaultValue: "Lanterns in every window of the village.",
            bundle: .module, comment: "What happens on Midwinter Lights.")
    }
}

/// The words for the people, loan, debt, post and calendar events.
func villageEventText(_ e: GameEvent, _ s: GameState) -> String? {
    switch e {
    case .chose(let story, let option):
        let choice = choiceText(story: story, option: option)
        guard let reply = choiceReplyText(story: story, option: option) else {
            return String(
                localized: "village.chose", defaultValue: "You've decided: \(choice).", bundle: .module,
                comment: "After the keeper picks an option. The placeholder is the option's words.")
        }
        return String(
            localized: "village.choseReply", defaultValue: "You've decided: \(choice). \(reply)", bundle: .module,
            comment:
                "After the keeper picks an option. Placeholders: the option's words, what the person says back.")
    case .storyCoins(_, let n):
        return n == 1
            ? String(
                localized: "village.storyCoins.one", defaultValue: "You're given \(n) coin.", bundle: .module,
                comment: "A story's gift, n == 1. The placeholder is the coins.")
            : String(
                localized: "village.storyCoins.other", defaultValue: "You're given \(n) coins.", bundle: .module,
                comment: "A story's gift, n other than 1. The placeholder is the coins.")
    case .storyTreats(_, let n):
        return n == 1
            ? String(
                localized: "village.storyTreats.one",
                defaultValue: "You're given \(n) mealworm. You have \(s.treats) treats.", bundle: .module,
                comment: "A story's gift, n == 1. Placeholders: the mealworms given, the treats the keeper has now.")
            : String(
                localized: "village.storyTreats.other",
                defaultValue: "You're given \(n) mealworms. You have \(s.treats) treats.", bundle: .module,
                comment:
                    "A story's gift, n other than 1. Placeholders: the mealworms given, the treats the keeper has now.")
    case .storyGiftEgg(_, let breed):
        return String(
            localized: "village.storyGiftEgg",
            defaultValue: "A \(breed.definition.displayName) egg goes into your carton, already candled.",
            bundle: .module, comment: "A story's gift. The placeholder is the breed's name.")
    case .loanArrived(let id, let owner):
        let bird = s.bird(id)
        let they =
            bird.map { subjectPronoun($0) }
            ?? String(
                localized: "village.pronounShe", defaultValue: "she", bundle: .module,
                comment: "A loaned bird no longer at home: she, lower case.")
        let name = birdName(id, s)
        let ownerName = People.name(owner)
        if bird?.revealed == true && bird?.sex == .rooster {
            return String(
                localized: "village.loanArrivedHis",
                defaultValue:
                    "\(name) comes to stay. \(they.capitalizedFirst) belongs to \(ownerName), and comes with a box of his own.",
                bundle: .module,
                comment:
                    "A loaned rooster arrives. Placeholders: his name, his pronoun or name (capital first), the owner's name."
            )
        }
        return String(
            localized: "village.loanArrivedHer",
            defaultValue:
                "\(name) comes to stay. \(they.capitalizedFirst) belongs to \(ownerName), and comes with a box of her own.",
            bundle: .module,
            comment:
                "A loaned hen, or a bird whose sex is hidden, arrives. Placeholders: the bird's name, her pronoun or name (capital first), the owner's name."
        )
    case .loanReturned(let id, let owner):
        return String(
            localized: "village.loanReturned", defaultValue: "\(birdName(id, s)) goes home to \(People.name(owner)).",
            bundle: .module, comment: "A loaned bird goes home. Placeholders: the bird's name, the owner's name.")
    case .loanKept(let id, let owner):
        let they =
            s.bird(id).map { subjectPronoun($0) }
            ?? String(
                localized: "village.pronounShe", defaultValue: "she", bundle: .module,
                comment: "A loaned bird no longer at home: she, lower case.")
        return String(
            localized: "village.loanKept",
            defaultValue: "\(birdName(id, s)) is yours now. \(People.name(owner)) is glad \(they)'s staying.",
            bundle: .module,
            comment:
                "The keeper keeps a loaned bird. Placeholders: the bird's name, the owner's name, the bird's pronoun or name."
        )
    case .debtOwed(_, let owner, let coins):
        return String(
            localized: "village.debtOwed",
            defaultValue: "You owe \(People.name(owner)) \(coins) coins. Pay when you can: there's no hurry.",
            bundle: .module, comment: "A new debt. Placeholders: the person's name, the coins.")
    case .debtReminder(_, let owner):
        return String(
            localized: "village.debtReminder",
            defaultValue:
                "\(People.name(owner)) waves over the fence. \"No rush on those coins, mind. Whenever suits.\"",
            bundle: .module, comment: "A kind reminder of a debt. The placeholder is the person's name.")
    case .debtPaid(_, let owner, let coins):
        return String(
            localized: "village.debtPaid",
            defaultValue: "You pay \(People.name(owner)) \(coins) coins. \"Thank you, love.\"",
            bundle: .module, comment: "A debt is paid. Placeholders: the person's name, the coins.")
    case .noteArrived(let person, let id):
        return postNoteText(id, s).map { note in
            String(
                localized: "village.noteArrived", defaultValue: "A note from \(People.name(person)): \(note)",
                bundle: .module, comment: "A note in the post. Placeholders: the sender's name, the note.")
        }
    case .villageDayComing(let v, let days):
        return String(
            localized: "village.dayComing",
            defaultValue: "\(villageDayName(v).capitalizedFirst) is in \(days) days. \(villageDayAbout(v))",
            bundle: .module,
            comment:
                "A village day comes soon (always 2 or more days away). Placeholders: the day's name (capital first), the days, what happens on it."
        )
    case .villageDay(let v):
        return String(
            localized: "village.dayToday", defaultValue: "Today is \(villageDayName(v)). \(villageDayAbout(v))",
            bundle: .module, comment: "A village day is today. Placeholders: the day's name, what happens on it.")
    default:
        return nil
    }
}

/// The people the keeper has met, one line each, with what they are waiting on. For the CLI `people`.
/// A person is met once one of their stories has started, the keeper owes them or has their bird on loan,
/// or a note from them has come. Hazel and Wren are met on day 1.
public func peopleLines(_ s: GameState) -> [String] {
    var out: [String] = []
    for person in Person.allCases where hasMet(person, s) {
        out.append(
            String(
                localized: "village.peopleLine",
                defaultValue: "\(People.name(person)), \(People.role(person)). \(People.about(person))",
                bundle: .module,
                comment: "CLI people list. Placeholders: the person's name, their part in the game, who they are."))
        for story in Storylines.all where story.person == person {
            guard let p = s.stories[story.id] else { continue }
            out.append("  \(p.rewarded ? "✓" : "•") \(story.id)")
        }
    }
    for c in s.pendingChoices {
        let items = c.options.map { option in
            String(
                localized: "village.peopleOption",
                defaultValue: "\(option) (\(choiceText(story: c.story, option: option)))",
                bundle: .module,
                comment: "CLI: one option of a choice. Placeholders: the option ID the player types, its words.")
        }
        let options = items.dropFirst().reduce(items.first ?? "") { list, next in
            String(
                localized: "village.peopleOptionList", defaultValue: "\(list), \(next)", bundle: .module,
                comment: "CLI: joins the options of a choice. Placeholders: the options so far, the next option.")
        }
        out.append(
            String(
                localized: "village.peopleChoice",
                defaultValue:
                    "\(People.name(c.person)) asks you to choose: \(options). Type: choose \(c.story) <option>",
                bundle: .module,
                comment:
                    "CLI: a choice that waits. Keep \"choose\" and \"<option>\" in English: the player types them. Placeholders: the person's name, the options, the story ID."
            ))
    }
    for d in s.debts {
        out.append(
            String(
                localized: "village.peopleDebt",
                defaultValue: "You owe \(People.name(d.to)) \(d.coins) coins. No hurry. To pay: pay \(d.id)",
                bundle: .module,
                comment:
                    "CLI: a debt. Keep \"pay\" after the colon in English: the player types it. Placeholders: the person's name, the coins, the debt ID."
            ))
    }
    for b in s.loanedBirds {
        guard let loan = b.loan else { continue }
        out.append(
            String(
                localized: "village.peopleLoan", defaultValue: "\(b.name) is on loan from \(People.name(loan.owner)).",
                bundle: .module, comment: "CLI: a loaned bird. Placeholders: the bird's name, the owner's name."))
    }
    return out
}

/// True once the keeper has met this person.
public func hasMet(_ p: Person, _ s: GameState) -> Bool {
    if p == .hazel || p == .wren { return true }
    if Storylines.all.contains(where: { $0.person == p && s.stories[$0.id] != nil }) { return true }
    if s.debts.contains(where: { $0.to == p }) || s.loanedBirds.contains(where: { $0.loan?.owner == p }) { return true }
    if p == .teddy && s.notesSeen.contains(where: { VillageDay.midwinterNoteYear($0) != nil }) { return true }
    return Notes.pool.contains { $0.from == p && s.notesSeen.contains($0.id) }
}

/// The next village days, one line each. `villageCalendarLines` adds what each day does.
public func calendarLines(_ s: GameState, count: Int = 4) -> [String] {
    s.upcomingVillageDays(count).map { next in
        let days = next.date - s.day
        let name = villageDayName(next.day).capitalizedFirst
        let about = villageDayAbout(next.day)
        return switch days {
        case 0:
            String(
                localized: "village.calendarToday", defaultValue: "\(name), today. \(about)", bundle: .module,
                comment: "CLI calendar line. Placeholders: the day's name (capital first), what happens on it.")
        case 1:
            String(
                localized: "village.calendarTomorrow", defaultValue: "\(name), tomorrow. \(about)", bundle: .module,
                comment: "CLI calendar line. Placeholders: the day's name (capital first), what happens on it.")
        default:
            String(
                localized: "village.calendarLater",
                defaultValue: "\(name), in \(days) days (day \(next.date)). \(about)", bundle: .module,
                comment:
                    "CLI calendar line. Placeholders: the day's name (capital first), the days until it (2 or more), its day number, what happens on it."
            )
        }
    }
}
