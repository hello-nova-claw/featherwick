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

The CLI autosaves to a named slot (default `featherwick-save.json`) in the current folder, writing
atomically with rolling backups. Launch flags: `--slot <name>` picks a save, `--preset <relaxed|standard|challenge>`
sets the difficulty of a new game. Type `help` in the game for commands. `day 10` runs ten full days
(feed, collect, close, sleep) for fast tuning; `sim [days] [games]` prints a balance report.

## Engine

`Engine.apply(command, to: &state, using: &rng) -> [GameEvent]`. Command in, events out. All tunable numbers live in `Rules`.

Night order: fox (only if the coop is open) → foraging (if the door was left open and the flock came through) → new day → lost birds come home (needs a free perch) → growth and reveals → neighbour's gift hen (rooster starter only) → hatching (eggs due today) → brooder to coop → broody hens wake → retirements → laying (only if fed) → stories & trade offer → county show (on show days) → door opens.

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
  Now: Silkie, Orpington, Wyandotte, Araucana, Australorp (in game); Plymouth Rock (planned).
  Australorp is not a starter: it is unlocked at the shop by the "heritage breed" storyline.
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

## Shows (data layer)

`Shows.swift`. Three kinds of class, as at a real poultry show:

| Class | Who enters | Points |
| --- | --- | --- |
| Breed | Purebred adults | type 50 · colour 30 · condition 20 |
| Pet chicken | Any grower or adult, crosses too | condition 50 · friendliness 50 |
| Eggs | A matched plate of 3 | match 30 · shape 30 · shell 20 · freshness 20 |

- Standard colours come from the breed table: a colour is standard if one of the breed's varieties
  makes it. A splash Orpington is not standard; a buff Wyandotte is shown as gold laced.
- Show type and egg shape are quantitative traits (`QuantitativeTrait.swift`): many small genes,
  half from each parent, score capped. Selective breeding works; nothing can exceed the maximum.
  Birds from outside the flock get random quality genes from their own ID.
- Condition and shell quality come from care: moult (autumn), frights, broodiness, hunger, heat, age.
- Grades are absolute (fair → excellent). `judge <name>` / `judge eggs` are practice: judging with no competitors.

Saves: missing GameState fields and rules load with their starting values (`fillNewSettings`).

### The county show (`ShowEvent.swift`)

A recurring show (one every `showIntervalDays`, ~once a season) is where breeding, taming and egg
quality finally pay off. Before a show you `enter <name>` (a bird routes to its breed class, or the
pet class) or `enter eggs` (your best matched plate), paying a small entry fee — a coin sink. On the
show day (a `passNight` step) each entry is judged by the same `Judge` code against `showCompetitors`
AI entries generated from random IDs (so quality varies), placed 1st/2nd/3rd by score; ribbons pay
coins and a first place is kept in the trophy case. CLI: `enter <name>`, `enter eggs`, `shows`.

## Friendliness

`Friendliness.swift`. Score 0...1 = 40% calm genes (8-gene quantitative trait, stronger in calm
breeds) + 60% learned tameness. Bands: wild, skittish, friendly, lap chicken.

- `pet <name>` and `treat <name>`: once a day per bird each. Gains shrink as a bird gets tamer
  and never pass 1. Chicks learn 3x faster, growers 1.5x. Chicks with a mother hen learn at half speed.
- Start: brooder chick 0.2, chick raised by a hen 0.05, bought bird 0.25.
- A fox fright and days lost lower tameness. Neglect never does.
- Effects: half of the pet show class; lap chickens rehome for more.

## Flock turnover and feed

Hens slow and retire with age, so breeding keeps mattering (`Rules.layAgeFactor`, `Bird.isRetired`).

- A hen lays at full rate until `layDeclineStartDays`, then gradually less, down to `layDeclineFloor`.
- At `retirementAgeDays` (three in-game years) she becomes a beloved non-layer — never death (cozy).
  Retired hens keep their perch, can still be petted, shown in the pet class, and rehomed.
- **Premium feed** is an optional coin sink (basic feed stays free). A bag is several day-portions;
  `feed premium` feeds the flock for the day and lifts that day's laying. CLI: `buy feed`, `feed premium`.

## Foraging

Leaving the coop door open is a real risk/reward, not just a fox gamble. If the flock comes through
the night, the free-ranging birds forage: they return fed (no feeding needed that day) and a little
better off — a small lay bonus (`forageLayBonus`) and show-condition bonus (`forageConditionBonus`).
So each night you choose: close up safe but feed tomorrow, or leave open to forage and risk the fox.

## Saves, difficulty and balance

- **Saves** (`SaveStore.swift`): named slots, atomic writes, and rolling backups (`…bak1/bak2.json`),
  so a bad write can't lose a game. An unreadable save is quarantined, not overwritten. `SaveFormat`
  still versions and migrates the state itself.
- **Difficulty** (`Rules.preset(named:)`): `relaxed`, `standard`, `challenge`. Presets only seed a new
  game; loading an existing save is unaffected (new rules fields fall back to their defaults).
