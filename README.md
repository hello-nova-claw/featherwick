# Featherwick

Cozy chicken-keeping game: Stardew Valley daily life, Pokémon-style collecting, real chicken genetics.

This repo is the game logic first. The iOS front end (SpriteKit + SwiftUI) comes later and uses the same core.

## Layout

- `Sources/FeatherwickCore`: pure game logic. No printing, no input, no system clock, no global random.
- `Sources/FeatherwickText`: the words players read, shared by the CLI and the app.
- `Sources/FeatherwickCLI`: text front end (`featherwick`).
- `App`: iOS test app (SwiftUI, no art yet). Make the Xcode project with `cd App && xcodegen`.
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

Night order: fox (only if the coop is open) → foraging (if the door was left open and the flock came through) → new day → lost birds come home (needs a free perch) → growth and reveals → neighbour's gift hen (rooster starter only) → hatching (eggs due today; clear ones go back to the carton; the first hatch teaches candling) → brooder to coop (a bird that waited `homeWaitNights` for a perch is rehomed) → unnamed birds take a name (after `autoNameNights`) → broody hens wake → retirements → laying (only if fed) → stories (a fertile-eggs step teaches candling if needed) & trade offer → county show (on show days) → early game (features whose day has come; the show tip) → milestones → door opens.

## The early game (tutorial timeline)

`EarlyGame.swift`. A new keeper starts with one chick and learns one thing at a time. The game is
a tutorial told as a fixed timeline. Each morning on the timeline, the neighbour introduces one
`Feature`. A lesson locks nothing. Other features stay locked until their day: the command is
refused with `.notYet(feature)`, and the app hides the shop row or the Show tab.

