import Foundation

// Loans and debts: a person lends the keeper a bird for a while, and a keeper who keeps her pays when
// they can.
//
// A loaned bird lives in the coop but needs no perch: she comes with her own box. She can be fed,
// cuddled, given treats, shown in the pet class, scared by the fox, and she always comes home. She
// cannot be rehomed, penned, renamed or set on eggs: she is not the keeper's yet. Her eggs are the keeper's.
// She does not count toward the keeper's own flock (milestones, jobs, goals, the last-bird rule).
// Her look goes in the Breed Book: the keeper has seen her.
// When the loan ends she goes home to her owner (`.loanReturned`), and her family-tree record stays.
// If the keeper keeps her, the loan is cleared and she is the keeper's bird, pedigree intact.
//
// Debts are cozy: no interest, no deadline, and nothing is held back while one stands. The owner
// mentions it kindly at most once a season (`Rules.debtReminderDays`).

/// A bird on loan from one of Featherwick's people.
public struct Loan: Hashable, Codable, Sendable {
    public var owner: Person
    /// The story tag for this loan (see `LoanSpec.tag`).
    public var tag: String
    /// The morning she goes home. Nil: she stays until a story ends the loan.
    public var returnDay: Int?

    public init(owner: Person, tag: String, returnDay: Int? = nil) {
        self.owner = owner
        self.tag = tag
        self.returnDay = returnDay
    }
}

/// Coins the keeper owes someone. Paid with `Command.payDebt`, whenever the keeper likes.
public struct Debt: Hashable, Codable, Sendable, Identifiable {
    public var id: String
    public var to: Person
    public var coins: Int
    /// The last day the owner mentioned it (the day it began, at first).
    public var mentionedDay: Int

    public init(id: String, to: Person, coins: Int, mentionedDay: Int) {
        self.id = id
        self.to = to
        self.coins = coins
        self.mentionedDay = mentionedDay
    }
}

extension Bird {
    public var isOnLoan: Bool { loan != nil }
}

extension GameState {
    /// Perches in use: coop birds that are the keeper's own. A loaned bird brings her own box.
    public var perchesUsed: Int { coop.count(where: { $0.loan == nil }) }
    /// True while a perch is free for one more bird of the keeper's own.
    public var hasFreePerch: Bool { perchesUsed < perches }
    /// Birds on loan, at home or lost.
    public var loanedBirds: [Bird] { (coop + lost.map(\.bird)).filter(\.isOnLoan) }
    /// The keeper's own birds, wherever they are: every owned bird but those on loan.
    public var ownBirds: [Bird] { ownedBirds.filter { !$0.isOnLoan } }
    /// The bird on loan under this tag, if she is here.
    public func loanedBird(tag: String) -> Bird? { loanedBirds.first { $0.loan?.tag == tag } }
    /// The coins owed in all.
    public var coinsOwed: Int { debts.reduce(0) { $0 + $1.coins } }
}

extension Engine {
    /// A bird comes to stay. Named by her owner, grown, her sex and breed shown. Once per tag at a time.
    static func lend<R: RandomNumberGenerator>(_ spec: LoanSpec, _ s: inout GameState, _ rng: inout R) -> [GameEvent] {
        guard s.loanedBird(tag: spec.tag) == nil else { return [] }
        let breed = spec.breed ?? s.starterID.flatMap { s.bird($0)?.breed } ?? Breed.starters[0]
        var bird = Bird(
            id: makeID(using: &rng), name: spec.name, breed: breed,
            genome: breed.purebred(spec.sex, variety: breed.definition.varieties.randomElement(using: &rng)),
            hatchDay: s.day - spec.ageDays, origin: spec.owner.origin, revealed: true
        ).withFounderQuality()
        bird.tameness = s.rules.boughtBirdTameness
        bird.loan = Loan(owner: spec.owner, tag: spec.tag, returnDay: spec.stayDays.map { s.day + $0 })
        s.coop.append(bird)
        return [.loanArrived(bird.id, from: spec.owner)] + recordBreed(bird, into: &s.breedBook)
    }

    /// The loan under this tag ends. She goes home now, or, if she is sitting on eggs or mothering chicks,
    /// as soon as she is free (the night step). Nothing happens if she is not here.
    static func endLoan(tag: String, _ s: inout GameState) -> [GameEvent] {
        guard let bird = s.loanedBird(tag: tag) else { return [] }
        let today = s.day
        setLoan(of: bird.id, in: &s) { loan in
            let due = min(loan?.returnDay ?? today, today)
            loan?.returnDay = due
        }
        return isBusy(bird.id, s) ? [] : sendLoanHome(bird.id, &s)
    }

