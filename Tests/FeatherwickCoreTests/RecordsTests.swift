import Foundation
import Testing

@testable import FeatherwickCore

/// The flock record book (Records.swift): egg counts kept as hens lay, ribbons and flock facts read from state.
struct RecordsTests {
    /// Eggs laid per hen, and the day of each, from the events of every command.
    struct Tally {
        var total: [UUID: Int] = [:]
        var days: [UUID: [Int]] = [:]

        mutating func add(_ events: [GameEvent], onDay day: Int) {
            for case .eggLaid(_, let hen) in events {
                total[hen, default: 0] += 1
                days[hen, default: []].append(day)
            }
        }
    }

    /// A seeded game with two hens and a rooster: it feeds, collects, sets some eggs and sells the rest every day.
    /// `forget` clears the record book after every command, as if the game kept no records.
    static func play(days: Int, seed: UInt64 = 5, forget: Bool = false) -> (GameState, SeededRNG, Tally, [GameEvent]) {
        var (s, rng) = startedGame(sex: .hen, seed: seed)
        s.coins = 500
        var tally = Tally()
        var log: [GameEvent] = []
        func run(_ c: Command) {
            let ev = Engine.apply(c, to: &s, using: &rng)
            tally.add(ev, onDay: s.day)
            log += ev
            if forget { s.layRecords = [] }
        }
        run(.buy(.pullet))
        run(.buy(.cockerel))  // fertile eggs, so the neighbour's incubator comes and eggs are set
        for _ in 0..<days {
            run(.feed)
            run(.collectEggs)
            if !s.carton.isEmpty, s.incubatorClutch == nil, s.hasIncubator {
                run(.incubate(count: min(3, s.carton.count)))
            }
            run(.sellEggs)
            run(.closeCoop)
            Engine.restUntilEvening(&s, using: &rng)
            run(.passNight)
        }
        return (s, rng, tally, log)
    }

    static func hen(
        _ name: String, hatchDay: Int, revealed: Bool, origin: String = Bird.shopOrigin, _ rng: inout SeededRNG
    )
        -> Bird
    {
        Bird(
            id: makeID(using: &rng), name: name, breed: .orpington, genome: Breed.orpington.purebred(.hen),
            hatchDay: hatchDay, origin: origin, revealed: revealed)
    }

    // MARK: - Eggs

    @Test func eggTotalsMatchTheLaidEvents() throws {
        let (s, _, tally, _) = Self.play(days: 90)
        #expect(!tally.total.isEmpty)
        #expect(s.layRecords.count == tally.total.count)
        for r in s.layRecords {
            #expect(r.eggsLaid == tally.total[r.henID])
            #expect(r.firstEggDay == tally.days[r.henID]?.min())
        }
        let window = s.rules.recordWindowDays
        for row in Records.eggRows(s) where row.total != nil {
            let recent = tally.days[row.henID, default: []].count(where: { $0 > s.day - window })
            #expect(row.recent == recent)
            #expect(row.total == tally.total[row.henID])
        }
    }

    /// Selling eggs empties the carton, but the hens laid them: they still count.
    @Test func soldAndSetEggsStillCount() throws {
        let (s, _, tally, log) = Self.play(days: 60)
        #expect(log.contains { if case .eggsSold = $0 { true } else { false } })
        let held = s.nest.count + s.carton.count + s.clutches.reduce(0) { $0 + $1.eggs.count }
        let counted = s.layRecords.reduce(0) { $0 + $1.eggsLaid }
        #expect(counted == tally.total.values.reduce(0, +))
        #expect(counted > held)
        #expect(log.contains { if case .eggsSet = $0 { true } else { false } })
    }

    @Test func aRehomedHenKeepsHerTotal() throws {
        var (s, rng, _, _) = Self.play(days: 40)
        let record = try #require(s.layRecords.max { $0.eggsLaid < $1.eggsLaid })
        let ev = Engine.apply(.rehome(record.henID), to: &s, using: &rng)
        #expect(ev.contains { if case .rehomed = $0 { true } else { false } })
        let row = try #require(Records.eggRows(s).first { $0.henID == record.henID })
        #expect(row.total == record.eggsLaid)
        #expect(row.rehomed)
        // She is gone, so she lays no more; her total stays through the next nights.
        for _ in 0..<5 { night(&s, &rng) }
        #expect(s.layRecords.first { $0.henID == record.henID }?.eggsLaid == record.eggsLaid)
    }

    /// The recent list holds only the window, however long the game runs.
    @Test func recentLayDaysAreTrimmedToTheWindow() {
        let (s, _, _, _) = Self.play(days: 120)
        for r in s.layRecords {
            #expect(r.recentLayDays.allSatisfy { $0 > s.day - s.rules.recordWindowDays })
            #expect(r.recentLayDays.count <= s.rules.recordWindowDays)
        }
    }

    // MARK: - Rule 8

    /// Only hens whose sex shows: a chick is never in the hens' table. A visible hen with no eggs has none yet.
    @Test func onlyVisibleHensAreListed() {
        var (s, rng) = startedGame(sex: .rooster)
        let chick = Self.hen("Chick", hatchDay: s.day, revealed: false, origin: Bird.homeOrigin, &rng)
        let pullet = Self.hen("Pullet", hatchDay: s.day - s.rules.growerAge, revealed: true, &rng)
        s.brooder.append(chick)
        s.coop.append(pullet)
        let rows = Records.eggRows(s)
        #expect(!rows.contains { $0.henID == chick.id })
        let row = rows.first { $0.henID == pullet.id }
        #expect(row?.total == nil && row?.recent == nil && row?.firstEggDay == nil)
        #expect(!rows.contains { $0.henID == s.starterID })  // the rooster
    }

