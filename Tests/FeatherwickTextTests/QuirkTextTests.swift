import FeatherwickCore
import FeatherwickText
import Foundation
import Testing

/// Every quirk has one line of words, and only a hen or rooster quirk may say she or he.
struct QuirkTextTests {
    static func words(_ line: String) -> Set<String> {
        Set(line.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
    }

    @Test func everyQuirkHasOneLine() {
        let lines = Quirk.allCases.map(quirkText)
        #expect(Set(lines).count == Quirk.allCases.count)
        for line in lines {
            #expect(!line.isEmpty)
            #expect(!line.contains("\n"))
            #expect(line.hasSuffix("."))
        }
    }

    @Test func onlyASexQuirkSaysSheOrHe() {
        let henWords: Set = ["she", "her", "hers", "hen", "pullet"]
        let roosterWords: Set = ["he", "him", "his", "rooster", "cockerel"]
        for q in Quirk.allCases {
            let w = Self.words(quirkText(q))
            if q.sex != .hen { #expect(w.isDisjoint(with: henWords), "\(q)") }
            if q.sex != .rooster { #expect(w.isDisjoint(with: roosterWords), "\(q)") }
        }
    }

    @Test func aBirdCardShowsItsQuirks() {
        var rng = SeededRNG(seed: 3)
        var s = Engine.newGame(using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Basil"), to: &s, using: &rng)
        let chick = s.ownedBirds[0]
        #expect(quirkLines(chick, s) == Quirks.of(chick, in: s).map(quirkText))
        #expect(quirkLines(chick, s).count == 2)
    }
}
