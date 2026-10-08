import Foundation

// Daylight: a day has a few slots for errands, so a day is a handful of choices, not a to-do list.
//
// Care is always free: feeding, collecting, cuddles, treats, selling at the gate, setting eggs.
// An errand takes a slot: a trip to Speckle & Down, candling, the show desk, a visit to the
// neighbour, building. The first errand of a kind spends the slot; more of the same kind that day
// are free, because the keeper is already there. Resting spends a slot and does nothing else.
//
// Sleep waits until every slot is spent, and a refused errand simply waits for the morning: nothing
// is ever lost. Before the early-game lesson (`Feature.daylight`, day 9) none of this applies.
//
// Slots reset at the start of the night's "new day" group (`Engine.passNight`).

/// A kind of errand. The first of a kind each day takes a slot of daylight.
public enum Errand: String, Hashable, Codable, Sendable, CaseIterable {
    /// Speckle & Down: birds, eggs, treats, feed, the special, the big incubator.
    case village
    /// Holding eggs up to a light. Setting eggs is free; candling is the errand.
    case candling
    /// Entering birds or eggs in the county show. Show day itself costs nothing.
    case showDesk
    /// A visit to the neighbour: a story delivery, a trade, or a bird going to a new home.
    case neighbour
    /// The carpenter adds perches.
    case building
}

/// The time of day, worked out from the slots spent and never stored, so it can never drift.
/// Morning is the first slot, evening the last (and after), afternoon anything in between.
public enum TimeOfDay: String, Hashable, Codable, Sendable, CaseOrdered {
    case morning, afternoon, evening
}

extension GameState {
    /// Slots of daylight today: the plain day plus bonuses, capped. A bigger coop and a lap chicken
    /// make the keeper's day go further.
    public func slotsToday(rules: Rules) -> Int {
        var slots = rules.daySlots
        if coopUpgraded { slots += rules.slotBonusCoopUpgraded }
        if birdsAtHome.contains(where: { $0.friendliness == .lapChicken }) { slots += rules.slotBonusLapChicken }
        return min(slots, rules.maxDaySlots)
    }

    /// Slots still to spend today. Never below 0: today's slots can drop if a lap chicken leaves.
    public var slotsLeft: Int { max(0, slotsToday(rules: rules) - slotsUsed) }

    /// The time of day the next slot is spent in. Evening once one slot (or none) is left.
    public var timeOfDay: TimeOfDay {
        if slotsLeft <= 1 { return .evening }
        return slotsUsed == 0 ? .morning : .afternoon
    }

    /// True once the coop has more perches than it started with.
    var coopUpgraded: Bool { perches > rules.startPerches }
}

extension Engine {
    /// The errand a command runs, if any. Care, setting eggs and the pen cost no daylight.
    public static func errand(for command: Command) -> Errand? {
        switch command {
        case .buy, .buySpecial, .buyIncubator: .village
        case .candle, .candleEgg: .candling
        case .enterShow, .enterShowIn, .enterEggs, .enterEggPlate: .showDesk
        case .deliver, .acceptTrade, .rehome: .neighbour
        case .upgradeCoop: .building
        case .chooseStarter, .feed, .feedPremium, .collectEggs, .sellEggs, .sellChosenEggs, .sellClearEggs,
            .closeCoop, .pet, .giveTreat, .rename, .incubate, .incubateEggs, .sit, .sitEggs, .penBird, .unpenBird,
            .rest, .passNight, .openPlanner, .nameKeeper:
            nil
        }
    }

    /// Why the time of day refuses this command now, or nil. Front ends use it to show the refusal
    /// words in place of a button. Nothing is refused for time before the daylight lesson.
    public static func daylightRefusal(for command: Command, in s: GameState) -> Rejection? {
        guard s.isOpen(.daylight) else { return nil }
        switch command {
        case .passNight:
            return s.slotsLeft > 0 ? .notEveningYet(slotsLeft: s.slotsLeft) : nil
        case .rest:
            return s.slotsLeft > 0 ? nil : .timeForBed
        default:
            guard let errand = errand(for: command), !s.errandsToday.contains(errand), s.slotsLeft <= 0 else {
                return nil
            }
            return .noTimeLeft(errand)
        }
    }

    /// Spends a slot for a rest, or for the first errand of its kind today. Only a command that went
    /// through spends: a refused one (no coins, no egg) costs no daylight.
    static func spendDaylight(on command: Command, after ev: [GameEvent], _ s: inout GameState) -> [GameEvent] {
        guard s.isOpen(.daylight), !ev.isEmpty else { return [] }
        if ev.contains(where: { if case .rejected = $0 { true } else { false } }) { return [] }
        if command == .rest {
            s.slotsUsed += 1
            return [.slotSpent(nil, left: s.slotsLeft)]
        }
        guard let errand = errand(for: command), s.errandsToday.insert(errand).inserted else { return [] }
        s.slotsUsed += 1
        return [.slotSpent(errand, left: s.slotsLeft)]
    }

    /// A new day: every slot is back, and no errand has been run.
    static func resetDaylight(_ s: inout GameState) {
        s.slotsUsed = 0
        s.errandsToday = []
    }

    /// Rests until no daylight is left, so the keeper can sleep. For front ends and the simulation
    /// that end a day in one go. Does nothing before the daylight lesson.
    @discardableResult
    public static func restUntilEvening<R: RandomNumberGenerator>(
        _ s: inout GameState, using rng: inout R
    ) -> [GameEvent] {
        var ev: [GameEvent] = []
        while s.phase == .playing, s.isOpen(.daylight), s.slotsLeft > 0 {
            ev += apply(.rest, to: &s, using: &rng)
        }
        return ev
    }
}
