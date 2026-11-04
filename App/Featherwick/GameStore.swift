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

/// The words for a command the time of day refuses now, or nil. Shown under or in place of its button,
/// so the keeper knows before tapping that it waits for the morning.
func daylightRefusalText(_ command: Command, in s: GameState) -> String? {
    Engine.daylightRefusal(for: command, in: s).flatMap { eventText(.rejected($0), s) }
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
    /// What happened overnight, after the keeper chose Sleep. The farm shows it once, before the farm,
    /// until the keeper goes back. Nil when the "Morning report" switch is off.
    private(set) var morningReport: MorningReport?
    /// True only while `sleep()` runs the night, so test tools and fast forward make no report.
    private var reportingNight = false
    /// When this evening began on the device clock, for the 30-minute crossfade to night. Nil before evening.
    /// App state, not game state: the game only knows the time of day.
    private(set) var eveningSince: Date?
    /// True from Sleep until the morning report (or the farm) shows: the farm is night meanwhile.
    private(set) var asleep = false
    /// While a rest plays, how long it lasts in seconds. The farm takes no taps meanwhile, and the sun
    /// mark and the light move over this time. Nil when no rest plays.
    private(set) var restSeconds: Double?
    /// What the keeper did with the rest, shown over the farm while it plays.
    private(set) var restLine: String?
    /// Shop stock the keeper has looked at since the early game brought it in. The game has no idea of
    /// "seen", so the app keeps it (per save slot), and the farm gate stops saying "new in today".
    private(set) var seenNewStock: Set<Feature>
    private var store: SaveStore
    /// The save version, when this slot holds a save from a newer game. The app then shows a note in place
    /// of the farm and never writes, so the keeper's farm is safe for the newer build.
    let saveTooNew: Int?
    private let seenStockKey: String
    /// The save slot, so per-slot notes kept outside the save (new stock seen, beta prompts) find theirs.
    let slot: String
    private var nextLogID = 0

    var state: GameState { save.state }
    var saveLocation: String { store.url.path }

    /// `newGameSeed` seeds the game an empty slot starts with. Tests pass one, so the same seed is the same game.
    init(
        directory: URL = GameStore.saveDirectory(), slot: String = SaveStore.defaultSlot, newGameSeed: UInt64? = nil
    ) {
        // A local first: @Observable can't read `self.store` until every property is set.
        let store = SaveStore(directory: directory, slot: slot)
        self.store = store
        self.slot = slot
        let (loaded, recovery) = store.load()
        if case .tooNew(let version) = recovery { saveTooNew = version } else { saveTooNew = nil }
        save = loaded ?? Self.newSave(rules: .standard, seed: newGameSeed ?? .random(in: .min ... .max))
        seenStockKey = "seenNewStock.\(slot)"
        let seen = UserDefaults.standard.stringArray(forKey: seenStockKey) ?? []
        seenNewStock = Set(seen.compactMap(Feature.init(rawValue:)))
        if case .choosingStarter = state.phase {
            append("Welcome to Featherwick.")
        } else {
            append("Welcome back. It is day \(state.day).")
        }
        if let words = recoveryText(recovery) { append(words) }
        noteEvening()
    }

    /// Saves live in Application Support, which the system backs up but the user never sees.
    nonisolated static func saveDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Featherwick", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    nonisolated static func newSave(rules: Rules, seed: UInt64 = .random(in: .min ... .max)) -> SaveGame {
        var rng = SeededRNG(seed: seed)
        let state = Engine.newGame(rules: rules, using: &rng)
        return SaveGame(state: state, rng: rng)
    }

    // MARK: - Playing

    @discardableResult
    func run(_ command: Command) -> [GameEvent] {
        let before = save.state
        var state = save.state
        var rng = save.rng
        let events = Engine.apply(command, to: &state, using: &rng)
        save = SaveGame(state: state, rng: rng)
        noteEvening()
        if Self.isShopping(command) { sawNewStock() }
        // The morning report shows the whole night, so its events get no toasts. The neighbour's words also
        // come as her own note, which opens once the keeper is back from the report.
        let morning =
            reportingNight && command == .passNight ? MorningReport.from(events: events, state: state) : nil
        for event in events {
            if morning == nil,
                let toast = toast(for: event, in: state) ?? handlingToast(for: event, in: events, before, state)
            {
                showToast(toast)
            }
            guard let words = eventText(event, state) else { continue }
            if Self.isNeighbourNote(event, overnight: command == .passNight) { neighbourNotes.append(words) }
            var rejected = false
            if case .rejected = event { rejected = true }
            append(words, rejected: rejected)
        }
        // Sound and haptics for what just happened (eggs, hatching, coins, a "no").
        GameFeedback.play(for: events)
        if let morning {
            morningReport = morning
            openRequest = .morningReport
        }
        // Day 1: once the chick is home, Hazel shows the keeper round. Her note waits until the tour ends.
        if events.contains(where: { if case .starterChosen = $0 { true } else { false } }) { openRequest = .tour }
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
    /// Overnight, everything else the neighbour says or does (the morning report's "neighbour" group) is
    /// her note too. In the day, story steps and trades answer the keeper's own action, so they stay in the log.
    /// The light is gone, or not gone yet: also a note, not an error toast.
    private static func isNeighbourNote(_ event: GameEvent, overnight: Bool) -> Bool {
        switch event {
        case .introduced, .showAnnounced, .neighbourGaveIncubator: true
        default: (overnight && MorningReport.group(of: event) == .neighbour) || isDaylightRefusal(event)
        }
    }

    /// No time left for an errand, the sun still up at bedtime, or no light left to rest in.
    static func isDaylightRefusal(_ event: GameEvent) -> Bool {
        switch event {
        case .rejected(.noTimeLeft), .rejected(.notEveningYet), .rejected(.timeForBed): true
        default: false
        }
    }

    /// The keeper goes to bed: the night passes, and the morning report opens if the switch is on.
    /// While the sun is still up the engine says no, and that "no" is a note, not a morning report.
    func sleep() {
        reportingNight = MorningReportSetting.isOn && Engine.daylightRefusal(for: .passNight, in: state) == nil
        defer { reportingNight = false }
        run(.passNight)
    }

    /// Sleep from the farm: night falls first (a short pause, shorter with Reduce Motion), then the night
    /// passes and the morning report opens.
    func goToBed(reduceMotion: Bool) async {
        guard !asleep, restSeconds == nil else { return }
        asleep = true
        try? await Task.sleep(for: .seconds(reduceMotion ? 0.5 : 2))
        sleep()
        asleep = false
    }

    /// The keeper rests a while: one slot of daylight passes. The scene lasts about 4 seconds (1 with
    /// Reduce Motion) and cannot be skipped: the sun mark slides one place and the light moves on.
    func restAWhile(reduceMotion: Bool) async {
        guard !asleep, restSeconds == nil else { return }
        let seconds: Double = reduceMotion ? 1 : 4
        restSeconds = seconds
        let events = run(.rest)
        let rested = events.first { if case .rested = $0 { true } else { false } }
        restLine = rested.flatMap { eventText($0, state) }
        try? await Task.sleep(for: .seconds(seconds))
        restSeconds = nil
        restLine = nil
    }

    /// Rests until no daylight is left, so the night can pass. Fast forward and the test tools use it;
    /// the farm rests one slot at a time. Does nothing before the daylight lesson.
    func restUntilEvening() {
        while state.phase == .playing, state.isOpen(.daylight), state.slotsLeft > 0 {
            let used = state.slotsUsed
            run(.rest)
            if state.slotsUsed == used { break }
        }
    }

    /// When the evening began, for the crossfade to night. Set once evening comes, cleared by a new day.
    private func noteEvening() {
        let s = state
        let evening = s.phase == .playing && s.isOpen(.daylight) && s.timeOfDay == .evening
        if !evening {
            eveningSince = nil
        } else if eveningSince == nil {
            eveningSince = .now
        }
    }

    /// The keeper is back from the morning report.
    func finishMorningReport() { morningReport = nil }

    /// The keeper has read the neighbour's notes.
    func readNeighbourNotes() { neighbourNotes.removeAll() }

    /// A whole day, as a keeper in a hurry: feed, collect, sell if the carton is full, close, rest until
    /// evening, sleep.
    func fullDays(_ count: Int) {
        for _ in 0..<max(1, count) {
            run(.feed)
            if !state.nest.isEmpty { run(.collectEggs) }
            if state.carton.count >= state.cartonCapacity { run(.sellEggs) }
            if state.coopDoorOpen { run(.closeCoop) }
            restUntilEvening()
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

    func newGame() {
        save = Self.newSave(rules: .standard)
        log = []
        showReport = nil
        morningReport = nil
        noteEvening()
        // A new game brings its stock in again, so it is all new again.
        seenNewStock = []
        UserDefaults.standard.removeObject(forKey: seenStockKey)
        append("A new game begins.")
        persist()
    }

    func note(_ text: String) { append(text) }

    // MARK: - New stock at the farm gate

    /// The early-game steps that bring new stock to Speckle & Down.
    static let shopFeatures: [Feature] = MorningReport.newStockFeatures

    /// Stock the early game brought in this morning that the keeper has not looked at yet.
    var hasNewStock: Bool {
        let s = state
        return Self.shopFeatures.contains {
            s.isOpen($0) && s.introductionDay(of: $0) == s.day && !seenNewStock.contains($0)
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
        case .rejected where Self.isDaylightRefusal(event):
            // Out of daylight is not an error: the neighbour says so in a note (`isNeighbourNote`).
            return nil
        case .rejected:
            // The engine said no: say why, so a tap is never silently ignored.
            return eventText(event, s).map { ($0, nil, nil) }
        case .chicksHatched(let ids, _):
            let one = ids.count == 1
            return (one ? "A chick has hatched" : "\(ids.count) chicks have hatched", "Name", .naming)
        case .hatchSurprise(let id, _):
            // Shown with the hatch toast: the neighbour says why a chick looks like neither parent.
            return eventText(event, s).map { ($0, "View", .bird(id)) }
        case .revealed(let id, let sex, _):
            let name = s.bird(id)?.name ?? "A chick"
            return ("\(name) is a \(sex == .hen ? "pullet" : "cockerel")", "View", .bird(id))
        case .sexGuessResolved(let id, _, _):
            // The keeper's "hen or roo?" guess, settled the same morning as the reveal above.
            return eventText(event, s).map { ($0, "View", .bird(id)) }
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
        // A newer game's save is never written over.
        guard saveTooNew == nil, let data = try? SaveFormat.encode(save) else { return }
        try? store.write(data)
    }
}
