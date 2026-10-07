import Foundation

// Naming.
//
// Birds the player hatches or buys arrive unnamed (`needsName`): the UI asks the player to name
// them, with a suggestion. Birds given by people already have the name their keeper gave them.
// Any bird the player owns can be renamed at any time.
//
// Names are unique in the flock (ignoring case and spaces), so the player can always tell
// birds apart, and the CLI can find a bird by name.
// Suggestions for a chick whose sex is not yet known come from a neutral list, so a
// suggestion never gives the sex away.
// A suggestion is never a name the keeper has used before: not a bird in the flock, and not a
// bird that went to a new home. The player may still type an old name by hand.

public enum NameBook {
    public static let maxLength = 24

    // Long lists, so a suggestion does not come round again in a long game. Each name is in one
    // list only. A new name can go anywhere in its list.
    public static let neutral = [
        "Pepper", "Biscuit", "Nutmeg", "Pip", "Sorrel", "Bramble", "Juniper", "Pebble", "Sage", "Quill",
        "Dumpling", "Tansy", "Fennel", "Sprout", "Button", "Crumble", "Toffee", "Moss", "Ember", "Acorn", "Almond",
        "Anise", "Apple", "Ash", "Aspen", "Barley", "Bean", "Berry", "Birch", "Bonbon", "Bracken", "Brioche",
        "Buckwheat", "Bun", "Butterscotch", "Caramel", "Cardamom", "Cashew", "Chai", "Chestnut", "Chickpea", "Chive",
        "Cinder", "Cinnamon", "Clove", "Cobble", "Cocoa", "Comfrey", "Conker", "Cookie", "Coriander", "Crouton",
        "Cumin", "Currant", "Custard", "Dandelion", "Dill", "Dune", "Elder", "Fig", "Flax", "Flint", "Fudge",
        "Garnet", "Ginger", "Gravel", "Hickory", "Honey", "Hops", "Huckleberry", "Indigo", "Jelly", "Kale", "Kestrel",
        "Kipper", "Lark", "Leek", "Lentil", "Linden", "Loaf", "Lupin", "Mallow", "Mango", "Marble", "Marzipan",
        "Meadow", "Merry", "Millet", "Mint", "Miso", "Mochi", "Muffin", "Mustard", "Noodle", "Nutkin", "Oak", "Oat",
        "Onyx", "Paprika", "Parsley", "Parsnip", "Peanut", "Pecan", "Persimmon", "Pickle", "Pine", "Pistachio",
        "Plum", "Pocket", "Pudding", "Puffin", "Pumpkin", "Quince", "Radish", "Raisin", "Rhubarb", "Rook", "Rowan",
        "Rue", "Rye", "Saffron", "Scone", "Sesame", "Shortbread", "Sky", "Slate", "Smudge", "Soot", "Spruce",
        "Squash", "Sugar", "Sumac", "Tapioca", "Teacake", "Teasel", "Thistle", "Thyme", "Treacle", "Truffle",
        "Tumble", "Turnip", "Waffle", "Walnut", "Wheat", "Whisk", "Yarrow", "Zest", "Cobnut", "Hazelnut",
    ]
    public static let hens = [
        "Clover", "Maple", "Marigold", "Henrietta", "Daisy", "Primrose", "Mabel", "Rosie", "Florence", "Ivy",
        "Poppy", "Edith", "Willow", "Matilda", "Winifred", "Bluebell", "Hattie", "Agnes", "Dot", "Ada", "Adelaide",
        "Agatha", "Alma", "Annie", "Beatrice", "Bella", "Bertha", "Betty", "Blanche", "Bonnie", "Cecily", "Clara",
        "Clementine", "Cora", "Daphne", "Delia", "Dolly", "Dora", "Doris", "Edna", "Effie", "Eleanor", "Elsie",
        "Esme", "Ethel", "Etta", "Eudora", "Evie", "Fern", "Fay", "Flora", "Freya", "Georgie", "Gertrude", "Gladys",
        "Greta", "Gwen", "Harriet", "Heather", "Helena", "Hilda", "Imogen", "Iris", "Isla", "Jemima", "Josephine",
        "June", "Kitty", "Lavinia", "Lettie", "Lilac", "Lily", "Lottie", "Louisa", "Lucy", "Lula", "Mae", "Maggie",
        "Margot", "Marjorie", "Martha", "Maud", "May", "Meg", "Millie", "Minnie", "Miriam", "Molly", "Myrtle",
        "Nancy", "Nell", "Nora", "Olive", "Opal", "Pansy", "Pearl", "Peggy", "Penelope", "Petunia", "Philippa",
        "Phoebe", "Polly", "Prudence", "Queenie", "Ruby", "Ruth", "Sadie", "Sally", "Sophie", "Stella", "Sylvie",
        "Tabitha", "Tilly", "Una", "Vera", "Violet", "Wilhelmina", "Winnie", "Yvette", "Zelda", "Zinnia", "Beryl",
        "Mavis", "Irene", "Enid", "Ida", "Lorna", "Peony", "Rosalind", "Hyacinth", "Camellia", "Dahlia", "Magnolia",
        "Cleo", "Ottilie", "Henny", "Goldie", "Bettina", "Honora",
    ]
    public static let roosters = [
        "Rufus", "Barnaby", "Alfred", "Basil", "Reginald", "Clarence", "Fergus", "Rupert", "Hamish", "Ambrose",
        "Cedric", "Bertie", "Monty", "Percival", "Ogden", "Gilbert", "Archie", "Horace", "Wilbur", "Duncan", "Albert",
        "Algernon", "Angus", "Arthur", "Atticus", "Augustus", "Benedict", "Bernard", "Boris", "Brutus", "Bruno",
        "Byron", "Caspar", "Cecil", "Chester", "Clement", "Colin", "Cornelius", "Cuthbert", "Cyril", "Dennis",
        "Desmond", "Douglas", "Edgar", "Edmund", "Edwin", "Elmer", "Ernest", "Eustace", "Felix", "Frank", "Frederick",
        "George", "Gerald", "Gordon", "Graham", "Gus", "Harold", "Harvey", "Hector", "Henry", "Herbert", "Hubert",
        "Hugo", "Humphrey", "Ignatius", "Ivor", "Jasper", "Jeremiah", "Jonah", "Kenneth", "Lambert", "Leonard",
        "Lionel", "Louis", "Magnus", "Malcolm", "Marmaduke", "Maurice", "Mervyn", "Milo", "Mortimer", "Murray",
        "Nigel", "Norman", "Norris", "Oliver", "Orville", "Oscar", "Otis", "Otto", "Percy", "Peregrine", "Quentin",
        "Ralph", "Randolph", "Roderick", "Roland", "Roscoe", "Rudy", "Samson", "Seymour", "Sidney", "Stanley",
        "Sylvester", "Theodore", "Thaddeus", "Tobias", "Ulysses", "Vernon", "Victor", "Walter", "Wallace", "Wendell",
        "Wilfred", "Winston", "Woody", "Yorick", "Zachary", "Ezra", "Elliot", "Fitz", "Gideon", "Godfrey", "Rocky",
        "Dudley", "Ferdinand", "Leopold", "Solomon", "Bartholomew", "Rex", "Duke", "Earl", "Baron", "Hamlet",
        "Napoleon", "Alistair", "Bertram", "Crispin", "Dashiell",
    ]

