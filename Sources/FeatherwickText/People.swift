import FeatherwickCore

/// The people of Featherwick, and the words that introduce them. Shared by the CLI and the app.
public enum People {
    /// The neighbour over the back fence. She gives the lessons, the gifts and the news.
    public static let neighbour = "Hazel"
    /// Who the neighbour is, in one line.
    public static let neighbourAbout =
        "Hazel has kept hens over the back fence for forty years, and she has a story for every breed."
    /// The shop keeper at Speckle & Down.
    public static let shopkeeper = "Wren"
    /// Who the shop keeper is, in one line.
    public static let shopkeeperAbout =
        "Wren took over her gran's feed shop, Speckle & Down. She knows all the village news."

    /// Day 1, before the starter: Hazel says hello and asks the keeper's name.
    public static let welcome = [
        "Hello there! I'm Hazel, from over the back fence. You must be the new keeper at Henhaven.",
        "What do I call you?",
    ]

    /// Day 1, after the name: Hazel offers a chick.
    public static func chickOffer(_ name: String) -> String {
        "Lovely to meet you, \(name). My hens hatched a clutch yesterday. Take whichever chick you like."
    }
}

/// The four places the first-day tour visits, left to right on the farm.
public enum TourPlace: String, Sendable, CaseIterable {
    case coop, yard, backFence, farmGate
}

/// One stop on the first-day tour of the farm.
public struct TourStop: Sendable {
    /// The place the farm moves to for this stop.
    public let place: TourPlace
    public let title: String
    public let words: String
}

extension People {
    /// The first-day tour: one stop per place, left to right on the farm.
    public static func tour(_ s: GameState) -> [TourStop] {
        let chick = s.starterID.flatMap { s.bird($0)?.name } ?? "your chick"
        return [
            TourStop(
                place: .coop, title: "The coop",
                words: "\(chick) sleeps in the brooder here, under the heat lamp. Grown birds get a perch. "
                    + "Feed the flock every day and collect the eggs."),
            TourStop(
                place: .yard, title: "The yard",
                words: "Your birds scratch about here in the day. Tap a bird to see it, "
                    + "and pick it up to make friends."),
            TourStop(
                place: .backFence, title: "The back fence",
                words: "That's my garden over the fence. Come to me for lessons and news. "
                    + "I'll leave you a note when there's something new."),
            TourStop(
                place: .farmGate, title: "The farm gate",
                words: "The lane goes down to Speckle & Down. \(shopkeeperAbout) "
                    + "She's only got feed in for now, but she'll have more soon."),
        ]
    }
}
