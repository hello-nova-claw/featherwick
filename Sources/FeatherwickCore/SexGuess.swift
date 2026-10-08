import Foundation

// "Hen or roo?": before a chick's sex shows, the keeper may guess it once. A cuddle-time game.
//
// The guess is free: no daylight, no coins, no feature gate. It reveals nothing. A guess is only
// allowed while the chick is younger than `Rules.growerAge` and its sex has not shown, and the
// refusals depend on age and the guess alone, never on the bird's sex (rule 8).
//
// On the morning the sex shows (the `.revealed` event in `passNight` step 4) the guess is resolved:
// a right guess pays `Rules.sexGuessTreats` mealworms, a wrong one costs nothing. Either way the
// guess is cleared. A chick that leaves before that morning takes its guess with it, silently.
// No randomness here, so seeded games do not change.

extension Engine {
    /// Why the keeper cannot guess for this bird now, or nil if they can. Front ends show the buttons
    /// when this is nil. Age, the visible reveal and the guess itself only: never the bird's sex.
    public static func sexGuessRefusal(_ id: UUID, in s: GameState) -> Rejection? {
        guard let bird = s.ownedBirds.first(where: { $0.id == id }) else { return .noSuchBird }
        if bird.revealed || bird.age(onDay: s.day) >= s.rules.growerAge { return .tooLateToGuess }
        if s.sexGuesses[id] != nil { return .alreadyGuessed }
        return nil
    }

    /// Records the keeper's guess for a chick whose sex does not show yet.
    static func guessSex(_ id: UUID, _ guess: Sex, _ s: inout GameState) -> [GameEvent] {
        if let refusal = sexGuessRefusal(id, in: s) { return [.rejected(refusal)] }
        s.sexGuesses[id] = guess
        return [.sexGuessed(id, guess)]
    }

    /// The night's reveals settle the guesses for those birds. Called right after growth.
    static func resolveSexGuesses(after ev: [GameEvent], _ s: inout GameState) -> [GameEvent] {
        guard !s.sexGuesses.isEmpty else { return [] }
        var out: [GameEvent] = []
        for case .revealed(let id, let actual, _) in ev {
            guard let guessed = s.sexGuesses.removeValue(forKey: id) else { continue }
            if guessed == actual {
                s.treats += s.rules.sexGuessTreats
                s.sexGuessesRight += 1
            }
            out.append(.sexGuessResolved(id, guessed: guessed, actual: actual))
        }
        return out
    }

    /// Drops guesses for birds that left the flock, or whose sex shows already. No event: the guess
    /// simply goes with the bird.
    static func dropStaleSexGuesses(_ s: inout GameState) {
        guard !s.sexGuesses.isEmpty else { return }
        let open = Set(s.ownedBirds.filter { !$0.revealed }.map(\.id))
        s.sexGuesses = s.sexGuesses.filter { open.contains($0.key) }
    }
}