| Day | Feature | What happens |
| --- | --- | --- |
| 0 | — | Choose one chick. Feed, cuddle, name. Nothing to buy. |
| 1 | `handling` (lesson) | "Pick her up every day. Chicks learn trust fastest." |
| 2 | `treats` | The neighbour gives `welcomeTreats` (3). Speckle & Down sells treats. |
| 4 | `premiumFeed` | Speckle & Down sells premium feed. |
| 6 | `coopDoor` (lesson) | The chick moves to the coop tomorrow: the door, the fox, foraging. |
| 7 | — | The sex shows (`growerAge`). A rooster starter gets the gift hen. |
| 8 | `breedBook` (lesson) | The neighbour names the starter's breed and colour: the Breed Book. |
| 10 | `birdShop` | Pullets, cockerels, fertile eggs, the daily special, story breeds. |
| 14 | `coopUpgrade` | More perches. |
| 18 | `laying` (lesson) | Your hen starts to lay soon: feed, collect, sell. |
| 21 | `shows` | The show opens, a week before the first show. The neighbour's show tip. |
| 28 | — | The first county show. |
| 29 | `incubatorShop` | The big incubator. (The neighbour's small one still comes with the first fertile egg.) |

- The days are in `Rules.featureDays`. The show opens `showNoticeDays` (7) before the first show.
- No birds, perches, incubators or shows before the sex shows (`EarlyGameTests` checks this).
- **The show tip** (`Engine.showTip`). When the show opens, the neighbour names one of your birds and
  one class, by name: "Oh hey, I notice that Basil is a beautiful buff Orpington! … I think you
  should enter her in the Orpington class." She suggests the breed class if the bird places 1st to
  3rd in at least `showTipBreedClassOdds` (40%) of `showTipTrials` practice fields. Otherwise she
  suggests the pet class for the bird with the best odds there. Ties go to the starter.
- The practice fields come from the bird's own ID, not the game RNG, so the tip changes nothing.
  Only visible traits are judged, and chicks are never named, so the tip leaks no hidden gene.
- The tip is kept in `GameState.showTip` until show day. The app shows it on the Show tab with an
  "Enter" button, and a notice at the farm gate.
- `Engine.newGame(earlyGame: false)` opens everything on day 0. Saves from before the early game
  have every feature open (`GameState.introduced` defaults to all).
- To add a step: a `Feature` case (in timeline order), its day in `featureDays`, the command it gates
  in `Engine.feature(for:)`, and its words in `introducedText` and `notYetText`.

## Hatching and candling

- You choose the exact eggs to hatch or sell. The incubator takes more eggs on the same day until it is full.
- Eggs hatch in the incubator after `incubatorHatchDays` nights (3). Under a broody hen, after `broodyHatchDays`.
- A new keeper cannot candle. A set egg is a guess. The app shows "?" on an egg you cannot judge yet.
- A clear egg never hatches. On hatch day it goes back to the carton, marked clear. If the carton is full, it
  goes to the nest boxes.
- Bought eggs are already candled, so they show as fertile.
- When `chicksToLearnCandling` chicks (1) have hatched, the neighbour teaches candling. Then you candle one egg
  at a time (`candleEgg`). The CLI can still candle the whole carton (`candle`).
- A story step that asks for eggs you know are fertile also teaches candling. If you cannot candle when
  the step starts (or on any night while it waits), the neighbour shows you at once. So the step never sticks.
- Every egg known to be fertile hatches (cozy rule).
- Saves from before this rule keep candling (`canCandle` is true when it is missing).

## Birds never wait forever

- A grown bird needs a perch. With no free perch, it waits in the brooder. If the brooder is full, it
  boards with the neighbour. Boarding birds stop you setting eggs.
- A bird waits at most `homeWaitNights` (3). Then the neighbour finds it a good home and pays you its
  rehome value. So a full coop never blocks the brooder or the incubator for long.
- The game tells you each night how many nights are left. Rehome a bird or upgrade the coop to keep it.
- The starter is never sent away.
- A new bird with no name for `autoNameNights` (2) takes its suggested name. You can rename it any time.

## Rehoming

`Rules.rehomeValue(of:onDay:ribbons:)`. A neighbour adopts a bird and pays for it. Front ends use
`GameState.rehomeValue(of:)`, which counts the bird's ribbons.

- Base by stage: chick 2, grower 4, adult 6.
- Rare looks add a fixed bonus: lavender, splash, blue, barring, silkie feathers on a non-Silkie,
  olive, blue or speckled eggs (laying hens only). A lap chicken adds `lapChickenRehomeBonus`.
- Quality adds more. Show type above average adds up to `rehomeTypeBonus` (16). Egg shape above average
  adds up to `rehomeEggShapeBonus` (6), for a laying hen only. Each 1st to 3rd place at a show adds
  `rehomeRibbonBonus` (6), for up to `rehomeMaxRibbons` (5) ribbons. Egg-class ribbons do not count.
- A purebred in a standard colour multiplies the quality bonus by `rehomeStandardPurebredFactor` (1.5).
- An average bird gets no quality bonus. A plain adult is worth 6. A fine purebred hen with ribbons is worth 40 or more.
- Only what the keeper can see counts. An unrevealed chick is worth its base price only.
- Ribbons are matched by the bird's name for now. (The show code will match them by bird ID later.)

## Speckle & Down (the shop)

- Basic stock is always there: a pullet, a cockerel, or a fertile egg. The breed is a random starter
  breed. You find out the breed when you buy it.
- Treats, premium feed and the big incubator are always there too.
- Breeds that a storyline unlocks are sold as pullets (`buyBreed`, `rareBreedPulletPrice`).
- **The daily special** (`Shop.swift`): one young bird. The seller names its breed, sex and colour.
  It changes each day. Its breed is any in-game breed. Its colour is one of the breed's usual colours.
  With `shopRareChance` (8%) it is a rare colour: splash, lavender, or a colour the breed does not
  usually come in. Its genes make that colour, so the bird looks as advertised.
- Price: `shopSpecialPulletPrice` (35) or `shopSpecialCockerelPrice` (20), plus `shopRarePremium` (15)
  for a rare colour. One special a day (`buySpecial`). It needs a free perch.
- The special comes from `GameState.shopSeed` and the day, not from the game RNG. Looking at the shop
  changes nothing. Old saves have seed 0, so they still get a special that changes each day.
- CLI: `shop`, `buy pullet|cockerel|egg`, `buy special`.

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

A recurring show (one every `showIntervalDays`, once a season) is where breeding, taming and egg
quality pay off. Before a show, you enter birds and plates of eggs. Each entry costs a small fee
(a coin sink).

- `enter <name>` enters a bird in its default class: its breed class, or the pet class.
- A purebred adult in a standard colour may enter its breed class OR the pet class
  (`Engine.eligibleClasses`, command `enterShowIn`). CLI: `enter <name> pet`.
- `enter eggs` enters your best matched plate. The app can choose the plate (`enterEggPlate`):
  3 carton eggs of one colour, all speckled or all plain.
- A bird can be entered once per show. If a bird no longer fits its chosen class on show day,
  it competes in its default class.

On show day (a `passNight` step), each entry is judged by the same `Judge` code against a field of
AI entries. The entries are placed by score. Places 1–3 win prizes. A first place goes in the
trophy case.

Each kind of class has its own difficulty and prizes (`Rules`):

| Kind | Rivals (`showCompetitorsByKind`) | Each rival is best of (`showRivalPicks`) | Prizes 1st/2nd/3rd |
| --- | --- | --- | --- |
| Pet (easy) | 3 | 1 | 8/4/2 coins + 3/2/1 treats |
| Eggs | 5 | 2 | 15/8/4 coins |
| Breed (hard) | 7 | 3 | 30/15/8 coins |

Each show has a theme from the season of its day (`ShowTheme`). The featured kind pays
`showFeaturedBonus` (×1.5, rounded) coins.

| Season | Show | Featured |
| --- | --- | --- |
| Spring | Spring Egg Fair | Eggs |
| Summer | Summer Fete | Pet |
| Autumn | Harvest Show | Breed (birds moult: condition is harder) |
| Winter | Winter Championship | Breed. Every rival picks `winterChampionshipExtraPicks` more candidates. |

`GameState.nextShowTheme` gives the theme of the next show. Each `ShowResult` keeps the bird, coins,
treats, the judge's notes and the theme. CLI: `enter <name>`, `enter <name> pet`, `enter eggs`, `shows`.

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
- A bird still unnamed after `autoNameNights` takes its suggestion (see "Birds never wait forever").
- The app shows "needs a name" under the place where the bird lives now: the potting shed or the coop.

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
  pullets at Speckle & Down. (Now and then an Australorp is also the shop's daily special.)
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
