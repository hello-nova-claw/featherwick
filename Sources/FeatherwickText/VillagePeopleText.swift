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
    case "broodySilkie": "The broody Silkie"
    case "lacedGift": "A laced gift"
    case "heritageBreed": "A heritage breed"
    case "dotStandard": "The standard"
    case "teddyHelps": "Teddy helps out"
    case "okaforWindow": "The bakery window"
    case "beaPostcards": "Postcards from the rescue"
    default: id
    }
}

/// What a person says when one of the four village arcs starts (`step` nil) or moves to a step.
/// Nil for a story or step that is not one of theirs.
func peopleStoryText(_ id: String, step: String?) -> String? {
    switch (id, step) {
    case ("dotStandard", nil):
        """
        At the entry desk, a woman with reading glasses on a chain watches you fill in your form. \
        "First show? I'm Dot. I judge. Don't let that frighten you."
        """
    case ("dotStandard", "invite"):
        """
        Dot stops you in the lane. "Come by on a quiet afternoon and I'll show you the standard. \
        It's the book we judges score by. Every breed has its own page."
        """
    case ("dotStandard", "standard"):
        """
        Dot opens a fat old book with a cracked spine. "Which page shall we read first? \
        One of your own breeds, I think."
        """
    case ("teddyHelps", nil):
        """
        A boy with muddy knees hangs over your gate. "Is that your chicken? Can I meet it? \
        I'm Teddy. I live down the lane."
        """
    case ("teddyHelps", "notAllowed"):
        """
        Teddy is back at the gate. "Mum says I'm not allowed a chicken. Not even a small one. \
        So I'm going to visit yours instead."
        """
    case ("teddyHelps", "help"):
        """
        Teddy has his wellies on today. "Can I help? I could name your next chick. I'm good at names. \
        Or we could have a drawing day, and I'll draw all of them."
        """
    case ("teddyHelps", "lap"):
        """
        Teddy runs home happy. "Pick them up lots," he calls back. "Then one of them will be a lap chicken. \
        I'll know when it happens."
        """
    case ("okaforWindow", nil):
        """
        Mr Okafor from the bakery stops at your gate, flour on his sleeves. "Those brown eggs of yours! \
        I've a basket in my shop window that wants filling."
        """
    case ("okaforWindow", "window"):
        """
        Mr Okafor is back. "Six brown eggs would fill the basket now. But a colour nobody has seen in my \
        window yet... I'd wait for that. It's your choice, and there's no hurry."
        """
    case ("okaforWindow", "bring"):
        """
        Mr Okafor clears a space in his window. "Bring them down to the bakery when they're ready."
        """
    case ("okaforWindow", "thanks"):
        "Mr Okafor sets your eggs in his window one by one, and steps back to look."
    case ("okaforWindow", "board"):
        "People stop at the bakery window to look at your eggs. Mr Okafor says it's good for trade."
    case ("beaPostcards", nil):
        """
        News travels in Featherwick. Bea, who runs the hen rescue on the hill, has heard about the bird \
        that went to a new home from Henhaven.
        """
    case ("beaPostcards", "invite"):
        "You pin Bea's postcard up by the coop door."
    case ("beaPostcards", "third"):
        "Bea's invitation goes on the shelf by the door. The rescue is open whenever you like."
    default:
        nil
    }
}

/// The words for an option at one of the four village arcs' choices. Nil for any other.
func peopleChoiceText(story: String, option: String) -> String? {
    switch (story, option) {
    case ("dotStandard", _):
        BreedTable.inGame.first { $0.id.rawValue == option }.map { "the \($0.displayName) page" }
    case ("teddyHelps", "name"): "let Teddy name your next chick"
    case ("teddyHelps", "drawing"): "have a drawing day with Teddy"
    case ("okaforWindow", "now"): "take him six brown eggs now"
    case ("okaforWindow", "wait"): "wait, and take him three eggs of a new colour"
    default: nil
    }
}

