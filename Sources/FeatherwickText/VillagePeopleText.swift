import FeatherwickCore

// The words for the village's four people and their first arcs: Dot (the judge), Teddy (the kid down the
// lane), Mr Okafor (the baker) and Bea (the rescue). Core holds the story, step, option and note IDs; every
// one has its words here. The shared word functions (`storyText`, `choiceText`, `postNoteText`, `eventText`)
// fall through to these.
//
// Rule 8: no line here names a gene, or a sex the keeper has not seen. A bird's pronoun comes from
// `subjectPronoun`, which gives its name while its sex is hidden.

/// A storyline's short title, for the People page and the CLI.
public func storyTitle(_ id: String) -> String {
    switch id {
    case "broodySilkie":
        String(
            localized: "villagePeople.title.broodySilkie", defaultValue: "The broody Silkie", bundle: .module,
            comment: "A story's title: Hazel's broody Silkie hen.")
    case "lacedGift":
        String(
            localized: "villagePeople.title.lacedGift", defaultValue: "A laced gift", bundle: .module,
            comment: "A story's title: Hazel gives a laced bird.")
    case "heritageBreed":
        String(
            localized: "villagePeople.title.heritageBreed", defaultValue: "A heritage breed", bundle: .module,
            comment: "A story's title: Hazel's old breed.")
    case "dotStandard":
        String(
            localized: "villagePeople.title.dotStandard", defaultValue: "The standard", bundle: .module,
            comment: "A story's title: Dot shows the keeper the breed standard, the book judges score by.")
    case "teddyHelps":
        String(
            localized: "villagePeople.title.teddyHelps", defaultValue: "Teddy helps out", bundle: .module,
            comment: "A story's title.")
    case "okaforWindow":
        String(
            localized: "villagePeople.title.okaforWindow", defaultValue: "The bakery window", bundle: .module,
            comment: "A story's title: Mr Okafor's shop window of eggs.")
    case "beaPostcards":
        String(
            localized: "villagePeople.title.beaPostcards", defaultValue: "Postcards from the rescue", bundle: .module,
            comment: "A story's title: Bea writes about rehomed birds.")
    case "marigold":
        String(
            localized: "villagePeople.title.marigold", defaultValue: "The borrowed hen", bundle: .module,
            comment: "A story's title: Hazel's hen Marigold stays with the keeper.")
    default: id
    }
}

