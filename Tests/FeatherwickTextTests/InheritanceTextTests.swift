import Foundation
import Testing

@testable import FeatherwickCore
@testable import FeatherwickText

/// The words for the inheritance page. A rule names no bird and gives no percentage.
@Suite struct InheritanceTextTests {
    @Test func rulesReadAsLooksAndShares() {
        let blue = InheritanceRule.colours(
            .blue, .blue, [ColourShare(.black, 1), ColourShare(.blue, 2), ColourShare(.splash, 1)], denominator: 4)
        #expect(inheritanceText(blue) == "blue × blue → 1 black : 2 blue : 1 splash")
        #expect(
            inheritanceText(.colours(.lavender, .lavender, [ColourShare(.lavender, 1)], denominator: 1))
                == "lavender × lavender → all lavender")
        #expect(
            inheritanceText(.colours(.black, .blue, [ColourShare(.blue, 1)], denominator: 2))
                == "black × blue → 1 in 2 blue")
        #expect(
            inheritanceText(.sexLink(barredAre: .rooster))
                == "barred hen × plain rooster → barred chicks are cockerels")
        #expect(
            inheritanceText(.trait(.barred, hen: true, rooster: false, numerator: 1, denominator: 2))
                == "barred hen × plain rooster → 1 in 2 barred")
        #expect(
            inheritanceText(.trait(.speckledEggs, hen: true, rooster: nil, numerator: 1, denominator: 1))
                == "speckled-egg hen × rooster → every daughter lays speckled eggs")
    }

    @Test func anEmptyPageSaysHowToFillIt() {
        var rng = SeededRNG(seed: 1)
        let s = Engine.newGame(earlyGame: false, using: &rng)
        #expect(
            inheritanceLines(s) == [
                "Inheritance", "  Set eggs from a pair in the pen and what you learn ends up here.",
            ])
    }

    /// Every rule a played game's pairs could teach: none names a bird, none gives a percentage.
    @Test func noRuleTextNamesABird() {
        var checked = 0
        for seed in UInt64(1)...10 {
            let s = Simulation.play(seed: seed, days: 120)
            let names = (s.ownedBirds + s.rehomed).map(\.name).filter { !$0.isEmpty }
            let grown = s.coop.filter { $0.revealed && $0.stage(onDay: s.day, rules: s.rules) == .adult }
            for hen in grown where hen.sex == .hen {
                for rooster in grown where rooster.sex == .rooster {
                    var t = s
                    t.plannerKnown = true
                    t.pen = [hen.id, rooster.id]
                    t.seenRules = Inheritance.rules(forHen: hen.id, in: t)
                    for line in inheritanceLines(t).dropFirst() {
                        checked += 1
                        #expect(!line.contains("%"), "\(line)")
                        let words = Set(line.split(whereSeparator: { !$0.isLetter }).map(String.init))
                        for name in names where words.contains(name) { Issue.record("\(line) names \(name)") }
                    }
                }
            }
        }
        #expect(checked > 0)
    }
}
