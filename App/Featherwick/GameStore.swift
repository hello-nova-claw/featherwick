import FeatherwickCore
import FeatherwickText
import Foundation
import Observation

/// One line in the "what happened" log, oldest first.
struct LogLine: Identifiable, Hashable {
    let id: Int
    let day: Int
    let text: String
    /// The engine said no (not enough coins, no free perch...). Shown in a warning colour.
    let isRejection: Bool
}

/// A short note over the farm, with at most one action ("Name her", "View").
struct Toast: Identifiable, Hashable {
    let id: Int
    let text: String
    var action: String?
    var opens: FarmSheet?
}

/// One county show, as the show screen tells it: the day, the theme, and how each entry placed.
struct ShowReport: Identifiable, Hashable {
    let day: Int
    let theme: ShowTheme
    /// The player's placings, in the order the engine judged them (class by class).
    let results: [ShowResult]
    var id: Int { day }

    var coinsWon: Int { results.reduce(0) { $0 + $1.prize } }
    var treatsWon: Int { results.reduce(0) { $0 + ($1.treats ?? 0) } }
}

/// The app's one game. Every button sends a `Command` here; the engine answers with events, which
/// become log lines through FeatherwickText. The game saves after every command.
@MainActor @Observable
final class GameStore {
    private(set) var save: SaveGame
    private(set) var log: [LogLine] = []
    /// Notes over the farm, newest last. At most two show at once.
    private(set) var toasts: [Toast] = []
    /// A sheet something asked to open (a toast's action). The farm opens it and clears this.
    var openRequest: FarmSheet?
    /// What the neighbour told the keeper and they have not read yet (lessons, show news).
    /// The farm opens them as a note, so a lesson is never only in the log.
    private(set) var neighbourNotes: [String] = []
    /// The show that was just held. The farm shows it full screen until the player goes back.
    private(set) var showReport: ShowReport?
    /// Shop stock the keeper has looked at since the early game brought it in. The game has no idea of
    /// "seen", so the app keeps it (per save slot), and the farm gate stops saying "new in today".
    private(set) var seenNewStock: Set<Feature>
    private var store: SaveStore
    private let seenStockKey: String
    /// The save slot, so per-slot notes kept outside the save (new stock seen, beta prompts) find theirs.
    let slot: String
    private var nextLogID = 0

    var state: GameState { save.state }
    var saveLocation: String { store.url.path }

    init(directory: URL = GameStore.saveDirectory(), slot: String = SaveStore.defaultSlot) {
        // A local first: @Observable can't read `self.store` until every property is set.
        let store = SaveStore(directory: directory, slot: slot)
        self.store = store
        self.slot = slot
        save = Self.load(from: store) ?? Self.newSave(rules: .standard)
        seenStockKey = "seenNewStock.\(slot)"
        let seen = UserDefaults.standard.stringArray(forKey: seenStockKey) ?? []
        seenNewStock = Set(seen.compactMap(Feature.init(rawValue:)))
        append(state.day == 0 ? "Welcome to Featherwick." : "Welcome back. It is day \(state.day).")
    }

