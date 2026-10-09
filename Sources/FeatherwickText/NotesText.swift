import FeatherwickCore

// The words for the post's note pool (`Notes.pool`), by note ID. One short note each, in the sender's voice.
//
// A note that names something reads it from the state when the words are shown. If that thing has gone,
// the note falls back to a general line, so a pool note always has words.
// Rule 8: a note names only what the keeper has seen. A bird whose sex is hidden gets no "she" or "he"
// (`subjectPronoun`, `objectPronoun`), and no word that tells its sex or breed.
// Only Teddy uses exclamation marks.

/// The words for a note in `Notes.pool`. Nil for an ID that is not in the pool.
public func poolNoteText(_ id: String, _ s: GameState) -> String? {
    switch id {
    // MARK: Wren
    case "wren.mealworms":
        return "Fresh mealworms in at the shop this week. A treat a day makes a tame bird."
    case "wren.premiumFeed":
        return "Premium feed is back on the shelf. A scoop in the morning lifts the day's laying."
    case "wren.specialPen":
        return "There's a new bird in the special pen every morning. Come and look, even if you don't buy."
    case "wren.surpriseBoxes":
        return "The surprise boxes are popular this week. Nobody knows the breed till the lid comes off."
    case "wren.bigIncubator":
        return "The big incubator is in at the shop. It holds a good many more eggs than a small one."
    case "wren.timber":
        return "The timber cart came by. If your coop feels tight, I have perches in stock."
    case "wren.rain":
        return "Rain all week, they say. Chickens don't mind it. They just look cross."
    case "wren.heat":
        return "Hot days ahead. A dish of water in the shade keeps a flock content."
    case "wren.leaves":
        return "The leaves are coming down. Chickens love to scratch through them for beetles."
    case "wren.frost":
        return "Frost on the lane this morning. Everyone at the shop is in two jumpers."
    case "wren.showTalk":
        return "The whole village is talking about the show. Dot has been seen measuring tables."
    case "wren.hazelNews":
        return "\(People.neighbour) was in for twine. She says your flock is coming on nicely."
    case "wren.newLoaf":
        return "Mr Okafor has a new loaf in his window. He says it's the eggs that make it."
    case "wren.breedBook":
        return
            "I hear your Breed Book has \(s.breedBook.count) pages now. That's more than mine, and I sell the birds."

    // MARK: Hazel
    case "hazel.peckingOrder":
        return "A word on the pecking order. Every flock sorts itself out. Give it a few days and all is calm."
    case "hazel.handling":
        return "Pick them up while they're small, love. A chick learns trust faster than any grown bird."
    case "hazel.coopDoor":
        return "A shut door is a quiet night. An open one is a fed flock in the morning. Your choice, love."
    case "hazel.moult":
        return "Feathers everywhere? That's the moult. They'll be in new clothes before winter."
    case "hazel.winterLaying":
        return "Hens lay less in the short days. Don't fret. They pick up again in spring."
    case "hazel.broody":
        return "If a hen sits tight and fluffs up at you, she's broody. She's the best incubator there is."
    case "hazel.firstPeep":
        return "Every egg hatches if you give it time. I still go soft at the first peep."
    case "hazel.notes":
        return "Keep notes on who you pair. A colour can hide for a generation and turn up later."
    case "hazel.crosses":
        return "A cross can be as fine a bird as any purebred. The pet class takes crosses, and judges them fairly."
    case "hazel.favouriteLook":
        guard let look = favouriteLook(s) else { return "I keep thinking about your flock. A lovely mix of looks." }
        return "I keep thinking about your \(look). A lovely look."
    case "hazel.oldHens":
        return "Old hens stop laying in time. They still earn their keep: they keep the young ones in line."
    case "hazel.springAgain":
        return "Spring again. The best time to set eggs, my mother always said."
    case "hazel.borrowed":
        return "A borrowed bird is a guest. Treat a guest well, and the stories go home with them."
    case "hazel.patience":
        return "Your birds come to the gate when you call. That's patience, that is."

    // MARK: Dot
    case "dot.ribbon":
        guard let r = lastRibbon(s, kind: nil) else { return "I noticed your entry at the show. Well kept." }
        return
            "I noticed your \(entryWords(r)) at the \(showName(r)). \(placeWord(r.placing).capitalizedFirst) place. Well earned."
    case "dot.petClass":
        guard let r = lastRibbon(s, kind: .pet) else {
            return "The pet class is a pleasure to judge. Calm birds, kind hands."
        }
        return "\(r.entrantName.capitalizedFirst) stood so calmly on my table. That comes from kind hands."
    case "dot.breedClass":
        guard let r = lastRibbon(s, kind: .breed) else { return "A good breed bird is bred, not bought. Keep at it." }
        return "Your \(r.entrantName) showed good type in the \(r.showClass.name) class. That is bred, not bought."
    case "dot.eggClass":
        guard let r = lastRibbon(s, kind: .eggs) else { return "A plate of eggs that match is harder than it looks." }
        return "Your plate in the \(r.showClass.name.lowercased()) class matched well. Harder than it looks."
    case "dot.firstEntry":
        return "Thank you for bringing your birds to the show. Every keeper starts somewhere."
    case "dot.shutTheDoor":
        return "A hint for show week: shut the coop at night. A fox fright still shows on the judging table."
    case "dot.friendliness":
        return "The pet class is half friendliness. A bird that sits still for me scores well."
    case "dot.eggFair":
        return "The \(showThemeName(.springEggFair)) is my favourite for eggs. Three that match, clean and fresh."
    case "dot.fete":
        return "At the \(showThemeName(.summerFete)) the pet class is the star. Bring your calmest bird."
    case "dot.harvest":
        return "The \(showThemeName(.harvestShow)) favours the breed classes. Type and colour count most."
    case "dot.championship":
        return
            "The \(showThemeName(.winterChampionship)) draws the strongest field of the year. Don't let that stop you."
    case "dot.lapChicken":
        return "I hear you have a lap chicken. The pet class judges friendliness. Just saying."

    // MARK: Teddy
    case "teddy.drawing":
        guard let b = tamestBird(s) else { return "I drew your chickens! I gave everyone big feet." }
        return "I drew your chickens! The one in the middle is \(b.name). I gave everyone big feet."
    case "teddy.whichEgg":
        return "Do chickens know which egg is theirs? I think they do. I asked Mum and she doesn't know."
    case "teddy.handFed":
        guard let b = tamestBird(s) else { return "One of your chickens ate from my hand! It tickled!" }
        return "\(b.name) ate from my hand today! It tickled! Mum says I can come back on Saturday."
    case "teddy.lap":
        guard let b = tamestBird(s) else { return "A chicken sat on my lap for AGES! Best day ever!" }
        return "\(b.name) sat on my lap for AGES! Best day ever!"
    case "teddy.counted":
        let n = s.birdsAtHome.count(where: { $0.friendliness >= .friendly })
        guard n > 1 else { return "Your chickens come running when I say hello! I counted!" }
        return "\(n) of your chickens came running when I said hello! I counted twice!"
    case "teddy.dreams":
        return "Where do chickens sleep? Do they dream? I think they dream about worms."
    case "teddy.snow":
        return "It snowed! Do chickens get cold feet? I drew them a picture of the sun."
    case "teddy.chickNames":
        return "Can I name a chick one day? I have a list! Number one is Captain Fluff."
    case "teddy.ribbon":
        return "You won a ribbon at the show! I told everyone at school!"
    case "teddy.feather":
        return "I found a feather by your gate! I'm keeping it in my best book."
    case "teddy.dustBath":
        return "Your chickens were rolling in the dirt! I thought they were broken! Gran says it's a bath."
    case "teddy.visitor":
        guard let b = s.loanedBirds.first else { return "You had a visitor chicken! Can I say hello next time?" }
        return "\(b.name) is visiting! Can I say hello to \(b.name)? I'll be very quiet!"

    // MARK: Mr Okafor
    case "okafor.laying":
        return "Word reached the bakery that your flock is laying. Fresh eggs make the best bread."
    case "okafor.blue":
        return "A blue egg, I hear. There is a space in my window for one, if you ever have a spare."
    case "okafor.olive":
        return "Olive eggs. My grandmother kept a hen that laid them. You have brought back a memory."
    case "okafor.chocolate":
        return "A chocolate egg, dark as a crust. I would like to bake with one, one day."
    case "okafor.green":
        return "Green eggs in Featherwick. The children at my counter will not believe me."
    case "okafor.white":
        return "A white egg, plain and clean. Good for meringue, and for painting at Easter."
    case "okafor.brown":
        return "Brown eggs, warm as toast. The colour is only on the outside, but I like it all the same."
    case "okafor.window":
        return "My window has \(eggColourList(s)) eggs this week, thanks to you. There is room for more colours."
    case "okafor.winterOven":
        return "In winter the eggs come slower and the oven stays on longer. We manage."
    case "okafor.custard":
        return "Spring, and every basket is full. I am making custard tarts this week."

    // MARK: Bea
    case "bea.settled":
        guard let b = rehomedBird(s, 0) else { return "Your birds have settled in well at their new homes." }
        return "\(b.name) has settled in well. \(they(b)) found the sunny corner on the first day."
    case "bea.appleTree":
        guard let b = rehomedBird(s, 1) else { return "One of your birds has a new garden with an apple tree." }
        return "\(b.name) has a new garden with an apple tree. \(they(b)) spends the afternoons under it."
    case "bea.storyTime":
        guard let b = rehomedBird(s, 2) else { return "Your birds' new families read to them after school." }
        return "\(b.name)'s new family has two small girls. They read to \(objectPronoun(b)) after school."
    case "bea.newFriend":
        guard let b = rehomedBird(s, 3) else { return "Your birds have made friends in their new homes." }
        return "\(b.name) has a friend at the new place. The two of them dust-bathe side by side."
    case "bea.fridge":
        guard let b = rehomedBird(s, 4) else { return "I have a photo of your birds on my fridge." }
        return "I have a photo of \(b.name) on my fridge. \(they(b)) looks very pleased in it."
    case "bea.thanks":
        return "\(s.rehomed.count) of your birds have found homes through the rescue now. Every one is loved."
    case "bea.winterCheck":
        guard let b = rehomedBird(s, 6) else { return "Winter check on your birds: warm coops and deep straw." }
        return "Winter check on \(b.name): a warm coop, deep straw and a family who fusses."
    case "bea.fence":
        guard let b = rehomedBird(s, 7) else { return "I visited your birds today. They're doing well." }
        return "I visited \(b.name) today. \(they(b)) came straight to the fence to see me."
    case "bea.quietWeek":
        return "The rescue is quiet this week. I sit with the old birds and drink my tea."

    default:
        return nil
    }
}

