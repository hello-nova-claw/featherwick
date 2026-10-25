# CLAUDE.md

Featherwick: a cozy chicken-keeping game with real chicken genetics. Swift 6 package.
Game logic first. The iOS app (`App/`, SwiftUI) uses the same core. Its art comes later.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before any change. It holds the process, commit style, code, test,
localisation and accessibility rules, and this file does not repeat them.

`docs/design.md` is the design record. Section 2 holds the design principles: they are not negotiable.
Section 4 records rejected options. The rest is the design of each system (genes, breeds, shows,
storylines, night order). `docs/design/README.md` is a different file: the UI system spec (tokens,
screens, the farm scene, painted parts, the frame budget). Each path below names the one it means. Read the section for the system you change. Keep it current: a change to
behaviour updates its section.

**The repository is public.** Nothing secret or personal goes into an issue, a pull request, a commit
message, a comment or a file: no keys, no team IDs, no email addresses, no private links, no personal notes.

## Commands

```sh
swift build
swift test                          # Swift Testing (`import Testing`), not XCTest
swift test --filter ShowTests       # one suite
swift run featherwick 2026          # play; the seed is used only for a new save
swift format --in-place --recursive Package.swift Sources Tests App   # format (CI fails on unformatted code)
```

In the game: `day 10` runs ten full days; `sim [days] [games]` prints a balance report.
The CLI writes `featherwick-save*.json` in the current folder (git-ignored). Do not commit saves.

## Layout

| Path | What |
| --- | --- |
| `Sources/FeatherwickCore` | Pure game logic. All rules live here. |
| `Sources/FeatherwickText` | The words players read (events, screens, milestones). Shared by CLI and app. `People.swift`: Hazel (neighbour), Wren (shop), the day-1 welcome and tour. `VillageText.swift`: every person's name and about line, choices, loans, debts, the post, the calendar. `VillagePeopleText.swift`: the arcs of Dot, Teddy, Mr Okafor and Bea. `MarketText.swift`: the market board. `Text.swift`: `eventText`, `storyText`, `milestoneText`, `introducedText`, `notYetText`. Also `NotesText`, `CalendarText`, `PlannerText`, `InheritanceText`, `RecordsText`, `BreedLore`. |
| `Sources/FeatherwickCLI/main.swift` | Thin text front end. Parses input, prints text. No rules, no words. |
| `App/` | iOS test app (SwiftUI, no art yet). `project.yml` is the XcodeGen spec. |
| `Tests/FeatherwickCoreTests` | One suite per system. `Fixtures/save-v0.json` is a real old save. |
| `Tests/FeatherwickTextTests` | Tests for the words (e.g. `PlannerTextTests`, `NotesTests`). |

Key Core files:

- `Engine.swift`: `Engine.apply(command, to: &state, using: &rng) -> [GameEvent]`. `Command`,
  `GameEvent` and `Rejection` (a refused command, sent as `.rejected`) are defined here. `passNight` runs the numbered night steps.
- `Rules.swift`: every tunable number. The game has one setting, `Rules.standard` (no difficulty levels).
- `GameState.swift`, `Genome.swift`, `Locus.swift`, `Alleles.swift`, `Phenotype.swift`: state and genetics.
- `BreedTable.swift`, `Breed.swift`: breeds and colour varieties (data tables).
- `SaveFormat.swift` (versions, migrations), `SaveStore.swift` (slots, atomic writes, backups).
- One file per feature: `EarlyGame`, `BreedingPen`, `Shows`, `ShowEvent`, `Friendliness`, `SexGuess` ("hen or roo?"), `Pedigree`, `Names`, `Quirks`, `Story`
  (people, choices), `Loans` (loaned birds, debts), `BorrowedHen` (Marigold, days 2 to 10), `Post` (notes), `VillageDay` (the calendar), `HatchAlong` (the spring egg swap),
  `Milestone`, `Jobs` (daily jobs, season goals), `MorningReport` (the night's events in groups), `Shop` (the daily special), `Records` (the flock record book), `Daylight` (day slots, errands, the sleep gate), `MarketBoard` (wanted cards, the keeper's card, buyers), `Look`, `Simulation`, `HatchWhy` (hatch-day "why" note).
- Helpers: `Breeding` (a chick genome from two parents), `QuantitativeTrait` (many-gene traits), `SeededRNG`,
  `Identity` (seeded IDs), `CaseOrdered`.
- What might hatch: `Visible` (what the keeper sees, no genes), `Knowledge` + `KnowledgeTables` (genes worked
  out by elimination), `Planner` + `PlannerTables` (the pen forecast, carrier notes), `Inheritance`
  (`InheritancePage`, the Books page: rules learned by setting eggs from a penned pair). Never read genes there.

## iOS app

