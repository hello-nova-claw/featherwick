import Foundation

/// Plays seeded games with a simple "competent keeper" policy and collects balance metrics.
///
/// Two uses: tune the first-guess numbers in `Rules` from data (via the CLI `sim` command), and
/// catch balance regressions in tests (coins or the flock running away, or the game going dead).
/// The policy is deterministic from the seed, so a report is reproducible.
public enum Simulation {
    /// What one simulated game turned out like.
    public struct Report: Hashable, Sendable {
        public var seed: UInt64
        public var days: Int
        public var finalCoins: Int
        public var peakCoins: Int
        public var finalFlock: Int
        public var peakFlock: Int
        public var breedBook: Int
        public var eggBook: Int
        public var eggsLaid: Int
        public var eggsSold: Int
        public var coinsFromEggs: Int
        public var coinsFromShows: Int
        public var chicksHatched: Int
        public var foxVisits: Int
        public var storiesFinished: Int

        public var eggsPerDay: Double { days > 0 ? Double(eggsLaid) / Double(days) : 0 }
    }

    /// One game: `days` nights from a fresh start on `seed` with `rules`.
    public static func run(seed: UInt64, days: Int, rules: Rules = .standard) -> Report {
        var rng = SeededRNG(seed: seed)
        var s = Engine.newGame(rules: rules, using: &rng)
        var r = Report(
            seed: seed, days: days, finalCoins: 0, peakCoins: 0, finalFlock: 0, peakFlock: 0,
            breedBook: 0, eggBook: 0, eggsLaid: 0, eggsSold: 0, coinsFromEggs: 0, coinsFromShows: 0,
            chicksHatched: 0, foxVisits: 0, storiesFinished: 0)
        apply(.chooseStarter(index: Int(seed % 3), name: "Sim"), &s, &rng, &r)

        for _ in 0..<max(0, days) {
            playDay(&s, &rng, &r)
            r.peakCoins = max(r.peakCoins, s.coins)
            r.peakFlock = max(r.peakFlock, s.ownedBirds.count)
        }
        r.finalCoins = s.coins
        r.finalFlock = s.ownedBirds.count
        r.breedBook = s.breedBook.count
        r.eggBook = s.eggBook.count
        r.storiesFinished = s.stories.values.count(where: \.rewarded)
        return r
    }

    public static func runMany(seeds: ClosedRange<UInt64>, days: Int, rules: Rules = .standard) -> [Report] {
        seeds.map { run(seed: $0, days: days, rules: rules) }
    }

    // MARK: - The keeper policy

    private static func apply(_ c: Command, _ s: inout GameState, _ rng: inout SeededRNG, _ r: inout Report) {
        for e in Engine.apply(c, to: &s, using: &rng) { tally(e, &r) }
    }

    /// A sensible day: feed, collect, candle, hatch what fits, sell the rest, make room, shut up, sleep.
    private static func playDay(_ s: inout GameState, _ rng: inout SeededRNG, _ r: inout Report) {
        apply(.feed, &s, &rng, &r)
        if !s.nest.isEmpty { apply(.collectEggs, &s, &rng, &r) }
        if s.canCandle { apply(.candle, &s, &rng, &r) }

        ensureBreedingPair(&s, &rng, &r)
        if !s.hasIncubator, s.coins >= s.rules.incubatorPrice { apply(.buyIncubator, &s, &rng, &r) }

        // Set fertile eggs if the incubator is free and the brooder has room for every one.
        // A keeper who can't candle yet tries unchecked eggs instead.
        let known = s.carton.count(where: { $0.isCandled && $0.isFertile })
        let unchecked = s.carton.count(where: { !$0.isCandled })
        let fertile = s.canCandle ? known : unchecked
        if s.hasIncubator, s.incubatorClutch == nil, s.boarding.isEmpty, fertile > 0 {
            let n = min(fertile, s.incubatorSize, max(0, s.brooderSize - s.brooder.count))
            if n > 0 { apply(.incubate(count: n), &s, &rng, &r) }
        }

        // Sell before the carton overflows, but keep eggs known to be fertile for hatching.
        if s.carton.count >= s.cartonCapacity - 2 { apply(.sellClearEggs, &s, &rng, &r) }

        manageRoosters(&s, &rng, &r)
        maybeEnterShow(&s, &rng, &r)
        makeRoom(&s, &rng, &r)
        apply(.closeCoop, &s, &rng, &r)
        apply(.passNight, &s, &rng, &r)
    }

    /// Keep one adult rooster for breeding and rehome the rest: a real keeper does this to ease rooster
    /// tension (so the hens lay) and to turn spare cockerels into coins. Without it the flock fills with
    /// roosters and laying is dragged down — which would make the balance report lie.
    private static func manageRoosters(_ s: inout GameState, _ rng: inout SeededRNG, _ r: inout Report) {
        while true {
            let roosters = s.coop.filter {
                $0.sex == .rooster && $0.stage(onDay: s.day, rules: s.rules) == .adult && !$0.isBroody(onDay: s.day)
            }
            guard let spare = roosters.count > 1 ? roosters.last : nil else { break }
            apply(.rehome(spare.id), &s, &rng, &r)
            if s.coop.contains(where: { $0.id == spare.id }) { break }  // rehome refused: stop, don't spin
        }
    }