/// What a person says when one of the four village arcs starts (`step` nil) or moves to a step.
/// Nil for a story or step that is not one of theirs.
func peopleStoryText(_ id: String, step: String?) -> String? {
    switch (id, step) {
    case ("dotStandard", nil):
        String(
            localized: "arc.dot.start",
            defaultValue: """
                At the entry desk, a woman with reading glasses on a chain watches you fill in your form. \
                "First show? I'm Dot. I judge. Don't let that frighten you."
                """,
            bundle: .module, comment: "Dot's story starts at the county show's entry desk.")
    case ("dotStandard", "invite"):
        String(
            localized: "arc.dot.invite",
            defaultValue: """
                Dot stops you in the lane. "Come by on a quiet afternoon and I'll show you the standard. \
                It's the book we judges score by. Every breed has its own page."
                """,
            bundle: .module, comment: "Dot's story: she invites the keeper to see the breed standard.")
    case ("dotStandard", "standard"):
        String(
            localized: "arc.dot.standard",
            defaultValue: """
                Dot opens a fat old book with a cracked spine. "Which page shall we read first? \
                One of your own breeds, I think."
                """,
            bundle: .module, comment: "Dot's story: she asks which breed's page to read.")
    case ("teddyHelps", nil):
        String(
            localized: "arc.teddy.start",
            defaultValue: """
                A boy with muddy knees hangs over your gate. "Is that your chicken? Can I meet it? \
                I'm Teddy. I live down the lane."
                """,
            bundle: .module, comment: "Teddy's story starts.")
    case ("teddyHelps", "notAllowed"):
        String(
            localized: "arc.teddy.notAllowed",
            defaultValue: """
                Teddy is back at the gate. "Mum says I'm not allowed a chicken. Not even a small one. \
                So I'm going to visit yours instead."
                """,
            bundle: .module, comment: "Teddy's story: he may not keep a chicken.")
    case ("teddyHelps", "help"):
        String(
            localized: "arc.teddy.help",
            defaultValue: """
                Teddy has his wellies on today. "Can I help? I could name your next chick. I'm good at names. \
                Or we could have a drawing day, and I'll draw all of them."
                """,
            bundle: .module, comment: "Teddy's story: he offers two ways to help.")
    case ("teddyHelps", "lap"):
        String(
            localized: "arc.teddy.lap",
            defaultValue: """
                Teddy runs home happy. "Pick them up lots," he calls back. "Then one of them will be a lap chicken. \
                I'll know when it happens."
                """,
            bundle: .module, comment: "Teddy's story: he asks the keeper to make a lap chicken.")
    case ("okaforWindow", nil):
        String(
            localized: "arc.okafor.start",
            defaultValue: """
                Mr Okafor from the bakery stops at your gate, flour on his sleeves. "Those brown eggs of yours! \
                I've a basket in my shop window that wants filling."
                """,
            bundle: .module, comment: "Mr Okafor's story starts.")
    case ("okaforWindow", "window"):
        String(
            localized: "arc.okafor.window",
            defaultValue: """
                Mr Okafor is back. "Six brown eggs would fill the basket now. But a colour nobody has seen in my \
                window yet... I'd wait for that. It's your choice, and there's no hurry."
                """,
            bundle: .module, comment: "Mr Okafor's story: brown eggs now, or a new colour later.")
    case ("okaforWindow", "bring"):
        String(
            localized: "arc.okafor.bring",
            defaultValue: """
                Mr Okafor clears a space in his window. "Bring them down to the bakery when they're ready."
                """,
            bundle: .module, comment: "Mr Okafor's story: he waits for the eggs.")
    case ("okaforWindow", "thanks"):
        String(
            localized: "arc.okafor.thanks",
            defaultValue: "Mr Okafor sets your eggs in his window one by one, and steps back to look.",
            bundle: .module, comment: "Mr Okafor's story: the eggs go in his window.")
    case ("okaforWindow", "board"):
        String(
            localized: "arc.okafor.board",
            defaultValue:
                "People stop at the bakery window to look at your eggs. Mr Okafor says it's good for trade.",
            bundle: .module, comment: "Mr Okafor's story ends.")
    case ("beaPostcards", nil):
        String(
            localized: "arc.bea.start",
            defaultValue: """
                News travels in Featherwick. Bea, who runs the hen rescue on the hill, has heard about the bird \
                that went to a new home from Henhaven.
                """,
            bundle: .module, comment: "Bea's story starts. Henhaven is the keeper's farm.")
    case ("beaPostcards", "invite"):
        String(
            localized: "arc.bea.invite", defaultValue: "You pin Bea's postcard up by the coop door.",
            bundle: .module, comment: "Bea's story: her postcard comes.")
    case ("beaPostcards", "third"):
        String(
            localized: "arc.bea.third",
            defaultValue: "Bea's invitation goes on the shelf by the door. The rescue is open whenever you like.",
            bundle: .module, comment: "Bea's story: her invitation comes.")
    default:
        nil
    }
}

