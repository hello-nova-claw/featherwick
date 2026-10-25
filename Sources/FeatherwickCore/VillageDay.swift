import Foundation

// The village calendar: a few small days a year that come round every year.
//
// Each village day falls in one season, on a day of that season set in `Rules.villageDays`. Seven
// mornings before (`Rules.villageDayNoticeDays`) the village says it is coming (`.villageDayComing`),
// and on the morning itself it happens (`.villageDay`). Nothing is missable: next year it comes again.
// The night step is "village day", after the post. Dates come from the day number only: no randomness.

public enum VillageDay: String, Hashable, Codable, Sendable, CaseIterable {
    /// Spring: bring a fertile egg to the village hatch.
    case hatchAlong
    /// Summer: the fox stays home on the longest night.
    case longestDay
    /// Autumn: the flock moults, and Hazel tells you about it.
    case moultWeek
    /// Winter: lights in the village, and a gift.
    case midwinterLights

    public var season: Season {
        switch self {
        case .hatchAlong: .spring
        case .longestDay: .summer
        case .moultWeek: .autumn
        case .midwinterLights: .winter
        }
    }
}

extension Rules {
    /// The day of its season a village day falls on, 1 to `daysPerSeason`.
    public func dayInSeason(_ v: VillageDay) -> Int {
        min(max(1, villageDays[v] ?? Rules.standard.villageDays[v] ?? 1), max(1, daysPerSeason))
    }

    /// The game day a village day falls on in a year (year 0 is the first).
    public func date(of v: VillageDay, inYear year: Int) -> Int {
        let seasons = Season.allCases
        let seasonIndex = seasons.firstIndex(of: v.season) ?? 0
        let perSeason = max(1, daysPerSeason)
        return (year * seasons.count + seasonIndex) * perSeason + dayInSeason(v) - 1
    }
}

extension GameState {
    /// The year a game day is in (year 0 is the first).
    public func year(onDay day: Int) -> Int { max(0, day) / (max(1, rules.daysPerSeason) * Season.allCases.count) }

    /// The next village day on or after `from` (today by default), and its day.
    public func nextVillageDay(from start: Int? = nil) -> (day: VillageDay, date: Int) {
        let from = start ?? day
        let year = year(onDay: from)
        return [year, year + 1].flatMap { y in
            VillageDay.allCases.map { (day: $0, date: rules.date(of: $0, inYear: y)) }
        }
        .filter { $0.date >= from }
        .min { ($0.date, $0.day.rawValue) < ($1.date, $1.day.rawValue) }!
    }

    /// The next village day from today.
    public var nextVillageDay: (day: VillageDay, date: Int) { nextVillageDay() }

    /// The next `count` village days from today, soonest first.
    public func upcomingVillageDays(_ count: Int) -> [(day: VillageDay, date: Int)] {
        var out: [(day: VillageDay, date: Int)] = []
        var from = day
        while out.count < count {
            let next = nextVillageDay(from: from)
            out.append(next)
            from = next.date + 1
        }
        return out
    }

    /// The village day on this game day, if one falls on it.
    public func villageDay(onDay d: Int) -> VillageDay? {
        VillageDay.allCases.first { rules.date(of: $0, inYear: year(onDay: d)) == d }
    }
}

extension Engine {
    /// Each morning: a notice a week before a village day, and the day itself. Then the Hatch-along
    /// chick, if it is due (see HatchAlong.swift).
    static func villageCalendar<R: RandomNumberGenerator>(_ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        var ev: [GameEvent] = []
        let notice = s.rules.villageDayNoticeDays
        if notice > 0, let coming = s.villageDay(onDay: s.day + notice) {
            ev.append(.villageDayComing(coming, inDays: notice))
        }
        if let today = s.villageDay(onDay: s.day) {
            ev.append(.villageDay(today))
            ev += villageDayEffects(today, &s, &rng)
        }
        return ev + hatchAlongChickHome(&s)
    }

    /// What a village day does. Each day's effect is its own small rule (see "The village calendar" in docs/design.md).
    /// Gifts come every year. No day draws from the game RNG (the Longest Day skips one draw: see
    /// `GameState.foxStaysHome`).
    static func villageDayEffects<R: RandomNumberGenerator>(
        _ v: VillageDay, _ s: inout GameState, _ rng: inout R
    ) -> [GameEvent] {
        var ev: [GameEvent] = [.villageDayScene(v, year: s.year(onDay: s.day))]
        switch v {
        case .hatchAlong, .longestDay:
            break  // the Hatch-along waits for an egg; the Longest Day acts at night (`foxStaysHome`)
        case .moultWeek:
            let treats = s.rules.moultWeekTreats
            s.treats += treats
            ev.append(.villageDayGift(.moultWeek, coins: 0, treats: treats))
        case .midwinterLights:
            let coins = s.rules.midwinterCoins
            s.coins += coins
            ev.append(.villageDayGift(.midwinterLights, coins: coins, treats: 0))
            let note = VillageDay.midwinterNote(year: s.year(onDay: s.day))
            s.notesSeen.insert(note)
            ev.append(.noteArrived(.teddy, note))
        }
        return ev
    }
}

extension VillageDay {
    /// Teddy's Midwinter Lights notes, with a drawing, one a year. The ID holds the year it came, so its
    /// words stay that year's words whenever they are read.
    public static let midwinterNotePrefix = "teddyMidwinterDrawing.y"

    public static func midwinterNote(year: Int) -> String { "\(midwinterNotePrefix)\(year)" }

    /// The year in a Midwinter note ID, or nil for any other note.
    public static func midwinterNoteYear(_ id: String) -> Int? {
        id.hasPrefix(midwinterNotePrefix) ? Int(id.dropFirst(midwinterNotePrefix.count)) : nil
    }
}

extension GameState {
    /// True on the Longest Day: that night the fox stays home. `passNight` skips the fox roll, so that
    /// night draws one number fewer from the game RNG. Every draw after it in that game moves too. Nights
    /// before the first Longest Day are unchanged.
    public var foxStaysHome: Bool { villageDay(onDay: day) == .longestDay }
}
