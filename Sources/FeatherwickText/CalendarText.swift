import FeatherwickCore

// The words for the four village days: each day's scene, its gifts, Teddy's Midwinter note and the
// Hatch-along. Core holds the IDs and the year; every one has its words here.
//
// Each day has two scenes: the first year's (year 0) and the one for every year after. The first year
// explains; later years remember. Rule 8: nothing here names a bird's sex or breed before it shows.

/// A village day's short name, for notices ("Hatch-along in 3 days").
public func villageDayShortName(_ v: VillageDay) -> String {
    switch v {
    case .hatchAlong: "Hatch-along"
    case .longestDay: "Longest Day"
    case .moultWeek: "Moult Week"
    case .midwinterLights: "Midwinter Lights"
    }
}

/// What a village day does for the keeper, in one line. Each line is a rule the engine keeps.
public func villageDayEffectText(_ v: VillageDay) -> String {
    switch v {
    case .hatchAlong: "Bring an egg you know is fertile in its week, and a surprise chick comes back."
    case .longestDay: "The fox stays home that night."
    case .moultWeek: "\(People.neighbour) brings mealworms for the moult."
    case .midwinterLights: "The village gives its keepers a gift."
    }
}

/// The next village days with what each one does, one line each. For the CLI `calendar` and the app.
public func villageCalendarLines(_ s: GameState, count: Int = 4) -> [String] {
    zip(calendarLines(s, count: count), s.upcomingVillageDays(count)).map { "\($0) \(villageDayEffectText($1.day))" }
}

/// What a village day brings, in its year's words: year 0 explains, later years remember.
public func villageDaySceneText(_ v: VillageDay, year: Int, _ s: GameState) -> String {
    let first = year == 0
    let nights = s.rules.hatchAlongReturnNights
    switch v {
    case .hatchAlong:
        return first
            ? "\(People.neighbour) has her big incubator set up in the village hall. \"Everyone brings one egg "
                + "they know is fertile, and everyone gets a chick back in \(nights) nights. Not your own egg's "
                + "chick, mind: whichever the hatch sends you. That's the fun of it. You've all week.\""
            : "The Hatch-along again. \(People.neighbour)'s incubator hums in the village hall, and the "
                + "children have drawn name cards for the trays. One known-fertile egg this week, and a "
                + "surprise chick comes home \(nights) nights later."
    case .longestDay:
        return first
            ? "The longest day of the year. The whole village is out on the green until the light goes. "
                + "\"The fox never stirs tonight,\" \(People.neighbour) says. \"Too many people about. "
                + "Leave the door open if you like: they can forage in peace.\""
            : "Midsummer again. The lanes smell of elderflower, and the fox keeps to its den tonight. "
                + "A safe night to leave the door open, if you like."
    case .moultWeek:
        return first
            ? "\(People.neighbour) leans on the fence. \"Don't fret if the coop looks like a pillow burst. "
                + "It's the moult. Every autumn they drop their old feathers and grow new ones. They look a "
                + "fright for a week or two, but nobody's poorly, and the judges know what season it is. "
                + "Feathers are nearly all protein, so here: these help.\""
            : "Moult Week again. Feathers drift round the yard like snow. \(People.neighbour) passes "
                + "a bag over the fence. \"Same as last year, love. Protein in, new coats out.\""
    case .midwinterLights:
        return first
            ? "Midwinter Lights. There's a lantern in every window down the lane, and \(People.shopkeeper) "
                + "hangs a paper star over the shop door. The village keeps a little fund for its keepers, "
                + "and this year you're one of them."
            : "Midwinter Lights again. You know the way to the green now. The lanterns are lit, the "
                + "kettle's on in the hall, and the keepers' fund comes round."
    }
}

