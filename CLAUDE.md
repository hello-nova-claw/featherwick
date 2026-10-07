# CLAUDE.md

Featherwick: a cozy chicken-keeping game with real chicken genetics. Swift 6 package.
Game logic first; an iOS front end (SpriteKit + SwiftUI) comes later and uses the same core.

`README.md` is the full design doc (genes, breeds, shows, storylines, night order). Read the
section for the system you change. Keep it current: a change to behaviour updates its README section.

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
| `Sources/FeatherwickText` | The words players read (events, screens, milestones). Shared by CLI and app. |
| `Sources/FeatherwickCLI/main.swift` | Thin text front end. Parses input, prints text. No rules, no words. |
| `App/` | iOS test app (SwiftUI, no art yet). `project.yml` is the XcodeGen spec. |
| `Tests/FeatherwickCoreTests` | One suite per system. `Fixtures/save-v0.json` is a real old save. |

Key Core files:

- `Engine.swift`: `Engine.apply(command, to: &state, using: &rng) -> [GameEvent]`. `Command`,
  `GameEvent` and `GameError` are defined here. `passNight` runs the numbered night steps.
- `Rules.swift`: every tunable number. The game has one setting, `Rules.standard` (no difficulty levels).
- `GameState.swift`, `Genome.swift`, `Locus.swift`, `Alleles.swift`, `Phenotype.swift`: state and genetics.
- `BreedTable.swift`, `Breed.swift`: breeds and colour varieties (data tables).
- `SaveFormat.swift` (versions, migrations), `SaveStore.swift` (slots, atomic writes, backups).
- One file per feature: `EarlyGame`, `BreedingPen`, `Shows`, `ShowEvent`, `Friendliness`, `Pedigree`, `Names`, `Story`,
  `Milestone`, `Jobs` (daily jobs, season goals), `Daylight` (day slots, errands, the sleep gate), `Look`, `Simulation`, `HatchWhy` (hatch-day "why" note).
- What might hatch: `Visible` (what the keeper sees, no genes), `Knowledge` + `KnowledgeTables` (genes worked
  out by elimination), `Planner` + `PlannerTables` (the pen forecast, carrier notes). Never read genes there.

## iOS app

SwiftUI menus over the farm, built to the UI system in `docs/design/README.md` (tokens, type,
components, screens 1a–8a). The painted farm and bird art come later; dashed boxes stand in for them.

- `App/Featherwick/Design/`: tokens (`Theme.swift`: `Palette` day/night, `Typeface`, `Space`, `Radius`,
  `Stitch`), marks (eggs, feathers, dabs) and components (buttons, tabs, sheet page, notices).
  Use these; do not hard-code colours, fonts or sizes in screens.
- `Farm/FarmView.swift`: HUD, 4 swipe panels, a panel rail (dots, right side), and a bottom row: Books, Today,
  the panel's place, Rest a while / Sleep (after the daylight lesson), ≡. Panels left to right: Barn (Coop, which holds the brooder too), Yard (Yard), Far yard
  (Back fence), Shop (Farm gate). Barn and Shop are a flat colour until their painting exists. Each place opens
  a sheet (`Sheets/`). Notices under a place come from game state.
- `Scene/`: the 2.5D scene on the Yard and Far yard (`FarmScene`): depth from ground Y (`SceneDepth`), walk
  mask (`WalkMask`), seeded trees (`SceneTrees`), tufts, and the season-ramp shader (`SeasonRamp.swift/.metal`).
  Art in `Art/Scene/` and `Scene/SceneArtLayout.swift` come from `python3 scripts/make_scene_art.py`;
  run it after changing the script and commit its output. See "Farm scene (2.5D)" in `docs/design/README.md`.
- `Farm/FarmBirds.swift`: where each bird is drawn, blobs (`BirdSwatch`) on the Barn, and `PettableBird`
  (tap opens the bird card; press and rub sends `.pet`). In the yards the coop birds are rigged chickens
  inside the scene (`Scene/SceneChicken.swift`: `YardScene`, `SceneChicken`).
  `Feedback/`: `Haptics` and `Sound` (bundled `Sounds/*.caf`, silent if missing), with on/off switches in Settings. `GameStore.run` plays event feedback through `GameFeedback`.
