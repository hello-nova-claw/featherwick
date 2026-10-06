import AVFoundation

/// Short bundled sounds (see `Sounds/README.md`). A missing file plays nothing, so the game works
/// silently until the sounds exist. The `.ambient` session obeys the silent switch and mixes with
/// the player's own music.
@MainActor
enum Sound {
    /// One sound each. The raw value is the file name, without the extension.
    enum Cue: String, CaseIterable {
        case cluck, egg, hatch, coins
    }

    static var isOn: Bool { FeedbackSettings.isOn(FeedbackSettings.soundKey) }

    private static var players: [Cue: AVAudioPlayer] = [:]
    /// Cues with no file in the bundle. Looked up once, then skipped.
    private static var missing: Set<Cue> = []
    private static var sessionReady = false

    static func play(_ cue: Cue) {
        guard isOn, let player = player(for: cue) else { return }
        prepareSession()
        player.currentTime = 0
        player.play()
    }

    private static func player(for cue: Cue) -> AVAudioPlayer? {
        if let player = players[cue] { return player }
        if missing.contains(cue) { return nil }
        guard let url = url(for: cue), let player = try? AVAudioPlayer(contentsOf: url) else {
            missing.insert(cue)
            return nil
        }
        player.prepareToPlay()
        players[cue] = player
        return player
    }

    /// XcodeGen copies the Sounds folder's files to the bundle root; a folder reference keeps the folder.
    private static func url(for cue: Cue) -> URL? {
        for ext in ["caf", "m4a"] {
            if let url = Bundle.main.url(forResource: cue.rawValue, withExtension: ext) { return url }
            if let url = Bundle.main.url(forResource: cue.rawValue, withExtension: ext, subdirectory: "Sounds") {
                return url
            }
        }
        return nil
    }

    private static func prepareSession() {
        guard !sessionReady else { return }
        sessionReady = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
    }
}