/// The words for an option at one of the four village arcs' choices. Nil for any other.
func peopleChoiceText(story: String, option: String) -> String? {
    switch (story, option) {
    case ("dotStandard", _):
        BreedTable.inGame.first { $0.id.rawValue == option }.map { breed in
            String(
                localized: "villagePeople.choice.dotPage", defaultValue: "the \(breed.displayName) page",
                bundle: .module,
                comment:
                    "A choice, lower case: which page of the breed standard to read. The placeholder is a breed's name."
            )
        }
    case ("teddyHelps", "name"):
        String(
            localized: "villagePeople.choice.teddy.name", defaultValue: "let Teddy name your next chick",
            bundle: .module, comment: "A choice, lower case.")
    case ("teddyHelps", "drawing"):
        String(
            localized: "villagePeople.choice.teddy.drawing", defaultValue: "have a drawing day with Teddy",
            bundle: .module, comment: "A choice, lower case.")
    case ("okaforWindow", "now"):
        String(
            localized: "villagePeople.choice.okafor.now", defaultValue: "take him six brown eggs now",
            bundle: .module, comment: "A choice, lower case: eggs for Mr Okafor's window.")
    case ("okaforWindow", "wait"):
        String(
            localized: "villagePeople.choice.okafor.wait",
            defaultValue: "wait, and take him three eggs of a new colour",
            bundle: .module, comment: "A choice, lower case: eggs for Mr Okafor's window.")
    default: nil
    }
}

/// What Dot looks for in a breed, from her copy of the standard. Every in-game breed has words.
public func dotStandardText(_ breed: Breed) -> String? {
    switch breed {
    case .orpington:
        String(
            localized: "villagePeople.standard.orpington",
            defaultValue: """
                A big, soft, deep bird, low to the ground. A short back and a smooth curve from neck to tail. \
                Plenty of loose feather, and a neat single comb that stands up straight.
                """,
            bundle: .module, comment: "Dot's notes on the Orpington, from the breed standard.")
    case .wyandotte:
        String(
            localized: "villagePeople.standard.wyandotte",
            defaultValue: """
                Curves everywhere: a round body, a short back and a full breast. A rose comb, low and tight. \
                On a laced bird, a clean, even edge on every feather.
                """,
            bundle: .module, comment: "Dot's notes on the Wyandotte, from the breed standard.")
    case .araucana:
        String(
            localized: "villagePeople.standard.araucana",
            defaultValue: """
                A neat crest that never hides the eyes, and a small pea comb. A lively, upright bird, \
                with the tail carried well. And the eggs must be blue.
                """,
            bundle: .module, comment: "Dot's notes on the Araucana, from the breed standard.")
    case .australorp:
        String(
            localized: "villagePeople.standard.australorp",
            defaultValue: """
                Upright and busy, with a deep body and a bright red single comb. Dark eyes. \
                In the right light, the black feathers shine beetle-green.
                """,
            bundle: .module, comment: "Dot's notes on the Australorp, from the breed standard.")
    case .silkie:
        String(
            localized: "villagePeople.standard.silkie",
            defaultValue: """
                Fluff all over, like a powder puff. A round crest, a walnut comb, feathered feet and five toes. \
                Dark skin and face, and turquoise earlobes.
                """,
            bundle: .module, comment: "Dot's notes on the Silkie, from the breed standard.")
    default:
        nil
    }
}