    /// In the few days before a show, enter one eligible bird and the best plate of eggs, once.
    /// Exercises the show system (entry fees out, prize coins in) so the report reflects it.
    private static func maybeEnterShow(_ s: inout GameState, _ rng: inout SeededRNG, _ r: inout Report) {
        let until = s.nextShowDay - s.day
        guard s.showEntries.isEmpty, until >= 0, until <= 3, s.coins >= s.rules.showEntryFee else { return }
        if let bird = s.coop.first(where: { $0.stage(onDay: s.day, rules: s.rules) != .chick }) {
            apply(.enterShow(bird.id), &s, &rng, &r)
        }
        apply(.enterEggs, &s, &rng, &r)  // enters the best plate if there is one; a harmless no-op otherwise
    }

    /// A flock needs both sexes to breed: a lone hen buys a cockerel, a lone rooster a hen.
    /// (A rooster starter is given a hen by the neighbour, so this mainly rescues a hen starter.)
    private static func ensureBreedingPair(_ s: inout GameState, _ rng: inout SeededRNG, _ r: inout Report) {
        guard s.coop.count < s.perches else { return }
        let owned = s.ownedBirds
        if !owned.contains(where: { $0.sex == .rooster }), s.coins >= s.rules.cockerelPrice {
            apply(.buy(.cockerel), &s, &rng, &r)
        } else if !owned.contains(where: { $0.sex == .hen }), s.coins >= s.rules.pulletPrice {
            apply(.buy(.pullet), &s, &rng, &r)
        }
    }

    /// Grow the coop when it is full and affordable; rehome a spare adult only if birds are boarding
    /// (which blocks hatching) or the coop has hit its maximum size.
    private static func makeRoom(_ s: inout GameState, _ rng: inout SeededRNG, _ r: inout Report) {
        if s.coop.count >= s.perches, s.perches < s.rules.maxPerches, s.coins >= s.rules.coopUpgradePrice {
            apply(.upgradeCoop, &s, &rng, &r)
        }
        if !s.boarding.isEmpty || s.perches >= s.rules.maxPerches, let spare = spareBird(s) {
            apply(.rehome(spare), &s, &rng, &r)
        }
    }

    /// An adult that can be rehomed while still leaving at least one hen and one rooster to breed with.
    private static func spareBird(_ s: GameState) -> UUID? {
        let adults = s.coop.filter { $0.stage(onDay: s.day, rules: s.rules) == .adult && !$0.isBroody(onDay: s.day) }
        let roosters = adults.filter { $0.sex == .rooster }
        let hens = adults.filter { $0.sex == .hen }
        if roosters.count > 1 { return roosters.last?.id }
        if hens.count > 1 { return hens.last?.id }
        return nil
    }

    private static func tally(_ e: GameEvent, _ r: inout Report) {
        switch e {
        case .eggLaid: r.eggsLaid += 1
        case .eggsSold(let n, let coins, _):
            r.eggsSold += n
            r.coinsFromEggs += coins
        case .showPrizesWon(let coins): r.coinsFromShows += coins
        case .chicksHatched(let ids, _): r.chicksHatched += ids.count
        case .foxVisited: r.foxVisits += 1
        default: break
        }
    }

    // MARK: - Reporting

    /// A short min/mean/max balance report over `games` seeded games of `days` each.
    public static func textReport(days: Int, games: Int, rules: Rules = .standard) -> String {
        let reports = runMany(seeds: 1...UInt64(max(1, games)), days: days, rules: rules)
        func line(_ label: String, _ fmt: String = "%.0f", _ f: (Report) -> Double) -> String {
            let xs = reports.map(f)
            let lo = xs.min() ?? 0
            let hi = xs.max() ?? 0
            let mean = xs.reduce(0, +) / Double(xs.count)
            let pad = label.padding(toLength: 12, withPad: " ", startingAt: 0)
            return
                "  \(pad) min \(String(format: fmt, lo))   mean \(String(format: fmt, mean))   max \(String(format: fmt, hi))"
        }
        return """
            Balance report — \(reports.count) games × \(days) days
            \(line("coins") { Double($0.finalCoins) })
            \(line("flock") { Double($0.finalFlock) })
            \(line("breed book") { Double($0.breedBook) })
            \(line("eggs/day", "%.2f") { $0.eggsPerDay })
            \(line("egg income") { Double($0.coinsFromEggs) })
            \(line("show income") { Double($0.coinsFromShows) })
            \(line("hatched") { Double($0.chicksHatched) })
            \(line("fox visits") { Double($0.foxVisits) })
            """
    }
}