    // MARK: - Ribbons

    @Test func ribbonsMatchTheShowResults() throws {
        var (s, rng) = startedGame(sex: .hen)
        let pip = try #require(s.ownedBirds.first)
        let other = Self.hen("Clover", hatchDay: 0, revealed: true, &rng)
        s.coop.append(other)
        func result(_ b: Bird?, _ placing: Int, day: Int, _ cls: ShowClass = .breed(.orpington)) -> ShowResult {
            ShowResult(
                day: day, showClass: cls, entrantName: b?.name ?? "Eggs", placing: placing, fieldSize: 8, score: 70,
                prize: 10, birdID: b?.id, treats: 0, notes: nil, theme: nil, podium: nil)
        }
        s.showResults = [
            result(pip, 1, day: 28), result(other, 3, day: 28), result(nil, 2, day: 28, .eggs(.brown)),
            result(pip, 2, day: 56), result(other, 0, day: 56), result(pip, 1, day: 84, .pet),
        ]
        let rows = Records.ribbonRows(s)
        #expect(rows.count == 2)
        #expect(rows.first?.birdID == pip.id)
        for b in [pip, other] {
            let row = rows.first { $0.birdID == b.id }
            #expect(row?.total == s.ribbons(for: b))
        }
        #expect(rows.first { $0.birdID == pip.id }.map { [$0.firsts, $0.seconds, $0.thirds] } == [2, 1, 0])
        #expect(rows.first { $0.birdID == other.id }.map { [$0.firsts, $0.seconds, $0.thirds] } == [0, 0, 1])
        // The egg plate has no bird, but it is a ribbon: the first ribbon day counts it.
        #expect(Records.flockFacts(s).firstRibbonDay == 28)
    }

    // MARK: - The flock

    @Test func flockFactsComeFromOriginsAndRehomes() throws {
        var (s, rng, _, _) = Self.play(days: 40)
        let home = (s.ownedBirds + s.rehomed).filter { $0.origin == Bird.homeOrigin }
        let facts = Records.flockFacts(s)
        #expect(facts.birdsNow == s.ownedBirds.count)
        #expect(facts.bought == 2)
        #expect(facts.hatchedHere == home.count)
        #expect(facts.hatchedHere > 0)
        #expect(facts.firstHatchDay == home.map(\.hatchDay).min())
        #expect(facts.daysKept == s.day)
        let leaving = try #require(s.coop.first { $0.id != s.starterID })
        _ = Engine.apply(.rehome(leaving.id), to: &s, using: &rng)
        #expect(Records.flockFacts(s).rehomed == facts.rehomed + 1)
        #expect(Records.flockFacts(s).birdsNow == facts.birdsNow - 1)
    }

    // MARK: - Saves and seeds

    @Test func versionZeroSaveBackFillsFromTheEggsItHolds() throws {
        let game = try SaveFormat.decode(SaveFormatTests.fixture("save-v0"))
        let s = game.state
        #expect(s.rules.recordWindowDays == 14)
        let held = s.nest + s.carton + s.clutches.flatMap(\.eggs)
        #expect(!held.isEmpty)
        for egg in held {
            let r = try #require(s.layRecords.first { $0.henID == egg.motherID })
            #expect(r.firstEggDay <= egg.layDay)
        }
        #expect(s.layRecords.reduce(0) { $0 + $1.eggsLaid } == held.count)
    }

    /// A save from before the record book loses its key; loading rebuilds what the held eggs show.
    @Test func aSaveWithoutRecordsBackFillsOnce() throws {
        let (s, rng, _, _) = Self.play(days: 30)
        var json = try #require(
            JSONSerialization.jsonObject(with: SaveFormat.encode(SaveGame(state: s, rng: rng))) as? [String: Any])
        var state = try #require(json["state"] as? [String: Any])
        state["layRecords"] = nil
        json["state"] = state
        let loaded = try SaveFormat.decode(JSONSerialization.data(withJSONObject: json)).state
        let held = (s.nest + s.carton + s.clutches.flatMap(\.eggs)).filter { s.bird($0.motherID) != nil }
        #expect(loaded.layRecords.reduce(0) { $0 + $1.eggsLaid } == held.count)
        // A save with records keeps them as they are.
        let again = try SaveFormat.decode(SaveFormat.encode(SaveGame(state: s, rng: rng))).state
        #expect(again.layRecords == s.layRecords)
    }

    /// Recording draws nothing from the RNG and changes nothing else: a game that forgets its records
    /// plays the same events, to the same RNG state and the same flock.
    @Test func recordingLeavesTheSeededGameUnchanged() {
        let (kept, keptRNG, _, keptLog) = Self.play(days: 80, seed: 11)
        let (forgot, forgotRNG, _, forgotLog) = Self.play(days: 80, seed: 11, forget: true)
        #expect(keptLog == forgotLog)
        #expect(keptRNG == forgotRNG)
        var same = kept
        same.layRecords = []
        #expect(same == forgot)
        #expect(!kept.layRecords.isEmpty)
    }
}