/// The words for a note from the four village people, by note ID. Nil for any other ID.
func peopleNoteText(_ id: String, _ s: GameState) -> String? {
    if id.hasPrefix("standard-"),
        let breed = BreedTable.inGame.first(where: { "standard-\($0.id.rawValue)" == id })?.id,
        let looks = dotStandardText(breed)
    {
        let name = breed.definition.displayName
        return String(
            localized: "villagePeople.note.standard",
            defaultValue: """
                Here is the \(name) page, with my pencil notes in the margin. "\(looks)" \
                (Dot's notes are in your Breed Book now, on the \(name) page.)
                """,
            bundle: .module,
            comment: "Dot's note. Placeholders: the breed's name, her notes on it, the breed's name again.")
    }
    switch id {
    case "teddy-drawing":
        return String(
            localized: "villagePeople.note.teddyDrawing",
            defaultValue: """
                A drawing in crayon of every bird in your flock, with the names spelled Teddy's own way. \
                You pin it to the coop door.
                """,
            bundle: .module, comment: "Teddy's drawing comes in the post.")
    case "teddy-lapChicken":
        let named = s.chosen("help", in: "teddyHelps") == "name"
        guard let lap = s.birdsAtHome.first(where: { $0.friendliness >= .lapChicken }) else {
            return named
                ? String(
                    localized: "villagePeople.note.teddyLapYardNamed",
                    defaultValue: """
                        "That one's a lap chicken, you know," Teddy says, pointing into the yard. He looks very proud. \
                        He still talks about naming your chick.
                        """,
                    bundle: .module, comment: "Teddy sees a lap chicken. He named one of the keeper's chicks.")
                : String(
                    localized: "villagePeople.note.teddyLapYard",
                    defaultValue: """
                        "That one's a lap chicken, you know," Teddy says, pointing into the yard. He looks very proud.
                        """,
                    bundle: .module, comment: "Teddy sees a lap chicken.")
        }
        return named
            ? String(
                localized: "villagePeople.note.teddyLapNamed",
                defaultValue: """
                    "That one's a lap chicken, you know," Teddy says, pointing at \(lap.name). He looks very proud. \
                    He still talks about naming your chick.
                    """,
                bundle: .module,
                comment:
                    "Teddy sees a lap chicken. He named one of the keeper's chicks. The placeholder is the bird's name."
            )
            : String(
                localized: "villagePeople.note.teddyLap",
                defaultValue: """
                    "That one's a lap chicken, you know," Teddy says, pointing at \(lap.name). He looks very proud.
                    """,
                bundle: .module, comment: "Teddy sees a lap chicken. The placeholder is the bird's name.")
    case "okafor-window":
        return String(
            localized: "villagePeople.note.okaforWindow",
            defaultValue: """
                Your eggs sit in the middle of my window, and people come in just to ask about them. \
                Since you waited, I've put a card by them with Henhaven's name on it.
                """,
            bundle: .module, comment: "Mr Okafor's note. Henhaven is the keeper's farm.")
    case "okafor-marketBoard":
        return String(
            localized: "villagePeople.note.okaforMarketBoard",
            defaultValue: """
                There's talk of a market board by the bakery, where keepers can say what they have. \
                I've put your name down first, if you'll have it.
                """,
            bundle: .module, comment: "Mr Okafor's note about the market board.")
    case "bea-postcard":
        // The first bird that left Henhaven. If that was long ago (an older save meets Bea late), the
        // words still fit: Bea has been to see how the bird is getting on.
        let name = s.rehomed.first?.name ?? yourBird
        return String(
            localized: "villagePeople.note.beaPostcard",
            defaultValue: """
                Dear keeper, I've been to see \(name), who went to a new home from Henhaven. \
                Happy as anything, with a favourite corner of the run, \
                and the children say good morning every day. Love, Bea.
                """,
            bundle: .module,
            comment: "Bea's postcard. The placeholder is a rehomed bird's name, or \"your bird\".")
    case "bea-invite":
        let name = s.rehomed.first?.name ?? yourBird
        return String(
            localized: "villagePeople.note.beaInvite",
            defaultValue: """
                Come up to the rescue one afternoon and see \(name) for yourself. \
                I'll put the kettle on. No need to write first. Love, Bea.
                """,
            bundle: .module, comment: "Bea's invitation. The placeholder is a rehomed bird's name, or \"your bird\".")
    case "bea-postcard-3":
        // The newest bird to leave. Its name appears once, with no pronoun, so a hidden sex never shows.
        guard let newest = s.rehomed.last else {
            return String(
                localized: "villagePeople.note.beaPostcard3",
                defaultValue: """
                    Three of your birds have new homes in Featherwick now. The newest one settled in at once. \
                    You raise them kind, keeper. Love, Bea.
                    """,
                bundle: .module, comment: "Bea's third postcard.")
        }
        return String(
            localized: "villagePeople.note.beaPostcard3Named",
            defaultValue: """
                Three of your birds have new homes in Featherwick now. \(newest.name) is the newest, and settled in \
                at once. You raise them kind, keeper. Love, Bea.
                """,
            bundle: .module, comment: "Bea's third postcard. The placeholder is the newest rehomed bird's name.")
    default:
        return nil
    }
}