    /// The keeper keeps the loaned bird. She is the keeper's now; her price is a debt to her owner.
    static func keepLoan(tag: String, price: Int, _ s: inout GameState) -> [GameEvent] {
        guard let bird = s.loanedBird(tag: tag), let loan = bird.loan else { return [] }
        setLoan(of: bird.id, in: &s) { $0 = nil }
        var ev: [GameEvent] = [.loanKept(bird.id, from: loan.owner)]
        if price > 0, !s.debts.contains(where: { $0.id == tag }) {
            s.debts.append(Debt(id: tag, to: loan.owner, coins: price, mentionedDay: s.day))
            ev.append(.debtOwed(tag, to: loan.owner, coins: price))
        }
        return ev
    }

    /// Each night: loans whose day has come go home, once the bird is free to go.
    static func returnLoans(_ s: inout GameState) -> [GameEvent] {
        var ev: [GameEvent] = []
        for bird in s.loanedBirds {
            guard let due = bird.loan?.returnDay, due <= s.day, !isBusy(bird.id, s) else { continue }
            ev += sendLoanHome(bird.id, &s)
        }
        return ev
    }

    /// Each night: an owner mentions a debt kindly, at most once every `debtReminderDays`.
    static func mentionDebts(_ s: inout GameState) -> [GameEvent] {
        var ev: [GameEvent] = []
        for i in s.debts.indices where s.day - s.debts[i].mentionedDay >= max(1, s.rules.debtReminderDays) {
            s.debts[i].mentionedDay = s.day
            ev.append(.debtReminder(s.debts[i].id, to: s.debts[i].to))
        }
        return ev
    }

    static func payDebt(_ id: String, _ s: inout GameState) -> [GameEvent] {
        guard let i = s.debts.firstIndex(where: { $0.id == id }) else { return [.rejected(.noSuchDebt)] }
        let debt = s.debts[i]
        if s.coins < debt.coins { return [.rejected(.notEnoughCoins(needed: debt.coins, have: s.coins))] }
        s.coins -= debt.coins
        s.debts.remove(at: i)
        s.debtsPaid.insert(id)
        return [.debtPaid(id, to: debt.to, coins: debt.coins)]
    }

    /// Sitting on eggs, or raising chicks: a hen this busy stays put.
    static func isBusy(_ id: UUID, _ s: GameState) -> Bool {
        s.clutch(under: id) != nil || s.henChicks.contains { $0.raisedBy == id }
    }

    /// She leaves the coop (or, if lost, goes straight home). Her family-tree record stays, with the
    /// look the keeper last saw, so her chicks keep a mother.
    static func sendLoanHome(_ id: UUID, _ s: inout GameState) -> [GameEvent] {
        var bird: Bird?
        if let i = s.coop.firstIndex(where: { $0.id == id }) {
            bird = s.coop.remove(at: i).leavingSight(in: s, onDay: s.day)
        } else if let i = s.lost.firstIndex(where: { $0.bird.id == id }) {
            bird = s.lost.remove(at: i).bird.leavingSight(in: s, onDay: s.day, wasAway: true)
        }
        guard let bird, let owner = bird.loan?.owner else { return [] }
        s.pedigree[bird.id] = PedigreeRecord(bird, look: bird.lastSeenLook)
        s.pen.removeAll { $0 == id }
        // An entry in the next show goes with her, and the fee comes back: nothing is lost.
        let entries = s.showEntries.count(where: { $0.birdID == id })
        s.showEntries.removeAll { $0.birdID == id }
        s.coins += entries * s.rules.showEntryFee
        if s.starterID == id { s.starterID = nil }
        return [.loanReturned(bird.id, to: owner)]
    }

    static func setLoan(of id: UUID, in s: inout GameState, _ change: (inout Loan?) -> Void) {
        if let i = s.coop.firstIndex(where: { $0.id == id }) {
            change(&s.coop[i].loan)
        } else if let i = s.lost.firstIndex(where: { $0.bird.id == id }) {
            change(&s.lost[i].bird.loan)
        }
    }
}

extension Person {
    /// The `Bird.origin` for a bird from this person. Saves store these words: never change one.
    public var origin: String {
        switch self {
        case .hazel: Bird.neighbourOrigin
        case .wren: Bird.shopOrigin
        case .dot, .teddy, .okafor, .bea: Bird.villageOrigin
        }
    }
}