    /// Saves live in Application Support, which the system backs up but the user never sees.
    nonisolated static func saveDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Featherwick", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    nonisolated static func newSave(rules: Rules) -> SaveGame {
        var rng = SeededRNG(seed: UInt64.random(in: .min ... .max))
        let state = Engine.newGame(rules: rules, using: &rng)
        return SaveGame(state: state, rng: rng)
    }

    /// The main save, else the newest backup. An unreadable save is moved aside, never deleted.
    private static func load(from store: SaveStore) -> SaveGame? {
        if let data = try? store.read() {
            if let save = try? SaveFormat.decode(data) { return save }
            store.quarantine()
        }
        return store.newestBackupData().flatMap { try? SaveFormat.decode($0) }
    }

    // MARK: - Playing

    @discardableResult
    func run(_ command: Command) -> [GameEvent] {
        let before = save.state
        var state = save.state
        var rng = save.rng
        let events = Engine.apply(command, to: &state, using: &rng)
        save = SaveGame(state: state, rng: rng)
        if Self.isShopping(command) { sawNewStock() }
        for event in events {
            if let toast = toast(for: event, in: state) ?? handlingToast(for: event, in: events, before, state) {
                showToast(toast)
            }
            guard let words = eventText(event, state) else { continue }
            if Self.isNeighbourNote(event) { neighbourNotes.append(words) }
            var rejected = false
            if case .rejected = event { rejected = true }
            append(words, rejected: rejected)
        }
        // Sound and haptics for what just happened (eggs, hatching, coins, a "no").
        GameFeedback.play(for: events)
        if !neighbourNotes.isEmpty, openRequest == nil { openRequest = .neighbourNote }
        // Several nights can pass in one go (`fullDays`): the newest show wins.
        if let report = Self.report(from: events, in: state) { showReport = report }
        #if DEBUG || BETA
            noticeBetaMoments(in: events)
        #endif
        persist()
        return events
    }

    /// Lessons, show news and the gift incubator from the neighbour: the words the keeper must not miss.
    /// The incubator note says what to do with a fertile egg, so it must not sit only in the log.
    private static func isNeighbourNote(_ event: GameEvent) -> Bool {
        switch event {
        case .introduced, .showAnnounced, .neighbourGaveIncubator: true
        default: false
        }
    }

    /// The keeper has read the neighbour's notes.
    func readNeighbourNotes() { neighbourNotes.removeAll() }

    /// A whole day, as a keeper in a hurry: feed, collect, sell if the carton is full, close, sleep.
    func fullDays(_ count: Int) {
        for _ in 0..<max(1, count) {
            run(.feed)
            if !state.nest.isEmpty { run(.collectEggs) }
            if state.carton.count >= state.cartonCapacity { run(.sellEggs) }
            if state.coopDoorOpen { run(.closeCoop) }
            run(.passNight)
        }
    }

    /// The player is back from the show.
    func finishShow() {
        #if DEBUG || BETA
            // The first show the keeper entered: ask once they are back on the farm, not over the results.
            if showReport?.results.isEmpty == false { queueBetaPrompt(.firstShow) }
        #endif
        showReport = nil
        #if DEBUG || BETA
            offerBetaPrompt()
        #endif
    }

    /// The show held this night, if any. With no entries there is no result to carry the theme, so the
    /// show day's season names it.
    private static func report(from events: [GameEvent], in s: GameState) -> ShowReport? {
        var day: Int?
        var results: [ShowResult] = []
        for event in events {
            switch event {
            case .showDay(let d): day = d
            case .showPlacing(let r): results.append(r)
            default: break
            }
        }
        guard let day else { return nil }
        let theme = results.first?.theme ?? ShowTheme.forSeason(s.season)
        return ShowReport(day: day, theme: theme, results: results)
    }

    func newGame(_ difficulty: Difficulty) {
        save = Self.newSave(rules: difficulty.rules)
        log = []
        showReport = nil
        // A new game brings its stock in again, so it is all new again.
        seenNewStock = []
        UserDefaults.standard.removeObject(forKey: seenStockKey)
        append("A new game begins (\(difficulty.rawValue)).")
        persist()
    }

    func note(_ text: String) { append(text) }

    // MARK: - New stock at the farm gate

    /// The early-game steps that bring new stock to Speckle & Down.
    static let shopFeatures: [Feature] = [.treats, .premiumFeed, .birdShop, .coopUpgrade, .incubatorShop]

    /// Stock the early game brought in this morning that the keeper has not looked at yet.
    var hasNewStock: Bool {
        let s = state
        return Self.shopFeatures.contains {
            s.isOpen($0) && s.rules.introductionDay(of: $0) == s.day && !seenNewStock.contains($0)
        }
    }

    /// The keeper opened the shop (or bought from it): everything on sale there is no longer new.
    func sawNewStock() {
        let open = Set(Self.shopFeatures.filter { state.isOpen($0) })
        guard !open.isSubset(of: seenNewStock) else { return }
        seenNewStock.formUnion(open)
        UserDefaults.standard.set(seenNewStock.map(\.rawValue).sorted(), forKey: seenStockKey)
    }

    /// Commands that buy from Speckle & Down. Buying also counts as having seen the new stock.
    private static func isShopping(_ command: Command) -> Bool {
        switch command {
        case .buy, .buySpecial, .upgradeCoop, .buyIncubator: true
        default: false
        }
    }

    // MARK: - Toasts

    /// The few events worth a toast: new birds, reveals, collection entries, milestones, the fox.
    private func toast(for event: GameEvent, in s: GameState) -> (String, String?, FarmSheet?)? {
        switch event {
        case .rejected:
            // The engine said no: say why, so a tap is never silently ignored.
            return eventText(event, s).map { ($0, nil, nil) }
        case .chicksHatched(let ids, _):
            let one = ids.count == 1
            return (one ? "A chick has hatched" : "\(ids.count) chicks have hatched", "Name", .naming)
        case .revealed(let id, let sex, _):
            let name = s.bird(id)?.name ?? "A chick"
            return ("\(name) is a \(sex == .hen ? "pullet" : "cockerel")", "View", .bird(id))
        case .newBreedBookEntry(let entry):
            // No "View" until the neighbour has shown the keeper the books (see `FarmView`).
            let view = s.isOpen(.breedBook)
            let words = "\(entryText(entry).capitalized) added to the Breed Book"
            return (words, view ? "View" : nil, view ? .books : nil)
        case .breedBookEntrySeen(let entry, let theme):
            let view = s.isOpen(.breedBook)
            let words = "\(entryText(entry).capitalized) added to the Breed Book (seen at the \(showThemeName(theme)))"
            return (words, view ? "View" : nil, view ? .books : nil)
        case .newEggBookEntry(let entry):
            let view = s.isOpen(.breedBook)
            let words = "\(entry.speckled ? "Speckled " : "")\(entry.colour.rawValue) eggs added to the Egg Book"
            return (words, view ? "View" : nil, view ? .books : nil)
        case .milestoneReached(let id):
            return ("Milestone: \(milestoneText(id).title)", nil, nil)
        case .storyGift(_, let id):
            return ("\(s.bird(id)?.name ?? "A hen") has joined the flock", "View", .bird(id))
        case .rehomedByNeighbour(let id, let coins):
            return ("\(s.bird(id)?.name ?? "A bird") went to a new home (+\(coins) coins)", nil, nil)
        case .namedForYou(let id):
            return ("The new bird is now called \(s.bird(id)?.name ?? "something")", "View", .bird(id))
        case .showAnnounced(let tip):
            let show = showThemeName(ShowTheme.forSeason(s.season(onDay: tip?.showDay ?? s.nextShowDay)))
            return ("The \(show) is next week", "View", .place(.farmGate))
        case .introduced(let f) where Self.shopFeatures.contains(f):
            return ("New at Speckle & Down", "View", .place(.farmGate))
        case .foxVisited(let ids):
            return ("A fox scared \(ids.count) bird\(ids.count == 1 ? "" : "s") away. They'll come home.", nil, nil)
        case .friendlierNow:
            // A move up a friendliness band: the same words as the log.
            return eventText(event, s).map { ($0, nil, nil) }
        case .allJobsDone(let coins):
            return ("All of today's jobs are done (+\(coins) coins)", "View", .jobs)
        case .seasonGoalReached(_, let coins):
            return ("Season goal reached (+\(coins) coins)", "View", .jobs)
        default:
            return nil
        }
    }

    /// A small note when a cuddle or a treat made a bird a little tamer. Skipped when the same action
    /// moved the bird up a band: that has its own toast.
    private func handlingToast(
        for event: GameEvent, in events: [GameEvent], _ before: GameState, _ after: GameState
    ) -> (String, String?, FarmSheet?)? {
        guard case .handled(let id, let kind) = event else { return nil }
        let movedUp = events.contains { e in
            if case .friendlierNow(let other, _) = e { return other == id }
            return false
        }
        if movedUp { return nil }
        let was = before.bird(id)?.currentTameness ?? 1
        let now = after.bird(id)?.currentTameness ?? 0
        guard now > was else { return nil }
        return (handledToastText(id, kind, after), nil, nil)
    }

    private func showToast(_ t: (String, String?, FarmSheet?)) {
        let toast = Toast(id: nextLogID, text: t.0, action: t.1, opens: t.2)
        nextLogID += 1
        toasts.append(toast)
        if toasts.count > 2 { toasts.removeFirst(toasts.count - 2) }
    }

    func dismissToast(_ id: Int) { toasts.removeAll { $0.id == id } }

    // MARK: - Beta prompts (TestFlight only, see `Beta/BetaNotes.swift`)

    // No stored property here: the Observable macro and `#if` do not mix well, and the waiting question
    // is not something a view draws. `BetaNotes.waiting` holds it.
    #if DEBUG || BETA
        /// The first hatch asks straight away. The first show waits until the results close (`finishShow`).
        private func noticeBetaMoments(in events: [GameEvent]) {
            let hatched = events.contains { e in
                if case .chicksHatched = e { return true }
                return false
            }
            if hatched { queueBetaPrompt(.firstHatch) }
            offerBetaPrompt()
        }

        private func queueBetaPrompt(_ moment: BetaMoment) {
            guard !BetaNotes.waiting.contains(moment), BetaNotes.isOn, !BetaNotes.wasAsked(moment, slot: slot)
            else { return }
            BetaNotes.waiting.append(moment)
        }

        /// Asks the farm to open the waiting question, unless a show or another sheet comes first.
        /// The farm calls this again when its sheet closes.
        func offerBetaPrompt() {
            guard let moment = BetaNotes.waiting.first, showReport == nil, openRequest == nil else { return }
            openRequest = .betaPrompt(moment)
        }

        /// Saved, skipped or swiped away: this slot is never asked again. Not on open, so a question that
        /// another sheet pushed aside is still asked later.
        func betaPromptAnswered(_ moment: BetaMoment) {
            BetaNotes.waiting.removeAll { $0 == moment }
            BetaNotes.markAsked(moment, slot: slot)
        }

        /// Settings (Debug): ask this question when Settings closes, asked before or not.
        func tryBetaPrompt(_ moment: BetaMoment) { BetaNotes.waiting = [moment] }
    #endif

    // MARK: - Log and saving

    private func append(_ text: String, rejected: Bool = false) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        log.append(LogLine(id: nextLogID, day: state.day, text: clean, isRejection: rejected))
        nextLogID += 1
        if log.count > 400 { log.removeFirst(log.count - 400) }
    }

    private func persist() {
        guard let data = try? SaveFormat.encode(save) else { return }
        try? store.write(data)
    }
}