SwiftUI menus over the farm, built to the UI system in `docs/design/README.md` (tokens, type,
components, screens 1a–9a). The painted farm and bird art come later; dashed boxes stand in for them.

- `App/Featherwick/Design/`: tokens (`Theme.swift`: `Palette` day/night, `Typeface`, `Space`, `Radius`,
  `Stitch`), marks (eggs, feathers, dabs) and components (buttons, tabs, sheet page, notices).
  Use these; do not hard-code colours, fonts or sizes in screens.
- `Farm/FarmView.swift`: HUD, 4 swipe panels, a panel rail (dots, right side), and a bottom row: Books (after the Breed Book lesson), Today,
  the panel's place, Rest a while / Sleep (after the daylight lesson), ≡. Panels left to right: Barn (Coop, which holds the brooder too), Yard (Yard), Far yard
  (Back fence), Shop (Farm gate). Barn and Shop are a flat colour until their painting exists. Each place opens
  a sheet (`Sheets/`). Notices under a place come from game state.
- `Scene/`: the 2.5D scene on the Yard and Far yard (`FarmScene`): depth from ground Y (`SceneDepth`), walk
  mask (`WalkMask`), seeded trees (`SceneTrees`), tufts, and the season-ramp shader (`SeasonRamp.swift/.metal`).
  Art in `Art/Scene/` and `Scene/SceneArtLayout.swift` come from `python3 scripts/make_scene_art.py`;
  run it after changing the script and commit its output. See "Farm scene (2.5D)" in `docs/design/README.md`.
- `Farm/FarmBirds.swift`: where each bird is drawn, blobs (`BirdSwatch`) on the Barn, and `PettableBird`
  (tap opens the bird card; press and rub sends `.pet`). In the yards the coop birds are rigged chickens
  inside the scene (`Scene/SceneChicken.swift`: `YardScene`, `SceneChicken`). Every chicken moves on one
  skeleton (`Scene/ChickenSkeleton.swift`: bones, inverse-kinematics legs, the walk, peck and sit motions, fluff follow;
  pure maths, tested on Linux too). The placeholder chicken (`ChickenRig`) and each painted kit ride its
  bones through `BoneEffect`; test tools have a rig lab. A body shape with a painted kit
  (`Art/Parts/<build>/kit.json` + PNGs, read by `Scene/PartKit.swift`; `kit.json` and its skeleton are
  `Scene/KitSpec.swift`, pure) is drawn by `PaintedChickenRig`. No kit ships now; source art that is not a
  kit lives in `art-source/` (outside the bundle). `art-source/kit-template/` is the page to paint a kit
  over, from `python3 scripts/make_kit_template.py`.
  `ChickenView` picks the rig. Kit format: "Painted parts" in `docs/design/README.md`.
  A tap on yard ground makes a ripple. The birds react by friendliness band (`Scene/RippleReaction.swift`). It is view only: no command, no save. Scene presentation numbers go in `Scene/SceneConstants.swift`, not `Rules`. App unit tests are in `App/FeatherwickTests/` (Swift Testing, the `FeatherwickTests` target).
  `Feedback/`: `Haptics` and `Sound` (bundled `Sounds/*.caf`, silent if missing), with on/off switches in Settings. `GameStore.run` plays event feedback through `GameFeedback`.
- Market board (`Sheets/MarketBoardSheet.swift`): opened from the farm gate sheet. Wanted cards, the keeper's own card, the buyer.
- What might hatch (`Sheets/WhatMightHatchSection.swift`): the forecast in the breeding pen sheet, and carrier lines on the bird card.
- Books ▸ People (`Sheets/PeopleBook.swift`): each person met, their arcs, and their choices and deliveries. The back fence offers the same choices and deliveries.
- Day 1 (`RootView.swift`, `Sheets/TourSheet.swift`): Hazel asks the keeper's name (`.nameKeeper`), offers a chick, then
  walks the keeper round the four places. The game starts on day 1.
- Morning report (`Sheets/MorningReportSheet.swift`): after Sleep, one page of the night, before the farm.
  Core's `MorningReport.from(events:state:)` sorts the night's events into groups; every event lands in one.
  A new `GameEvent` needs a group in `MorningReport.group(of:)`. Settings has a switch (on by default).
- Day or night follows game time, not the device clock, via `\.palette`. Morning and afternoon are day. Evening starts a 30-minute crossfade to night. Night lasts from Sleep until the morning report (or the farm) shows. Settings ▸ Time of day (`TimeOfDayPin`: Game, Day, Night) pins day or night for testing.
- Fonts (Libre Caslon Display/Text, Figtree; OFL) are bundled in `Fonts/` and registered at launch.
- UI tests (`App/FeatherwickUITests/`, XCTest) launch the app with `-uiTestState fresh|farm` (and
  `-uiTestSeed`), which `UITestLaunch` turns into a known game on an empty save folder, Debug builds only.
  `AccessibilityAuditTests` audits every screen four ways. Find buttons by label prefix, not exact label:
  doubled strings read "Settings Settings". Move between panels with the rail dots, not swipes: swipes
  reverse right to left. The four variants take about 4 minutes; two simulator runs at once make it 30.
