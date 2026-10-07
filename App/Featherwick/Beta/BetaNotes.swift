// Beta prompts: two short questions for TestFlight testers. None of this is in an App Store build.
//
// Two locks keep it out of the App Store:
// 1. Build flag. `BETA` is set only by the Beta build configuration (`App/project.yml`), which the
//    "Featherwick Beta" scheme archives for TestFlight. The App Store archive (Release) leaves it out,
//    so the code is not even compiled in. Debug builds compile it too, so it can be tried in the Simulator.
// 2. Receipt check. A TestFlight install has a sandbox receipt; an App Store install does not. So a
//    Beta build that reached the App Store by mistake would still never ask.
// The answers stay on the device, in a JSON file next to the saves. The tester sends them on with the
// share sheet (Settings ▸ Share beta notes). No network, no analytics.
#if DEBUG || BETA

    import Foundation

    /// The two moments worth a question: the first chick, and the first show the keeper entered.
    enum BetaMoment: String, Codable, CaseIterable, Identifiable {
        case firstHatch, firstShow
        var id: String { rawValue }

        /// What just happened, as the sheet tells the tester.
        var label: String {
            switch self {
            case .firstHatch: "Your first chick hatched."
            case .firstShow: "You saw your first show results."
            }
        }
    }

    /// One answer. A skip is kept too, so a tester's notes show what they passed over.
    struct BetaAnswer: Codable, Hashable {
        var moment: BetaMoment
        var slot: String
        var day: Int
        /// 1 (not clear) to 5 (very clear). Nil when the tester did not pick one.
        var clarity: Int?
        var wish: String
        var skipped: Bool
        var at: Date
        var appVersion: String
    }

    /// The beta notes file. It is kept apart from the game save, so the game state never changes.
    struct BetaNotesFile: Codable {
        /// The moments already asked, per save slot. Each one is asked once, ever.
        var asked: [String: [BetaMoment]] = [:]
        var answers: [BetaAnswer] = []
    }

    /// Reads and writes `beta-notes.json` in Application Support, and says if the prompts are on.
    @MainActor
    enum BetaNotes {
        /// Debug only: a switch in Settings, so the prompts can be tried without TestFlight.
        static let debugKey = "tester.betaPrompts"

        /// A question waiting for a quiet moment on the farm (no show, no other sheet). Not saved:
        /// if the app closes first, the next hatch or show asks instead.
        static var waiting: BetaMoment?

        /// Should the prompts fire in this build, on this install?
        static var isOn: Bool {
            #if BETA
                // TestFlight installs carry a sandbox receipt; App Store installs carry "receipt".
                return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
            #else
                return UserDefaults.standard.bool(forKey: debugKey)
            #endif
        }

        /// Settings shows the beta notes row in Debug builds, and in Beta builds installed from TestFlight.
        static var showsInSettings: Bool {
            #if DEBUG
                return true
            #else
                return isOn
            #endif
        }

        static var url: URL { GameStore.saveDirectory().appendingPathComponent("beta-notes.json") }

        static func read() -> BetaNotesFile {
            guard let data = try? Data(contentsOf: url) else { return BetaNotesFile() }
            return (try? decoder.decode(BetaNotesFile.self, from: data)) ?? BetaNotesFile()
        }

        private static func write(_ file: BetaNotesFile) {
            guard let data = try? encoder.encode(file) else { return }
            try? data.write(to: url, options: .atomic)
        }

        static func wasAsked(_ moment: BetaMoment, slot: String) -> Bool {
            read().asked[slot]?.contains(moment) ?? false
        }

        /// Marked as soon as the sheet opens, so a tester who swipes it away is not asked again.
        static func markAsked(_ moment: BetaMoment, slot: String) {
            var file = read()
            guard !(file.asked[slot]?.contains(moment) ?? false) else { return }
            file.asked[slot, default: []].append(moment)
            write(file)
        }

        static func record(_ answer: BetaAnswer) {
            var file = read()
            file.answers.append(answer)
            write(file)
        }

        /// The file to share, once there is at least one answer.
        static var shareableURL: URL? { read().answers.isEmpty ? nil : url }

        static var appVersion: String {
            let info = Bundle.main.infoDictionary
            let version = info?["CFBundleShortVersionString"] as? String ?? "?"
            let build = info?["CFBundleVersion"] as? String ?? "?"
            return "\(version) (\(build))"
        }

        private static var encoder: JSONEncoder {
            let e = JSONEncoder()
            e.outputFormatting = [.prettyPrinted, .sortedKeys]
            e.dateEncodingStrategy = .iso8601
            return e
        }

        private static var decoder: JSONDecoder {
            let d = JSONDecoder()
            d.dateDecodingStrategy = .iso8601
            return d
        }
    }

#endif