/// The words for the village-day and Hatch-along events.
func calendarEventText(_ e: GameEvent, _ s: GameState) -> String? {
    switch e {
    case .villageDayScene(let v, let year):
        return villageDaySceneText(v, year: year, s)
    case .villageDayGift(.moultWeek, _, let treats):
        return "You're given \(treats) mealworm\(treats == 1 ? "" : "s"). You have \(s.treats) treats."
    case .villageDayGift(_, let coins, let treats):
        let parts = [coins > 0 ? "\(coins) coins" : nil, treats > 0 ? "\(treats) mealworms" : nil].compactMap { $0 }
        return parts.isEmpty ? nil : "The village gives you \(parts.joined(separator: " and "))."
    case .hatchAlongEggGiven:
        let nights = s.rules.hatchAlongReturnNights
        return "You hand \(People.neighbour) an egg you know is fertile. She pencils your name on the tray "
            + "and tucks it in with the village's eggs. \"\(nights) nights, and a chick comes back to you.\""
    case .hatchAlongChickWaiting:
        return "\(People.neighbour) calls over the fence. \"Your Hatch-along chick is ready, but there's no "
            + "room for it yet. It needs a place in the brooder, and a perch for when it's grown. It can "
            + "stay with me until then. No hurry.\""
    case .hatchAlongChickArrived(let id):
        return "\(People.neighbour) brings a chick home from the village hatch, cupped in her hands, and "
            + "settles it under the heat lamp. What breed is it? You'll see when its feathers come in. "
            + "\(birdName(id, s)) needs a name."
    default:
        return nil
    }
}

/// Why the Hatch-along can't take an egg now.
func hatchAlongRefusalText(_ why: HatchAlongRefusal) -> String {
    switch why {
    case .notThisWeek:
        "The Hatch-along is in spring. Bring an egg in its week: the village calendar says when."
    case .alreadyGiven:
        "You've brought your Hatch-along egg this year. One each, \(People.neighbour) says. There's next spring."
    case .noFertileEgg:
        "The Hatch-along needs an egg you KNOW is fertile. Candle your eggs to find one, or buy a fertile "
            + "egg at Speckle & Down: they come candled."
    }
}

/// The words for the notes the calendar sends (not from the post's pool). Nil for any other ID.
func calendarNoteText(_ id: String, _ s: GameState) -> String? {
    // Words by the year the note came (it is in the ID). Rule 8: the drawing shows no bird in particular.
    switch VillageDay.midwinterNoteYear(id) {
    case .some(let year):
        year == 0
            ? "\"Mum says I can't have a chicken but I can draw one. This is yours. The yellow bit is the "
                + "lights.\" A crayon drawing of a very round bird under a very big moon."
            : "\"I drew all of them this year. The one in the hat is you.\" A crayon drawing of a lot of "
                + "birds, a coop, and someone in a hat."
    case .none: nil
    }
}

/// The Hatch-along lines for the calendar: a chick on its way, and the week while an egg can still go.
/// Empty otherwise. No CLI commands: each front end offers its own way to bring the egg.
public func hatchAlongLines(_ s: GameState) -> [String] {
    var out: [String] = []
    let due = s.hatchAlongChickDays.count
    if due > 0 {
        out.append(
            due == 1
                ? "Your Hatch-along chick is coming from \(People.neighbour)'s."
                : "\(due) Hatch-along chicks are coming from \(People.neighbour)'s, one as each finds room.")
    }
    switch s.hatchAlongRefusal() {
    case nil: out.append("It's Hatch-along week. Bring \(People.neighbour) an egg you know is fertile.")
    case .noFertileEgg: out.append("It's Hatch-along week. You need an egg you know is fertile to bring one.")
    case .notThisWeek, .alreadyGiven: break
    }
    return out
}

/// A short notice for the farm gate: a village day coming soon, today, or the Hatch-along week. Nil
/// when nothing is close.
public func villageNotice(_ s: GameState) -> String? {
    if s.hatchAlongRefusal() == nil { return "Hatch-along: bring an egg" }
    let next = s.nextVillageDay
    let days = next.date - s.day
    guard days <= s.rules.villageDayNoticeDays else { return nil }
    let name = villageDayShortName(next.day)
    return days == 0 ? "\(name) today" : days == 1 ? "\(name) tomorrow" : "\(name) in \(days) days"
}