- What might hatch (`Sheets/WhatMightHatchSection.swift`): the forecast in the breeding pen sheet, and carrier lines on the bird card.
- Morning report (`Sheets/MorningReportSheet.swift`): after Sleep, one page of the night, before the farm.
  Core's `MorningReport.from(events:state:)` sorts the night's events into groups; every event lands in one.
  A new `GameEvent` needs a group in `MorningReport.group(of:)`. Settings has a switch (on by default).
- Day or night follows game time, not the device clock, via `\.palette`. Morning and afternoon are day. Evening starts a 30-minute crossfade to night. Night lasts from Sleep until the morning report (or the farm) shows. Settings ▸ Time of day (`TimeOfDayPin`: Game, Day, Night) pins day or night for testing.
- Fonts (Libre Caslon Display/Text, Figtree; OFL) are bundled in `Fonts/` and registered at launch.
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
6. **Cozy design.** No death, no lethal genes, every egg hatches, the fox scares and never kills,
   milestones are reached and never failed, neglect never lowers tameness.
7. **Genetics stay real.** A bird's colour comes from its genes (`Phenotype`), never from a variety
   name. `GeneticsRealismTests` must pass.
8. **No hidden-gene leaks.** Player-visible text, names and milestones must not reveal a gene or
   sex the player cannot see yet.

## Adding content

Most new content is a table entry. See README "Data layer" and the feature sections.

- Breed: a `BreedDefinition` in `BreedTable.all` (status `.planned` until art is ready) + a static id on `Breed`.
- Colour: a `ColourVariety`, then list it on its breeds.
- Gene: an allele enum in `Alleles.swift` (conforms to `GeneLocus`), append to `Loci` in `Locus.swift`, add its look in `Phenotype.swift`.
  `Knowledge` and the planner's feather table (`ChickLookTable`) pick it up from `Loci.mendelian`. An egg gene goes in
  `ChickLookTable.eggGenes`. A new look also needs a `Trait` and its line in `Trait.showing`.
  Knowledge and the planner pick it up from `Loci`; check `KnowledgeTests`. Its carrier words go in
  `carrierText` (`PlannerTextTests` checks every allele).
- Storyline: a `Storyline` in `Storylines.all` + its words in `storyText`.
- Milestone: a `Milestone` in `Milestones.all` (order = ladder) + its words in `milestoneText`.
- Night step: add it to `passNight` in order and update the "Night order" line in README.
- Early-game step: a `Feature` case (timeline order), its day in `Rules.featureDays`, its gate in
  `Engine.feature(for:)`, and its words in `introducedText` and `notYetText`. Tests that are not about
  the timeline start with `Engine.newGame(earlyGame: false)` (see `startedGame`).

## Workflow

- Add or update tests in the matching suite for each change. Run `swift test` before a commit.
- CI (`.github/workflows/swift.yml`) runs on Linux (`swift:6.0-noble`) for every pull request:
  format check, build with warnings as errors, then tests. Code must build on Linux too: no
  Apple-only APIs in Core. Fix warnings; do not silence them.
- `.github/workflows/apple.yml` builds and tests on macOS and builds the core for iOS. It runs on
  `main` only (macOS minutes cost 10x); run it by hand before merging a change to platform code.
- Dependabot (`.github/dependabot.yml`) opens weekly PRs for new GitHub Action versions.
- After a `Rules` balance change, run `sim` and check `SimulationTests` still pass.
- Prefer the standard library: `count(where:)`, tuple compares for sort tie-breaks, Hashable
  structs (not joined strings) as dictionary keys. A ranked enum with String raw values conforms
  to `CaseOrdered` instead of writing its own `<`.
- Code style: short doc comments in plain English that say *why*. Match the file you are in.
- Docs (README, this file) use Simplified Technical English: short sentences, one idea each.
