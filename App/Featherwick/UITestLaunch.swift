#if DEBUG
    import FeatherwickCore
    import Foundation

    /// Launch arguments that start the app in a known game, for UI tests and screenshots. Debug builds only.
    /// `-uiTestState fresh` is day 1 before the keeper is named. `-uiTestState farm` is a farm a few days in,
    /// with the early game's lessons already open, so every screen and button can be reached.
    /// `-uiTestSeed <n>` picks the seed (2026 if left out), so the same arguments give the same game.
    struct UITestLaunch: Equatable {
        enum Start: String {
            case fresh, farm
        }

        let start: Start
        let seed: UInt64

        init(start: Start, seed: UInt64) {
            self.start = start
            self.seed = seed
        }

        init?(arguments: [String]) {
            guard let start = Self.value(after: "-uiTestState", in: arguments).flatMap(Start.init(rawValue:)) else {
                return nil
            }
            self.start = start
            seed = Self.value(after: "-uiTestSeed", in: arguments).flatMap(UInt64.init) ?? 2026
        }

        /// The save this launch starts from, played through the engine like any game.
        func save() -> SaveGame {
            var rng = SeededRNG(seed: seed)
            var state = Engine.newGame(earlyGame: start == .fresh, using: &rng)
            if start == .farm {
                let opening: [Command] = [.nameKeeper("Robin"), .chooseStarter(index: 0, name: "Pip")]
                for command in opening { _ = Engine.apply(command, to: &state, using: &rng) }
                for _ in 0..<3 { sleepThroughTheNight(&state, &rng) }
            }
            return SaveGame(state: state, rng: rng)
        }

        /// A store on its own empty folder, holding this launch's save, so one test never sees another's game.
        @MainActor func makeStore() throws -> GameStore {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("uitest-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // Its own slot too: the app keeps per-slot notes (new stock seen, beta prompts) outside the save.
            let slot = "uitest-\(UUID().uuidString)"
            try SaveStore(directory: directory, slot: slot).write(SaveFormat.encode(save()))
            return GameStore(directory: directory, slot: slot)
        }

        /// Cares for the flock, rests until the sleep gate opens, then sleeps.
        private func sleepThroughTheNight(_ state: inout GameState, _ rng: inout SeededRNG) {
            for command: Command in [.feed, .collectEggs] { _ = Engine.apply(command, to: &state, using: &rng) }
            var rests = 0
            while Engine.daylightRefusal(for: .passNight, in: state) != nil, rests < 8 {
                _ = Engine.apply(.rest, to: &state, using: &rng)
                rests += 1
            }
            _ = Engine.apply(.passNight, to: &state, using: &rng)
        }

        private static func value(after flag: String, in arguments: [String]) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }
    }
#endif