/// What Dot looks for in a breed, from her copy of the standard. Every in-game breed has words.
public func dotStandardText(_ breed: Breed) -> String? {
    switch breed {
    case .orpington:
        "A big, soft, deep bird, low to the ground. A short back and a smooth curve from neck to tail. "
            + "Plenty of loose feather, and a neat single comb that stands up straight."
    case .wyandotte:
        "Curves everywhere: a round body, a short back and a full breast. A rose comb, low and tight. "
            + "On a laced bird, a clean, even edge on every feather."
    case .araucana:
        "A neat crest that never hides the eyes, and a small pea comb. A lively, upright bird, "
            + "with the tail carried well. And the eggs must be blue."
    case .australorp:
        "Upright and busy, with a deep body and a bright red single comb. Dark eyes. "
            + "In the right light, the black feathers shine beetle-green."
    case .silkie:
        "Fluff all over, like a powder puff. A round crest, a walnut comb, feathered feet and five toes. "
            + "Dark skin and face, and turquoise earlobes."
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
        return "Here is the \(name) page, with my pencil notes in the margin. \"\(looks)\" "
            + "(Dot's notes are in your Breed Book now, on the \(name) page.)"
    }
    switch id {
    case "teddy-drawing":
        return "A drawing in crayon of every bird in your flock, with the names spelled Teddy's own way. "
            + "You pin it to the coop door."
    case "teddy-lapChicken":
        let lap = s.birdsAtHome.first { $0.friendliness >= .lapChicken }
        let who = lap.map { "pointing at \($0.name)" } ?? "pointing into the yard"
        let since = s.chosen("help", in: "teddyHelps") == "name" ? " He still talks about naming your chick." : ""
        return "\"That one's a lap chicken, you know,\" Teddy says, \(who). He looks very proud.\(since)"
    case "okafor-window":
        return "Your eggs sit in the middle of my window, and people come in just to ask about them. "
            + "Since you waited, I've put a card by them with Henhaven's name on it."
    case "okafor-marketBoard":
        return "There's talk of a market board by the bakery, where keepers can say what they have. "
            + "I've put your name down first, if you'll have it."
    case "bea-postcard":
        let bird = rehomedBird(0, s)
        return "Dear keeper, \(bird.map(\.name) ?? "your bird") is settling in beautifully at the new home. "
            + "\(bird.map { subjectPronoun($0).capitalizedFirst } ?? "Your bird") already has a favourite corner of the run, "
            + "and the children say good morning every day. Love, Bea."
    case "bea-invite":
        let name = rehomedBird(0, s)?.name ?? "your bird"
        return "Come up to the rescue one afternoon and see \(name) for yourself. "
            + "I'll put the kettle on. No need to write first. Love, Bea."
    case "bea-postcard-3":
        let bird = rehomedBird(2, s)
        let who = bird.map { "\($0.name) is the newest, and \(subjectPronoun($0))" } ?? "The newest one"
        return "Three of your birds have new homes in Featherwick now. \(who) took to the place at once. "
            + "You raise them kind, keeper. Love, Bea."
    default:
        return nil
    }
}

/// The bird that went to a new home in this place in line (0 is the first), or the latest one.
func rehomedBird(_ index: Int, _ s: GameState) -> Bird? {
    s.rehomed.indices.contains(index) ? s.rehomed[index] : s.rehomed.last
}

/// The words for the village people's events and refusals. Nil for any other event.
func peopleEventText(_ e: GameEvent, _ s: GameState) -> String? {
    switch e {
    case .chickNamed(let id, let person):
        let name = birdName(id, s)
        return "\(People.name(person)) is at the gate the minute he hears. \"That one's called \(name)!\" "
            + "(You can rename \(name) any time.)"
    case .delivered("okaforWindow"):
        return "You carry the eggs down to the bakery, carefully."
    case .rejected(.needEggs(let colour, let need, let have)):
        return "That needs \(need) \(colour.rawValue) eggs in your carton. You have \(have). Collect more first."
    case .rejected(.needEggsOfNewColour(let colours, let need, let have)):
        let list = anyOfList(colours.map(\.rawValue))
        return "That needs \(need) eggs of one new colour in your carton: \(list). "
            + "You have \(have) of the colour you have most of. No hurry: Mr Okafor will wait."
    default:
        return nil
    }
}

/// "blue", "blue or green", "blue, green or olive".
func anyOfList(_ words: [String]) -> String {
    guard let last = words.last else { return "" }
    return words.count == 1 ? last : words.dropLast().joined(separator: ", ") + " or " + last
}

/// What the keeper did in a finished or running arc, remembered in words ("since you waited").
/// Nil before the choice is made, and for an arc with no choice.
public func rememberedText(_ storyID: String, _ s: GameState) -> String? {
    switch storyID {
    case "dotStandard":
        return s.dotStandardBreed.map { "Dot showed you the \($0.definition.displayName) standard." }
    case "teddyHelps":
        return switch s.chosen("help", in: storyID) {
        case "name": "You let Teddy name a chick."
        case "drawing": "Teddy's drawing is on the coop door."
        default: nil
        }
    case "okaforWindow":
        return switch s.chosen("window", in: storyID) {
        case "now": "Your brown eggs filled his window."
        case "wait": "You waited, and took him eggs of a new colour."
        default: nil
        }
    default:
        return nil
    }
}

/// The labels on the app's People page (Books ▸ People) and Dot's line on a Breed Book page.
public enum PeopleWords {
    public static let tab = "People"
    public static let title = "People"
    public static let finished = "Finished"
    public static let underWay = "Under way"
    public static let handOver = "Hand over the eggs"
    public static let dotHeading = "What Dot looks for"

    /// "Dot asks you to choose:"
    public static func asks(_ p: Person) -> String { "\(People.name(p)) asks you to choose:" }
}

/// The Breed Book lines Dot's standard adds, for the CLI `book`. Empty until the keeper has chosen.
public func dotBookLines(_ s: GameState) -> [String] {
    guard let breed = s.dotStandardBreed, let looks = dotStandardText(breed) else { return [] }
    return ["What Dot looks for in the \(breed.definition.displayName): \(looks)"]
}
