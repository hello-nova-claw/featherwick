import Foundation

// The breeding pen: the keeper chooses the sire.
//
// The pen is a corner of the coop. It holds at most one rooster and `Rules.penHens` hens. Penned
// birds keep their coop perch, so the pen adds no room and takes none away. Every coop rule (the fox,
// foraging, feeding, handling, finding homes) treats a penned bird like any coop bird.
//
// Only laying is different (see `Engine.lay`). A penned hen's egg is fathered by the penned rooster
// only. With no adult rooster in the pen her eggs are not fertile, like a coop with no rooster.
// A coop hen's egg is fathered by a random adult coop rooster, never the penned one. The pen's birds
// do not count toward coop rooster tension, and its hens are not unsettled by the coop roosters.
//
// A bird that leaves the coop (rehomed, traded, scared off by the fox) leaves the pen too.
// The pen sorts birds by sex, so a bird whose sex does not show yet cannot go in (rule 8).

extension GameState {
    /// The coop birds in the breeding pen, in coop order.
    public var pennedBirds: [Bird] { coop.filter { pen.contains($0.id) } }

    /// True when this bird is in the breeding pen.
    public func isPenned(_ id: UUID) -> Bool { pen.contains(id) && coop.contains { $0.id == id } }

    /// The rooster in the breeding pen, if any.
    public var penRooster: Bird? { pennedBirds.first { $0.sex == .rooster } }

    /// The day the penned rooster is grown and can father eggs. Nil when there is no penned rooster,
    /// or he is grown already. A cockerel may go in the pen early, so the keeper can plan; his hens'
    /// eggs stay clear until this day (the lay step uses an adult rooster only).
    public var penRoosterGrownDay: Int? {
        guard let rooster = penRooster, rooster.stage(onDay: day, rules: rules) != .adult else { return nil }
        return rooster.hatchDay + rules.adultAge
    }

    /// The hens in the breeding pen.
    public var pennedHens: [Bird] { pennedBirds.filter { $0.sex == .hen } }
}

extension Engine {
    /// Why this bird cannot go in the breeding pen now, or nil if it can. Front ends hide "Pen"
    /// when this is not nil. The sex check comes after the reveal check, so no answer leaks a hidden sex.
    public static func penBlocker(_ id: UUID, in s: GameState) -> Rejection? {
        if !s.isOpen(.breedingPen) { return .notYet(.breedingPen) }
        if s.isPenned(id) { return .alreadyInPen }
        guard let bird = s.coop.first(where: { $0.id == id }) else {
            if let b = s.birdsAtHome.first(where: { $0.id == id }) { return b.revealed ? .notInCoop : .tooYoungForPen }
            let away = s.lost.contains { $0.bird.id == id } || s.boarding.contains { $0.id == id }
            return away ? .birdNotHome : .noSuchBird
        }
        guard bird.revealed else { return .tooYoungForPen }
        switch bird.sex {
        case .rooster: return s.penRooster == nil ? nil : .penHasRooster
        case .hen: return s.pennedHens.count < s.rules.penHens ? nil : .penFull(hens: s.rules.penHens)
        }
    }

    /// True when front ends should offer "Pen" for this bird: a coop bird whose sex shows, not penned yet.
    /// A full pen still offers it; the refusal then says why, so a tap is never silent.
    public static func canOfferPen(_ id: UUID, in s: GameState) -> Bool {
        switch penBlocker(id, in: s) {
        case nil, .penFull, .penHasRooster: true
        default: false
        }
    }

    static func penBird(_ id: UUID, _ s: inout GameState) -> [GameEvent] {
        if let blocker = penBlocker(id, in: s) { return [.rejected(blocker)] }
        s.pen.append(id)
        return [.birdPenned(id)]
    }

    static func unpenBird(_ id: UUID, _ s: inout GameState) -> [GameEvent] {
        guard s.isPenned(id) else { return [.rejected(.notInPen)] }
        s.pen.removeAll { $0 == id }
        return [.birdUnpenned(id)]
    }

    /// Takes every bird that is no longer in the coop out of the pen. Runs after every command.
    static func leavePenIfGone(_ s: inout GameState) {
        guard !s.pen.isEmpty else { return }
        let inCoop = Set(s.coop.map(\.id))
        s.pen.removeAll { !inCoop.contains($0) }
    }
}
