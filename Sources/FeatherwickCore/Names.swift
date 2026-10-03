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

public enum NameBook {
    public static let maxLength = 24

    public static let neutral = [
        "Pepper", "Biscuit", "Nutmeg", "Pip", "Sorrel", "Bramble", "Juniper", "Pebble", "Sage", "Wren",
        "Quill", "Dumpling", "Tansy", "Fennel", "Sprout", "Button", "Crumble", "Toffee", "Moss", "Ember",
    ]
    public static let hens = [
        "Clover", "Maple", "Hazel", "Marigold", "Henrietta", "Daisy", "Primrose", "Mabel", "Rosie", "Florence",
        "Ivy", "Poppy", "Edith", "Willow", "Matilda", "Winifred", "Bluebell", "Hattie", "Agnes", "Dot",
    ]
    public static let roosters = [
        "Rufus", "Barnaby", "Alfred", "Basil", "Reginald", "Clarence", "Fergus", "Rupert", "Hamish", "Ambrose",
        "Cedric", "Bertie", "Monty", "Percival", "Ogden", "Gilbert", "Archie", "Horace", "Wilbur", "Duncan",
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

    /// A free name for this bird, picked from its own ID (so it moves no game randomness).
    /// Neutral names while its sex is still a secret.
    public static func suggestion(for bird: Bird, in s: GameState) -> String {
        let list = !bird.revealed ? neutral : bird.sex == .hen ? hens : roosters
        var local = bird.localRNG(salt: 0x4E41_4D45)  // "NAME"
        let start = Int.random(in: 0..<list.count, using: &local)
        for offset in 0..<list.count {
            let name = list[(start + offset) % list.count]
            if !isTaken(name, exceptID: bird.id, in: s) { return name }
        }
        var n = 2
        while isTaken("\(list[start]) \(n)", exceptID: bird.id, in: s) { n += 1 }
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
