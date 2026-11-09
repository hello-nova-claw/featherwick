import FeatherwickText
import Foundation
import Testing

@testable import FeatherwickCore

/// The Breed Book's lore pages: one per breed, short, and with no gene words (rule 8).
struct BreedLoreTests {
    static func words(_ text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    /// Tokens for the symbol check: letters, digits and "+", so "bl+" and "lav+" stay whole.
    static func tokens(_ text: String) -> Set<String> {
        Set(text.split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "+") }).map(String.init))
    }

    @Test func everyBreedHasAPagePlannedBreedsToo() {
        for breed in BreedTable.all {
            let lore = breedLore(breed.id)
            #expect(lore != nil, "\(breed.id)")
            for section in lore?.sections ?? [] { #expect(!section.text.isEmpty, "\(breed.id): \(section.heading)") }
        }
        #expect(breedLore("not a breed") == nil)
    }

    @Test func everyPageIsShort() {
        for breed in BreedTable.all {
            let count = Self.words(breedLore(breed.id)?.text ?? "").count
            #expect(count <= 130, "\(breed.id): \(count) words")
            #expect(count >= 80, "\(breed.id): \(count) words")
        }
    }

    /// Every allele symbol, taken from the genes themselves, matched as a whole word and case-sensitive.
    @Test func noPageNamesAnAllele() {
        let symbols = Set(Loci.mendelian.flatMap(\.alleles))
        #expect(symbols.contains("Bl") && symbols.contains("lav+"))
        for breed in BreedTable.all {
            let found = Self.tokens(breedLore(breed.id)?.text ?? "").intersection(symbols)
            #expect(found.isEmpty, "\(breed.id): \(found.sorted())")
        }
    }

    /// "Found on day N" is the first day any look of the breed was found. A breed not found, or found
    /// only in an old save with no days, gets no line.
    @Test func foundDayIsTheBreedsFirstLook() {
        func look(_ breed: Breed, _ variety: ColourVariety) -> BreedBookEntry {
            BreedBookEntry(
                Bird(
                    id: UUID(), name: "", breed: breed, genome: breed.purebred(.hen, variety: variety), hatchDay: 0,
                    origin: "Speckle & Down", revealed: true))
        }
        var rng = SeededRNG(seed: 5)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        let blue = look(.orpington, .blue)
        let black = look(.orpington, .black)
        let buff = look(.silkie, .buff)
        #expect(blue != black)
        s.breedBook = [blue, black, buff]
        s.breedBookDays = [blue: 9, black: 5]  // the Silkie look is from an old save: no day
        #expect(breedFoundText(.orpington, s) == "Found on day 5")
        #expect(breedFoundText(.silkie, s) == nil)
        #expect(breedFoundText(.wyandotte, s) == nil)  // not found at all
        s.breedBookDays = [blue: 9]
        #expect(breedFoundText(.orpington, s) == "Found on day 9")
    }

    /// Every page reads the same after the words moved into the String Catalog (#58).
    @Test func everyPageReadsAsBefore() {
        let silkie = breedLore(.silkie)
        #expect(
            silkie?.sections.map(\.heading) == [
                "Where it comes from", "Bred for", "Eggs", "Temperament", "What the judge looks for", "Did you know?",
            ])
        #expect(
            silkie?.judge
                == "A broad, stout body with a short back that rises to a short, round, fluffy tail, "
                + "and soft fluff of one clear, even colour.")
        let lines = BreedTable.all.flatMap { breed in
            (breedLore(breed.id)?.sections ?? []).flatMap { [$0.heading, $0.text] }
        }
        let fingerprint = pin(lines)
        #expect(fingerprint == "aea94bada289b885")
    }

    @Test func noPageUsesGeneWords() {
        let geneWords = [
            "gene", "genes", "genetic", "dominant", "recessive", "allele", "alleles", "locus",
            "loci", "carrier", "carriers", "carries", "carry", "barring gene", "copy", "copies",
        ]
        for breed in BreedTable.all {
            let text = (breedLore(breed.id)?.text ?? "").lowercased()
            let tokens = Self.tokens(text)
            for word in geneWords where word.contains(" ") ? text.contains(word) : tokens.contains(word) {
                Issue.record("\(breed.id): \"\(word)\"")
            }
        }
    }
}
