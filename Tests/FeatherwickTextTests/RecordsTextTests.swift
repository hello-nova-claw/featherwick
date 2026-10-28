import FeatherwickText
import Foundation
import Testing

@testable import FeatherwickCore

/// The record book reads the same words after they moved into the String Catalog (#58).
struct RecordsTextTests {
    /// Ninety days of the CLI's `day`: eggs laid, collected and sold, so every table has rows.
    static func keptGame() -> GameState {
        var rng = SeededRNG(seed: 7)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        for _ in 0..<90 {
            _ = Engine.apply(.feed, to: &s, using: &rng)
            if !s.nest.isEmpty { _ = Engine.apply(.collectEggs, to: &s, using: &rng) }
            if s.carton.count >= s.cartonCapacity { _ = Engine.apply(.sellEggs, to: &s, using: &rng) }
            _ = Engine.apply(.closeCoop, to: &s, using: &rng)
            Engine.restUntilEvening(&s, using: &rng)
            _ = Engine.apply(.passNight, to: &s, using: &rng)
        }
        return s
    }

    /// The words as they read before the catalog, line for line.
    @Test func cliRecordsReadTheSameWords() {
        #expect(
            recordsLines(Self.keptGame()) == [
                "Record Book:",
                "Eggs (total, last 14 days, first egg):",
                "  Pip — 42, 7, day 21",
                "Ribbons (1st, 2nd, 3rd):",
                "  No ribbons yet. The county show gives them for 1st, 2nd and 3rd.",
                "The flock:",
                "  Birds now: 1",
                "  Hatched here: 0",
                "  Bought: 0",
                "  Rehomed: 0",
                "  Retired: 0",
                "  First hatch: not yet",
                "  First ribbon: not yet",
                "  Days kept: 91",
            ])
    }

    @Test func aNewGameHasNoHensAndNoRibbons() {
        let s = CalendarTextTests.game()
        let lines = recordsLines(s)
        #expect(lines.contains("  No hens laying yet."))
        #expect(lines.contains("  No ribbons yet. The county show gives them for 1st, 2nd and 3rd."))
        #expect(lines.contains("  First hatch: not yet"))
    }

    /// The app's record book headings: the English the views show.
    @Test func headingsReadInEnglish() {
        #expect(RecordsWords.tab == "Records")
        #expect(
            [RecordsWords.hen, RecordsWords.bird, RecordsWords.total, RecordsWords.firstEgg]
                == ["Hen", "Bird", "Total", "First egg"])
        #expect([RecordsWords.first, RecordsWords.second, RecordsWords.third] == ["1st", "2nd", "3rd"])
        #expect(RecordsWords.recent(14) == "Last 14 days")
        #expect(RecordsWords.eggs == "Eggs" && RecordsWords.ribbons == "Ribbons")
    }

    /// A hen with no eggs on record reads "none yet", a rehomed hen keeps her row with a note, and a
    /// bird's ribbons are counted by place.
    @Test func rarerRowsReadInEnglish() throws {
        var s = Self.keptGame()
        let pip = try #require(s.ownedBirds.first)
        var unlaid = s
        unlaid.layRecords = []
        #expect(recordsLines(unlaid).contains("  Pip — none yet"))

        s.showResults = [
            ShowResult(
                day: s.day, showClass: .pet, entrantName: "Pip", placing: 1, fieldSize: 8, score: 70, prize: 10,
                birdID: pip.id, treats: 0, notes: nil, theme: nil, podium: nil)
        ]
        // The engine keeps the last bird home, so the state says she went: out of the coop, into the village.
        s.coop.removeAll { $0.id == pip.id }
        s.rehomed.append(pip)
        let lines = recordsLines(s)
        #expect(lines.contains("  Pip (rehomed) — 42, 7, day 21"))
        #expect(lines.contains("  Pip — 1, 0, 0"))
    }
}