// MARK: - What a note names

/// "She", "He", or the bird's name while its sex is hidden: the start of a sentence.
private func they(_ b: Bird) -> String { subjectPronoun(b).capitalizedFirst }

/// A rehomed bird for Bea's note, picked by the note's place in her list. Stable while no bird leaves.
private func rehomedBird(_ s: GameState, _ index: Int) -> Bird? {
    let named = s.rehomed.filter { $0.needsName != true }
    guard !named.isEmpty else { return nil }
    return named[index % named.count]
}

/// The tamest named bird at home. Ties go to the oldest, then by ID, so the pick is stable.
private func tamestBird(_ s: GameState) -> Bird? {
    s.birdsAtHome.filter { $0.needsName != true && $0.loan == nil }
        .max {
            ($0.friendlinessScore, -$0.hatchDay, $1.id.uuidString) < (
                $1.friendlinessScore, -$1.hatchDay, $0.id.uuidString
            )
        }
}

/// The keeper's newest ribbon, in this kind of class (or any).
private func lastRibbon(_ s: GameState, kind: ShowKind?) -> ShowResult? {
    s.showResults.last { $0.isRibbon && (kind == nil || $0.showClass.kind == kind) }
}

/// "Juniper" for a bird, "plate of blue eggs" for an egg plate.
private func entryWords(_ r: ShowResult) -> String {
    if case .eggs(let colour) = r.showClass { return "plate of \(colour.rawValue) eggs" }
    return r.entrantName
}

/// "Summer Fete", or "county show" for a result from an older save, which has no theme.
private func showName(_ r: ShowResult) -> String {
    r.theme.map(showThemeName) ?? "county show"
}

private func placeWord(_ placing: Int) -> String {
    switch placing {
    case 1: "first"
    case 2: "second"
    default: "third"
    }
}

/// One look from the Breed Book, as Hazel would say it: "gold laced wyandotte". The first in sorted order.
private func favouriteLook(_ s: GameState) -> String? {
    s.breedBook.map(entryText).sorted().first
}

/// "cream, blue and brown": the Egg Book's colours, in a fixed order.
private func eggColourList(_ s: GameState) -> String {
    let colours = EggColour.allCases.filter { c in s.eggBook.contains { $0.colour == c } }.map(\.rawValue)
    switch colours.count {
    case 0: return "fine"
    case 1: return colours[0]
    default: return colours.dropLast().joined(separator: ", ") + " and " + colours[colours.count - 1]
    }
}
