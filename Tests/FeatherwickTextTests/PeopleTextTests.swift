import FeatherwickCore
import FeatherwickText
import Testing

/// Hazel's and Wren's words (People.swift) read the same after they moved into the String Catalog (#58).
struct PeopleTextTests {
    @Test func thePeoplesWordsReadAsBefore() {
        var rng = SeededRNG(seed: 2)
        var s = Engine.newGame(using: &rng)
        let noChick = People.tour(s)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Basil"), to: &s, using: &rng)
        let tour = People.tour(s)
        #expect(
            People.welcome == [
                "Hello there! I'm Hazel, from over the back fence. You must be the new keeper at Henhaven.",
                "What do I call you?",
            ])
        #expect(
            People.chickOffer("Anna")
                == "Lovely to meet you, Anna. My hens hatched a clutch yesterday. Take whichever chick you like.")
        #expect(tour[0].title == "The coop")
        #expect(
            tour[3].words
                == "The lane goes down to Speckle & Down. Wren took over her gran's feed shop, Speckle & Down. "
                + "She knows all the village news. She's only got feed in for now, but she'll have more soon.")
        #expect(noChick[0].words.hasPrefix("your chick sleeps in the brooder here"))
        let all =
            [People.neighbour, People.neighbourAbout, People.shopkeeper, People.shopkeeperAbout] + People.welcome
            + (tour + noChick).flatMap { [$0.title, $0.words] }
        let fingerprint = pin(all)
        #expect(fingerprint == "4de4198c7bff875f")
    }
}
