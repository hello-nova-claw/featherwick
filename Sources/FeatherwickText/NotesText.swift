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
        return String(
            localized: "notes.wren.mealworms",
            defaultValue: "Fresh mealworms in at the shop this week. A treat a day makes a tame bird.", bundle: .module,
            comment: "A note in the post from Wren.")
    case "wren.premiumFeed":
        return String(
            localized: "notes.wren.premiumFeed",
            defaultValue: "Premium feed is back on the shelf. A scoop in the morning lifts the day's laying.",
            bundle: .module,
            comment: "A note in the post from Wren.")
    case "wren.specialPen":
        return String(
            localized: "notes.wren.specialPen",
            defaultValue: "There's a new bird in the special pen every morning. Come and look, even if you don't buy.",
            bundle: .module,
            comment: "A note in the post from Wren.")
    case "wren.surpriseBoxes":
        return String(
            localized: "notes.wren.surpriseBoxes",
            defaultValue: "The surprise boxes are popular this week. Nobody knows the breed till the lid comes off.",
            bundle: .module,
            comment: "A note in the post from Wren.")
    case "wren.bigIncubator":
        return String(
            localized: "notes.wren.bigIncubator",
            defaultValue: "The big incubator is in at the shop. It holds a good many more eggs than a small one.",
            bundle: .module,
            comment: "A note in the post from Wren.")
    case "wren.timber":
        return String(
            localized: "notes.wren.timber",
            defaultValue: "The timber cart came by. If your coop feels tight, I have perches in stock.",
            bundle: .module,
            comment: "A note in the post from Wren.")
    case "wren.rain":
        return String(
            localized: "notes.wren.rain",
            defaultValue: "Rain all week, they say. Chickens don't mind it. They just look cross.", bundle: .module,
            comment: "A note in the post from Wren.")
    case "wren.heat":
        return String(
            localized: "notes.wren.heat",
            defaultValue: "Hot days ahead. A dish of water in the shade keeps a flock content.", bundle: .module,
            comment: "A note in the post from Wren.")
    case "wren.leaves":
        return String(
            localized: "notes.wren.leaves",
            defaultValue: "The leaves are coming down. Chickens love to scratch through them for beetles.",
            bundle: .module,
            comment: "A note in the post from Wren.")
    case "wren.frost":
        return String(
            localized: "notes.wren.frost",
            defaultValue: "Frost on the lane this morning. Everyone at the shop is in two jumpers.", bundle: .module,
            comment: "A note in the post from Wren.")
    case "wren.showTalk":
        return String(
            localized: "notes.wren.showTalk",
            defaultValue: "The whole village is talking about the show. Dot has been seen measuring tables.",
            bundle: .module,
            comment: "A note in the post from Wren.")
    case "wren.hazelNews":
        return String(
            localized: "notes.wren.hazelNews",
            defaultValue: "\(People.neighbour) was in for twine. She says your flock is coming on nicely.",
            bundle: .module,
            comment: "A note in the post from Wren. The placeholder is Hazel's name.")
    case "wren.newLoaf":
        return String(
            localized: "notes.wren.newLoaf",
            defaultValue: "Mr Okafor has a new loaf in his window. He says it's the eggs that make it.",
            bundle: .module,
            comment: "A note in the post from Wren.")
    case "wren.breedBook":
        return String(
            localized: "notes.wren.breedBook",
            defaultValue:
                "I hear your Breed Book has \(s.breedBook.count) pages now. That's more than mine, and I sell the birds.",
            bundle: .module,
            comment: "A note in the post from Wren. The placeholder is the pages in the Breed Book (more than 1).")

    // MARK: Hazel
    case "hazel.peckingOrder":
        return String(
            localized: "notes.hazel.peckingOrder",
            defaultValue:
                "A word on the pecking order. Every flock sorts itself out. Give it a few days and all is calm.",
            bundle: .module,
            comment: "A note in the post from Hazel.")
    case "hazel.handling":
        return String(
            localized: "notes.hazel.handling",
            defaultValue: "Pick them up while they're small, love. A chick learns trust faster than any grown bird.",
            bundle: .module,
            comment: "A note in the post from Hazel.")
    case "hazel.coopDoor":
        return String(
            localized: "notes.hazel.coopDoor",
            defaultValue: "A shut door is a quiet night. An open one is a fed flock in the morning. Your choice, love.",
            bundle: .module,
            comment: "A note in the post from Hazel.")
    case "hazel.moult":
        return String(
            localized: "notes.hazel.moult",
            defaultValue: "Feathers everywhere? That's the moult. They'll be in new clothes before winter.",
            bundle: .module,
            comment: "A note in the post from Hazel.")
    case "hazel.winterLaying":
        return String(
            localized: "notes.hazel.winterLaying",
            defaultValue: "Hens lay less in the short days. Don't fret. They pick up again in spring.", bundle: .module,
            comment: "A note in the post from Hazel.")
    case "hazel.broody":
        return String(
            localized: "notes.hazel.broody",
            defaultValue: "If a hen sits tight and fluffs up at you, she's broody. She's the best incubator there is.",
            bundle: .module,
            comment: "A note in the post from Hazel.")
    case "hazel.firstPeep":
        return String(
            localized: "notes.hazel.firstPeep",
            defaultValue: "Every egg hatches if you give it time. I still go soft at the first peep.", bundle: .module,
            comment: "A note in the post from Hazel.")
    case "hazel.notes":
        return String(
            localized: "notes.hazel.notes",
            defaultValue: "Keep notes on who you pair. A colour can hide for a generation and turn up later.",
            bundle: .module,
            comment: "A note in the post from Hazel.")
    case "hazel.crosses":
        return String(
            localized: "notes.hazel.crosses",
            defaultValue:
                "A cross can be as fine a bird as any purebred. The pet class takes crosses, and judges them fairly.",
            bundle: .module,
            comment: "A note in the post from Hazel.")
    case "hazel.favouriteLook":
        guard let look = favouriteLook(s) else {
            return String(
                localized: "notes.hazel.favouriteLook.general",
                defaultValue: "I keep thinking about your flock. A lovely mix of looks.", bundle: .module,
                comment: "A note in the post from Hazel, when what it names has gone.")
        }
        return String(
            localized: "notes.hazel.favouriteLook", defaultValue: "I keep thinking about your \(look). A lovely look.",
            bundle: .module,
            comment:
                "A note in the post from Hazel. The placeholder is a look from the Breed Book, such as \"gold laced wyandotte\"."
        )
    case "hazel.oldHens":
        return String(
            localized: "notes.hazel.oldHens",
            defaultValue: "Old hens stop laying in time. They still earn their keep: they keep the young ones in line.",
            bundle: .module,
            comment: "A note in the post from Hazel.")
    case "hazel.springAgain":
        return String(
            localized: "notes.hazel.springAgain",
            defaultValue: "Spring again. The best time to set eggs, my mother always said.", bundle: .module,
            comment: "A note in the post from Hazel.")
    case "hazel.borrowed":
        return String(
            localized: "notes.hazel.borrowed",
            defaultValue: "A borrowed bird is a guest. Treat a guest well, and the stories go home with them.",
            bundle: .module,
            comment: "A note in the post from Hazel.")
    case "hazel.patience":
        return String(
            localized: "notes.hazel.patience",
            defaultValue: "Your birds come to the gate when you call. That's patience, that is.", bundle: .module,
            comment: "A note in the post from Hazel.")

    // MARK: Dot
    case "dot.ribbon":
        guard let r = lastRibbon(s, kind: nil) else {
            return String(
                localized: "notes.dot.ribbon.general", defaultValue: "I noticed your entry at the show. Well kept.",
                bundle: .module,
                comment: "A note in the post from Dot, when what it names has gone.")
        }
        let entry = entryWords(r)
        let show = showName(r)
        switch r.placing {
        case 1:
            return String(
                localized: "notes.dot.ribbon.first",
                defaultValue: "I noticed your \(entry) at the \(show). First place. Well earned.", bundle: .module,
                comment:
                    "A note in the post from Dot. Placeholders: the bird's name or \"plate of blue eggs\", the show's name."
            )
        case 2:
            return String(
                localized: "notes.dot.ribbon.second",
                defaultValue: "I noticed your \(entry) at the \(show). Second place. Well earned.", bundle: .module,
                comment:
                    "A note in the post from Dot. Placeholders: the bird's name or \"plate of blue eggs\", the show's name."
            )
        default:
            return String(
                localized: "notes.dot.ribbon.third",
                defaultValue: "I noticed your \(entry) at the \(show). Third place. Well earned.", bundle: .module,
                comment:
                    "A note in the post from Dot. Placeholders: the bird's name or \"plate of blue eggs\", the show's name."
            )
        }
    case "dot.petClass":
        guard let r = lastRibbon(s, kind: .pet) else {
            return String(
                localized: "notes.dot.petClass.general",
                defaultValue: "The pet class is a pleasure to judge. Calm birds, kind hands.", bundle: .module,
                comment: "A note in the post from Dot, when the ribbon is not in the records.")
        }
        return String(
            localized: "notes.dot.petClass",
            defaultValue: "\(r.entrantName.capitalizedFirst) stood so calmly on my table. That comes from kind hands.",
            bundle: .module,
            comment: "A note in the post from Dot. The placeholder is the bird's name.")
    case "dot.breedClass":
        guard let r = lastRibbon(s, kind: .breed) else {
            return String(
                localized: "notes.dot.breedClass.general",
                defaultValue: "A good breed bird is bred, not bought. Keep at it.", bundle: .module,
                comment: "A note in the post from Dot, when what it names has gone.")
        }
        return String(
            localized: "notes.dot.breedClass",
            defaultValue:
                "Your \(r.entrantName) showed good type in the \(r.showClass.name) class. That is bred, not bought.",
            bundle: .module,
            comment: "A note in the post from Dot. Placeholders: the bird's name, the show class (a breed's name).")
    case "dot.eggClass":
        guard let r = lastRibbon(s, kind: .eggs) else {
            return String(
                localized: "notes.dot.eggClass.general",
                defaultValue: "A plate of eggs that match is harder than it looks.", bundle: .module,
                comment: "A note in the post from Dot, when what it names has gone.")
        }
        return String(
            localized: "notes.dot.eggClass",
            defaultValue:
                "Your plate in the \(r.showClass.name.lowercased()) class matched well. Harder than it looks.",
            bundle: .module,
            comment: "A note in the post from Dot. The placeholder is the egg class, lower case, such as \"blue eggs\"."
        )
    case "dot.firstEntry":
        return String(
            localized: "notes.dot.firstEntry",
            defaultValue: "Thank you for bringing your birds to the show. Every keeper starts somewhere.",
            bundle: .module,
            comment: "A note in the post from Dot.")
    case "dot.shutTheDoor":
        return String(
            localized: "notes.dot.shutTheDoor",
            defaultValue:
                "A hint for show week: shut the coop at night. A fox fright still shows on the judging table.",
            bundle: .module,
            comment: "A note in the post from Dot.")
    case "dot.friendliness":
        return String(
            localized: "notes.dot.friendliness",
            defaultValue: "The pet class is half friendliness. A bird that sits still for me scores well.",
            bundle: .module,
            comment: "A note in the post from Dot.")
    case "dot.eggFair":
        return String(
            localized: "notes.dot.eggFair",
            defaultValue:
                "The \(showThemeName(.springEggFair)) is my favourite for eggs. Three that match, clean and fresh.",
            bundle: .module,
            comment: "A note in the post from Dot. The placeholder is the spring show's name.")
    case "dot.fete":
        return String(
            localized: "notes.dot.fete",
            defaultValue: "At the \(showThemeName(.summerFete)) the pet class is the star. Bring your calmest bird.",
            bundle: .module,
            comment: "A note in the post from Dot. The placeholder is the summer show's name.")
    case "dot.harvest":
        return String(
            localized: "notes.dot.harvest",
            defaultValue: "The \(showThemeName(.harvestShow)) favours the breed classes. Type and colour count most.",
            bundle: .module,
            comment: "A note in the post from Dot. The placeholder is the autumn show's name.")
    case "dot.championship":
        return String(
            localized: "notes.dot.championship",
            defaultValue:
                "The \(showThemeName(.winterChampionship)) draws the strongest field of the year. Don't let that stop you.",
            bundle: .module,
            comment: "A note in the post from Dot. The placeholder is the winter show's name.")
    case "dot.lapChicken":
        return String(
            localized: "notes.dot.lapChicken",
            defaultValue: "I hear you have a lap chicken. The pet class judges friendliness. Just saying.",
            bundle: .module,
            comment: "A note in the post from Dot.")

    // MARK: Teddy
    case "teddy.drawing":
        guard let b = tamestBird(s) else {
            return String(
                localized: "notes.teddy.drawing.general",
                defaultValue: "I drew your chickens! I gave everyone big feet.", bundle: .module,
                comment: "A note in the post from Teddy, when what it names has gone.")
        }
        return String(
            localized: "notes.teddy.drawing",
            defaultValue: "I drew your chickens! The one in the middle is \(b.name). I gave everyone big feet.",
            bundle: .module,
            comment: "A note in the post from Teddy. The placeholder is the tamest bird's name.")
    case "teddy.whichEgg":
        return String(
            localized: "notes.teddy.whichEgg",
            defaultValue: "Do chickens know which egg is theirs? I think they do. I asked Mum and she doesn't know.",
            bundle: .module,
            comment: "A note in the post from Teddy.")
    case "teddy.handFed":
        guard let b = tamestBird(s) else {
            return String(
                localized: "notes.teddy.handFed.general",
                defaultValue: "One of your chickens ate from my hand! It tickled!", bundle: .module,
                comment: "A note in the post from Teddy, when what it names has gone.")
        }
        return String(
            localized: "notes.teddy.handFed",
            defaultValue: "\(b.name) ate from my hand today! It tickled! Mum says I can come back on Saturday.",
            bundle: .module,
            comment: "A note in the post from Teddy. The placeholder is the tamest bird's name.")
    case "teddy.lap":
        guard let b = tamestBird(s) else {
            return String(
                localized: "notes.teddy.lap.general", defaultValue: "A chicken sat on my lap for AGES! Best day ever!",
                bundle: .module,
                comment: "A note in the post from Teddy, when what it names has gone.")
        }
        return String(
            localized: "notes.teddy.lap", defaultValue: "\(b.name) sat on my lap for AGES! Best day ever!",
            bundle: .module,
            comment: "A note in the post from Teddy. The placeholder is the tamest bird's name.")
    case "teddy.counted":
        let n = s.birdsAtHome.count(where: { $0.friendliness >= .friendly })
        guard n > 1 else {
            return String(
                localized: "notes.teddy.counted.general",
                defaultValue: "Your chickens come running when I say hello! I counted!", bundle: .module,
                comment: "A note in the post from Teddy, when what it names has gone.")
        }
        return String(
            localized: "notes.teddy.counted",
            defaultValue: "\(n) of your chickens came running when I said hello! I counted twice!", bundle: .module,
            comment: "A note in the post from Teddy. The placeholder is the friendly birds (more than 1).")
    case "teddy.dreams":
        return String(
            localized: "notes.teddy.dreams",
            defaultValue: "Where do chickens sleep? Do they dream? I think they dream about worms.", bundle: .module,
            comment: "A note in the post from Teddy.")
    case "teddy.snow":
        return String(
            localized: "notes.teddy.snow",
            defaultValue: "It snowed! Do chickens get cold feet? I drew them a picture of the sun.", bundle: .module,
            comment: "A note in the post from Teddy.")
    case "teddy.chickNames":
        return String(
            localized: "notes.teddy.chickNames",
            defaultValue: "Can I name a chick one day? I have a list! Number one is Captain Fluff.", bundle: .module,
            comment: "A note in the post from Teddy.")
    case "teddy.ribbon":
        return String(
            localized: "notes.teddy.ribbon", defaultValue: "You won a ribbon at the show! I told everyone at school!",
            bundle: .module,
            comment: "A note in the post from Teddy.")
    case "teddy.feather":
        return String(
            localized: "notes.teddy.feather",
            defaultValue: "I found a feather by your gate! I'm keeping it in my best book.", bundle: .module,
            comment: "A note in the post from Teddy.")
    case "teddy.dustBath":
        return String(
            localized: "notes.teddy.dustBath",
            defaultValue: "Your chickens were rolling in the dirt! I thought they were broken! Gran says it's a bath.",
            bundle: .module,
            comment: "A note in the post from Teddy.")
    case "teddy.visitor":
        guard let b = s.coop.first(where: \.isOnLoan) else {
            return String(
                localized: "notes.teddy.visitor.general",
                defaultValue: "You had a visitor chicken! Can I say hello next time?",
                bundle: .module,
                comment: "A note in the post from Teddy, when the visiting bird is not at home.")
        }
        return String(
            localized: "notes.teddy.visitor",
            defaultValue: "\(b.name) is visiting! Can I say hello to \(b.name)? I'll be very quiet!", bundle: .module,
            comment: "A note in the post from Teddy. Placeholders: a loaned bird's name, twice.")

    // MARK: Mr Okafor
    case "okafor.laying":
        return String(
            localized: "notes.okafor.laying",
            defaultValue: "Word reached the bakery that your flock is laying. Fresh eggs make the best bread.",
            bundle: .module,
            comment: "A note in the post from Mr Okafor.")
    case "okafor.blue":
        return String(
            localized: "notes.okafor.blue",
            defaultValue: "A blue egg, I hear. There is a space in my window for one, if you ever have a spare.",
            bundle: .module,
            comment: "A note in the post from Mr Okafor.")
    case "okafor.olive":
        return String(
            localized: "notes.okafor.olive",
            defaultValue: "Olive eggs. My grandmother kept a hen that laid them. You have brought back a memory.",
            bundle: .module,
            comment: "A note in the post from Mr Okafor.")
    case "okafor.chocolate":
        return String(
            localized: "notes.okafor.chocolate",
            defaultValue: "A chocolate egg, dark as a crust. I would like to bake with one, one day.", bundle: .module,
            comment: "A note in the post from Mr Okafor.")
    case "okafor.green":
        return String(
            localized: "notes.okafor.green",
            defaultValue: "Green eggs in Featherwick. The children at my counter will not believe me.", bundle: .module,
            comment: "A note in the post from Mr Okafor.")
    case "okafor.white":
        return String(
            localized: "notes.okafor.white",
            defaultValue: "A white egg, plain and clean. Good for meringue, and for painting at Easter.",
            bundle: .module,
            comment: "A note in the post from Mr Okafor.")
    case "okafor.brown":
        return String(
            localized: "notes.okafor.brown",
            defaultValue: "Brown eggs, warm as toast. The colour is only on the outside, but I like it all the same.",
            bundle: .module,
            comment: "A note in the post from Mr Okafor.")
    case "okafor.window":
        return String(
            localized: "notes.okafor.window",
            defaultValue:
                "My window has \(eggColourList(s)) eggs this week, thanks to you. There is room for more colours.",
            bundle: .module,
            comment:
                "A note in the post from Mr Okafor. The placeholder is the egg colours (\"cream, blue and brown\") or \"fine\"."
        )
    case "okafor.winterOven":
        return String(
            localized: "notes.okafor.winterOven",
            defaultValue: "In winter the eggs come slower and the oven stays on longer. We manage.", bundle: .module,
            comment: "A note in the post from Mr Okafor.")
    case "okafor.custard":
        return String(
            localized: "notes.okafor.custard",
            defaultValue: "Spring, and every basket is full. I am making custard tarts this week.", bundle: .module,
            comment: "A note in the post from Mr Okafor.")

    // MARK: Bea
    case "bea.settled":
        guard let b = rehomedBird(s, 0) else {
            return String(
                localized: "notes.bea.settled.general",
                defaultValue: "Your birds have settled in well at their new homes.", bundle: .module,
                comment: "A note in the post from Bea, when what it names has gone.")
        }
        return String(
            localized: "notes.bea.settled",
            defaultValue: "\(b.name) has settled in well. \(they(b)) found the sunny corner on the first day.",
            bundle: .module,
            comment:
                "A note in the post from Bea. Placeholders: a rehomed bird's name, its pronoun or name (capital first)."
        )
    case "bea.appleTree":
        guard let b = rehomedBird(s, 1) else {
            return String(
                localized: "notes.bea.appleTree.general",
                defaultValue: "One of your birds has a new garden with an apple tree.", bundle: .module,
                comment: "A note in the post from Bea, when what it names has gone.")
        }
        return String(
            localized: "notes.bea.appleTree",
            defaultValue: "\(b.name) has a new garden with an apple tree. \(they(b)) spends the afternoons under it.",
            bundle: .module,
            comment:
                "A note in the post from Bea. Placeholders: a rehomed bird's name, its pronoun or name (capital first)."
        )
    case "bea.storyTime":
        guard let b = rehomedBird(s, 2) else {
            return String(
                localized: "notes.bea.storyTime.general",
                defaultValue: "Your birds' new families read to them after school.", bundle: .module,
                comment: "A note in the post from Bea, when what it names has gone.")
        }
        return String(
            localized: "notes.bea.storyTime",
            defaultValue: "\(b.name)'s new family has two small girls. They read to \(objectPronoun(b)) after school.",
            bundle: .module,
            comment: "A note in the post from Bea. Placeholders: a rehomed bird's name, its object pronoun or name.")
    case "bea.newFriend":
        guard let b = rehomedBird(s, 3) else {
            return String(
                localized: "notes.bea.newFriend.general",
                defaultValue: "Your birds have made friends in their new homes.", bundle: .module,
                comment: "A note in the post from Bea, when what it names has gone.")
        }
        return String(
            localized: "notes.bea.newFriend",
            defaultValue: "\(b.name) has a friend at the new place. The two of them dust-bathe side by side.",
            bundle: .module,
            comment: "A note in the post from Bea. The placeholder is a rehomed bird's name.")
    case "bea.fridge":
        guard let b = rehomedBird(s, 4) else {
            return String(
                localized: "notes.bea.fridge.general", defaultValue: "I have a photo of your birds on my fridge.",
                bundle: .module,
                comment: "A note in the post from Bea, when what it names has gone.")
        }
        return String(
            localized: "notes.bea.fridge",
            defaultValue: "I have a photo of \(b.name) on my fridge. \(they(b)) looks very pleased in it.",
            bundle: .module,
            comment:
                "A note in the post from Bea. Placeholders: a rehomed bird's name, its pronoun or name (capital first)."
        )
    case "bea.thanks":
        return String(
            localized: "notes.bea.thanks",
            defaultValue: "\(s.rehomed.count) of your birds have found new homes now. Every one is loved.",
            bundle: .module,
            comment: "A note in the post from Bea. The placeholder is the birds rehomed (more than 1).")
    case "bea.winterCheck":
        guard let b = rehomedBird(s, 6) else {
            return String(
                localized: "notes.bea.winterCheck.general",
                defaultValue: "Winter check on your birds: warm coops and deep straw.", bundle: .module,
                comment: "A note in the post from Bea, when what it names has gone.")
        }
        return String(
            localized: "notes.bea.winterCheck",
            defaultValue: "Winter check on \(b.name): a warm coop, deep straw and a family who fusses.",
            bundle: .module,
            comment: "A note in the post from Bea. The placeholder is a rehomed bird's name.")
    case "bea.fence":
        guard let b = rehomedBird(s, 7) else {
            return String(
                localized: "notes.bea.fence.general", defaultValue: "I visited your birds today. They're doing well.",
                bundle: .module,
                comment: "A note in the post from Bea, when what it names has gone.")
        }
        return String(
            localized: "notes.bea.fence",
            defaultValue: "I visited \(b.name) today. \(they(b)) came straight to the fence to see me.",
            bundle: .module,
            comment:
                "A note in the post from Bea. Placeholders: a rehomed bird's name, its pronoun or name (capital first)."
        )
    case "bea.quietWeek":
        return String(
            localized: "notes.bea.quietWeek",
            defaultValue: "The rescue is quiet this week. I sit with the old birds and drink my tea.", bundle: .module,
            comment: "A note in the post from Bea.")

    // MARK: Added later
    case "okafor.cream":
        return String(
            localized: "notes.okafor.cream",
            defaultValue: "Cream eggs, the colour of good butter. They sell first in my window, every time.",
            bundle: .module,
            comment: "A note in the post from Mr Okafor.")

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

