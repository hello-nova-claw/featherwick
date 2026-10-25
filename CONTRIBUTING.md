# Contributing to Featherwick

These rules apply to everyone: outside contributors, the maintainer and coding agents. The reviewer enforces them, and CI enforces the parts a machine can check.

## The rule above all others

Featherwick is a cozy game with real genetics. Before you build anything, check it against the design principles in [docs/design.md](docs/design.md#2-design-principles-not-negotiable). A pull request that breaks one of them is closed, however good the code is. In short:

1. Cozy: nothing dies, and nothing can be failed. Every fertile egg hatches, the fox never kills, and nothing is unsuitable for a child.
2. Real genetics, and no leaks. Looks come from genes, and the game never shows a gene or a sex the keeper cannot see yet.
3. The same seed plays the same game, and saves always load.
4. Nothing leaves the device unless the player sends it. No ads, analytics, tracking or accounts. It works offline.
5. Fair and calm. No pay-to-win, no dark patterns, no streaks to lose, no nagging notifications.

## How work flows

1. **Issue first.** Every change starts as an issue made from the task template. An issue is not ready until all five fields are filled in: problem, scope, out of scope, acceptance criteria, how to test. Agents fill the template before they write code.
2. **Outside contributors wait.** If you are not the maintainer, open an issue and wait until it is accepted (moved to Ready) before you write code. A pull request without an accepted issue is closed.
3. **Board.** Issues move across the [project board](https://github.com/users/hello-nova-claw/projects/2): Backlog, Ready, In progress, In review, Done. Move the issue, not the pull request.
   - New issues are not added to the board automatically. Whoever files an issue adds it (`gh project item-add 2 --owner hello-nova-claw --url <issue url>`) and sets its milestone, Priority and Status together.
   - Priority mirrors the milestone: `P0 · 0.2 TestFlight`, `P1 · 0.3 Trade codes`, `P2 · Later`.
   - Backlog comes first. An issue stays in Backlog, whatever its Priority, while it is labelled `question`, while it is in Later, or while it is an outside contributor's issue the maintainer has not triaged.
   - Every other P0 and P1 issue is Ready.
4. **One branch and one pull request per issue.** Name the branch `<issue number>-<short-slug>`, for example `58-string-catalog`.
5. **Pull request.** Use the template. Link the issue with `Fixes #58`. Add a changelog fragment, `changelog/<issue>-<slug>.txt`, with one line a player would understand. Do not edit `CHANGELOG.md`: at release time `bin/changelog` folds every fragment in and deletes them. If the change has no effect a player can see, say so, and the maintainer adds the `no-changelog` label.
6. **Review.** CodeRabbit reviews every pull request, and its approval is the required review. `main` is protected: no direct pushes, all checks green, stale approvals dismissed on push.

## Licensing of contributions

- **Code.** You contribute code under the MIT licence in [LICENSE](LICENSE), the licence it is published under. Opening a pull request means you agree to this, and that you have the right to contribute the code.
- **Assets.** Art, sound, music, the game's writing and anything else under a path named in [ASSETS-LICENSE.md](ASSETS-LICENSE.md) are not accepted without a written agreement first. A pull request that adds or changes those files without one is closed. This keeps every asset under one owner.
- **The name and icon** belong to the project ([TRADEMARKS.md](TRADEMARKS.md)). A fork uses its own.

## Housekeeping

- **Branches go when they merge.** GitHub deletes a pull request's branch on merge. Run `git config fetch.prune true` once per checkout, and delete your local branch with `git branch -d <branch>`.
- **`main` is the only long-lived branch.** Branch from an up-to-date `main`. If your branch conflicts with `main`, merge `main` into it. Do not rebase a branch someone else may have checked out.
- **An issue is done when its pull request merges.** Work found along the way gets its own issue, not an extra commit.
- **Commit only source.** Never commit build output (`.build/`), the generated Xcode project, saves (`featherwick-save*.json`), signing files, or editor and agent folders such as `.claude/` and `.vscode/`. If something new shows in `git status` that is not yours to commit, add it to `.gitignore` in its own commit.
- **Leave no scaffolding.** Remove debug output and commented-out code before review. A TODO names its issue: `// TODO(#58): ...`. A TODO without one is not allowed.

## Commits

Write commit messages in WordPress core style.

- Imperative mood, a component prefix, under 72 characters, ending with a full stop: `Genetics: Pass the speckle allele on from both parents.`
- Add a body only when there is a reason worth recording. Explain why, not what.
- No emoji. No `feat:` or other Conventional Commits prefixes. No bullet list of every file you touched.
- Keep commits small, one thing each. Commit the test before the code that makes it pass.
- A large pull request with a single commit is sent back.

Prefixes: `Genetics`, `Gameplay`, `Story`, `Save`, `Text`, `Scene`, `UI`, `Art`, `Audio`, `I18N`, `A11y`, `Build/Test Tools`, `Docs`.

## Code

- Swift 6, formatted with `swift-format` using `.swift-format`. CI fails on unformatted code and on any warning. Fix warnings; do not silence them.
- SwiftLint (`.swiftlint.yml`) checks force unwraps, `try!`, force casts and a few more. Old violations sit in `.swiftlint-baseline.json`. Fix one and it leaves the baseline; never add one to get a pull request through.
- Rules live in `FeatherwickCore`, and only there. Words live in `FeatherwickText`, and only there. Views send commands and show state. See the core rules in [CLAUDE.md](CLAUDE.md).
- Core builds on Linux: no Apple-only APIs in `FeatherwickCore` or `FeatherwickText`.
- No force unwraps and no `try!` outside tests.
- UI code runs on the main actor. Do no slow work on the main thread or in a frame of the scene.

### Use what Apple already has

Featherwick should feel like an iPhone app. Before you write anything custom, use the system equivalent. If there isn't one, say so in the pull request.

- **UI.** SwiftUI system components: `.sheet` with `presentationDetents`, `NavigationStack`, `Button`, `Toggle`, `Picker`, `List`. Build on the components in `App/Featherwick/Design/`, which wrap them. SF Symbols for icons.
- **Colour.** Colours come only from the `Palette` tokens in `App/Featherwick/Design/`, which have day and night values. No `Color(red:…)`, `Color(hex:)` or `UIColor(red:…)` anywhere else. The known exceptions sit in `.swiftlint-baseline.json`: the scene shader's channel colours (data, not colour), the placeholder chicken's eye, and the farm panels' flat stand-ins until their paintings exist (#77).
- **Type.** Fonts come only from the `Typeface` tokens, and every font scales with Dynamic Type (`relativeTo:`). No `.font(.system(size:))` and no fixed font sizes in screens.
- **Logging.** `os.Logger` in the app. No `print` in the app, Core or Text; the CLI prints, and a test may print what a failing run needs.
- **Saves.** `Codable` and `FileManager`, through `SaveStore`. No other storage for game state.
- **Feedback.** `UIFeedbackGenerator` through `Haptics`, and `AVAudioSession` (`.ambient`) through `Sound`.
- **Game Center** through GameKit, if the game ever uses it.
- **Dependencies.** None today. A new Swift package needs an entry on the allowlist in `bin/check-native`, an MIT-compatible licence, a line in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md), and a reason in the pull request. Nothing may phone home (principle 4).

### Comments

Comments explain why. Delete any comment that restates the line below it. Each type and function gets a short doc comment in plain English, and that is all. Match the file you are in.

## Tests

- Write the test first, and commit it first.
- A pull request that changes `Sources/` or `App/Featherwick/` must also change a file under `Tests/`, `App/FeatherwickTests/` or `App/FeatherwickUITests/`. CI checks this ("Tests change with code").
- Tests use Swift Testing (`import Testing`). No XCTest except for UI tests, which need it.
- Game logic is tested without the app or the renderer. Pass a `SeededRNG` with a fixed seed. Never read the clock: game time is state.
- No sleeps and no real network in tests.
- Line coverage must not drop. CI fails below the figure in `.github/coverage-baseline` (Core and Text, on Linux); when your change raises coverage, raise the baseline in the same pull request.
- `Fixtures/save-v0.json` must always load. A change to the save shape needs a migration and a test.

Run everything locally:

```bash
swift build --build-tests -Xswiftc -warnings-as-errors
swift test
swift format --in-place --recursive Package.swift Sources Tests App && git diff --exit-code   # from a clean tree
swiftlint lint --strict --baseline .swiftlint-baseline.json
bin/check-native && bin/check-licences
cd App && xcodegen && xcodebuild test -project Featherwick.xcodeproj -scheme Featherwick \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```

## Localisation

- Every word the player reads lives in `FeatherwickText`, never in `FeatherwickCore` or a view.
- The words are moving into a String Catalog (#58). After that, every user-facing string goes in the catalog, with a translator comment on every string that has a placeholder.
- Never build a sentence by joining fragments. Write the whole sentence, with the values in it.
- Numbers, dates and durations use `FormatStyle`, never hand-built strings.
- Layouts survive right-to-left languages and strings twice as long as English.

## Accessibility

- Every interactive element has a VoiceOver label. A bird's label says what the keeper can see, never a hidden gene or sex (principle 2).
- Layouts survive the largest accessibility Dynamic Type sizes. Text wraps; it is never cut off.
- Respect Reduce Motion: birds and the scene stay still or cross-fade when it is on.
- Never use colour as the only signal. A colour that carries meaning also has a word, a shape or a mark.
- Every sound has a visual or haptic equivalent, and the game is fully playable with sound off.
- A toast or result the player must know about is announced to VoiceOver.
- Apple's accessibility audit runs on the main screens (the rest follow in #98), four ways: default, the largest text, right to left, and doubled strings (`App/FeatherwickUITests/AccessibilityAuditTests.swift`). A new screen or sheet gets a test there. Known issue types are listed in `knownIssue` with the issue that fixes them; the pull request that fixes one removes its line. Any other issue fails.
- **Every pull request that touches UI says how it was tested with VoiceOver**: what you focused, what was read out, what you activated, and where focus went afterwards.
- The game does not support hardware keyboards, so Full Keyboard Access is not required.

## Screenshots

- Every pull request from this repository that touches UI or asset paths gets a **Screenshots** comment: before and after images of every shot that changed or is new, and a collapsed list of the ones that did not. Look at it before you approve. A visual change never fails the check, so nothing else will catch one.
- The shots cover the screens the accessibility audit covers. The rest follow in #98.
- Each screen is shot by day and by night, in English, right to left and with doubled strings.
- Each is shot on a small and a large iPhone.
- Each shot is named `<screen>--<state>--<locale>--<device>.png`.
- The Yard sheet is not shot with doubled strings, because it stalls (#97).
- A visual change never fails the check. A shot that cannot be taken does.
- The images are kept on the `screenshots` branch under `pr-<number>/before/` and `pr-<number>/after/`; each push adds a commit there, so the record stays after the pull request merges.
- When you add a screen or a state, add it to `App/FeatherwickUITests/ScreenshotTests.swift`.
- Pull requests from forks get no comment, because posting needs a write token.
- For a fork's pull request, the maintainer runs the shots locally: `xcodebuild test ... -only-testing:FeatherwickUITests/ScreenshotTests`, then `bin/screenshots-export`.

## Security

Report vulnerabilities privately as [SECURITY.md](SECURITY.md) says, never in a public issue. Follow the [code of conduct](CODE_OF_CONDUCT.md).
