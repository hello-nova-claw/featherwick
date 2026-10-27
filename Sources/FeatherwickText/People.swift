import FeatherwickCore
import Foundation

/// The people of Featherwick, and the words that introduce them. Shared by the CLI and the app.
public enum People {
    /// The neighbour over the back fence. She gives the lessons, the gifts and the news.
    public static var neighbour: String {
        String(
            localized: "people.neighbour", defaultValue: "Hazel", bundle: .module,
            comment: "The neighbour's name, over the back fence.")
    }
    /// Who the neighbour is, in one line.
    public static var neighbourAbout: String {
        String(
            localized: "people.neighbourAbout",
            defaultValue:
                "Hazel has kept hens over the back fence for forty years, and she has a story for every breed.",
            bundle: .module, comment: "Who Hazel, the neighbour, is, in one line.")
    }
    /// The shop keeper at Speckle & Down.
    public static var shopkeeper: String {
        String(
            localized: "people.shopkeeper", defaultValue: "Wren", bundle: .module,
            comment: "The shop keeper's name, at Speckle & Down.")
    }
    /// Who the shop keeper is, in one line.
    public static var shopkeeperAbout: String {
        String(
            localized: "people.shopkeeperAbout",
            defaultValue: "Wren took over her gran's feed shop, Speckle & Down. She knows all the village news.",
            bundle: .module, comment: "Who Wren, the shop keeper, is, in one line.")
    }

    /// Day 1, before the starter: Hazel says hello and asks the keeper's name.
    public static var welcome: [String] {
        [
            String(
                localized: "people.welcome.hello",
                defaultValue:
                    "Hello there! I'm Hazel, from over the back fence. You must be the new keeper at Henhaven.",
                bundle: .module, comment: "Day 1: Hazel says hello."),
            String(
                localized: "people.welcome.askName", defaultValue: "What do I call you?", bundle: .module,
                comment: "Day 1: Hazel asks the keeper's name."),
        ]
    }

    /// Day 1, after the name: Hazel offers a chick.
    public static func chickOffer(_ name: String) -> String {
        String(
            localized: "people.chickOffer",
            defaultValue:
                "Lovely to meet you, \(name). My hens hatched a clutch yesterday. Take whichever chick you like.",
            bundle: .module, comment: "Day 1: Hazel offers a chick. The placeholder is the keeper's name.")
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
        [
            TourStop(
                place: .coop,
                title: String(
                    localized: "people.tour.coopTitle", defaultValue: "The coop", bundle: .module,
                    comment: "Day 1 tour: the first stop's title."),
                words: coopWords(s)),
            TourStop(
                place: .yard,
                title: String(
                    localized: "people.tour.yardTitle", defaultValue: "The yard", bundle: .module,
                    comment: "Day 1 tour: the second stop's title."),
                words: String(
                    localized: "people.tour.yard",
                    defaultValue:
                        "Your birds scratch about here in the day. Tap a bird to see it, and pick it up to make friends.",
                    bundle: .module, comment: "Day 1 tour: Hazel at the yard.")),
            TourStop(
                place: .backFence,
                title: String(
                    localized: "people.tour.backFenceTitle", defaultValue: "The back fence", bundle: .module,
                    comment: "Day 1 tour: the third stop's title."),
                words: String(
                    localized: "people.tour.backFence",
                    defaultValue: """
                        That's my garden over the fence. Come to me for lessons and news. \
                        I'll leave you a note when there's something new.
                        """,
                    bundle: .module, comment: "Day 1 tour: Hazel at the back fence.")),
            TourStop(
                place: .farmGate,
                title: String(
                    localized: "people.tour.farmGateTitle", defaultValue: "The farm gate", bundle: .module,
                    comment: "Day 1 tour: the last stop's title."),
                words: String(
                    localized: "people.tour.farmGate",
                    defaultValue: """
                        The lane goes down to Speckle & Down. \(shopkeeperAbout) \
                        She's only got feed in for now, but she'll have more soon.
                        """,
                    bundle: .module,
                    comment:
                        "Day 1 tour: Hazel at the farm gate. The placeholder is Wren's about line (people.shopkeeperAbout)."
                )),
        ]
    }

    /// The coop stop names the keeper's chick. Before a chick is chosen it says "your chick".
    private static func coopWords(_ s: GameState) -> String {
        guard let chick = s.starterID.flatMap({ s.bird($0)?.name }) else {
            return String(
                localized: "people.tour.coopNoChick",
                defaultValue: """
                    your chick sleeps in the brooder here, under the heat lamp. Grown birds get a perch. \
                    Feed the flock every day and collect the eggs.
                    """,
                bundle: .module, comment: "Day 1 tour: Hazel at the coop, before a chick is chosen.")
        }
        return String(
            localized: "people.tour.coop",
            defaultValue: """
                \(chick) sleeps in the brooder here, under the heat lamp. Grown birds get a perch. \
                Feed the flock every day and collect the eggs.
                """,
            bundle: .module, comment: "Day 1 tour: Hazel at the coop. The placeholder is the chick's name.")
    }
}
