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
    /// The show that was just held. The farm shows it full screen until the player goes back.
    private(set) var showReport: ShowReport?
    private var store: SaveStore
    private var nextLogID = 0

    var state: GameState { save.state }
    var saveLocation: String { store.url.path }

    init(directory: URL = GameStore.saveDirectory(), slot: String = SaveStore.defaultSlot) {
        // A local first: @Observable can't read `self.store` until every property is set.
        let store = SaveStore(directory: directory, slot: slot)
        self.store = store
        save = Self.load(from: store) ?? Self.newSave(rules: .standard)
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
        var state = save.state
        var rng = save.rng
        let events = Engine.apply(command, to: &state, using: &rng)
        save = SaveGame(state: state, rng: rng)
        for event in events {
            if let toast = toast(for: event, in: state) { showToast(toast) }
            guard let words = eventText(event, state) else { continue }
            var rejected = false
            if case .rejected = event { rejected = true }
            append(words, rejected: rejected)
        }
        // Several nights can pass in one go (`fullDays`): the newest show wins.
        if let report = Self.report(from: events, in: state) { showReport = report }
        persist()
        return events
    }

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
    func finishShow() { showReport = nil }

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
        append("A new game begins (\(difficulty.rawValue)).")
        persist()
    }

    func note(_ text: String) { append(text) }

    // MARK: - Toasts

    /// The few events worth a toast: new birds, reveals, collection entries, milestones, the fox.
    private func toast(for event: GameEvent, in s: GameState) -> (String, String?, FarmSheet?)? {
        switch event {
        case .chicksHatched(let ids, _):
            let one = ids.count == 1
            return (one ? "A chick has hatched" : "\(ids.count) chicks have hatched", "Name", .naming)
        case .revealed(let id, let sex, _):
            let name = s.bird(id)?.name ?? "A chick"
            return ("\(name) is a \(sex == .hen ? "pullet" : "cockerel")", "View", .bird(id))
        case .newBreedBookEntry(let entry):
            return ("\(entryText(entry).capitalized) added to the Breed Book", "View", .books)
        case .newEggBookEntry(let entry):
            return (
                "\(entry.speckled ? "Speckled " : "")\(entry.colour.rawValue) eggs added to the Egg Book", "View",
                .books
            )
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
        case .introduced(let f) where [.treats, .premiumFeed, .birdShop, .coopUpgrade, .incubatorShop].contains(f):
            return ("New at Speckle & Down", "View", .place(.farmGate))
        case .foxVisited(let ids):
            return ("A fox scared \(ids.count) bird\(ids.count == 1 ? "" : "s") away. They'll come home.", nil, nil)
        default:
            return nil
        }
    }

    private func showToast(_ t: (String, String?, FarmSheet?)) {
        let toast = Toast(id: nextLogID, text: t.0, action: t.1, opens: t.2)
        nextLogID += 1
        toasts.append(toast)
        if toasts.count > 2 { toasts.removeFirst(toasts.count - 2) }
    }

    func dismissToast(_ id: Int) { toasts.removeAll { $0.id == id } }

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