/// The tamest bird at home, loaned birds too (they are cuddled in the coop). So it is a bird that meets the
/// note's friendliness condition. Ties go to the oldest, then by ID, so the pick is stable. Nil while that
/// bird still waits for a name: the note then says a general line.
private func tamestBird(_ s: GameState) -> Bird? {
    let tamest = s.birdsAtHome.max {
        ($0.friendlinessScore, -$0.hatchDay, $1.id.uuidString) < (
            $1.friendlinessScore, -$1.hatchDay, $0.id.uuidString
        )
    }
    return tamest?.needsName == true ? nil : tamest
}

/// The keeper's newest ribbon, in this kind of class (or any).
private func lastRibbon(_ s: GameState, kind: ShowKind?) -> ShowResult? {
    s.showResults.last { $0.isRibbon && (kind == nil || $0.showClass.kind == kind) }
}

/// "Juniper" for a bird, "plate of blue eggs" for an egg plate.
private func entryWords(_ r: ShowResult) -> String {
    if case .eggs(let colour) = r.showClass {
        return String(
            localized: "notes.plateOfEggs", defaultValue: "plate of \(colour.rawValue) eggs", bundle: .module,
            comment: "In Dot's note: \"I noticed your plate of blue eggs\". The placeholder is the egg colour.")
    }
    return r.entrantName
}

