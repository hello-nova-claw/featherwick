import Foundation

// Quirks: small habits that make each bird its own. Flavour only.
//
// A quirk changes no rule: no coins, no friendliness, no condition. Quirks are not stored. They come
// from the bird's own ID (as name suggestions do), so they move no game randomness and a save holds
// nothing new. The same bird always has the same quirks.
//
// Every bird has two quirks from the neutral set, fixed for life. Once its sex shows, it may gain a
// third from its sex's set (about half of birds do: `Rules.quirkSexShare`). A chick whose sex is
// still hidden shows only neutral quirks, so a quirk never gives the sex away.

/// One habit. Raw values are stable and the list is append-only: words and the app key on them.
/// Each case notes the idle animation it suggests, for the farm scene later.
public enum Quirk: String, Hashable, Codable, Sendable, CaseIterable {
    /// Idle: scratches a hollow, flops down and kicks dust over its back.
    case dustBathLover
    /// Hens only. Idle: stands up in the nest box and calls the egg song.
    case singsWhenLaying
    /// Idle: waits by the gate at dawn and is first through it.
    case firstToTheGate
    /// Idle: paces the fence, then flutters up to look over it.
    case escapeArtist
    /// Idle: trails a few steps behind the keeper.
    case followsYouAbout
    /// Idle: hops up onto the fence post and sits there.
    case sitsOnTheFencePost
    /// Idle: in rain, hunches under the coop eaves.
    case hatesRain
    /// Idle: at dusk, settles near the keeper and leans in.
    case likesACuddleAtDusk
    /// Idle: grabs a mealworm and runs off with it.
    case hoardsTheMealworms
    /// Idle: stands by the far fence and chatters at it.
    case talksToTheDucks
    /// Idle: at roost time, climbs to the top perch.
    case roostsOnTheHighestPerch
    /// Hens only. Idle: sits tight on a nest of golf balls.
    case broodsOverGolfBalls
    /// Idle: lies on one side with a wing stretched out in a patch of sun.
    case napsInTheSun
    /// Idle: tugs at the keeper's bootlaces.
    case pecksAtBootlaces
    /// Roosters only. Idle: puffs up and charges toward the hedge.
    case runsAtTheFox
    /// Idle: the last one to go in at night, still pecking about.
    case alwaysLastToBed

    /// The sex this quirk belongs to, or nil for a quirk any bird may have.
    public var sex: Sex? {
        switch self {
        case .singsWhenLaying, .broodsOverGolfBalls: .hen
        case .runsAtTheFox: .rooster
        default: nil
        }
    }

    /// Quirks any bird may have.
    public static var neutral: [Quirk] { allCases.filter { $0.sex == nil } }
    /// Quirks only birds of this sex may have.
    public static func only(_ sex: Sex) -> [Quirk] { allCases.filter { $0.sex == sex } }
}

public enum Quirks {
    /// Neutral quirks every bird has.
    public static let neutralCount = 2

    /// This bird's quirks: two neutral ones, then one for its sex if its sex shows and its ID says so.
    /// Reads only the bird's ID and what the keeper can see (`revealed`, then its sex).
    public static func of(_ bird: Bird, in s: GameState) -> [Quirk] {
        var quirks = Array(ranked(Quirk.neutral, for: bird).prefix(neutralCount))
        guard bird.revealed else { return quirks }
        var local = bird.localRNG(salt: 0x5152_4B33)  // "QRK3"
        guard Double.random(in: 0..<1, using: &local) < s.rules.quirkSexShare,
            let extra = ranked(Quirk.only(bird.sex), for: bird).first
        else { return quirks }
        quirks.append(extra)
        return quirks
    }

    /// Quirks in this bird's own order. Each quirk gets a score from the bird's ID and the quirk's
    /// name, so a quirk appended later moves only the few birds that score it highest.
    static func ranked(_ quirks: [Quirk], for bird: Bird) -> [Quirk] {
        quirks.map { ($0, score($0, bird)) }
            .sorted { ($0.1, $0.0.rawValue) > ($1.1, $1.0.rawValue) }
            .map(\.0)
    }

    static func score(_ q: Quirk, _ bird: Bird) -> UInt64 {
        var local = bird.localRNG(salt: 0x5152_4B53 ^ fnv1a(q.rawValue))  // "QRKS"
        return local.next()
    }

    /// A stable hash of a name (FNV-1a). Swift's `hashValue` changes on every launch, so it can't be used.
    static func fnv1a(_ text: String) -> UInt64 {
        text.utf8.reduce(0xCBF2_9CE4_8422_2325) { ($0 ^ UInt64($1)) &* 0x0000_0100_0000_01B3 }
    }
}
