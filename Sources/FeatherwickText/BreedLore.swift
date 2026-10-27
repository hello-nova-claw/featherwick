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
            (
                String(
                    localized: "lore.heading.origin", defaultValue: "Where it comes from", bundle: .module,
                    comment: "Breed Book lore page heading: where and when the breed was made."), origin
            ),
            (
                String(
                    localized: "lore.heading.bredFor", defaultValue: "Bred for", bundle: .module,
                    comment: "Breed Book lore page heading: what keepers bred the breed for."), bredFor
            ),
            (
                String(
                    localized: "lore.heading.eggs", defaultValue: "Eggs", bundle: .module,
                    comment: "Breed Book lore page heading: the breed's eggs."), eggs
            ),
            (
                String(
                    localized: "lore.heading.temperament", defaultValue: "Temperament", bundle: .module,
                    comment: "Breed Book lore page heading: the breed's temperament."), temperament
            ),
            (
                String(
                    localized: "lore.heading.judge", defaultValue: "What the judge looks for", bundle: .module,
                    comment: "Breed Book lore page heading: what a show judge looks for."), judge
            ),
            (
                String(
                    localized: "lore.heading.oddity", defaultValue: "Did you know?", bundle: .module,
                    comment: "Breed Book lore page heading: one true, odd fact."), oddity
            ),
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
            origin: String(
                localized: "lore.silkie.origin",
                defaultValue:
                    "An old breed from China, written about by Western travellers as early as the 13th century.",
                bundle: .module, comment: "Breed Book, Silkie: where and when the breed was made."),
            bredFor: String(
                localized: "lore.silkie.bredFor",
                defaultValue: "Gentle company, and sitting: keepers set other birds' eggs under Silkie hens to hatch.",
                bundle: .module, comment: "Breed Book, Silkie: what keepers bred it for."),
            eggs: String(
                localized: "lore.silkie.eggs",
                defaultValue: "Small cream or tinted eggs, about three a week.",
                bundle: .module, comment: "Breed Book, Silkie: the eggs real hens of the breed lay."),
            temperament: String(
                localized: "lore.silkie.temperament",
                defaultValue: "One of the calmest and most docile breeds there is.",
                bundle: .module, comment: "Breed Book, Silkie: the breed's temperament."),
            judge: String(
                localized: "lore.silkie.judge",
                defaultValue: """
                    A broad, stout body with a short back that rises to a short, round, fluffy tail, \
                    and soft fluff of one clear, even colour.
                    """,
                bundle: .module, comment: "Breed Book, Silkie: what a show judge looks for."),
            oddity: String(
                localized: "lore.silkie.oddity",
                defaultValue: """
                    Its feathers do not lock together, so they feel like fur. Under them, the skin and bones \
                    are black, and each foot has five toes.
                    """,
                bundle: .module, comment: "Breed Book, Silkie: one true, odd fact."))
    case .orpington:
        BreedLore(
            origin: String(
                localized: "lore.orpington.origin",
                defaultValue: "Made in the town of Orpington in Kent, England, by William Cook, who showed it in 1886.",
                bundle: .module, comment: "Breed Book, Orpington: where and when the breed was made."),
            bredFor: String(
                localized: "lore.orpington.bredFor",
                defaultValue: "A hardy farm bird, good for both eggs and the table.",
                bundle: .module, comment: "Breed Book, Orpington: what keepers bred it for."),
            eggs: String(
                localized: "lore.orpington.eggs",
                defaultValue: "Light to medium brown.",
                bundle: .module, comment: "Breed Book, Orpington: the eggs real hens of the breed lay."),
            temperament: String(
                localized: "lore.orpington.temperament",
                defaultValue: "Calm, docile and easy to handle. The hens often go broody.",
                bundle: .module, comment: "Breed Book, Orpington: the breed's temperament."),
            judge: String(
                localized: "lore.orpington.judge",
                defaultValue: """
                    A deep, broad, heavy body with a curved back and a low stance, \
                    full but smooth feathers, and an even colour.
                    """,
                bundle: .module, comment: "Breed Book, Orpington: what a show judge looks for."),
            oddity: String(
                localized: "lore.orpington.oddity",
                defaultValue: """
                    Cook was a coachman. His first Orpingtons were black; buff, white and blue came later. \
                    Within ten years the breed was sent to other countries.
                    """,
                bundle: .module, comment: "Breed Book, Orpington: one true, odd fact."))
    case .wyandotte:
        BreedLore(
            origin: String(
                localized: "lore.wyandotte.origin",
                defaultValue: "Made in New York State, in the United States, in the 1870s.",
                bundle: .module, comment: "Breed Book, Wyandotte: where and when the breed was made."),
            bredFor: String(
                localized: "lore.wyandotte.bredFor",
                defaultValue: "A dual-purpose farm bird: a steady layer and a good table bird.",
                bundle: .module, comment: "Breed Book, Wyandotte: what keepers bred it for."),
            eggs: String(
                localized: "lore.wyandotte.eggs",
                defaultValue: "Light to rich brown, about 150 to 200 a year.",
                bundle: .module, comment: "Breed Book, Wyandotte: the eggs real hens of the breed lay."),
            temperament: String(
                localized: "lore.wyandotte.temperament",
                defaultValue: "Mostly calm and friendly, though some birds like to be in charge of the flock.",
                bundle: .module, comment: "Breed Book, Wyandotte: the breed's temperament."),
            judge: String(
                localized: "lore.wyandotte.judge",
                defaultValue: """
                    A medium-sized bird with a round, curved body, and an even colour. \
                    On laced birds, each feather has a clean, even edge.
                    """,
                bundle: .module, comment: "Breed Book, Wyandotte: what a show judge looks for."),
            oddity: String(
                localized: "lore.wyandotte.oddity",
                defaultValue: """
                    The first birds were called American Sebrights. The silver laced birds came first, \
                    and joined the American standard in 1883.
                    """,
                bundle: .module, comment: "Breed Book, Wyandotte: one true, odd fact."))
    case .araucana:
        BreedLore(
            origin: String(
                localized: "lore.araucana.origin",
                defaultValue: """
                    From the Araucanía region of Chile, where the breed took shape in the 20th century \
                    from fowl kept by the Mapuche people.
                    """,
                bundle: .module, comment: "Breed Book, Araucana: where and when the breed was made."),
            bredFor: String(
                localized: "lore.araucana.bredFor",
                defaultValue: """
                    Its blue eggs, which very few breeds lay. Breeders joined two local fowl: one laid blue \
                    eggs and had no tail, and the other had ear tufts.
                    """,
                bundle: .module, comment: "Breed Book, Araucana: what keepers bred it for."),
            eggs: String(
                localized: "lore.araucana.eggs",
                defaultValue: "Blue.",
                bundle: .module, comment: "Breed Book, Araucana: the eggs real hens of the breed lay."),
            temperament: String(
                localized: "lore.araucana.temperament",
                defaultValue: "Active, alert and curious. A keen forager.",
                bundle: .module, comment: "Breed Book, Araucana: the breed's temperament."),
            judge: String(
                localized: "lore.araucana.judge",
                defaultValue: """
                    A light, lively bird of the size its standard asks for, and a clean, even colour, \
                    such as black.
                    """,
                bundle: .module, comment: "Breed Book, Araucana: what a show judge looks for."),
            oddity: String(
                localized: "lore.araucana.oddity",
                defaultValue: """
                    Many Araucanas have no tail at all, and some grow tufts of feathers beside their ears. \
                    Not every bird shows them.
                    """,
                bundle: .module, comment: "Breed Book, Araucana: one true, odd fact."))
    case .australorp:
        BreedLore(
            origin: String(
                localized: "lore.australorp.origin",
                defaultValue:
                    "Made in Australia in the early 20th century, from Black Orpingtons brought from England.",
                bundle: .module, comment: "Breed Book, Australorp: where and when the breed was made."),
            bredFor: String(
                localized: "lore.australorp.bredFor",
                defaultValue: """
                    Eggs. Australian breeders kept the Orpington's size and bred for more eggs and less \
                    broodiness.
                    """,
                bundle: .module, comment: "Breed Book, Australorp: what keepers bred it for."),
            eggs: String(
                localized: "lore.australorp.eggs",
                defaultValue: "Light to medium brown, often 250 or more a year.",
                bundle: .module, comment: "Breed Book, Australorp: the eggs real hens of the breed lay."),
            temperament: String(
                localized: "lore.australorp.temperament",
                defaultValue: "Calm, gentle and friendly.",
                bundle: .module, comment: "Breed Book, Australorp: the breed's temperament."),
            judge: String(
                localized: "lore.australorp.judge",
                defaultValue: """
                    A deep, broad body with a full, rounded breast. Black birds should have a bright green \
                    sheen.
                    """,
                bundle: .module, comment: "Breed Book, Australorp: what a show judge looks for."),
            oddity: String(
                localized: "lore.australorp.oddity",
                defaultValue: """
                    The name joins Australian and Orpington. In the laying contests of the 1920s, Australorp \
                    hens set world records for the most eggs in a year. Orders for the birds soon came from \
                    England, the United States and other countries.
                    """,
                bundle: .module, comment: "Breed Book, Australorp: one true, odd fact."))
    case .plymouthRock:
        BreedLore(
            origin: String(
                localized: "lore.plymouthRock.origin",
                defaultValue: """
                    From Massachusetts, in the United States: made in the 1860s, and in the American standard \
                    by 1874.
                    """,
                bundle: .module, comment: "Breed Book, Plymouth Rock: where and when the breed was made."),
            bredFor: String(
                localized: "lore.plymouthRock.bredFor",
                defaultValue: "A farm bird for both eggs and meat.",
                bundle: .module, comment: "Breed Book, Plymouth Rock: what keepers bred it for."),
            eggs: String(
                localized: "lore.plymouthRock.eggs",
                defaultValue: "Brown, and plenty of them.",
                bundle: .module, comment: "Breed Book, Plymouth Rock: the eggs real hens of the breed lay."),
            temperament: String(
                localized: "lore.plymouthRock.temperament",
                defaultValue: "Docile, hardy and easy to keep.",
                bundle: .module, comment: "Breed Book, Plymouth Rock: the breed's temperament."),
            judge: String(
                localized: "lore.plymouthRock.judge",
                defaultValue: """
                    A long, broad back and a deep, full breast. On barred birds, the black and white bars \
                    should be crisp, straight and even.
                    """,
                bundle: .module, comment: "Breed Book, Plymouth Rock: what a show judge looks for."),
            oddity: String(
                localized: "lore.plymouthRock.oddity",
                defaultValue: """
                    Barred was the first colour. Until the Second World War it was the most common farm \
                    chicken in the United States, and in the 1920s it helped to found the broiler industry.
                    """,
                bundle: .module, comment: "Breed Book, Plymouth Rock: one true, odd fact."))
    case .marans:
        BreedLore(
            origin: String(
                localized: "lore.marans.origin",
                defaultValue: """
                    From the marshes around the port town of Marans in western France. It took its modern \
                    form in the early 20th century.
                    """,
                bundle: .module, comment: "Breed Book, Marans: where and when the breed was made."),
            bredFor: String(
                localized: "lore.marans.bredFor",
                defaultValue:
                    "A farm bird for eggs and the table. Breeders crossed the local marsh fowl with Langshans.",
                bundle: .module, comment: "Breed Book, Marans: what keepers bred it for."),
            eggs: String(
                localized: "lore.marans.eggs",
                defaultValue: "Very dark brown, from mahogany to chocolate.",
                bundle: .module, comment: "Breed Book, Marans: the eggs real hens of the breed lay."),
            temperament: String(
                localized: "lore.marans.temperament",
                defaultValue: "Calm and easy-going.",
                bundle: .module, comment: "Breed Book, Marans: the breed's temperament."),
            judge: String(
                localized: "lore.marans.judge",
                defaultValue: "A sturdy, active farm bird of good size, and a clean, even colour, such as black.",
                bundle: .module, comment: "Breed Book, Marans: what a show judge looks for."),
            oddity: String(
                localized: "lore.marans.oddity",
                defaultValue: """
                    The hen adds the dark brown last, in the final hours before the egg is laid. \
                    The breed nearly died out in the 1940s, and French breeders brought it back.
                    """,
                bundle: .module, comment: "Breed Book, Marans: one true, odd fact."))
    case .leghorn:
        BreedLore(
            origin: String(
                localized: "lore.leghorn.origin",
                defaultValue: """
                    From Tuscany in Italy. Ships took the birds to America from the port of Livorno in the \
                    19th century.
                    """,
                bundle: .module, comment: "Breed Book, Leghorn: where and when the breed was made."),
            bredFor: String(
                localized: "lore.leghorn.bredFor",
                defaultValue: """
                    Eggs. The early Italian birds were small, laid well and needed little feed. White Leghorns \
                    became the main breed behind commercial white-egg layers.
                    """,
                bundle: .module, comment: "Breed Book, Leghorn: what keepers bred it for."),
            eggs: String(
                localized: "lore.leghorn.eggs",
                defaultValue: "White, about 280 a year from a good hen.",
                bundle: .module, comment: "Breed Book, Leghorn: the eggs real hens of the breed lay."),
            temperament: String(
                localized: "lore.leghorn.temperament",
                defaultValue: "Very active and easily startled.",
                bundle: .module, comment: "Breed Book, Leghorn: the breed's temperament."),
            judge: String(
                localized: "lore.leghorn.judge",
                defaultValue: """
                    A slim, upright, streamlined body with the tail held high, and clean white feathers with \
                    no cream or yellow tint.
                    """,
                bundle: .module, comment: "Breed Book, Leghorn: what a show judge looks for."),
            oddity: String(
                localized: "lore.leghorn.oddity",
                defaultValue: """
                    Leghorn is the old English name for Livorno. In America, the first white birds were \
                    sold as Italian fowls.
                    """,
                bundle: .module, comment: "Breed Book, Leghorn: one true, odd fact."))
    default:
        nil
    }
}

/// "Found on day 12": the first day any look of this breed went into the Breed Book. Nil if no look is
/// owned yet, or if every look was found in a save from before the Breed Book kept days.
public func breedFoundText(_ breed: Breed, _ s: GameState) -> String? {
    let days = s.breedBook.filter { !$0.isCross && $0.variety == breed.rawValue }.compactMap { s.breedBookDays[$0] }
    return days.min().map {
        String(
            localized: "lore.foundOnDay", defaultValue: "Found on day \($0)", bundle: .module,
            comment: "Breed Book: the first day a look of the breed was found. The placeholder is the day number.")
    }
}