/// "Summer Fete", or "county show" for a result from an older save, which has no theme.
private func showName(_ r: ShowResult) -> String {
    r.theme.map(showThemeName)
        ?? String(
            localized: "notes.countyShow", defaultValue: "county show", bundle: .module,
            comment: "In Dot's note, for a show from an older save that has no name: \"at the county show\".")
}

/// One look from the Breed Book, as Hazel would say it: "gold laced wyandotte". The first in sorted order.
private func favouriteLook(_ s: GameState) -> String? {
    s.breedBook.map(entryText).sorted().first
}

/// "cream, blue and brown": the Egg Book's colours, in a fixed order.
private func eggColourList(_ s: GameState) -> String {
    let colours = EggColour.allCases.filter { c in s.eggBook.contains { $0.colour == c } }.map(\.rawValue)
    guard let last = colours.last else {
        return String(
            localized: "notes.fineEggs", defaultValue: "fine", bundle: .module,
            comment: "In Mr Okafor's note, when the Egg Book is empty: \"My window has fine eggs\".")
    }
    guard colours.count > 1 else { return last }
    // No comma before "and": `ListFormatStyle` adds one.
    let head = colours.dropLast().dropFirst().reduce(colours[0]) { list, next in
        String(
            localized: "notes.listComma", defaultValue: "\(list), \(next)", bundle: .module,
            comment: "Joins a list of egg colours. Placeholders: the colours so far, the next colour.")
    }
    return String(
        localized: "notes.listAndLast", defaultValue: "\(head) and \(last)", bundle: .module,
        comment:
            "The last colour of a list: \"cream, blue and brown\". Placeholders: the colours before it, the last colour."
    )
}