- ≡ → "Open test tools" shows the old plain screens (`TestTools/`), with every action and the full log.
- `Beta/`: TestFlight questions after the first hatch and the first show (once per save slot). Compiled only with the `BETA` flag (Beta config, "Featherwick Beta" scheme) or `DEBUG`, and shown only on a sandbox receipt. Answers go to `beta-notes.json` (not the save); Settings ▸ Share beta notes.

```sh
brew install xcodegen      # once
cd App && xcodegen         # makes Featherwick.xcodeproj (git-ignored); run again after changing project.yml
open Featherwick.xcodeproj
```

- `GameStore` holds the game, runs every `Command`, logs the words, and saves after each command
  (Application Support, same `SaveStore` as the CLI).
- Views only send commands and show state. No game rules in the app.
- To run on a device: copy `App/Config/Local.xcconfig.example` to `Local.xcconfig` and set your team ID.
- CI builds the app in `apple.yml` (on `main`, or run it by hand).

## Core rules (do not break)

1. **Core is pure.** No `print`, no input, no `Date()`/system clock, no `Int.random()` without
   `using:`. All randomness comes from the `SeededRNG` passed in. Same seed = same game.
2. **Command in, events out.** The engine returns IDs and enums only. Words for the player live in
   `FeatherwickText`. A new event or error needs its words in `eventText` (`Text.swift`).
3. **Tunable numbers go in `Rules`**, never as literals in logic.
4. **Append, never insert,** to `Loci`, `BreedTable.all`, `Storylines.all` and `Milestones.all`.
   Seeded breeding draws in list order; an insert changes every existing seed.
5. **Saves must always load.** `Fixtures/save-v0.json` must load in tests.
   - A new `GameState` or `Rules` field needs a starting value in `SaveFormat.fillNewSettings`.
   - A new gene needs no migration: missing genes are the default allele.
   - A change to the shape of existing data needs a new step in `SaveFormat.migrations`.
6. **Cozy design.** No death, no lethal genes, every fertile egg hatches, the fox scares and never kills,
   milestones are reached and never failed, neglect never lowers tameness.
7. **Genetics stay real.** A bird's colour comes from its genes (`Phenotype`), never from a variety
   name. `GeneticsRealismTests` must pass.
8. **No hidden-gene leaks.** Player-visible text, names and milestones must not reveal a gene or
   sex the player cannot see yet.

## Adding content

Most new content is a table entry. See "Data layer" and the feature sections in `docs/design.md`.

- Breed: a `BreedDefinition` in `BreedTable.all` (status `.planned` until art is ready) + a static id on `Breed`.
- Colour: a `ColourVariety`, then list it on its breeds.
- Gene: an allele enum in `Alleles.swift` (conforms to `GeneLocus`), append to `Loci` in `Locus.swift`, add its look in `Phenotype.swift`.
  `Knowledge` and the planner's feather table (`ChickLookTable`) pick it up from `Loci.mendelian`. An egg gene goes in
  `ChickLookTable.eggGenes`. A new look also needs a `Trait` and its line in `Trait.showing`.
  Knowledge and the planner pick it up from `Loci`; check `KnowledgeTests`. Its carrier words go in
  `carrierText` (`PlannerTextTests` checks every allele).
- Storyline: a `Storyline` in `Storylines.all` (with its `person`) + its words in `storyText`, and each
  choice option's words in `choiceText` (`VillageText.swift`).
- Note: a `Note` at the end of `Notes.added`, the last list in `Notes.pool` (with its `NoteCondition`) + its words in `poolNoteText` (`NotesText.swift`).
- Milestone: a `Milestone` in `Milestones.all` (order = ladder) + its words in `milestoneText`.
- Night step: add it to `passNight` in order and update the "Night order" line in `docs/design.md`.
- Early-game step: a `Feature` case (timeline order), its day in `Rules.featureDays`, its gate in
  `Engine.feature(for:)`, and its words in `introducedText` and `notYetText`. Tests that are not about
  the timeline start with `Engine.newGame(earlyGame: false)` (see `startedGame`).

## Workflow

- Add or update tests in the matching suite for each change. Run `swift test` before a commit.
- CI (`.github/workflows/swift.yml`) runs on Linux (`swift:6.0-noble`) for every pull request
  and push to `main`: build with warnings as errors, tests, then the format check. Code must build on Linux too: no
  Apple-only APIs in Core. Fix warnings; do not silence them.
