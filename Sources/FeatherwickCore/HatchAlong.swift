import Foundation

// The Hatch-along: the spring village day when Featherwick hatches eggs together.
//
// The week starts on the day itself and lasts `Rules.hatchAlongWeekDays` days. In that week the keeper may
// bring one egg they KNOW is fertile (candled) to Hazel (`giveHatchAlongEgg`, the `.neighbour` errand).
// The egg joins the village hatch. `Rules.hatchAlongReturnNights` later a chick comes back: not the
// keeper's own egg, but a surprise starter breed from the village hatch. It arrives as a new chick, in the
// brooder, with a name to give. Its breed and sex show as it grows, like any chick (rule 8).
//
// Room: like a gift bird, the chick needs a free perch, and as a chick it needs a brooder place too. With
// no room, it waits with Hazel (`.hatchAlongChickWaiting`, once) and comes the first morning there is room.
// It never boards and is never rehomed while it waits. A waiting chick does not stop next year's egg: the
// chicks queue (`hatchAlongChickDays`) and come home one by one, oldest first, as room is made.
// No egg costs nothing: the day comes round next year.
//
// The chick is drawn from its own seed (the shop seed and the day), never the game RNG, so giving an egg
// changes no seeded game.

/// Why the Hatch-along can't take an egg now.
public enum HatchAlongRefusal: String, Hashable, Codable, Sendable {
    /// It is not the Hatch-along week.
    case notThisWeek
    /// An egg was brought this year already.
    case alreadyGiven
    /// No egg in the carton is known to be fertile (or the chosen one is not).
    case noFertileEgg
}

extension GameState {
    /// The day the Hatch-along week started, if today is in it.
    public var hatchAlongWeekStart: Int? {
        let start = rules.date(of: .hatchAlong, inYear: year(onDay: day))
        let length = max(1, rules.hatchAlongWeekDays)
        return (start..<start + length).contains(day) ? start : nil
    }

    /// Why an egg can't go to the Hatch-along today, or nil if one can. Front ends hide the button
    /// when this is not nil. A chosen egg must be in the carton and known to be fertile.
    public func hatchAlongRefusal(egg id: UUID? = nil) -> HatchAlongRefusal? {
        guard let start = hatchAlongWeekStart else { return .notThisWeek }
        if hatchAlongYears.contains(year(onDay: start)) { return .alreadyGiven }
        return hatchAlongEgg(id) == nil ? .noFertileEgg : nil
    }

    /// The egg that would go: the chosen one, or the first known-fertile egg in the carton.
    func hatchAlongEgg(_ id: UUID?) -> Egg? {
        carton.first { $0.isCandled && $0.isFertile && (id == nil || $0.id == id) }
    }

    /// True while a Hatch-along chick is due or waiting with Hazel.
    public var hatchAlongChickDue: Bool { !hatchAlongChickDays.isEmpty }
}

extension Engine {
    /// The keeper hands one known-fertile egg to Hazel for the village hatch.
    static func giveHatchAlongEgg(_ id: UUID?, _ s: inout GameState) -> [GameEvent] {
        if let refusal = s.hatchAlongRefusal(egg: id) { return [.rejected(.hatchAlong(refusal))] }
        guard let egg = s.hatchAlongEgg(id), let start = s.hatchAlongWeekStart else { return [] }
        s.carton.removeAll { $0.id == egg.id }
        s.hatchAlongYears.insert(s.year(onDay: start))
        let returns = s.day + max(1, s.rules.hatchAlongReturnNights)
        s.hatchAlongChickDays.append(returns)
        return [.hatchAlongEggGiven(returnsOnDay: returns)]
    }

    /// Each morning: Hatch-along chicks whose day has come go home, oldest first, while there is room (a
    /// free perch and a brooder place). The rest wait with Hazel, and each says so once.
    ///
    /// A perch is free only if no bird already waits for it: every bird in the brooder or with a mother
    /// hen (each will want a perch when grown) and every bird boarding with Hazel holds one. So a chick
    /// that came home yesterday still holds its perch today, and no chick is ever rehomed for lack of one.
    static func hatchAlongChickHome(_ s: inout GameState) -> [GameEvent] {
        var ev: [GameEvent] = []
        var waiting: [Int] = []
        for due in s.hatchAlongChickDays.sorted() {
            let held = s.perchesUsed + s.brooder.count + s.henChicks.count + s.boarding.count
            let room = held < s.perches && brooderRoom(s) > 0
            guard s.day >= due, waiting.isEmpty, room else {
                if s.day >= due, s.storyNotices.insert("hatchAlong.\(due).waitingForRoom").inserted {
                    ev.append(.hatchAlongChickWaiting)
                }
                waiting.append(due)
                continue
            }
            ev.append(hatchAlongChick(due: due, &s))
        }
        s.hatchAlongChickDays = waiting
        return ev
    }

    /// One Hatch-along chick comes home to the brooder.
    static func hatchAlongChick(due: Int, _ s: inout GameState) -> GameEvent {
        // Its own seed: the shop seed and the day the chick was due. No game RNG.
        var rng = SeededRNG(seed: s.shopSeed ^ 0x4843_4841 ^ UInt64(truncatingIfNeeded: due))  // "HCHA"
        let breed = Breed.starters.randomElement(using: &rng)!
        let sex: Sex = Bool.random(using: &rng) ? .hen : .rooster
        let variety = breed.definition.varieties.randomElement(using: &rng)
        var chick = Bird(
            id: makeID(using: &rng), name: "Village chick", breed: breed,
            genome: breed.purebred(sex, variety: variety),
            hatchDay: s.day, origin: Bird.villageOrigin
        ).withFounderQuality().withTameness(s.rules.brooderChickTameness)
        chick.needsName = true
        s.brooder.append(chick)
        return .hatchAlongChickArrived(chick.id)
    }
}
