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
```

In the game: `day 10` runs ten full days; `sim [days] [games]` prints a balance report.
The CLI writes `featherwick-save*.json` in the current folder (git-ignored). Do not commit saves.

## Layout

| Path | What |
| --- | --- |
| `Sources/FeatherwickCore` | Pure game logic. All rules live here. |
| `Sources/FeatherwickCLI/main.swift` | Thin text front end. Parses input, prints events. No rules. |
| `Tests/FeatherwickCoreTests` | One suite per system. `Fixtures/save-v0.json` is a real old save. |

Key Core files:

- `Engine.swift`: `Engine.apply(command, to: &state, using: &rng) -> [GameEvent]`. `Command`,
  `GameEvent` and `GameError` are defined here. `passNight` runs the numbered night steps.
- `Rules.swift`: every tunable number, plus difficulty presets (`relaxed`, `standard`, `challenge`).
- `GameState.swift`, `Genome.swift`, `Locus.swift`, `Alleles.swift`, `Phenotype.swift`: state and genetics.
- `BreedTable.swift`, `Breed.swift`: breeds and colour varieties (data tables).
- `SaveFormat.swift` (versions, migrations), `SaveStore.swift` (slots, atomic writes, backups).
- One file per feature: `Shows`, `ShowEvent`, `Friendliness`, `Pedigree`, `Names`, `Story`,
  `Milestone`, `Look`, `Simulation`.

## Core rules (do not break)

1. **Core is pure.** No `print`, no input, no `Date()`/system clock, no `Int.random()` without
   `using:`. All randomness comes from the `SeededRNG` passed in. Same seed = same game.
2. **Command in, events out.** The engine returns IDs and enums only. Words for the player live in
   the UI (CLI now). A new event or error needs CLI text in `main.swift`.
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
- Storyline: a `Storyline` in `Storylines.all` + CLI words.
- Milestone: a `Milestone` in `Milestones.all` (order = ladder) + CLI words.
- Night step: add it to `passNight` in order and update the "Night order" line in README.

## Workflow

- Add or update tests in the matching suite for each change. Run `swift test` before a commit.
- After a `Rules` balance change, run `sim` and check `SimulationTests` still pass.
- Code style: short doc comments in plain English that say *why*. Match the file you are in.
- Docs (README, this file) use Simplified Technical English: short sentences, one idea each.