- `.github/workflows/apple.yml` builds and tests on macOS, builds the core for iOS, and builds the iOS app and its tests. It runs on
  `main` only (macOS minutes cost 10x); run it by hand before merging a change to platform code.
- Dependabot (`.github/dependabot.yml`) opens weekly PRs for new GitHub Action versions.
- After a `Rules` balance change, run `sim` and check `SimulationTests` still pass.
- Prefer the standard library: `count(where:)`, tuple compares for sort tie-breaks, Hashable
  structs (not joined strings) as dictionary keys. A ranked enum with String raw values conforms
  to `CaseOrdered` instead of writing its own `<`.
- Code style: short doc comments in plain English that say *why*. Match the file you are in.
- Docs (`docs/design.md`, CONTRIBUTING, this file) use Simplified Technical English: short sentences, one idea each.

## How it fits together

- **The loop.** A front end sends a `Command`. `Engine.apply` changes `GameState` and returns `GameEvent`s.
  The front end turns events into words with `FeatherwickText`. The keeper's day is a few slots of care
  and errands; `.passNight` runs the night steps in order and starts the next day.
- **The app.** `GameStore` owns the state and the `SeededRNG`. `GameStore.run` applies a command, logs
  the words, plays feedback, builds the morning report after `.passNight`, and saves. Views read
  `GameStore` and send commands; nothing else changes state.
- **Saves.** `SaveStore` writes a slot atomically with rolling backups and quarantines an unreadable
  file. `SaveFormat` versions and migrates. The CLI saves in the current folder; the app in
  Application Support.
- **Scenes.** `FarmView` holds four panels. The Yard and Far yard draw `FarmScene` (depth from ground Y,
  the walk mask, the season shader) with `YardScene` birds on `ChickenSkeleton`. Scene numbers live in
  `Scene/SceneConstants.swift`; game numbers live in `Rules`.

## Running checks locally

```sh
swift build --build-tests -Xswiftc -warnings-as-errors
swift test                                   # about 7 minutes; the simulation tests are slow
swift test --filter VillageDayTests          # one suite
swift test --filter "ShowTests/standardsListTheBreedsOwnColours"  # one test
swift format lint --strict --recursive Package.swift Sources Tests App
cd App && xcodegen && xcodebuild test -project Featherwick.xcodeproj -scheme Featherwick \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO \
  -only-testing:FeatherwickTests/PartKitTests
```

## Traps

- **Newer Swift finds new warnings.** CI builds with Swift 6.0. Xcode's newer Swift (6.4 on 25 October
  2026) flags `#require` calls in `VillageDayTests` and others as redundant, so a local
  `-warnings-as-errors` build fails where CI passes. Fix such warnings in their own pull request; do
  not change the CI toolchain to hide them.
- **Worktrees.** Worktrees live under `.claude/worktrees/`, and `.claude/` is git-ignored. No lint or
  format config may exclude `.claude/`: every check is given explicit paths (`Sources Tests App`),
  so it reads the worktree's own files. Run checks from inside the worktree, not the main checkout.
- **A worktree has its own `.build/`.** The first build in a new worktree takes several minutes.
- **The Xcode project is generated.** Run `xcodegen` again after any change to `App/project.yml` or a
  new folder under `App/`.

## Pull requests

- Every PR needs an issue with all five template fields, a branch named `<issue>-<slug>`, and a changelog
  fragment `changelog/<issue>-<slug>.txt`, or the `no-changelog` label for docs and tooling only.
- Commits use the repo-local Novaclaw git identity, in WordPress core style (see CONTRIBUTING.md).
- CodeRabbit's approval is the required review. It allows about 10 reviews an hour per repository, so
  batch fixes into one push. When it says "Review paused", comment `@coderabbitai resume`, then
  `@coderabbitai review`.
- Auto-merge (`gh pr merge <n> --auto --merge`) can land a PR while you are still fixing it. Run
  `gh pr view <n> --json state` and confirm it is `OPEN` before every push to its branch.
- Merge `main` into a branch only when it conflicts (GitHub says DIRTY). Being behind is not a reason:
  every push dismisses the approval and restarts CI. Don't rebase.
- Each push queues every CI job. GitHub Free runs 20 jobs at once, only 5 of them on macOS. Keep the
  number of open PRs to what the macOS slots can carry.
- When several sessions work at once, give each a lane: an ordered list of issues in one area, one PR
  at a time, so they never edit the same files.
- Only `main` is protected. Never enable auto-merge on a PR whose base is another feature branch: it
  merges into that base at once.
- Never enable auto-merge on a PR from outside. Outside PRs wait for the maintainer.