/// "your bird": in Bea's notes when the bird has gone from the list.
private var yourBird: String {
    String(
        localized: "villagePeople.yourBird", defaultValue: "your bird", bundle: .module,
        comment: "In Bea's notes, in place of a rehomed bird's name.")
}

/// The words for the village people's events and refusals. Nil for any other event.
func peopleEventText(_ e: GameEvent, _ s: GameState) -> String? {
    switch e {
    case .chickNamed(let id, let person):
        let name = birdName(id, s)
        return String(
            localized: "villagePeople.chickNamed",
            defaultValue: """
                \(People.name(person)) is at the gate the minute he hears. "That one's called \(name)!" \
                (You can rename \(name) any time.)
                """,
            bundle: .module,
            comment: "Teddy names a new chick. Placeholders: the person's name, the chick's name, the chick's name.")
    case .storyStarted("dotStandard") where hadShowBeforeDot(s):
        // A keeper who has shown before (an older save meets Dot late): no "first show?".
        return String(
            localized: "arc.dot.startVeteran",
            defaultValue: """
                At the entry desk, a woman with reading glasses on a chain looks up from her list. \
                "I've seen your birds at a show or two. I'm Dot. I judge. We should talk properly some time."
                """,
            bundle: .module, comment: "Dot's story starts, for a keeper who has shown birds before.")
    case .delivered("okaforWindow"):
        return String(
            localized: "villagePeople.deliveredOkafor",
            defaultValue: "You carry the eggs down to the bakery, carefully.",
            bundle: .module, comment: "The keeper takes eggs to Mr Okafor.")
    case .rejected(.needEggs(let colour, let need, let have)):
        return String(
            localized: "villagePeople.needEggs",
            defaultValue:
                "That needs \(need) \(colour.rawValue) eggs in your carton. You have \(have). Collect more first.",
            bundle: .module,
            comment: "Refused: not enough eggs. Placeholders: the eggs needed, the egg colour, the eggs the keeper has."
        )
    case .rejected(.needEggsOfNewColour(let colours, let need, let have)):
        let list = anyOfList(colours.map(\.rawValue))
        return String(
            localized: "villagePeople.needEggsOfNewColour",
            defaultValue: """
                That needs \(need) eggs of one new colour in your carton: \(list). \
                You have \(have) of the colour you have most of. No hurry: Mr Okafor will wait.
                """,
            bundle: .module,
            comment:
                "Refused: not enough eggs of a new colour. Placeholders: the eggs needed, the colours (\"blue or green\"), the most eggs of one of those colours the keeper has."
        )
    default:
        return nil
    }
}

/// True when the keeper had results at a show held before Dot's arc started. Stories run before the
/// night's county show, so results from the show of the night the arc starts do not count: a keeper
/// who enters two birds on the eve of their first show still hears "First show?".
func hadShowBeforeDot(_ s: GameState) -> Bool {
    let started = s.stories["dotStandard"]?.stepStartedDay ?? s.day
    return s.showResults.contains { $0.day < started }
}

/// "blue", "blue or green", "blue, green or olive". No comma before "or": `ListFormatStyle` adds one.
func anyOfList(_ words: [String]) -> String {
    guard let last = words.last else { return "" }
    guard words.count > 1 else { return last }
    let head = words.dropLast().dropFirst().reduce(words[0]) { list, next in
        String(
            localized: "villagePeople.listComma", defaultValue: "\(list), \(next)", bundle: .module,
            comment: "Joins a list of egg colours. Placeholders: the colours so far, the next colour.")
    }
    return String(
        localized: "villagePeople.listOrLast", defaultValue: "\(head) or \(last)", bundle: .module,
        comment:
            "The last colour of a list: \"blue, green or olive\". Placeholders: the colours before it, the last colour."
    )
}