    /// How names are compared: case and spaces don't count.
    public static func key(_ name: String) -> String {
        name.lowercased().filter { !$0.isWhitespace }
    }

    /// Birds whose names must be unique: everyone the player owns.
    static func flock(_ s: GameState) -> [Bird] { s.birdsAtHome + s.boarding + s.lost.map(\.bird) }

    public static func isTaken(_ name: String, exceptID: UUID? = nil, in s: GameState) -> Bool {
        let k = key(name)
        return flock(s).contains { $0.id != exceptID && key($0.name) == k }
    }

    /// Every name the keeper has used, as `key`s: birds they own now and birds that went to a new home.
    /// This bird's own name does not count.
    static func usedKeys(exceptID: UUID, in s: GameState) -> Set<String> {
        Set((flock(s) + s.rehomed).filter { $0.id != exceptID }.map { key($0.name) })
    }

    /// A name never used before, picked from the bird's own ID (so it moves no game randomness).
    /// Neutral names while its sex is still a secret. `skipping` steps on to later free names
    /// ("Try another" in the app).
    public static func suggestion(for bird: Bird, in s: GameState, skipping: Int = 0) -> String {
        let list = !bird.revealed ? neutral : bird.sex == .hen ? hens : roosters
        var local = bird.localRNG(salt: 0x4E41_4D45)  // "NAME"
        let start = Int.random(in: 0..<list.count, using: &local)
        let used = usedKeys(exceptID: bird.id, in: s)
        let free = (0..<list.count).map { list[(start + $0) % list.count] }.filter { !used.contains(key($0)) }
        if !free.isEmpty { return free[max(0, skipping) % free.count] }
        // Every name in the list is used: number them on from 2.
        var n = 2 + max(0, skipping)
        while used.contains(key("\(list[start]) \(n)")) { n += 1 }
        return "\(list[start]) \(n)"
    }
}

extension Bird {
    /// A random generator seeded from this bird's ID. Used for things fixed by the bird itself.
    func localRNG(salt: UInt64) -> SeededRNG {
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        let seed = bytes.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        return SeededRNG(seed: seed ^ salt)
    }

    /// A bird from a person who has already named it.
    func namedByKeeper(in s: GameState) -> Bird {
        var copy = self
        copy.name = NameBook.suggestion(for: copy, in: s)
        copy.needsName = nil
        return copy
    }

    /// A bird the player must name. `name` stays as a placeholder until then.
    func waitingForName() -> Bird {
        var copy = self
        copy.needsName = true
        return copy
    }
}

extension GameState {
    /// Birds the player has not named yet, oldest arrival first.
    public var unnamedBirds: [Bird] { birdsAtHome.filter { $0.needsName == true } }
}