- **Balance sim** (`Simulation.swift`): plays many seeded games with a simple keeper policy and reports
  coins, flock size, Breed Book growth and eggs/day, so the first-guess `Rules` numbers can be tuned
  from data. CLI: `sim [days] [games]`; `SimulationTests` guards against balance regressions.

## Look (render spec from a shared parts kit)

`Look.swift`. A bird is drawn from shared greyscale parts with flat mask layers. Breeds share
parts, so most new breeds need no new art. `bird.look(onDay:rules:)` returns:

- `parts`, back to front: tail, legs, body, head, comb (or one chick part). Each part has a colour
  token per mask and its own scale: combs and tails grow in with age, and a hen's comb is the
  rooster's drawing, smaller. Pullets and cockerels are the adult parts, smaller.
- `overlays`: pattern textures clipped to masks (lacing, barring, a barred chick's head spot).
- `scale`: breed size, grows smoothly with age; roosters end 20% bigger.

| Part | Shapes | Who uses them |
| --- | --- | --- |
| Body (hen + rooster) | heavy, medium, light, fluffy | Orpington/Australorp, Wyandotte/Plymouth Rock/crosses, Araucana, Silkie |
| Comb | single, rose, pea, walnut | most, Wyandotte, Araucana, Silkie |
| Legs | clean, feathered 5-toe | everyone but Silkie |
| Head | plain, crested | everyone but Silkie |
| Tail | hen, rooster, fluffy | |
| Chick | plain, fluffy | |

The kit is 21 parts and covers all 6 breeds in the table. Silkie feathering (a real gene) picks
the fluffy body, tail and chick, for crosses too. Tokens are not RGB: the art direction maps them.
Watercolour tip: paint each body whole, then cut it into parts with soft, overlapping edges.
CLI: `draw <name>`, `art`.

## Family tree and inbreeding

`Pedigree.swift`. Every bird keeps its mother's and father's IDs. Owned birds (rehomed ones
too) stay in the state; outside parents, such as those of a bought egg, are kept as
`PedigreeRecord`s, so no tree breaks.

- `Pedigree.tree(of:generations:)`, `offspring(of:)`, `kinship(a, b)`, `inbreeding(of:)`.
- Inbreeding is Wright's coefficient, as real breeders use: brother × sister = 0.25, half
  siblings 0.125, cousins 0.0625. Brother-sister lines climb 0.25, 0.375, 0.5, 0.59.
- Stored on each chick at hatch. Effects are light and never block a hatch: lay chance drops by
  the coefficient (capped at 50%); show condition drops (capped at 0.3) with "lacks vigour".
- CLI: `tree <name>`, `kin <name> <name>`.

## Names

`Names.swift`. Birds you hatch or buy arrive with `needsName`; the UI asks for a name at once,
with a suggestion (Enter takes it). Birds given by people (gift hen, trade hen, story gifts)
arrive already named by their keeper. Any bird you own can be renamed any time, even while lost.

- Names are unique in the flock, ignoring case and spaces; up to 24 letters.
- Suggestions come from the bird's own ID (no game randomness used) and skip taken names.
  A chick whose sex is still hidden gets a neutral suggestion, so the name never gives it away.

## Storylines

`Story.swift`. Small puzzles told through Featherwick's people, which lead to gifts and unlocks.
A storyline has a trigger, steps with goals, and rewards. Night goals (hatch chicks, wait days)
are checked in `passNight`; delivery goals need the player (`deliver`). Rewards are given once;
a gift bird waits for a free perch, so the coop never overfills. The engine holds IDs only; the
words live in the UI.

- **The broody Silkie** (first hatch): a neighbour's Silkie is sitting on a golf ball. Bring 3
  eggs you know are fertile (candled). 4 days later she thanks you with a Silkie pullet, and
  Speckle & Down starts selling Silkie pullets. Always solvable: the shop sells candled fertile eggs.
- **A laced gift** (after the broody Silkie): a neighbour admires your flock and gifts you a
  Wyandotte hen, so lacing enters your lines.
- **A heritage breed** (deliver 4 fertile eggs): earns an Australorp hen and unlocks Australorp
  pullets at Speckle & Down — the breed's only way into play.
- CLI: `story`, `give eggs`, `buy silkie` / `buy australorp` (once unlocked).

To add one: one `Storyline` in `Storylines.all`, plus its words in the UI.

## Goal ladder

`Milestone.swift`. Small, always-visible goals that give the no-loss sandbox a direction: first
egg, first hatch, a blue/olive/speckled egg, a growing flock, a show ribbon, a lap chicken, a
finished storyline, a hen into retirement. Cozy rule: a milestone is only ever *reached*, never
failed — no deadlines, nothing lost by missing one.

- Each `Milestone` is an id plus a test read from existing, player-visible state (so none can leak
  a hidden gene). Checked each night, after the day settles (`advanceMilestones`, a `passNight` step).
- Awarded once and recorded in `GameState.milestonesReached`; the engine emits `.milestoneReached(id)`
  and the words live in the UI. Loading an older save simply back-fills what you've already done.
- CLI: `journal` (the ladder, ✓ reached / ○ with a hint for what to aim for next).

To add one: append a `Milestone` to `Milestones.all` (list order is the ladder), plus its words in the UI.

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
