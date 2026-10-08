import FeatherwickCore
import FeatherwickText
import Testing

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
        var rng = SeededRNG(seed: 5)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        #expect(breedFoundText(.silkie, s) == nil)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Fern"), to: &s, using: &rng)
        s.coins = 500
        for _ in 0..<4 {
            _ = Engine.apply(.buy(.pullet), to: &s, using: &rng)
            _ = Engine.apply(.passNight, to: &s, using: &rng)
        }
        for breed in BreedTable.all {
            let looks = s.breedBook.filter { !$0.isCross && $0.variety == breed.id.rawValue }
            let first = looks.compactMap { s.breedBookDays[$0] }.min()
            #expect(breedFoundText(breed.id, s) == first.map { "Found on day \($0)" }, "\(breed.id)")
        }
        #expect(s.breedBook.contains { breedFoundText(Breed(rawValue: $0.variety), s) != nil })
        s.breedBookDays = [:]
        for breed in BreedTable.all { #expect(breedFoundText(breed.id, s) == nil) }
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
