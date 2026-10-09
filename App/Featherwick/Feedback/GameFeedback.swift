import FeatherwickCore

/// Sound and haptics for what the engine answered. `GameStore.run` calls this once per command,
/// so every screen gets the same feedback. Petting and tapping a bird on the farm play their own.
@MainActor
enum GameFeedback {
    static func play(for events: [GameEvent]) {
        var cues: Set<Sound.Cue> = []
        var success = false
        var warning = false
        for event in events {
            switch event {
            case .eggsCollected(let count, _) where count > 0:
                cues.insert(.egg)
                success = true
            case .eggLaid:
                cues.insert(.egg)
            case .chicksHatched:
                cues.insert(.hatch)
                success = true
            case .eggsSold, .rehomed, .showPrizesWon, .marketCardFilled, .soldToBuyer:
                cues.insert(.coins)
                success = true
            // Spending: a clear tap in the hand, so the keeper knows the purchase went through
            // and does not tap "Buy" twice.
            case .boughtBird, .boughtEgg, .boughtTreats, .boughtPremiumFeed, .boughtSpecial,
                .incubatorBought, .coopUpgraded, .enteredInShow:
                cues.insert(.coins)
                success = true
            case .rejected(.alreadyPettedToday):
                break  // Not an error: the bird just leans in (see `BirdBlob`).
            case .rejected(.noTimeLeft), .rejected(.notEveningYet), .rejected(.timeForBed):
                break  // Not an error: the light is gone, and the neighbour says so in a note.
            case .slotSpent, .rested:
                break  // The rest scene and the sun mark show the time passing: no sound, no buzz.
            case .rejected:
                warning = true
            default:
                break
            }
        }
        // One of each sound per command, so a night of many eggs is one soft sound.
        for cue in Sound.Cue.allCases where cues.contains(cue) { Sound.play(cue) }
        if success {
            Haptics.success()
        } else if warning {
            Haptics.warning()
        }
    }
}
