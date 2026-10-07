// TestFlight only. See `BetaNotes.swift` for how it stays out of App Store builds.
#if DEBUG || BETA

    import SwiftUI

    /// Two taps: how clear was that (1 to 5), then Save. One free line if the tester has more to say.
    /// Skip is always at the top, and the close button skips too.
    struct BetaPromptSheet: View {
        @Environment(GameStore.self) private var store
        @Environment(\.palette) private var palette
        @Environment(\.dismiss) private var dismiss
        let moment: BetaMoment
        /// 0 until the tester picks one, so no tab shows as chosen.
        @State private var clarity = 0
        @State private var wish = ""
        /// Saved or skipped. When the sheet goes any other way (swiped down, ×), that counts as a skip.
        @State private var done = false

        var body: some View {
            SheetPage(context: "Beta question") {
                HStack(alignment: .firstTextBaseline) {
                    Text("A quick question").font(Typeface.title2)
                    Spacer()
                    Button("Skip") { finish(skipped: true) }.buttonStyle(.textAction)
                }
                Text(moment.label).font(Typeface.body).foregroundStyle(palette.inkSoft)
                StitchDivider()
                Text("How clear was that?").font(Typeface.item)
                WordTabs(tabs: (1...5).map { ($0, "\($0)") }, selection: $clarity)
                Text("1 is not clear at all. 5 is very clear.")
                    .font(Typeface.caption).foregroundStyle(palette.inkMuted)
                StitchDivider()
                Text("What did you want to do that you couldn't?").font(Typeface.item)
                TextField("", text: $wish, axis: .vertical)
                    .font(Typeface.body)
                    .lineLimit(1...4)
                    .background(alignment: .bottom) {
                        HLine().stroke(palette.ink.opacity(0.5), style: Stitch.underline).frame(height: 2)
                            .offset(y: 4)
                    }
                    .accessibilityLabel("What did you want to do that you couldn't?")
                Text("Optional. Your answers stay on this phone until you share them from Settings.")
                    .font(Typeface.caption).foregroundStyle(palette.inkMuted)
                Button("Save") { finish(skipped: false) }
                    .buttonStyle(.primary)
                    .disabled(clarity == 0 && trimmedWish.isEmpty)
            }
            .presentationDetents([.large])
            .onAppear { store.betaPromptShown(moment) }
            .onDisappear { if !done { record(skipped: true) } }
        }

        private var trimmedWish: String { wish.trimmingCharacters(in: .whitespacesAndNewlines) }

        private func finish(skipped: Bool) {
            record(skipped: skipped)
            dismiss()
        }

        private func record(skipped: Bool) {
            guard !done else { return }
            done = true
            BetaNotes.record(
                BetaAnswer(
                    moment: moment, slot: store.slot, day: store.state.day,
                    clarity: skipped || clarity == 0 ? nil : clarity,
                    wish: skipped ? "" : trimmedWish, skipped: skipped,
                    at: .now, appVersion: BetaNotes.appVersion))
        }
    }

    /// Settings: share the notes file, and (Debug only) turn the prompts on and try them.
    struct BetaNotesSettings: View {
        @Environment(GameStore.self) private var store
        @Environment(\.palette) private var palette
        @Environment(\.dismiss) private var dismiss
        @AppStorage(BetaNotes.debugKey) private var debugOn = false

        var body: some View {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Beta notes").font(Typeface.item)
                if let url = BetaNotes.shareableURL {
                    ShareLink(item: url) { Text("Share beta notes") }
                        .buttonStyle(.secondary)
                } else {
                    Button("No beta notes yet") {}.buttonStyle(.secondary).disabled(true)
                }
                Text("Your answers to the beta questions, as a file. Send it to us any way you like.")
                    .font(Typeface.caption).foregroundStyle(palette.inkMuted)
                #if DEBUG
                    Toggle("Beta questions (testing)", isOn: $debugOn)
                        .font(Typeface.body)
                        .frame(minHeight: 44)
                        .tint(palette.ink)
                    HStack(spacing: Space.m) {
                        ForEach(BetaMoment.allCases) { moment in
                            Button(moment == .firstHatch ? "Ask: hatch" : "Ask: show") {
                                store.tryBetaPrompt(moment)
                                dismiss()
                            }
                            .buttonStyle(.secondary)
                        }
                    }
                    Text("Debug builds only. The switch lets the questions fire on the first hatch and show.")
                        .font(Typeface.caption).foregroundStyle(palette.inkMuted)
                #endif
            }
        }
    }

#endif
