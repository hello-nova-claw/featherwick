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
            inheritanceText(.sexLink)
                == "barred hen × plain rooster → barred chicks are cockerels")
        #expect(
            inheritanceText(.trait(.barred, hen: true, rooster: false, numerator: 1, denominator: 2))
                == "barred hen × plain rooster → 1 in 2 barred")
        #expect(
            inheritanceText(.trait(.speckledEggs, hen: true, rooster: nil, numerator: 1, denominator: 1))
                == "speckled-egg hen × rooster → every daughter lays speckled eggs")
    }

    /// Every rule shape reads the same after the words moved into the String Catalog (#58).
    @Test func everyRuleShapeReadsAsBefore() {
        #expect(
            inheritanceText(.colours(.black, .blue, [ColourShare(.blue, 1), ColourShare(.splash, 1)], denominator: 4))
                == "black × blue → 1 in 4 blue, 1 in 4 splash")
        #expect(
            inheritanceText(.trait(.colour(.lavender), hen: false, rooster: true, numerator: 1, denominator: 4))
                == "non-lavender hen × lavender rooster → 1 in 4 lavender")
        #expect(
            inheritanceText(.trait(.eggColour(.blue), hen: true, rooster: false, numerator: 1, denominator: 2))
                == "blue-egg hen × rooster → 1 in 2 daughters lay blue eggs")
        var lines: [String] = [inheritanceTitleText, inheritanceSubtitleText, inheritanceEmptyText]
        let traits: [FeatherwickCore.Trait] = [
            .colour(.black), .colour(.lavender), .barred, .laced, .silkieFeathered, .eggColour(.blue),
            .eggColour(.olive), .speckledEggs,
        ]
        let looks: [Bool?] = [true, false, nil]
        for t in traits {
            for hen in looks {
                for rooster in looks {
                    for n in [1, 2] {
                        lines.append(
                            inheritanceText(.trait(t, hen: hen, rooster: rooster, numerator: n, denominator: 2)))
                    }
                }
            }
        }
        let shares: [[ColourShare]] = [
            [ColourShare(.lavender, 1)], [ColourShare(.black, 1), ColourShare(.blue, 2), ColourShare(.splash, 1)],
            [ColourShare(.blue, 1), ColourShare(.splash, 1)],
        ]
        for share in shares {
            lines.append(inheritanceText(.colours(.blue, .splash, share, denominator: share.count == 1 ? 1 : 4)))
        }
        lines.append(inheritanceText(.sexLink))
        let fingerprint = pin(lines)
        #expect(fingerprint == "6c80e4c68aebc862")
    }

    @Test func anEmptyPageSaysHowToFillIt() {
        var rng = SeededRNG(seed: 1)
        let s = Engine.newGame(earlyGame: false, using: &rng)
        #expect(
            inheritanceLines(s) == [
                "Inheritance", "What your pairs have shown",
                "  Set eggs from a pair in the pen and what you learn ends up here.",
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
                    t.seenRules = InheritancePage.rules(forHen: hen.id, in: t)
                    for line in inheritanceLines(t).dropFirst(2) {
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
