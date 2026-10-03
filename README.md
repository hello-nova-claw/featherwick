# Featherwick

Cozy chicken-keeping game: Stardew Valley daily life, Pokémon-style collecting, real chicken genetics.

This repo is the game logic first. The iOS front end (SpriteKit + SwiftUI) comes later and uses the same core.

## Layout

- `Sources/FeatherwickCore`: pure game logic. No printing, no input, no system clock, no global random.
- `Sources/FeatherwickCLI`: text front end (`featherwick`).
- `Tests/FeatherwickCoreTests`: Swift Testing tests for the genetics rules.

## Commands

```sh
swift build
swift test
swift run featherwick 2026   # play; seed 2026 is used only for a new save
```

The CLI autosaves to `featherwick-save.json` in the current folder. Type `help` in the game for commands. `day 10` runs ten full days (feed, collect, close, sleep) for fast tuning.

## Engine

`Engine.apply(command, to: &state, using: &rng) -> [GameEvent]`. Command in, events out. All tunable numbers live in `Rules`.

Night order: fox (only if the coop is open) → new day → lost birds come home (needs a free perch) → growth and reveals → neighbour's gift hen (rooster starter only) → brooder to coop → laying (only if fed) → door opens.

## Genome (current genes)

| Locus | Alleles | Inheritance | Notes |
| --- | --- | --- | --- |
| Feathering | H / h | Recessive | Silkie feathering |
| Base colour | E / e | Dominant black | Simplified (real buff is several loci) |
| Blue | Bl / bl+ | Incomplete dominance | black, blue, splash |
| Lavender | lav+ / lav | Recessive | |
| Lacing | lc+ / lc | Recessive | Simplified stand-in for Pg + Co + Ml |
| Barring | B / b+ | Sex-linked (Z), dominant | Hens ZW, roosters ZZ |
| Blue shell | O / o+ | Dominant | |
| Brown coating | Br / br | Dominant | Simplified (real brown is polygenic). Blue + brown = olive |
| Speckle | sp+ / sp | Recessive | Game-only gene |

## Data layer: genes, breeds, colours, saves

Three tables. Most new content is a table entry, not new logic.

| Table | File | One entry is |
| --- | --- | --- |
| Gene registry `Loci` | `Locus.swift` | one gene: allele enum + default allele |
| Breed table `BreedTable` | `BreedTable.swift` | one breed: signature genes, colour varieties, broodiness, status |
| Colour varieties `ColourVariety` | `BreedTable.swift` | one named colour: a recipe of genes |

- Genomes store only genes that differ from the default allele. A gene missing from a save is the
  default, so a new gene needs no save migration.
- Breeds have a status: `inGame` or `planned`. Planned breeds are tested but never appear in play.
  Now: Silkie, Orpington, Wyandotte, Araucana (in game); Australorp, Plymouth Rock (planned).
- The colour a bird shows always comes from its genes (`Phenotype`), never from a variety name.

How to add:

1. **A breed** whose genes exist: one `BreedDefinition` in `BreedTable.all` (status `.planned`),
   plus a static id on `Breed`. Set `.inGame` when its art is ready.
2. **A colour variety**: one `ColourVariety`, then list it on the breeds that come in it.
3. **A gene**: an allele enum conforming to `GeneLocus`, appended to `Loci`, plus its look in
   `Phenotype.swift`.

Append new breeds and genes at the END of their lists: seeded breeding draws in list order.

Saves are `{ version, state, rng }` (`SaveFormat`). A migration is needed only when existing data
changes shape. `Tests/.../Fixtures/save-v0.json` is a real old save; it must always load.

## Realism rules (tested)

- Lacing shows only on a gold (buff) ground ("gold laced"); barring shows only on black-based birds.
  Hidden pattern genes are still passed on.
- A chick is purebred only if both parents are purebred and the same breed. Crosses are named
  like real keepers name them: olive egger (blue egg x brown egg), easter egger (other blue-egg
  crosses), barnyard mix (everything else).
- `GeneticsRealismTests` breeds tens of thousands of birds over 6 generations and fails on any
  bird a real keeper couldn't breed.

## Design rules

- Real genetics, but no lethal genes. Every egg hatches.
- Seeded random only, so every hatch can be replayed and tested.
- V1 placeholder: a chick takes its mother's breed.
