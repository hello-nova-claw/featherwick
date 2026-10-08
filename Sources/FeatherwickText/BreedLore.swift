import FeatherwickCore

// The Breed Book's lore pages: one page per breed, planned breeds too.
//
// Real facts only. Each claim is one that two independent sources share (the sources are listed in the
// pull request that added the page, not in the game). The judge line names only what `Judge` scores:
// type (body size, shape and carriage) and colour. Rule 8: no gene words and no allele symbols. A page
// says "comes in blue", never which gene makes it.

/// One breed's lore page.
public struct BreedLore: Hashable, Sendable {
    /// Where and when the breed was made: country and century.
    public let origin: String
    /// What keepers bred it for.
    public let bredFor: String
    /// The usual egg colour of real hens of the breed.
    public let eggs: String
    public let temperament: String
    /// What a show judge looks for: type and colour only.
    public let judge: String
    /// One true, odd fact.
    public let oddity: String

    /// The page's parts with their headings, in reading order.
    public var sections: [(heading: String, text: String)] {
        [
            ("Where it comes from", origin), ("Bred for", bredFor), ("Eggs", eggs),
            ("Temperament", temperament), ("What the judge looks for", judge), ("Did you know?", oddity),
        ]
    }

    /// The whole page as one text, headings left out. For word counts and the CLI.
    public var text: String { sections.map(\.text).joined(separator: " ") }
}

/// The lore page for a breed. Nil for an id that is not in the table (for example from a newer save).
public func breedLore(_ breed: Breed) -> BreedLore? {
    switch breed {
    case .silkie:
        BreedLore(
            origin: "An old breed from China, written about by Western travellers as early as the 13th century.",
            bredFor: "Gentle company, and sitting: keepers set other birds' eggs under Silkie hens to hatch.",
            eggs: "Small cream or tinted eggs, about three a week.",
            temperament: "One of the calmest and most docile breeds there is.",
            judge: "A broad, stout body with a short back that rises to a short, round, fluffy tail, "
                + "and soft fluff of one clear, even colour.",
            oddity: "Its feathers do not lock together, so they feel like fur. Under them, the skin and bones "
                + "are black, and each foot has five toes.")
    case .orpington:
        BreedLore(
            origin: "Made in the town of Orpington in Kent, England, by William Cook, who showed it in 1886.",
            bredFor: "A hardy farm bird, good for both eggs and the table.",
            eggs: "Light to medium brown.",
            temperament: "Calm, docile and easy to handle. The hens often go broody.",
            judge: "A deep, broad, heavy body with a curved back and a low stance, "
                + "full but smooth feathers, and an even colour.",
            oddity: "Cook was a coachman. His first Orpingtons were black; buff, white and blue came later. "
                + "Within ten years the breed was sent to other countries.")
    case .wyandotte:
        BreedLore(
            origin: "Made in New York State, in the United States, in the 1870s.",
            bredFor: "A dual-purpose farm bird: a steady layer and a good table bird.",
            eggs: "Light to rich brown, about 150 to 200 a year.",
            temperament: "Mostly calm and friendly, though some birds like to be in charge of the flock.",
            judge: "A medium-sized bird with a round, curved body, and an even colour. "
                + "On laced birds, each feather has a clean, even edge.",
            oddity: "The first birds were called American Sebrights. The silver laced birds came first, "
                + "and joined the American standard in 1883.")
    case .araucana:
        BreedLore(
            origin: "From the Araucanía region of Chile, where the breed took shape in the 20th century "
                + "from fowl kept by the Mapuche people.",
            bredFor: "Its blue eggs, which very few breeds lay. Breeders joined two local fowl: one laid blue "
                + "eggs and had no tail, and the other had ear tufts.",
            eggs: "Blue.",
            temperament: "Active, alert and curious. A keen forager.",
            judge: "A light, lively bird of the size its standard asks for, and a clean, even colour, "
                + "such as black.",
            oddity: "Many Araucanas have no tail at all, and some grow tufts of feathers beside their ears. "
                + "Not every bird shows them.")
    case .australorp:
        BreedLore(
            origin: "Made in Australia in the early 20th century, from Black Orpingtons brought from England.",
            bredFor: "Eggs. Australian breeders kept the Orpington's size and bred for more eggs and less "
                + "broodiness.",
            eggs: "Light to medium brown, often 250 or more a year.",
            temperament: "Calm, gentle and friendly.",
            judge: "A deep, broad body with a full, rounded breast. Black birds should have a bright green "
                + "sheen.",
            oddity: "The name joins Australian and Orpington. In the laying contests of the 1920s, Australorp "
                + "hens set world records for the most eggs in a year. Orders for the birds soon came from "
                + "England, the United States and other countries.")
    case .plymouthRock:
        BreedLore(
            origin: "From Massachusetts, in the United States: made in the 1860s, and in the American standard "
                + "by 1874.",
            bredFor: "A farm bird for both eggs and meat.",
            eggs: "Brown, and plenty of them.",
            temperament: "Docile, hardy and easy to keep.",
            judge: "A long, broad back and a deep, full breast. On barred birds, the black and white bars "
                + "should be crisp, straight and even.",
            oddity: "Barred was the first colour. Until the Second World War it was the most common farm "
                + "chicken in the United States, and in the 1920s it helped to found the broiler industry.")
    case .marans:
        BreedLore(
            origin: "From the marshes around the port town of Marans in western France. It took its modern "
                + "form in the early 20th century.",
            bredFor: "A farm bird for eggs and the table. Breeders crossed the local marsh fowl with Langshans.",
            eggs: "Very dark brown, from mahogany to chocolate.",
            temperament: "Calm and easy-going.",
            judge: "A sturdy, active farm bird of good size, and a clean, even colour, such as black.",
            oddity: "The hen adds the dark brown last, in the final hours before the egg is laid. "
                + "The breed nearly died out in the 1940s, and French breeders brought it back.")
    case .leghorn:
        BreedLore(
            origin: "From Tuscany in Italy. Ships took the birds to America from the port of Livorno in the "
                + "19th century.",
            bredFor: "Eggs. The early Italian birds were small, laid well and needed little feed. White Leghorns "
                + "became the main breed behind commercial white-egg layers.",
            eggs: "White, about 280 a year from a good hen.",
            temperament: "Very active and easily startled.",
            judge: "A slim, upright, streamlined body with the tail held high, and clean white feathers with "
                + "no cream or yellow tint.",
            oddity: "Leghorn is the old English name for Livorno. In America, the first white birds were "
                + "sold as Italian fowls.")
    default:
        nil
    }
}

/// "Found on day 12": the first day any look of this breed went into the Breed Book. Nil if no look is
/// owned yet, or if every look was found in a save from before the Breed Book kept days.
public func breedFoundText(_ breed: Breed, _ s: GameState) -> String? {
    let days = s.breedBook.filter { !$0.isCross && $0.variety == breed.rawValue }.compactMap { s.breedBookDays[$0] }
    return days.min().map { "Found on day \($0)" }
}