/// What the keeper did in a finished or running arc, remembered in words ("since you waited").
/// Nil before the choice is made, and for an arc with no choice.
public func rememberedText(_ storyID: String, _ s: GameState) -> String? {
    switch storyID {
    case "dotStandard":
        return s.dotStandardBreed.map { breed in
            String(
                localized: "villagePeople.remembered.dot",
                defaultValue: "Dot showed you the \(breed.definition.displayName) standard.", bundle: .module,
                comment: "People page: what the keeper chose in Dot's story. The placeholder is a breed's name.")
        }
    case "teddyHelps":
        return switch s.chosen("help", in: storyID) {
        case "name":
            String(
                localized: "villagePeople.remembered.teddy.name", defaultValue: "You let Teddy name a chick.",
                bundle: .module, comment: "People page: what the keeper chose in Teddy's story.")
        case "drawing":
            String(
                localized: "villagePeople.remembered.teddy.drawing",
                defaultValue: "Teddy's drawing is on the coop door.", bundle: .module,
                comment: "People page: what the keeper chose in Teddy's story.")
        default: nil
        }
    case "okaforWindow":
        return switch s.chosen("window", in: storyID) {
        case "now":
            String(
                localized: "villagePeople.remembered.okafor.now", defaultValue: "Your brown eggs filled his window.",
                bundle: .module, comment: "People page: what the keeper chose in Mr Okafor's story.")
        case "wait":
            String(
                localized: "villagePeople.remembered.okafor.wait",
                defaultValue: "You waited, and took him eggs of a new colour.", bundle: .module,
                comment: "People page: what the keeper chose in Mr Okafor's story.")
        default: nil
        }
    default:
        return nil
    }
}

/// The labels on the app's People page (Books ▸ People) and Dot's line on a Breed Book page.
public enum PeopleWords {
    public static var tab: String {
        String(
            localized: "villagePeople.tab", defaultValue: "People", bundle: .module, comment: "Books tab: the people.")
    }
    public static var title: String {
        String(
            localized: "villagePeople.pageTitle", defaultValue: "People", bundle: .module,
            comment: "The People page's title.")
    }
    public static var finished: String {
        String(
            localized: "villagePeople.finished", defaultValue: "Finished", bundle: .module,
            comment: "People page: a story that is over.")
    }
    public static var underWay: String {
        String(
            localized: "villagePeople.underWay", defaultValue: "Under way", bundle: .module,
            comment: "People page: a story still running.")
    }
    public static var handOver: String {
        String(
            localized: "villagePeople.handOver", defaultValue: "Hand over the eggs", bundle: .module,
            comment: "Button: give the eggs to the person who asked for them.")
    }
    public static var dotHeading: String {
        String(
            localized: "villagePeople.dotHeading", defaultValue: "What Dot looks for", bundle: .module,
            comment: "Heading on a Breed Book page, above Dot's notes.")
    }

    /// "Dot asks you to choose:"
    public static func asks(_ p: Person) -> String {
        String(
            localized: "villagePeople.asks", defaultValue: "\(People.name(p)) asks you to choose:", bundle: .module,
            comment: "Above a choice's buttons. The placeholder is the person's name.")
    }
}

/// The Breed Book lines Dot's standard adds, for the CLI `book`. Empty until the keeper has chosen.
public func dotBookLines(_ s: GameState) -> [String] {
    guard let breed = s.dotStandardBreed, let looks = dotStandardText(breed) else { return [] }
    return [
        String(
            localized: "villagePeople.dotBookLine",
            defaultValue: "What Dot looks for in the \(breed.definition.displayName): \(looks)", bundle: .module,
            comment: "CLI Breed Book line. Placeholders: the breed's name, Dot's notes on it.")
    ]
}
