# Featherwick

Cozy chicken-keeping game: Stardew Valley daily life, Pokémon-style collecting, real chicken genetics.

This repo is the game logic first. The iOS front end (SpriteKit + SwiftUI) comes later and uses the same core.

## Layout

- `Sources/FeatherwickCore`: pure game logic. No printing, no input, no system clock, no global random.
- `Sources/FeatherwickText`: the words players read, shared by the CLI and the app.
- `Sources/FeatherwickCLI`: text front end (`featherwick`).
- `App`: iOS test app (SwiftUI, no art yet). Make the Xcode project with `cd App && xcodegen`.
  TestFlight builds (the "Featherwick Beta" scheme, `BETA` flag) ask two short beta questions, after the first hatch and after the first show. They are not in App Store builds: the flag leaves the code out, and a receipt check keeps it off outside TestFlight. Answers stay on the device until the tester shares them from Settings.
- `Tests/FeatherwickCoreTests`: Swift Testing tests for the game rules, one suite per system.
- `Tests/FeatherwickTextTests`: Swift Testing tests for the words.

## Commands

```sh
swift build
swift test
swift run featherwick 2026   # play; seed 2026 is used only for a new save
```

The CLI autosaves to a named slot (default `featherwick-save.json`) in the current folder, writing
atomically with rolling backups. Launch flag: `--slot <name>` picks a save. Type `help` in the game for commands. `day 10` runs ten full days
(feed, collect, sell if the carton is full, close, rest until evening, sleep) for fast tuning; `sim [days] [games]` prints a balance report.

After the daylight lesson (day 9), the prompt shows the day's slots: `Day 31 · ☀︎☀︎○ >`. A filled sun is a
slot spent. A hollow sun is a slot left. `rest` spends one slot. `time` gives the time of day and the
errands left. See "Daylight and errands".

## Engine

`Engine.apply(command, to: &state, using: &rng) -> [GameEvent]`. Command in, events out. All tunable numbers live in `Rules`.

`MorningReport.from(events:state:)` sorts one night's events into groups (the morning, hatched, the fox, came home,
the neighbours, the post, the village, new stock, the show, jobs, the season goal, eggs, other) for the app's morning report.
Every event lands in exactly one group. IDs and events only; the words come from `eventText`.

Night order: fox (only if the coop is open, and never on the Longest Day's night) → foraging (if the door was left open and the flock came through) → new day → daylight resets → lost birds come home (needs a free perch; a loaned bird needs none) → growth and reveals ("hen or roo?" guesses settle as the sex shows) → neighbour's gift hen (rooster starter only) → neighbour's gift incubator (a known-fertile egg in the carton and no incubator) → hatching (eggs due today; clear ones go back to the carton, and a hen with no chicks stops being broody; a chick that looks like neither parent may get a "why" note, and the first why note opens "What might hatch"; the first hatch teaches candling) → brooder to coop (a bird that waited `homeWaitNights` for a perch is rehomed) → unnamed birds take a name (after `autoNameNights`) → broody hens wake → laying (only if fed; then a full nest may set a hen broody) → retirements → stories (loans due go home; a fertile-eggs step teaches candling if needed; debts are mentioned at most once a season) & trade offer → post (maybe one note) → village day (a notice a week ahead, the day and its gift, then the Hatch-along chick if it is due) → county show (on show days) → early game (features whose day has come; the show tip) → market board (old cards come down, the keeper's buyer comes or goes, new cards once a week) → milestones → season goal (check, then a new one when the season turns) → today's jobs → door opens.

## The early game (tutorial timeline)

`EarlyGame.swift`. A new keeper starts with one chick and learns one thing at a time. The game is
a tutorial told as a fixed timeline. Each morning on the timeline, the neighbour (Hazel) introduces one
`Feature`. A lesson locks nothing, except `daylight`: it locks `rest`. Other features stay locked
until their day: the command is refused with `.notYet(feature)`. The app hides the shop row or the
Show tab. For treats and birds, the shop shows a "not yet" line (`notYetText`) instead.

### Day 1 and the people

- A new game starts on day 1. The starter chicks hatched on day 0, so a bird's age is still the day
  number, and the timeline days below are the same as before. Only the empty first night is gone.
- `nameKeeper(name)` stores the keeper's name (`GameState.keeperName`). It works before the starter
  and any time later (Settings, or `iam <name>` in the CLI). A blank name is refused with `.blankName`.
  It costs no daylight. Old saves have no name until one is given in Settings.
- Choosing the starter runs the first morning: the day-1 lesson, today's jobs and the season goal.
  Nothing grows, lays or hatches, and it draws no random numbers.
- The people (`People` in FeatherwickText): Hazel, the neighbour over the back fence, and Wren, who
  runs Speckle & Down. No person's name (`NameBook.peopleNames`: Hazel, Wren, Dot, Teddy, Okafor,
  Bea) is ever suggested for a bird.
- The app: a welcome page (Hazel asks your name), the chick choice, then a tour of the four places
  (`People.tour`, `TourSheet`). The farm moves to each place. The tour can be skipped. Hazel's first
  note opens after it.

| Day | Feature | What happens |
| --- | --- | --- |
| 1 | `handling` (lesson) | The game starts here. Hazel asks your name and offers a chick, then walks you round the farm. The lesson, day 1's jobs and the season goal come with the chick (`Engine.firstMorning`). |
| 2 | `treats` | The neighbour gives `welcomeTreats` (3). Speckle & Down sells treats. Hazel asks if Marigold may stay (see "The borrowed hen"). |
| 3 | `coopDoor` (lesson) | Marigold, Hazel's hen, comes to stay. The coop door lesson is about her: the door, the fox, foraging. |
| 4 | `laying` (lesson) | Marigold lays. Hazel's note: feed, collect, sell. |
| 5 | `premiumFeed` | Speckle & Down sells premium feed. |
| 7 | — | The sex shows (`growerAge`). A rooster starter gets the gift hen. |
| 8 | `breedBook` (lesson) | The neighbour names the starter's breed and colour: the Breed Book. If Marigold came: "Marigold's chick, of course." |
| 9 | `daylight` (lesson) | "There's only so much daylight." From now on, errands take a slot of the day. |
| 10 | `birdShop` | Pullets, cockerels, fertile eggs, the daily special, story breeds. Hazel is home: send Marigold home, or keep her. |
| 14 | `coopUpgrade` | More perches. |
| 21 | `shows` | The show opens, a week before the first show. The neighbour's show tip. |
| 28 | — | The first county show. |
| 29 | `incubatorShop` | The big incubator. (The neighbour's small one still comes with the first fertile egg, laid or bought.) If the neighbour gave hers, the big one comes at least `incubatorShopAfterGiftDays` (14) after the gift (`GameState.introductionDay(of:)`). |
| 35 | `breedingPen` | The neighbour helps build the breeding pen. The keeper chooses the sire. |
| 42 | `marketBoard` | Mr Okafor puts up the market board by the bakery. It opens sooner if his note about the board comes first. |

- The days are in `Rules.featureDays`. The show opens `showNoticeDays` (7) before the first show.
- One lesson or opening a day, days 1 to 5. `Feature` cases are in timeline order. Saves keep the raw
  values only, so the order can change.
- No bought birds, perches, incubators or shows before the sex shows (`EarlyGameTests` checks this).
  Marigold is a loan, not a bird the keeper buys.
- A save keeps its own `featureDays`. A game begun before this table keeps its old days (laying on 18).
- **The show tip** (`Engine.showTip`). When the show opens, the neighbour names one of your birds and
  one class, by name: "Oh hey, I notice that Basil is a beautiful buff Orpington! … I think you
  should enter her in the Orpington class." She suggests the breed class if the bird places 1st to
  3rd in at least `showTipBreedClassOdds` (40%) of `showTipTrials` practice fields. Otherwise she
  suggests the pet class for the bird with the best odds there. Ties go to the starter.
- The practice fields come from the bird's own ID, not the game RNG, so the tip changes nothing.
  Only visible traits are judged, and chicks are never named, so the tip leaks no hidden gene.
- The tip is kept in `GameState.showTip` until show day. The app shows it on the Show tab with an
  "Enter" button, and a notice at the farm gate.
- `Engine.newGame(earlyGame: false)` opens everything from day 1, and Marigold never comes. Saves
  from before the early game have every feature open (`GameState.introduced` defaults to all).
- To add a step: a `Feature` case (in timeline order), its day in `featureDays`, the command it gates
  in `Engine.feature(for:)`, and its words in `introducedText` and `notYetText`.

## Hatching and candling

- You choose the exact eggs to hatch or sell. The incubator takes more eggs on the same day until it is full.
- Eggs hatch in the incubator after `incubatorHatchDays` nights (3). Under a broody hen, after `broodyHatchDays`.
- A new keeper cannot candle. A set egg is a guess. The app shows "?" on an egg you cannot judge yet.
- Setting eggs never candles them. Every chosen egg goes in, unless it is already known to be clear
  (`eggIsClear`). Candling is its own step. The set note says "Any fertile ones will hatch" unless every
  egg in the clutch is known to be fertile.
- A clear egg never hatches. It sits the full time and takes its place in the incubator (and its brooder
  place) until hatch day. Then it goes back to the carton, marked clear: "Hm, 1 egg didn't hatch. It mustn't
  have been fertile." (`eggsDidNotHatch`). If the carton is full, it goes to the nest boxes.
- So candling pays: a keeper who candles first keeps clear eggs out, and saves the space and the wait.
- Bought eggs are already candled, so they show as fertile.
- **The neighbour's 1-egg incubator** (`giftIncubatorSize`) comes once, with the first fertile egg:
  - laid by a hen, with an adult rooster in the coop (in the night's laying step), or
  - bought at Speckle & Down, or
  - a fertile gift egg from a story, such as Hazel's egg when Marigold goes home.
  - A bought or gift egg brings it at once. A save that already holds a known-fertile egg and no
    incubator gets it the next night (`incubatorGiftForFertileEggs`).
  - No gift if the keeper already has an incubator. Event: `.neighbourGaveIncubator(size:ownRooster:)`.
  - Its words say what to do: set the egg, and it hatches in `incubatorHatchDays` nights. The app shows
    them as a neighbour note, not only in the log.
- When `chicksToLearnCandling` chicks (1) have hatched, the neighbour teaches candling. Then you candle one egg
  at a time (`candleEgg`). The CLI can still candle the whole carton (`candle`). After the daylight
  lesson, candling is an errand: the first candling of the day takes a slot. Setting eggs is free.
- A story step that asks for eggs you know are fertile also teaches candling. If you cannot candle when
  the step starts (or on any night while it waits), the neighbour shows you at once. So the step never sticks.
- Every fertile egg hatches (cozy rule).
- Saves from before this rule keep candling (`canCandle` is true when it is missing).

### Hatch-day "why" note (`HatchWhy.swift`)

- A chick can hatch looking like neither parent. Then the neighbour says why, in one sentence.
  Event: `.hatchSurprise(chick:reason:)`. It comes after the chick's `chicksHatched` event.
- Both parents must be birds you own now (not rehomed), and revealed (grower stage or older), so you have
  seen their looks.
- The check uses only what you can see: the chick's down and each parent's look, as the down it gives
  (`Phenotype.chickDown`). Buff and white both give yellow down. Barred down hides the colour under it.
  So a buff chick from white parents gets no note, and a barred chick's colour is never named.
- The words never say the chick's sex. Sex shows only at the grower stage.
- The engine picks one reason (`HatchReason`). Priority, first match wins:
  1. `whiteHidIt`: a parent is white. White hides every other colour, so a white bird passes on colours it never shows.
  2. `recessiveFromBothParents(locus)`: the chick is lavender (then buff) and no parent is. Each parent carried one hidden copy.
  3. `blueSplitsThreeWays`: chick and parents are all black, blue or splash. Blue x blue gives black, blue and
     splash. Black x splash gives blue.
  - Reasons 2 and 3 need an unbarred chick. If no reason fits, there is no note.
  - A plain chick from two barred parents gets no note. A barred hen gives her barring to every son,
    so that chick is always a pullet. A note would tell its sex before the grower stage.
- At most `Rules.hatchWhyNotesPerDay` (1) notes a night. The first chick that qualifies gets it.
- The note uses no random draws, so the same seed hatches the same chicks as before.
- The app shows the note in the log, and as a toast. The app keeps only the newest two toasts, so a busy
  night can push it out.
- The first why note of a game opens the planner. See "What might hatch".

## Breeding pen

`BreedingPen.swift`. The keeper chooses which rooster fathers which hens' eggs.

- The pen is a corner of the coop. It holds at most one rooster and `Rules.penHens` (3) hens.
- `GameState.pen` holds the ids of the penned birds. The birds stay in `coop`. They keep their perch,
  so the pen adds no room and takes none away. The "birds never wait forever" rules do not change.
- Commands: `penBird(id)` and `unpenBird(id)`. Events: `.birdPenned`, `.birdUnpenned`.
- Refusals: `.penFull(hens:)`, `.penHasRooster`, `.notInPen`, `.alreadyInPen`, `.notInCoop` (a brooder
  bird, or a chick with its mother), `.tooYoungForPen`, `.birdNotHome` (lost or boarding), `.onLoan`
  (a loaned bird, such as Marigold: her line is her owner's to plan).
- Laying (night step 8):
  - A penned hen's egg is fathered by the penned rooster only, if he is an adult.
  - A penned hen with no adult rooster in the pen lays eggs that are not fertile, like a coop with no rooster.
  - A cockerel may go in the pen before he is grown, so the keeper can plan. The words, the CLI and the
    app say that the pen hens' eggs stay clear until his grown day (`GameState.penRoosterGrownDay`).
  - A coop hen's egg is fathered by a random adult coop rooster. The penned rooster never fathers it.
  - The pen's birds do not count toward coop rooster tension (`Rules.extraRoosters`). The coop
    roosters do not unsettle the penned hens.
  - With an empty pen, laying makes the same random draws as before the pen. Old seeds do not change.
- The fox, foraging, feeding, handling and broodiness treat a penned bird like any coop bird.
- A bird that leaves the coop leaves the pen too: rehomed, traded, scared off by the fox, or a loan gone home. `Engine.apply`
  removes such ids after every command, and the fox step removes them at once. A bird that comes
  home is not penned again. The keeper pens it again.
- No hidden sex leaks. A bird whose sex does not show yet is refused with `.tooYoungForPen`, before any
  check that depends on its sex. The words do not say which sex it is. `Engine.canOfferPen` is false
  for such a bird, so the app never shows "Pen" for it.
- Early game: `Feature.breedingPen` opens on day 35 (`Rules.featureDays`). Before that, both commands are
  refused with `.notYet(.breedingPen)`. A save made before the pen has no day for it in its rules: it
  uses the standard day. Saves from before the early game have it open.
- Old saves load with an empty pen (`SaveFormat.fillNewSettings`).
- CLI: `pen` lists the pen, `pen <name>` and `unpen <name>` move a bird. App: "Breeding pen" in the
  Coop sheet (a rooster place and hen places), and "Pen" or "Take out of the pen" on the bird card.

## What might hatch

`Knowledge.swift`, `KnowledgeTables.swift`, `Visible.swift`, `Planner.swift`, `PlannerTables.swift`.
The breeding pen shows what each penned hen and the penned rooster could hatch. Each line has a reason.

**The one rule: the planner never reads genes.** It reads `Visible` birds (what the keeper can see)
and `Knowledge` (what the keeper can work out from them). Hidden genes are found by elimination only.

### What the keeper can see (`Visible`)

- A `Visible` holds plain values: name, sex, stage, breed, origin, parents, look (`SeenLook`) and
  type band. It holds no genes.
- A bird whose sex does not show yet has no sex and no breed. Its look is its chick down only.
- A grown bird at home shows its feathers. A grown hen at home shows her egg colour too.
- A bird out of sight (rehomed, boarding or lost) keeps the look the keeper last saw
  (`Bird.lastSeenLook`). The look is frozen when the bird leaves. Coming home clears it. So a grower
  that grows up while away never shows eggs the keeper did not see.
- An away bird from an older save has no frozen look. It counts as its chick down only, because the
  day it left is not known.
- Birds that count (`Visible.all(in:)`): owned birds (home, lost, boarding), rehomed birds, and
  family-tree records. Not the neighbour's starter chicks before one is chosen, and not a trade offer's hen.
- A family-tree record has a `look` field. Only a loaned bird that went home (such as Marigold) keeps one:
  the look the keeper last saw. Other records have none, so they give breed evidence only.

### Working it out (`Knowledge`)

Each bird starts with every genotype its sex allows at each single gene. Evidence removes the
genotypes that cannot be:

1. **Look.** `Phenotype` in reverse (`LookTable`). The table is made once from every combination of
   the single genes. It never reads a real bird.
2. **Origin.** A bird from outside the flock (not hatched at home) is one of its breed's public
   recipes (`RecipeTable`) that gives its look. Where it was bred decides this, not its parents: the
   starter has its mother (Marigold) on record, and is still Hazel's purebred stock.
3. **Family up.** A chick keeps only genotypes its parents can give it.
4. **Family down.** A parent keeps a genotype only if every seen chick can come from it.
5. Steps 3 and 4 repeat until nothing changes.

- A mother is a hen and a father a rooster, even before the sex shows.
- Knowledge is sex-blind for a bird whose sex does not show yet. At a sex-linked gene its candidates
  always hold both the hen's and the rooster's forms, and its parents do not narrow them. Otherwise
  the set could tell a barred chick's sex. The chick still counts as evidence about its parents.
- An outside bird from an old save may fit no recipe the game has now. Then origin evidence is
  skipped for it. It is not a contradiction.
- Knowledge covers the single genes (`Loci.mendelian`). That list is worked out from `Loci`, so a new
  single gene is picked up at once. The quantitative traits (many small genes) are not tracked.
- Type comes from the judge's type band the keeper saw at the bird's newest show (`Visible.typeBand`).
  It is never worked out from genes.
- Each gene ends in one of three states:
  - `pinned`: one genotype left.
  - `halfPinned`: more than one left, but one allele is in all of them.
  - `open`: no allele is certain.
- Evidence that would remove every genotype is a contradiction. It is counted and ignored. In normal play
  there are none.
- Knowledge is worked out on demand. It is never stored. Birds are sorted by id, so equal states give
  byte-identical output.

### The forecast (`Planner.forecast`)

Lines come in this order. Within a group, lines follow `Trait.planned` (feather colours, barred,
laced, silkie feathers, egg colours, speckled eggs). Egg colours appear only in the egg-colour line
and in "likely no" lines ("Likely no blue eggs").

1. **Certain.** Every chick shows it: "Every chick will be lavender."
2. **Ratio.** Only when no open gene can change the share. Each gene that decides it is pinned in
   both parents, or cannot change it (white, buff or lavender hides it). At most
   `plannerMaxRatioDenominator` (16). Feather colours share one denominator and one sentence:
   "About 1 in 4 black, 2 in 4 blue, 1 in 4 splash." A white parent gives no colour or pattern ratio.
3. **Sex-link.** A barred hen, a rooster pinned not barred, and no chick can be buff or white:
   "Every barred chick will be a cockerel, every plain one a pullet." Buff and white hide barring.
   If a chick can be buff or white, a plain chick can be a cockerel, so there is no sex-link line.
4. **Egg colours.** Always one line: "Hens from this pair will lay white, cream or brown eggs." If an open
   gene could add a colour, the line ends with "unless one of them carries blue", "unless one of
   them carries brown" or "unless one of them carries speckles". When the family showed that gene, the reason is the family evidence, and
   the line ends with "unless one of them is hiding another egg colour".
5. **Likely.** A parent with at least `plannerLikelyAfterChicks` (5) seen chicks, none of which shows
   an allele it may hide: "Likely no barred chicks." For an egg gene, only laying daughters count.
   For a hen's Z gene, only sons count. It is a likelihood, not a proof.
6. **Possible.** Can hatch only if a parent hides it. Only for traits a bird can carry without
   showing them: lavender, buff, barred, laced, silkie feathers, speckled eggs. Never black, blue,
   splash or white: they show whenever their genes are there. When nobody in the pair's seen family
   showed the trait: "If one of them is hiding lavender, you'll find out." When someone did, the
   reason gives the family evidence. This is a parent's proven allele, or a parent or chick that
   showed the gene: "Her mother, Clover, is lavender." Else it is the family tree.
7. **Not possible.** Proven by elimination: "No lavender chicks from this pair." At most
   `plannerNotPossibleLines` (4). Traits the pair's seen family showed come first, then the common looks.
8. **Type.** Only when the judge gave both birds a type band: "Both judged good for type. Chicks
   should carry it."
9. **Kinship.** Only when the pair are related: "They are related like cousins." From `Pedigree.relatedness`.
10. **White caveat.** A parent is white, and not every chick will be white: "White hides what's
    underneath. Anything either of them carries could show."

- "Possible" and "not possible" lines are given for the common looks, and for traits that the pair,
  their parents, grandparents or seen chicks showed. Other traits get no line. "Likely no" lines too
  cover only traits a bird can hide, and egg colours.
- Egg colours are coarse: cream, brown, blue, green. How dark a brown or green egg is comes from
  many small genes. The planner does not forecast it. White counts as cream, for the same reason.
  So the planner words the cream class "white or cream". A reason that names a hen's own eggs uses
  her real colour ("Pip lays white eggs").
- Never a percentage or a decimal. Ratios read "about 1 in 4".

### Reasons

Each line has one `Reason`. The app shows it on a tap. The CLI shows it in brackets.

- The bird's look: "Pip is blue. Blue birds always carry one of each."
- Its breed, for a bird from outside: "Pip came from Speckle & Down as an Orpington."
- A parent: "Her mother, Clover, is lavender."
- A chick: "They had a lavender chick, Clover."
- Unknown family: "No one in their family has shown lavender yet." Only when no bird in the pair's
  seen family (the pair, parents, grandparents, chicks) showed the gene. Egg colours count: a
  hen that laid blue or green eggs showed blue shell. This holds for the egg-colour line too.
- A parent or a chick is named only for a non-plain allele ("barring came down from his mother").
  A plain allele proven through family gives the family tree.
- A parent is named only when that parent alone is proven to carry the allele. When it takes
  both parents to prove it, and both or neither surely carry it, the reason is the family tree.
- A chick's down counts as shown: barred down shows barring, slate shows blue, pale grey shows
  splash, silver shows lavender. Yellow down is buff or white, so it shows neither.
- Many chicks: "Pip has had 5 chicks and none showed barring."
- The judge's notes, the family trees, or a white parent.
- A reason names only a bird the keeper owns or has rehomed. Any other bird is "a bird".
- A bird whose sex does not show yet gets its name, never he or she.

### The unlock

- The breeding pen opens the planner at the latest: when `.breedingPen` is open and the keeper has not met
  the planner, the night's early-game step sets `plannerKnown` and sends `.plannerShownAtPen` (a note from
  Hazel, in the morning report's neighbour group). A save already past the pen's day gets it the next night.
- The first why note (`hatchSurprise`) opens the planner. That night sets `GameState.plannerKnown` and
  sends `.plannerIntroduced` right after the `hatchSurprise`. This happens once a game.
- The neighbour says: "You can work this out ahead of time, you know. Come and look at the pen."
  Before the breeding pen opens, she says: "I'll show you once you have a breeding pen."
- The unlock makes no random draw. The same seed hatches the same chicks.
- The morning report puts `.plannerIntroduced` in the hatched group.
- The pen shows a "New" notice (`plannerNoticeText`) until the keeper opens the panel. The app shows
  it only when a hen and a rooster are penned.
  `Command.openPlanner` sets `plannerOpened`. It costs no daylight and returns no events. Before the
  unlock it does nothing.
- Panel states (`Planner.panel(in:)`):
  - `hidden`: the keeper has not met the planner. The pen shows nothing.
  - `needsHen`: "Pen a hen to see what might hatch."
  - `needsRooster`: "Pen a rooster to see what might hatch."
  - `forecast`: one forecast per penned hen with the penned rooster, hens in pen order.
- Old saves load with `plannerKnown` and `plannerOpened` false (`SaveFormat.fillNewSettings`). They
  get the planner at the next why note, or the next night once the breeding pen is open. Saves from
  before the early game have the pen open, so they get it the next night.

### Carrier notes

- The bird card lists the hidden alleles a bird surely carries: "Carries lavender."
  `Planner.carrierNotes(for:in:)` gives them, from `Knowledge.provenHidden`.
- A note needs an allele that every genotype left holds (pinned or half pinned), and that the look does
  not show. Never "may carry". Plain alleles get no note on the card.
- A tap shows the reason: "It came from Moss's mother, Clover."
- No new state: the notes are worked out again each time from the state.
- The family tree shows each bird's notes in a few words ("carries lavender and blue eggs",
  `carrierShortText`), rehomed birds too. The CLI `tree` adds them after a " · ". The app's tree on
  the bird card shows them under each bird.
- Rehomed birds stay in Knowledge. Their chicks still count as evidence. `carries <name>` finds a
  rehomed bird too, and so do `tree <name>` and `kin <name> <name>`. The app's bird card does not open
  for a rehomed bird.
- A bird whose sex does not show yet gets sexless words: its name, never he or she.
- Empty until the keeper has met the planner.

### Inheritance page

- Books has a third tab, "Inheritance". It lists what the keeper has worked out, one rule a row.
- A rule is a ratio, a certainty or a sex-link that the forecast gave for a penned pair.
  Examples: "blue × blue → 1 black : 2 blue : 1 splash", "lavender × lavender → all lavender",
  "barred hen × plain rooster → barred chicks are cockerels".
- A rule goes on the page only when the keeper sets an egg from that pair (incubator or broody hen).
  A forecast alone adds nothing. Seeing is not the same as trying it.
- The pair is the egg's layer, a penned hen, with the grown rooster in the pen. The hook does not read
  the egg's father or fertility: the keeper cannot see those before candling.
- Nothing is added before the keeper has met the planner, for a coop hen's egg, or with a cockerel
  (not grown yet) in the pen.
- A rule names no bird. It says the parents' looks and what hatches. Feather-colour rules list the
  parents in colour order, not hen first: the colour genes are not sex-linked.
- The page heading is "Inheritance", with "What your pairs have shown" under it. A rule is true for
  the pair it came from. It is not a law for every bird with the same look: two black birds can hide
  different genes.
- Each rule shows once, in the order first seen. Before the first rule, a dashed box says:
  "Set eggs from a pair in the pen and what you learn ends up here."
- State: `GameState.seenRules` (an ordered list with no repeats). Old saves start empty.
- Code: `Inheritance.swift` (`InheritancePage.known(in:)`, `InheritanceRule`). Words: `inheritanceText`,
  `inheritanceLines`, `inheritanceTitleText`, `inheritanceSubtitleText`, `inheritanceEmptyText`
  (`FeatherwickText/InheritanceText.swift`). It never reads genes: the "no genome"
  test covers this file too.
- CLI: `inheritance` prints the page.

### Words, app and CLI

- Words (`FeatherwickText/PlannerText.swift`): `plannerText`, `plannerReasonText`, `plannerPanelText`,
  `plannerLines`, `plannerNoticeText`, `plannerNotYetText`, `carrierText`, `carrierReasonText`,
  `carrierLines`, `carrierShortText`, `carrierNoneText`.
- App: `Sheets/WhatMightHatchSection.swift`. "What might hatch" is in the breeding pen sheet. A feather
  or egg mark shows the colour a line names, from its `Trait`. Carrier lines are on the bird card.
- CLI: `plan` shows the pen's forecast (and opens the panel). `plan <hen> <rooster>` shows any revealed
  hen and rooster. `carries <name>` shows what a bird surely carries. Before the unlock, both say
  "Not yet" (`plannerNotYetText`).

### Tests that guard it

- **Blind test** (`KnowledgeTests`): 2,000 seeded games of 120 days, about 14 minutes. Every bird's
  genes are swapped for others that keep what the keeper saw the same: the look at home, the frozen
  look for a bird out of sight. A chick whose sex does not show may change sex too. Knowledge, the
  carrier notes (owned and rehomed birds) and the forecasts must stay byte-identical. The forecasts
  are for the penned pair and every revealed adult hen × rooster pair in the coop.
- **Soundness** (`KnowledgeTests`): for each checked pair, 10,000 real `Breeding.cross` chicks.
  "Not possible" never hatches. "Certain" always hatches. A ratio lands within 3 points of the
  real share. A sure egg-colour list and a sex-link always hold.
- **No genome** (`KnowledgeTests`): `Knowledge.swift`, `Planner.swift` and `Inheritance.swift` must not
  contain "genome", "Genome" or "alleles(at:". A `Visible` holds no genes.
- **Speed:** `Knowledge.of` for 40 birds under 1 ms in release, 25 ms in debug. A full pen panel
  under 5 ms in release, 100 ms in debug.
- `PlannerTests` and `PlannerTests+Unlock` check each kind of line, the panel, the unlock and old saves.
- `InheritanceTests` checks the page: a rule only after eggs are set, no repeats, look-alike genomes
  give the same page, old saves load. `InheritanceTextTests` checks that no rule text names a bird.
  `PlannerTextTests` checks the words: no percentages, no sexed words for an unrevealed bird.
- The full `swift test` takes about 20 minutes.

### Rules

- `plannerLikelyAfterChicks` (5): seen chicks a parent needs, none showing an allele, before "likely no".
- `plannerNotPossibleLines` (4): "not possible" lines in one pair's forecast, at most.
- `plannerMaxRatioDenominator` (16): the largest "in N" a ratio uses. Finer shares say "possible".

## Birds never wait forever

- A grown bird needs a perch. A loaned bird (Marigold) does not. With no free perch, it waits in the brooder. If the brooder is full, it
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
  olive, green, chocolate, blue or speckled eggs (laying hens only). A lap chicken adds `lapChickenRehomeBonus`.
- Quality adds more. Show type above average adds up to `rehomeTypeBonus` (16). Egg shape above average
  adds up to `rehomeEggShapeBonus` (6), for a laying hen only. Each 1st to 3rd place at a show adds
  `rehomeRibbonBonus` (6), for up to `rehomeMaxRibbons` (5) ribbons. Egg-class ribbons do not count.
- A purebred in a standard colour multiplies the quality bonus by `rehomeStandardPurebredFactor` (1.5).
- An average bird gets no quality bonus. A plain adult is worth 6. A fine purebred hen with ribbons is worth 40 or more.
- Only what the keeper can see counts. An unrevealed chick is worth its base price only.
- Ribbons are matched by the bird's ID. A show result from before results kept the ID is matched by
  the bird's name.
- A loaned bird cannot be rehomed (`.onLoan`). Neither can a hen on eggs or with chicks
  (`.birdIsBusy`), or the keeper's last own bird (`.lastBird`). `Engine.rehomeBlocker` gives the reason.
- After the daylight lesson, rehoming is an errand (a visit to the neighbour): the first one of the
  day takes a slot.

## Speckle & Down (the shop)

- Basic stock is always there: a pullet, a cockerel, or a fertile egg. The breed is a surprise.
  You find out the breed when you buy it.
- A surprise pullet or cockerel is a starter breed, or a breed a storyline added
  (`GameState.surpriseBreeds`). A fertile egg comes from starter breeds only.
- Treats, premium feed and the big incubator are always there too, once the early game opens them.
- After the daylight lesson, a trip to the shop is an errand. The first buy of the day takes a slot.
  More buys that day are free.
- No breed has its own sale. A keeper gets a breed by surprise, as the daily special, or as a gift.
- **The daily special** (`Shop.swift`): one young bird. The seller names its breed, sex and colour.
  It changes each day. Its breed is any in-game breed. Its colour is one of the breed's usual colours.
  With `shopRareChance` (8%) it is a rare colour: splash, lavender, or a colour the breed does not
  usually come in. Its genes make that colour, so the bird looks as advertised.
- Price: `shopSpecialPulletPrice` (35) or `shopSpecialCockerelPrice` (20), plus `shopRarePremium` (15)
  for a rare colour. One special a day (`buySpecial`). It needs a free perch.
- The special comes from `GameState.shopSeed` and the day, not from the game RNG. Looking at the shop
  changes nothing. Old saves have seed 0, so they still get a special that changes each day.
- CLI: `shop`, `buy pullet|cockerel|egg`, `buy special`, `buy treats|feed|incubator`.

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
| Brown coating | Br / br | Dominant | Simplified (real brown is polygenic). Depth sets the shade |
| Speckle | sp+ / sp | Recessive | Game-only gene |
| Show type | + / - at 10 genes | Additive | Quantitative trait (`QuantitativeTrait.showType`). Judged in breed classes |
| Egg shape | + / - at 6 genes | Additive | Quantitative trait (`QuantitativeTrait.eggShape`). Judged in egg classes |
| Calm | + / - at 8 genes | Additive | Quantitative trait (`QuantitativeTrait.calm`). 40% of friendliness |
| Brown depth | + / - at 10 genes | Additive | Quantitative trait (`QuantitativeTrait.brownDepth`). Shows only with brown coating |
| Dominant white | I / i+ | Dominant | One copy makes white plumage. Hides base colour, blue, lavender, lacing and barring. White chicks have yellow down |

### Egg colours

`Phenotype` works out a hen's egg colour from three things: blue shell, brown coating and brown depth.
Depth is a share from 0 to 1 (the "+" alleles out of 20).

| Blue shell | Brown coating | Depth | Egg |
| --- | --- | --- | --- |
| no | no | up to `Rules.whiteShellDepth` (0.05) | white |
| no | no | above 0.05 | cream |
| no | yes | up to `Rules.chocolateShellDepth` (0.8) | brown |
| no | yes | above 0.8 | chocolate |
| yes | no | any | blue |
| yes | yes | below `Rules.oliveShellDepth` (0.4) | green |
| yes | yes | 0.4 or more | olive |

- The base shell is white. Real tint and brown are one pigment, laid down by many genes. So with no
  coating, depth is the faint tint that makes an egg cream. 0.05 is one "+" allele of 20, or none.
- The thresholds are static numbers on `Rules`. They are the same in every game, because the
  egg colour is part of the bird's look and `Phenotype` reads no rules.
- Depth is half from each parent, like show type. Keepers can select for darker eggs.
- Each breed has a depth (`BreedDefinition.brownDepth`). A purebred gets exactly that share. A bird
  from outside the flock draws each depth gene with that chance, from its own ID.
  Marans 0.9 (chocolate), Orpington, Wyandotte, Australorp and Plymouth Rock 0.5, Araucana and Silkie 0.2,
  Leghorn 0 (white).
- So Araucana x Orpington gives mostly green eggs, and Araucana x Marans gives olive eggs.
- Leghorn x Silkie gives pale cream eggs (depth 0.1). Bred on, about 5 in 16 daughters lay white.
  Back to a Leghorn, about 3 in 4 do.
- A Silkie from outside the flock draws its depth. About 1 in 15 has depth 0.05 or less, so she lays
  white. A purebred Silkie bred at home lays cream.
- Average depth (0.5) is the default allele set. A bird from an older save has no depth genes, so it
  lays the colour it laid before. Eggs keep the colour they were laid with.
- New colours need no migration: `EggColour` and `EggBookEntry` only gain cases. White was added
  this way. An egg keeps the colour it was laid with. A hen's colour comes from her genes when the
  game loads.
- White is a cream with no tint. So `Knowledge` and the planner count it as cream
  (`EggColour.coarse`), as they count chocolate as brown and olive as green.
- The "new egg" goal asks for white only when a breed in play lays white. Now none does.

## Data layer: genes, breeds, colours, saves

Three tables. Most new content is a table entry, not new logic.

| Table | File | One entry is |
| --- | --- | --- |
| Gene registry `Loci` | `Locus.swift` | one gene: allele enum + default allele |
| Breed table `BreedTable` | `BreedTable.swift` | one breed: signature genes, colour varieties, broodiness, calmness, shell depth, look, status |
| Colour varieties `ColourVariety` | `BreedTable.swift` | one named colour: a recipe of genes |

- Genomes store only genes that differ from the default allele. A gene missing from a save is the
  default, so a new gene needs no save migration.
- Breeds have a status: `inGame` or `planned`. Planned breeds are tested but never appear in play.
  Now: Silkie, Orpington, Wyandotte, Araucana, Australorp (in game); Plymouth Rock, Marans, Leghorn (planned).
  Marans comes in black only. Black copper needs genes the game does not have yet.
  Australorp is not a starter: the "heritage breed" storyline adds it to the shop's surprise stock.
- White varieties use dominant white (I/I): White Silkie, White Orpington, White Leghorn.
  Simplified: real white Silkies and Orpingtons are mostly recessive white (c/c). The game has no
  recessive white gene yet.
- The Leghorn is a White Leghorn: light body, single comb, clean yellow legs, rarely broody. It lays
  white eggs, as real Leghorns do (shell depth 0).
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
The current save version is 2. Version 0 has no version key. Two migrations:

- 0 → 1 (`migrateGenomesToRegistry`): genomes move from one field per gene to the locus names in `Loci`.
- 1 → 2 (`migrateToOneSetting`): a Relaxed or Challenge game switches to the standard rules.

A save with no `layRecords` gets its egg history from the eggs it still holds (`Records.backFill`).
This is not a migration: no data changes shape, so the version stays the same.

## Shows (data layer)

`Shows.swift`. Three kinds of class, as at a real poultry show:

| Class | Who enters | Points |
| --- | --- | --- |
| Breed | Purebred adults | type 50 · colour 30 · condition 20 |
| Pet chicken | Any grower or adult, crosses too | condition 50 · friendliness 50 |
| Eggs | A matched plate of 3 | match 30 · shape 30 · shell 20 · freshness 20 |

- An egg class is one `EggColour`: cream, brown, chocolate, blue, green, olive or white. A plate matches
  when all eggs have the same colour and speckle. So a plate of green eggs is a valid plate.

- Standard colours come from the breed table: a colour is standard if one of the breed's varieties
  makes it. A splash Orpington is not standard; a buff Wyandotte is shown as gold laced.
- Show type and egg shape are quantitative traits (`QuantitativeTrait.swift`): many small genes,
  half from each parent, score capped. Selective breeding works; nothing can exceed the maximum.
  Birds from outside the flock get random quality genes from their own ID.
- Condition and shell quality come from care: frights, broodiness, hunger, age. The season does not mark shells down.
- Condition starts at 1. A fright takes off 0.4 (`conditionLossStressed`), broodiness 0.3
  (`conditionLossBroody`) and hunger 0.2 (`conditionLossHungry`). Foraging adds `forageConditionBonus`.
- No mark for what every bird does in a season. Every bird moults in autumn, so the judge does not
  mark the moult. (`JudgeNote.moulting` stays only so old show results load.)
- Grades are absolute (fair → excellent). `judge <name>` / `judge eggs` are practice: judging with no competitors.
- Judge's notes name only what the game tracks in genes or care: standard colour (with barring and
  lacing), feathering (silkie or normal), type (size, shape and carriage), condition, friendliness,
  egg shape, shells and freshness. Comb and leg feathering are art only (see "Look"), so judges
  never mention them.
- The judge's notes are kept with each `ShowResult`. The bird card shows the newest notes.
- **Before the show, nothing is a surprise.** `Judge.forecast` lists what the judge will see on the
  next show day: a fright or broodiness that lasts to that day, a hungry
  flock (on the eve of the show only), close breeding. The same checks as `condition`, so the
  forecast always matches the judge. The app shows it on the bird card, in the show panel and before
  the fee is paid. The CLI says it when you enter a bird, and in `shows`.
- Each class says what it is judged on, with the points (`judgingText`).

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
- A bird on loan may enter the pet class only. Her breed class is her owner's to enter.

On show day (a `passNight` step), each entry is judged by the same `Judge` code against a field of
AI entries. The entries are placed by score. A tie goes to the keeper's entry. Places 1–3 win prizes.
A first place goes in the trophy case.

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
| Autumn | Harvest Show | Breed |
| Winter | Winter Championship | Breed. Every rival picks `winterChampionshipExtraPicks` more candidates. |

`GameState.nextShowTheme` gives the theme of the next show. Each `ShowResult` keeps the bird, coins,
treats, the judge's notes, the theme and the podium. CLI: `enter <name>`, `enter <name> pet`, `enter eggs`, `shows`.

#### The podium

The keeper sees the top three in each class they entered, rivals too, and why each one placed.

- `ShowResult.podium` holds up to 3 `PodiumPlace`s, best first: the placing, who stood there
  (`PodiumEntrant`), the score and the judge's notes. A class with fewer than 3 judged entries has a
  smaller podium. A disqualified entry never stands on it.
- The judge's notes are the same `JudgeNote`s as the keeper's own entries get. The words come from `noteText`.
- A rival bird is kept whole (`Bird`), so its colour comes from its genes, like any bird. Show birds
  are adults, so a spectator sees breed, colour and sex. Nothing hidden is told.
- An egg class podium holds plates: colour and speckle, no bird.
- A rival brings its own day, not the keeper's. Its condition is its own luck (`Engine.rivalsDay`):
  not fed (`rivalHungryChance`, 15%), a good forage (`rivalForagedChance`, 30%) or a fright
  (`rivalStressedChance`, 8%). The odds are drawn from the rival's ID, so they move no game randomness.
  What the keeper did with their own flock never changes a rival's score.
- Each rival has an owner number (`Engine.showOwner`, 0..<`showOwnerSlots`). It comes from the rival's
  own ID, not from the game RNG. Keeping the podium draws no extra random numbers, so existing seeds
  play the same shows. FeatherwickText turns the number into a village name (`showKeeperNames`).
  Two rivals on one podium never share a name.
- The engine sends `.showPodium(class, places)` before the placings of each class.
- Saves: `podium` is optional. Results from older saves have no podium.

#### Seen at a show (Breed Book)

- A rival bird on a podium adds its look to the Breed Book as *seen*: `GameState.seenAtShows`
  (`SeenBreedBookEntry`: the look, the show day and the theme). The event is `.breedBookEntrySeen`.
- Each look is seen once. A look the keeper owns is never added as seen: owned beats seen.
  `breedBookSeenOnly` hides seen looks the keeper has owned since.
- Seen looks do not count as owned. Milestones, jobs and season goals count `breedBook` only.
- Egg plates add nothing to the Egg Book: rival plates are plain eggs of the class colour, which the
  keeper's own plate in that class already shows.
- The app marks seen looks with a pale, dashed dot and "Seen at the Summer Fete". CLI: `book`.
- **Lore pages.** A tap on an owned breed's tile opens its page: the colours found, real breed facts
  (`breedLore` in `FeatherwickText`, no gene words), and "Found on day N" (`GameState.breedBookDays`).

## Friendliness

`Friendliness.swift`. Score 0...1 = 40% calm genes (8-gene quantitative trait, stronger in calm
breeds) + 60% learned tameness. Bands: wild (below 0.25), skittish (0.25), friendly (0.5),
lap chicken (0.75 or more).

- `pet <name>` and `treat <name>`: once a day per bird each. Gains shrink as a bird gets tamer
  and never pass 1. Chicks learn 3x faster, growers 1.5x. Chicks with a mother hen learn at half speed.
- In the app, press and rub a bird on the farm to pet it (the same `pet` command). A bird already
  petted today leans in. This is not an error.
- Start: brooder chick 0.2, chick raised by a hen 0.05, bought bird 0.25.
- A fox fright and days lost lower tameness. Neglect never does.
- Effects: half of the pet show class; lap chickens rehome for more (`lapChickenRehomeBonus`).
  A lap chicken at home gives one more day slot (`slotBonusLapChicken`). Some market cards ask
  for a friendly bird or a lap chicken.

### Hen or roo?

`SexGuess.swift`. Before a chick's sex shows, the keeper may guess it. This is a cuddle-time game.

- `guessSex(bird, sex)`: once per chick. It is free. It costs no daylight and no coins, and no
  early-game lesson gates it.
- The chick must be younger than `growerAge` and its sex must not show yet. If not, the refusal is
  `.tooLateToGuess`. A second guess is `.alreadyGuessed`. An unknown bird is `.noSuchBird`.
- The guess is kept in `GameState.sexGuesses`. The app shows "You said hen" on the bird card.
- On the morning the sex shows (night step "growth and reveals"), the engine emits
  `.sexGuessResolved(bird, guessed:, actual:)` after `.revealed`. A right guess pays
  `Rules.sexGuessTreats` (1 mealworm) into the treat bag. A wrong guess costs nothing. The guess is cleared.
- A chick that leaves before that morning (rehomed, for example) takes its guess with it. There is no event.
- The first right guess reaches the "Guessed hen or roo right" milestone (`henOrRoo`).
- Rule 8: the guess reveals nothing. The refusals depend on age and the guess only, never on sex.
  The reward comes only on the morning the sex shows anyway. No new clues: the barred head spot
  (`Look`) and the planner's sex-link line stay the only ones.
- No randomness. A guess does not change a seeded game.
- CLI: `guess <name> hen|roo`. The words are the neighbour's ("You said hen, and she is. Well spotted.
  Have a mealworm.").

## Flock turnover and feed

Hens slow and retire with age, so breeding keeps mattering (`Rules.layAgeFactor`, `Bird.isRetired`).

- A hen lays at full rate until `layDeclineStartDays`, then gradually less, down to `layDeclineFloor`.
- At `retirementAgeDays` (504 days, four and a half in-game years) she becomes a beloved non-layer — never death (cozy).
  Retired hens keep their perch, can still be petted, shown in the pet class, and rehomed.
- **Premium feed** is an optional coin sink (basic feed stays free). A bag is several day-portions;
  `feed premium` feeds the flock for the day and lifts that day's laying. CLI: `buy feed`, `feed premium`.

## Foraging

Leaving the coop door open is a real risk/reward, not just a fox gamble. On a night with the door
open, the birds still in the coop forage (night step 1b), also after a fox visit. Broody hens sit
tight and do not forage. A night's foraging counts as feeding for that night's laying, so the hens
lay even if the keeper did not feed them. Foraging birds are also a little better off: a small lay
bonus (`forageLayBonus`) and show-condition bonus (`forageConditionBonus`).
So each night you choose: close up safe, or leave open to forage and risk the fox.
On the Longest Day's night the fox stays home, so an open door forages for free (see "The village calendar").

## Saves, rules and balance

- **Saves** (`SaveStore.swift`): named slots, atomic writes, and rolling backups (`…bak1/bak2.json`),
  so a bad write can't lose a game. An unreadable save is quarantined, not overwritten. `SaveFormat`
  still versions and migrates the state itself.
- **One setting** (`Rules.standard`): the game has no difficulty levels. Every new game uses the
  standard rules. A save from a Relaxed or Challenge game (save version 1) switches to the standard
  rules when it loads (`SaveFormat.migrateToOneSetting`). Its birds, coins and progress stay.
- **Balance sim** (`Simulation.swift`): plays many seeded games with a simple keeper policy and reports
  coins, flock size, Breed Book growth, eggs/day, income from eggs, shows and the market board,
  chicks hatched and fox visits, so the first-guess `Rules` numbers can be tuned
  from data. CLI: `sim [days] [games]`; `SimulationTests` guards against balance regressions.
- **The sim keeper's day.** Care first: feed and collect. Then the errands, most useful first: candle
  (only if an egg is not candled), story choices (always the first option), shop (a breeding pair, the
  big incubator), the show desk in show week, the market board (egg cards, and a bird card with a spare
  adult), and the neighbour (a story delivery, and spare roosters go on the same visit). Then set eggs, sell clear
  eggs, make room (coop upgrade, rehoming), and shut the coop. Then rest until evening, and sleep.
  An errand with no slot left is refused and costs nothing. It waits for the next day.

## Look (render spec from a shared parts kit)

`Look.swift`. A bird is drawn from shared greyscale parts with flat mask layers. Breeds share
parts, so most new breeds need no new art. `bird.look(onDay:rules:)` returns:

- `parts`, back to front: tail, legs, body, head, comb (or one chick part). Each part has a colour
  token per mask and its own scale: combs and tails grow in with age, and a hen's comb is the
  rooster's drawing, smaller. Pullets and cockerels are the adult parts, smaller.
- `overlays`: pattern textures clipped to masks (lacing, barring, a barred chick's head spot).
  A white bird has no overlays: dominant white hides its patterns.
- White plumage uses the `whiteFeather` token. The `white` token is for skin (legs).
- `scale`: breed size, grows smoothly with age; roosters end 20% bigger.

| Part | Shapes | Who uses them |
| --- | --- | --- |
| Body (hen + rooster) | heavy, medium, light, fluffy | Orpington/Australorp/Marans, Wyandotte/Plymouth Rock/crosses, Araucana/Leghorn, Silkie |
| Comb | single, rose, pea, walnut | most, Wyandotte, Araucana, Silkie |
| Legs | clean, feathered 5-toe | everyone but Silkie |
| Head | plain, crested | everyone but Silkie |
| Tail | hen, rooster, fluffy | |
| Chick | plain, fluffy | |

The kit is 21 parts and covers all 8 breeds in the table. Silkie feathering (a real gene) picks
the fluffy body, tail and chick, for crosses too. Tokens are not RGB: the art direction maps them.
Watercolour tip: paint each body whole, then cut it into parts with soft, overlapping edges.
CLI: `draw <name>`, `art`.

## Family tree and inbreeding

`Pedigree.swift`. Every bird keeps its mother's and father's IDs. Owned birds (rehomed ones
too) stay in the state; outside parents, such as those of a bought egg, are kept as
`PedigreeRecord`s, so no tree breaks.

- A record has an optional look (`PedigreeRecord.look`, a `SeenLook`). Only a loaned bird that goes
  home (`sendLoanHome`, such as Marigold) gets a record with a look: the look the keeper last saw.
  A record with no look gives breed evidence only to "What might hatch".
- The "Local flock" parents of a bought egg are records with no look: the keeper never sees them.
- A bird that leaves sight (rehomed, boarding, lost) is not a record. It keeps the look the keeper
  last saw in `Bird.lastSeenLook`. See "What might hatch".
- Records in older saves have no look. The field is optional, so they load with no migration.
- Once the planner is known, the tree shows each bird's carrier notes, rehomed birds too
  ("carries lavender"). CLI: after a " · ". App: under the bird.

- `Pedigree.tree(of:generations:)`, `offspring(of:)`, `kinship(a, b)`, `inbreeding(of:)`.
- Inbreeding is Wright's coefficient, as real breeders use: brother × sister = 0.25, half
  siblings 0.125, cousins 0.0625. Brother-sister lines climb 0.25, 0.375, 0.5, 0.59.
- Stored on each chick at hatch. The game keeps it, but the player never sees it.
- The player sees no inbreeding number. The tree and `kin` say only how related two birds
  are, in words ("related like cousins"). Playtests found the percentage a worry.
- The penalty is off by default: `Rules.inbreedingMatters = false`. Old saves load with it
  off (`SaveFormat.fillNewSettings`). When it is on, effects are light and never block a hatch:
  lay chance drops by the coefficient (capped at 50%); show condition drops (capped at 0.3)
  with "lacks vigour", for a bird bred as close as cousins (0.0625) or closer.
- CLI: `tree <name>`, `kin <name> <name>`. Both find lost and rehomed birds too. A bird at home
  comes first when two share a name.

## Names and quirks

`Names.swift`. Birds you hatch or buy arrive with `needsName`; the UI asks for a name at once,
with a suggestion (Enter takes it). Birds given by people (gift hen, trade hen, story gifts)
arrive already named by their keeper. Any bird you own can be renamed any time, even while lost.
A bird on loan (such as Marigold) keeps the name her owner gave her.
If Teddy is to name the next chick (see "Storylines"), it hatches with a name from his list
(`NameBook.teddy`) and does not wait for one. His names are neutral and in no other list.
No list holds a person's name (`NameBook.peopleNames`).

- Names are unique in the flock, ignoring case and spaces; up to 24 letters.
- Suggestions come from the bird's own ID (no game randomness used). A suggestion is never a name
  used before: not a bird in the flock, and not a bird that went to a new home (`GameState.rehomed`).
  You can still type an old name by hand. Each list (neutral, hens, roosters) has 120+ names.
  When a list is all used, suggestions go on with numbers ("Clover 2").
  A chick whose sex is still hidden gets a neutral suggestion, so the name never gives it away.
- A bird still unnamed after `autoNameNights` takes its suggestion (see "Birds never wait forever").
- The app shows a "needs a name" notice under the Coop place (on the Barn panel).
- Quirks (`Quirks.swift`, words in `quirkText`) are small habits for flavour, such as "Dust-bath lover".
  They change no rule and are not saved. They come from the bird's ID, like a name suggestion.
  Every bird has two neutral quirks for life. When its sex shows, about half of birds
  (`quirkSexShare`) gain a third quirk for their sex. So a chick's quirks never give its sex away.
  The bird card shows them under the facts.

## Storylines

`Story.swift`. Small puzzles told through Featherwick's people, which lead to gifts and unlocks.
A storyline has a trigger, steps with goals, and rewards. Night goals (hatch chicks, wait days)
are checked in `passNight`; delivery goals need the player (`deliver`). Rewards are given once;
a gift bird waits for a free perch, so the coop never overfills. The engine holds IDs only. The
words are in FeatherwickText: `storyText` for the steps, `choiceText` for the options.

- **The broody Silkie** (first hatch): a neighbour's Silkie is sitting on a golf ball. Bring 3
  eggs you know are fertile (candled). 4 days later she thanks you with a Silkie pullet, and
  Silkies join Speckle & Down's surprise stock. Always solvable: the shop sells candled fertile eggs.
- **A laced gift** (after the broody Silkie, once 4 chicks have hatched): a neighbour admires your
  flock. 3 days later she gifts you a Wyandotte hen, so lacing enters your lines.
- **A heritage breed** (after the laced gift, once 8 chicks have hatched): deliver 4 fertile eggs.
  4 days later it earns an Australorp hen and adds Australorps to Speckle & Down's surprise stock. (Any in-game breed can also be the shop's daily special.)
- **The borrowed hen** (a new keeper's first fortnight; see below).
- Hazel's first three stories each have one line about her mother's lavender line. Lavender is a colour
  here. No line says that the keeper's birds carry it (rule 8).
- CLI: `story`, `give eggs`, `give eggs <story>`.

The village has four more people. Each has one first arc of three to five beats. No arc waits for
another (`after` is empty). Each arc's words are in `VillagePeopleText.swift`.

- **The standard** (Dot, the judge). Starts at the first show entry. Dot notices you. A keeper with
  results from a show held before the arc started hears no "First show?". Then she invites you
  to see the standard. Then she asks which breed page to read first (`choiceOfBreeds`). She offers two
  breeds: first the breeds of birds whose breed shows, then breeds in the Breed Book, then breeds the
  shop sells. A chick whose breed is hidden does not count (rule 8). A flock of one breed gets a second
  breed, so the choice is never a dead end. The two breeds are fixed when the step starts
  (`StoryProgress.options`). The pick sends `.note(dot, "standard-<breed>")`. That breed's Breed Book
  page then shows "What Dot looks for" (`GameState.dotStandardBreed`, `dotStandardText`). The CLI
  `book` shows the same line.
- **Teddy helps out** (Teddy, the kid down the lane). Starts at the first ribbon (top 3) or on day 30,
  whichever is first. He wants to meet your birds. He is not allowed a chicken. He asks to help. Choice:
  he names your next chick, or you have a drawing day. Both give 3 treats. "Name" sets
  `GameState.nextChickNamer`: the next chick that hatches takes a name from `NameBook.teddy`
  (`.chickNamed`). The names are neutral, because the chick's sex is hidden. The keeper can rename it.
  "Drawing" sends a note with his drawing. The last beat waits for a lap chicken. Then Teddy says
  "that one's a lap chicken, you know" (a note).
- **The bakery window** (Mr Okafor, the baker). Starts at the first brown egg in the Egg Book, on day 14 or later (a new keeper's first
  fortnight is Marigold's, and she lays from day 4). He wants
  eggs for his window. Then he talks of a colour you do not have yet. Choice: take him 6 brown eggs now
  (30 coins, well above the egg price), or wait and take him 3 eggs of a new colour (50 coins and a note). The delivery step
  depends on the choice (`StoryGoal.ifChosen`). "A new colour" means a colour not in the Egg Book when
  the step starts (`StoryProgress.wantedColours`). If no breed the shop sells lays such a colour, any
  colour but brown that the shop's breeds lay counts. The Araucana is a starter breed and lays blue,
  so the step is always possible. The last beat, 3 days later, is a note about a market board in the
  village (`okafor-marketBoard`). That note opens the market board early (see "Market board").
- **Postcards from the rescue** (Bea, the rescue). Starts at the first bird that goes to a new home.
  Two days later, a postcard names the first bird that left. The words fit even if it left long ago.
  Five days later, a second postcard asks you to visit. A third comes when three birds have new homes,
  and names the newest. No choice. A postcard uses the bird's name and no pronoun (rule 8).

Deliveries for the village arcs cost the `.neighbour` errand, as Hazel's do. A refusal says what is
needed (`.needEggs`, `.needEggsOfNewColour`). In the app, the back fence and Books ▸ People offer each
choice and each delivery. The People page lists each person met, their about line, and their arcs.

To add one: append one `Storyline` to `Storylines.all`, with its `person`. Add its words in `storyText`,
and the words for each option in `choiceText`. A choice or a delivery is a step goal on its own, never
inside `anyOf`.

### The borrowed hen

`BorrowedHen.swift`. The first fortnight has a plot. Hazel lends the keeper Marigold, the starter's mother.

- The days come from the game's rules. Marigold comes on the coop door day (`StoryGoal.featureDay`,
  day 3). Hazel is home `marigoldStayDays` (7) later (day 10). Her age (`marigoldAgeDays`, 112) and her
  price (`marigoldPrice`, 40) are rules too: the table names them with `StoryNumber.rule`, and the
  story reads them from `s.rules` when it runs. The words name no fixed day or price.
- **Day 2.** Hazel asks: she goes to her sister's soon, for a few days. Can Marigold stay?
- **Day 3.** Marigold comes (`.loanBird`): a grown hen of the starter's breed, named by Hazel, from
  Hazel's (`origin` "Neighbour"). "Her eggs are yours. Shut the door at night." The coop door lesson is
  about her. She needs no perch (see Loans below).
- **Day 4.** She lays. The laying lesson is a note from Hazel in her box. If the fox scared her off,
  the note says she lays when she is home. It never says "roosters don't lay" to a keeper whose only
  bird is a chick whose sex does not show yet.
- **Days 3 to 10.** Hazel is away (`GameState.hazelAway`, `hazelHomeDay`), so her words come as notes
  and a postcard. The back fence is quiet and says the day she is home.
  Jobs can name Marigold. A cuddle job that names her counts as done once she has gone home.
- **Day 8.** The Breed Book lesson adds "Marigold's chick, of course." (only in games where she came).
- **Day 10.** Hazel is home and asks: `choose marigold return` or `choose marigold keep`. Her words
  carry no command: the CLI prints the hint (`choiceHintText`) after the night that asks.
  - **Return:** Marigold goes home (`.endLoan`). Hazel gives a candled, fertile egg of Marigold's
    breed (`.giftEgg(nil, fertile: true)`: nil means the breed of the bird the story lent, kept in
    `GameState.lentBreeds`, else the starter's). It does not need the starter to be here. It is the first fertile egg,
    so the neighbour's 1-egg incubator comes with it. A full carton holds up only the egg.
  - **Keep:** Marigold is the keeper's (`.offerToKeep`). Her price, `marigoldPrice` (40), is a debt to
    Hazel: "Pay me when you can. She likes you." A kept bird needs a perch of her own: with none free,
    the choice is still made, and the keeping waits for a perch (`.storyGiftWaitingForRoom`).
    Meanwhile the bird card says "Yours once there's a perch for her", and Hazel says so at the fence.
  - The choice waits. Until it is made, Marigold stays. Nothing is lost by waiting.
- **She is the starter's mother.** `Breed.motherGenome(of:)` picks one of the breed's colours that
  holds one of the starter's alleles at every gene. So she is one of the breed's public recipes, and
  `Knowledge` reads her as it reads any bought bird. The genes behind each quantitative trait share
  the starter's first allele too. The starter's `motherID` is Marigold. Its `fatherID` is her mate, a
  family-tree record with no look (he stays at Hazel's). The starter keeps its own breed evidence
  (`Visible.isFromOutside` reads the origin only), so its parents add to what the keeper knows and
  never take away from it. The planner's sure lines stay as many as before (`KnowledgeTests`).
- **Rule 8.** Marigold's look is evidence, like any mother's. It must never tell the starter's sex.
  Barring is on the Z: a barred hen gives barring to every son, so a barred mother with an unbarred
  chick would say "a daughter". So her one Z copy is the starter's first Z copy. Her barring always
  matches the starter's, hen or rooster. `BorrowedHenTests` checks that a hen starter and a rooster
  starter with the same look give the same events, `Visible`, `Knowledge` and carrier notes until the
  sex shows.
- **Old saves get no Marigold.** The story starts on `StoryGoal.newKeeper`, which reads
  `GameState.earlyGameStories`. Only `Engine.newGame` with the early game sets it. A save from before
  has it false (`SaveFormat.fillNewSettings`), so no retroactive loan, debt or choice.
- The sim keeper picks the first option of every choice: Marigold goes home.
- App: the choice is two buttons in Hazel's note and at the back fence. The bird card says "Hazel's
  hen, staying 6 more days". Settings has "You owe" with a Pay button.

### People, choices, loans and debts

- **Every system has a person** (`Person`): Hazel (genetics and the pen), Wren (the shop and the news),
  Dot (shows), Teddy (friendliness), Mr Okafor (egg colours), Bea (rehoming). Each `Storyline` has a
  `person`. The first three stories and the borrowed hen are Hazel's. Names and about lines are in `People` (FeatherwickText).
  A person's name is never suggested for a bird (`NameBook.peopleNames`; no name list holds one).
- **Goals.** A step or trigger can wait for: a day (`onDay`, an absolute day), the day the early game
  introduces a feature (`featureDay`), a choice, the first show
  entry, a placing in the top N, N birds at a friendliness band or better, an Egg Book colour, N birds
  rehomed, a debt paid, any one of several goals (`anyOf`), or all of them (`allOf`). A step can also ask for eggs of one
  colour (`deliverEggs`), eggs of a colour new to the Egg Book (`deliverEggsOfNewColour`), a pick of two
  of the keeper's breeds (`choiceOfBreeds`), or a goal that depends on an earlier choice (`ifChosen`).
  What a step offers (the breeds, the new colours) is fixed when the step starts (`Engine.prepare`).
  It is cleared when the step finishes. The pick stays in `chosen`.
- **Step rewards.** A step can give rewards when its goal is met. The story's own rewards come after the
  last step. A step whose rewards need room (a perch for a bird, a carton space for an egg) waits for room.
  A delivery step gives no rewards of its own.
- **Rewards.** A gift bird, a shop breed, a gift egg (candled), coins, treats, a loaned bird, the end of a
  loan, the offer to keep a loaned bird, a note, a person who names the next chick (`namesNextChick`),
  and rewards that come only for one option (`ifChosen`).
- **Choices.** A choice step offers two or three options. It waits for `choose(story, option)`. The pick is
  kept in `StoryProgress.chosen`, so later words can remember it ("since you kept Marigold"). No option is
  wrong, and no option locks content: each trades one good thing for another. Choosing costs no daylight.
  Event: `.chose`. `GameState.pendingChoices` lists the choices that wait.
- **Loans** (`Loans.swift`). A loaned bird (`Bird.loan`: owner, tag, return day) lives in the coop and needs
  no perch: she brings her own box. She can be fed, cuddled, given treats, shown in the pet class and
  scared by the fox, and she always comes home, perch or not. She cannot be rehomed, penned, renamed
  or set on eggs (`.onLoan`). Her eggs are the keeper's. She does not count as the keeper's last bird.
- A loan ends on its return day, or when a story ends it. A hen sitting on eggs or raising chicks stays
  until she is free. She goes home with `.loanReturned`. Her family-tree record stays, with the look the
  keeper saw. If the keeper keeps her (`offerToKeep`), the loan is cleared, she is the keeper's bird with
  her pedigree, and her price becomes a debt (`.loanKept`, `.debtOwed`). A kept bird takes a perch, so
  the step waits for a free one, like a gift bird.
- **Debts.** `GameState.debts`. `payDebt(id)` pays one in full, when the keeper has the coins (`.debtPaid`).
  No interest, no deadline, and nothing is held back while a debt stands. The owner mentions it kindly at
  most once every `debtReminderDays` (28, a season): `.debtReminder`. Paying costs no daylight.
- CLI: `choose <story> <option>`, `pay <debt>`, `people`.

### The post

`Post.swift`. Some mornings a note comes from one of the people. In the night's "post" step, with
`noteChance` (0.4), one note is picked from `Notes.pool`: a note whose condition holds
(`NoteCondition`: always, has eggs, show in the week, has rehomed, has a loan, an Egg Book colour, N birds at
a band, a season, after a story) and that has not come before (`GameState.notesSeen`). The roll and the
pick come from `shopSeed` and the day, never from the game RNG, so the post changes no seeded game.
Event: `.noteArrived(person, noteID)`. The words come from `postNoteText` by note ID. The morning report
shows notes under "Post". Conditions read only what the keeper can see (rule 8).

More conditions: a day or later (`dayAtLeast`), a feature is open (`isOpen`), N chicks hatched
(`chicksHatched`), N Breed Book pages the keeper owns (`breedBookCount`; looks seen at a show do not count),
N birds rehomed (`rehomedCount`), a show entry judged (`enteredShow`), a ribbon (`placedAtShow`), a
ribbon in a kind of class (`placedInClass`: pet, eggs or breed), and a loaned bird in the coop now
(`loanedBirdHome`; a loaned bird lost after a fright does not count).

The pool (`Notes.pool`, 72 notes). Each person writes about their own system:

| Person | Notes | About |
| --- | --- | --- |
| Wren | 14 | Village news, shop stock, the weather. A stock note comes only when that stock is open. |
| Hazel | 14 | Chicken lore. The early-game lessons, recalled. One look from the Breed Book. |
| Dot | 12 | Show hints. What she noticed at a show: the bird or plate that placed, by name. |
| Teddy | 12 | Drawings and questions. The tamest bird at home (a loaned bird too), by name. |
| Mr Okafor | 11 | Eggs and bread. One note for each egg colour in the Egg Book, from day 6 (brown from day 14). |
| Bea | 9 | How the rehomed birds are doing, by name. |

- The first days are quiet. No note can come before day 6, whatever the starter: Marigold may lay blue
  from day 4, but Mr Okafor's blue-egg note waits. Most notes wait for a feature, a season or a later day.
- A note never comes twice. A note that names a thing reads it when the words show
  (`poolNoteText` in `NotesText.swift`). If the thing has gone, the note says a general line.
- Tone: short, plain, one idea, in the sender's voice. No nagging and no loss. Only Teddy uses exclamation marks.
- Rule 8. A note names only what the keeper has seen. A bird whose sex is hidden gets no "she" or "he",
  and no word that tells its sex or breed. Bea names a rehomed chick by its name only.
- Append, never insert: the seeded pick reads the pool in list order. Put a new note at the end of the
  `added` list (the last list in `pool`), not in a person's list.

### The village calendar

`VillageDay.swift`. Four village days a year: the Hatch-along (spring), the Longest Day (summer), Moult Week
(autumn) and Midwinter Lights (winter). Each falls on a day of its season (`Rules.villageDays`), every year.
`villageDayNoticeDays` (7) mornings before, `.villageDayComing(day, inDays:)`. On the morning,
`.villageDay(day)`, then `.villageDayScene(day, year:)`. The morning report shows them under "In the village".
Nothing is missable: each day comes round again next year. `GameState.nextVillageDay` and
`upcomingVillageDays(n)` give the dates. No day draws from the game RNG, except that the Longest Day skips one.

| Day | When | What happens |
| --- | --- | --- |
| Hatch-along | spring, day 10 | Bring one known-fertile egg in its week. A surprise chick comes back 3 nights later. |
| Longest Day | summer, day 14 | The fox stays home that night. An open door forages for free. |
| Moult Week | autumn, day 1 | Hazel's lesson on the moult, and `moultWeekTreats` (4) mealworms. |
| Midwinter Lights | winter, day 14 | The village gives `midwinterCoins` (15), and Teddy sends a note with a drawing. |

- **The Hatch-along** (`HatchAlong.swift`). The week is the day itself and the days after it:
  `hatchAlongWeekDays` (7) in all. The notice a week before gives time to find an egg. In the week the keeper
  may bring Hazel one egg they KNOW is fertile (candled): `giveHatchAlongEgg(egg)`, or `nil` for the first
  known-fertile egg in the carton. It is the `.neighbour` errand. One egg a year (`hatchAlongYears`).
  Refusals: `.hatchAlong(.notThisWeek)`, `.hatchAlong(.alreadyGiven)`, `.hatchAlong(.noFertileEgg)`.
  Event: `.hatchAlongEggGiven(returnsOnDay:)`.
- `hatchAlongReturnNights` (3) nights after the egg, a chick comes back (`hatchAlongChickDays`). It is not the
  keeper's own egg: it is a surprise starter breed from the village hatch. It is a new chick in the brooder,
  with a name to give. Its breed and sex show at grower age, like any chick (rule 8).
  Event: `.hatchAlongChickArrived(id)`. It does not count as a chick the keeper hatched.
- The chick needs room, like a gift bird: a free perch, and a brooder place. With no room it waits with
  Hazel. She says so once (`.hatchAlongChickWaiting`). It comes the first morning there is room. It never
  boards and is never rehomed while it waits. A waiting chick does not stop next year's egg: the chicks
  queue (`hatchAlongChickDays`) and come home oldest first, one per free perch and brooder place.
  A perch counts as free only if no bird waits for it: every bird in the brooder, with a mother hen or
  boarding holds one. So a chick that came home yesterday still holds its perch, and none is rehomed.
- The chick is drawn from its own seed (`shopSeed` and its day), never the game RNG. So giving an egg does
  not change the rest of a seeded game.
- No egg costs nothing. The day comes round next spring.
- **The Longest Day.** On the night that starts on its date, `passNight` skips the fox roll (`foxStaysHome`).
  `foxChance` does not change. The door is still the keeper's choice, and an open door forages as usual.
  That night draws one number fewer from the game RNG. So every later draw in that game moves, and a seeded
  game plays differently after its first Longest Day. Nights before it are unchanged.
- **Moult Week.** Hazel's lesson on the moult and `moultWeekTreats` (4) mealworms, each year:
  `.villageDayGift(.moultWeek, coins: 0, treats: 4)`. There is nothing to do and nothing to miss. The moult
  costs no show marks.
- **Midwinter Lights.** The village gives `midwinterCoins` (15) each year: `.villageDayGift`. Teddy sends a
  note with a drawing: `.noteArrived(.teddy, "teddyMidwinterDrawing.y<year>")`, also in `notesSeen`. The
  ID holds the year it came, so the note keeps that year's words. It is a gift, not a task.
- **Words** (`CalendarText.swift`). Each day's scene has two versions: year 0 explains, and every later year
  remembers. Teddy's note changes the same way. Shared words hold no CLI commands: the CLI prints its own
  hint, and the app has a button. `villageNotice` gives the farm gate notice ("Longest Day in 3
  days", "Hatch-along: bring an egg"). The words never name the Hatch-along chick's sex or breed.
- CLI: `calendar` lists the next four, each with what it does (`villageCalendarLines`), and the Hatch-along
  line in its week, then the hint `give egg`. `give egg` brings the egg. `hasMet` counts Teddy as met once his Midwinter note came.
- App: the farm gate notice, a "Village calendar" block on the Show tab, and "Bring an egg for the
  Hatch-along" at the back fence (which then "has news").

## Market board

`MarketBoard.swift`. A board by Mr Okafor's bakery. People pin cards for what they want, and the keeper
brings it. The keeper can pin a card of their own to sell young birds. Nothing here can be failed.

- **It opens** with `Feature.marketBoard`, on day 42 (`Rules.featureDays`). It opens sooner on the morning
  Mr Okafor's note `okafor-marketBoard` comes (`MarketBoard.openingNoteID`), if a story sends it.
- **Wanted cards.** Once a week (`marketPinIntervalDays`, 7) the night pins `marketCardsMin` to
  `marketCardsMax` (1 to 2) cards. At most `marketBirdCardsPerPin` (1) card asks for a bird. A card stays
  up for `marketCardDays` (7), the pin day included. Then it comes down (`.marketCardDown`). No penalty.
- **The table** is `MarketCards.pool` (`MarketCardKind`: an ID, a person, a want and a `NoteCondition`).
  Append, never insert: the seeded pick reads list order. Each pinned `MarketCard` keeps its own copy of
  the want and the coins, so a table change never changes a card in a save.
- **What a card asks** (`MarketWant`): N carton eggs of one colour (speckled or plain), or one bird
  (`MarketBirdAsk`: a sex, a friendliness band or better, a laying hen). An egg card is pinned only when
  the Egg Book has its colour.
- **Rewards** (`Rules.marketReward`). Eggs pay `marketEggRewardFactor` (2.5) times their fresh farm-gate
  price, rounded: 3 blue eggs pay 23, and 6 brown eggs pay 30 (as Mr Okafor's window does). A bird pays `marketBirdCoins` (8), plus `marketLayingHenCoins` (4),
  `marketFriendlyCoins` (5) or `marketLapChickenCoins` (12).
- **Filling a card** (`fillCard(card, bird:)`). An egg card takes eggs not known to be fertile first, then
  the oldest. A bird card takes the named bird, if it fits and can go to a new home (`rehomeBlocker`:
  not on loan, not busy, not the last bird). The bird goes to the rehomed list. Events: `.marketCardFilled`.
- **The keeper's card** (`postCard(breed)`). One at a time. The keeper needs a young purebred of the
  breed: feathers in, not adult yet, free to go (`youngBirdsForSale`). A buyer comes `marketBuyerMinDays`
  to `marketBuyerMaxDays` (1 to 3) later (`.marketBuyerCame`) and stays `marketBuyerWaitDays` (2).
  `sellToBuyer(bird)` sells one bird for `marketBuyerPrice`: the rehome value times `marketBuyerFactor`
  (1.5, rounded up), plus `marketBuyerBonus` (4). That is always more than a new home pays. If nothing
  suits, the buyer goes home and the card comes down (`.marketBuyerLeft`). No penalty.
  Events: `.marketCardPosted`, `.soldToBuyer`.
- **Errands.** Filling, pinning and selling are the `.market` errand: the first one each day takes a slot.
- **No game RNG.** The pins and the buyer's day come from `shopSeed` and the day. The board changes no
  seeded game.
- **Rule 8.** A card asks only for what the keeper can see. A bird whose feathers are not in never fits any
  card, and its refusal (`.tooYoungForCard`) is about age, never sex.
- **Morning report.** Pins, cards that came down and the buyer go under "In the village".
- **Balance.** The sim keeper fills every card it can. Over 20 games × 224 days the board adds a mean of
  217 coins (final coins: 606 without wanted cards, 754 with them). Much of that is spare adults, which the
  sim keeper keeps for no coins when there is no board. `SimulationTests` guards it.
- Saves: `GameState.marketBoard` and the `market*` rules fill in with their starting values
  (`SaveFormat.fillNewSettings`).
- CLI: `board`, `fill <n> [bird name]`, `post <breed>`, `sell <name>`. App: "Market board" on the farm
  gate sheet opens `MarketBoardSheet`. The farm gate says "a card you can fill" or "a buyer is here".
  Words: `MarketText.swift`.

## Goal ladder

`Milestone.swift`. Small, always-visible goals that give the no-loss sandbox a direction. The ladder,
in order: first egg, first hatch, a friendly bird, a growing flock (8 birds), a blue egg, an olive egg,
a speckled egg, 8 Breed Book looks, a show ribbon (top 3), a first place, a lap chicken, a finished
storyline, a hen into retirement, a chocolate egg, a green egg, a right "hen or roo?" guess, a white egg.
Cozy rule: a milestone is only ever *reached*, never failed — no deadlines, nothing lost by missing one.

- Each `Milestone` is an id plus a test read from existing, player-visible state (so none can leak
  a hidden gene). Checked each night, after the day settles (`advanceMilestones`, a `passNight` step).
- Awarded once and recorded in `GameState.milestonesReached`; the engine emits `.milestoneReached(id)`
  and the words are in `milestoneText` (FeatherwickText). Loading an older save simply back-fills what
  you've already done.
- CLI: `journal` (the ladder, ✓ reached / ○ with a hint for what to aim for next).

To add one: append a `Milestone` to `Milestones.all` (list order is the ladder), plus its words in `milestoneText`.

## Today's jobs and season goals

`Jobs.swift`. A gentle reason to come back each day. Nothing here can be failed.

- **Today's jobs.** Each morning the game picks up to `jobsPerDay` (3) small jobs. It picks only from
  what the keeper can do now, and it follows the early-game timeline. Examples: feed the flock, collect
  the eggs, cuddle Juniper, Pip and Sorrel, cuddle Pip, give a treat, shut the coop door, sell eggs,
  candle an egg, set eggs to hatch, name a new bird, enter the show (only in the week before a show).
- **Jobs fit the day's light.** The jobs never ask for more errands than the day's slots
  (`Engine.withinDaylight`). Three jobs are errands: candle an egg, enter the show, and give a treat
  when the bag is empty (the treat needs a trip to Speckle & Down). All other jobs are care, and free.
  A costed job that does not fit makes way for the next free job. Before the daylight lesson, no job
  takes a slot.
- A job ticks itself off when the keeper does it. `Engine.apply` checks each command's events
  (`progressJobs`). Events: `.jobsSet`, `.jobDone(kind)`.
- **Cuddle jobs name their birds.** "Cuddle Juniper and Pip" picks up to `jobPetBirds` (3) birds at
  home (`Job.birdIDs`), from its own seed. Each named bird counts once, when it is cuddled today.
  A bird with no name yet is "the new chick". A job saved before this change has no names: then
  any bird counts ("Cuddle 3 birds").
- A named bird that leaves home (rehomed, lost to the fox, away) counts as cuddled. So a cuddle job
  can always be finished. This is the cozy choice: the keeper is never stuck with a job she cannot do.
- All of today's jobs done pays `jobsRewardCoins` (5), once a day (`.allJobsDone`). Unfinished jobs
  simply go the next morning.
- **Season goal.** One bigger goal for each season: hatch 3 chicks, a new Breed Book page, a new egg,
  a show ribbon, one more friendly bird, grow the flock by 2, or collect a number of eggs. The game
  picks only goals the keeper can work on now. Progress shows as "2 of 3". A bird on loan goes home
  one day, so she never counts for the flock or friend goals (`GameState.ownBirds`).
- The "new egg" goal asks only for colours a breed in play can make. Chocolate needs an in-game breed
  with shell depth above `Rules.chocolateShellDepth`. White needs an in-game breed that lays white.
  No in-game breed has either yet, so both are left out. A chocolate or white egg found anyway still
  counts as a new egg.
- "Collect eggs" asks for `seasonGoalEggsPerHen` (8) eggs for each visible hen in the coop, at most
  `seasonGoalMaxEggs` (40).
- The goal is checked each night, like the milestones. Reached, it pays `seasonGoalRewardCoins` (25),
  once (`.seasonGoalReached`). New progress is told in the morning (`.seasonGoalProgress`).
- When the season turns, a new goal comes (`.seasonGoalSet`). An unfinished goal is never failed: the
  new goal's words say kindly that the last one can rest. A goal set late in a season (fewer than
  `seasonGoalMinDays` left) runs on through the next season.
- Jobs and goals come from `GameState.shopSeed` and the day, not from the game RNG. So existing seeds
  keep their games, and the same day always gives the same jobs.
- Jobs and goals read only what the keeper can see. A chick waiting for a name is "the new chick"
  until its sex shows. No goal names a colour.
- Old saves have no jobs and no goal. They get both on the next morning.
- `jobsPerDay = 0` turns daily jobs off. `seasonGoals = false` turns season goals off. Most tests
  turn both off (`startedGame`); `JobsTests` covers them.
- CLI: `jobs`. App: the "Today" button on the farm opens the jobs sheet.

### Flock record book

`Records.swift`. The numbers the keeper already made, in one place. It only reads and counts. Nothing
here changes play.

- **Eggs.** One row for each hen: her total, her eggs in the last `recordWindowDays` (14) days, and the
  day of her first egg. Sold, set and hatched eggs count. A broken floor egg does not count.
- The egg lists lose sold and set eggs. So each hen's laying is counted as she lays
  (`GameState.layRecords`: total, first egg day, and her lay days in the window). The engine adds to it
  in the night's lay step. It draws nothing from the game RNG, so seeded games stay the same.
- A rehomed hen keeps her row and her total. Her name has the note "rehomed". A loaned hen who went
  home keeps her row too, under her family-tree name.
- A visible hen who has not laid yet shows "none yet", not 0. A chick whose sex does not show yet is
  never in this table (rule 8).
- **Ribbons.** One row for each bird with a 1st, 2nd or 3rd place in a bird class (`showResults`).
  Egg plates have no bird, so they are not in this table.
- **The flock.** Birds now (lost and boarding birds included), hatched here, bought at Speckle & Down,
  rehomed, and hens retired now. Then the first hatch day, the first ribbon day (egg plates count) and
  the days kept. All of these come from existing state: each bird's `origin`, the rehomed list, show
  results and the day.
- An old save has no egg history. On load, `SaveFormat` starts each hen's record from the eggs that
  the save still holds (nest, carton, clutches). Bought fertile eggs have a mother from outside the
  flock, so they do not count.
- No gene, inbreeding or quantitative trait shows here. Eggs and ribbons are things the keeper saw.
- CLI: `records`. App: the "Records" tab in Books. Words: `RecordsText.swift`.

## Daylight and errands

`Daylight.swift`. A day has a few slots of daylight. Care is always free, and an errand takes a slot.
Sleep waits until every slot is spent, and nothing is ever lost: a refused errand waits for the morning.

- **Slots today** (`GameState.slotsToday(rules:)`): `daySlots` (3), plus `slotBonusCoopUpgraded` (1)
  once the coop has more perches than it started with, plus `slotBonusLapChicken` (1) while a lap chicken
  is at home (in the coop, in the brooder, or a chick with its mother). Never more than `maxDaySlots` (5).
- **Slots left** (`slotsLeft`): today's slots minus `slotsUsed`, never below 0. Today's slots can drop
  in the day, for example when a lap chicken goes to a new home.
- **What each command costs** (`Engine.errand(for:)`):

| Cost | Commands | Errand |
| --- | --- | --- |
| Free, never refused for time | `chooseStarter`, `feed`, `feedPremium`, `collectEggs`, `sellEggs`, `sellChosenEggs`, `sellClearEggs`, `closeCoop`, `pet`, `giveTreat`, `guessSex`, `rename`, `incubate`, `incubateEggs`, `sit`, `sitEggs`, `penBird`, `unpenBird`, `openPlanner`, `nameKeeper`, `choose`, `payDebt` | none |
| One slot | `buy`, `buySpecial`, `buyIncubator` | `.village` (Speckle & Down) |
| One slot | `candle`, `candleEgg` | `.candling` |
| One slot | `enterShow`, `enterShowIn`, `enterEggs`, `enterEggPlate` | `.showDesk` |
| One slot | `deliver`, `acceptTrade`, `rehome`, `giveHatchAlongEgg` | `.neighbour` |
| One slot | `upgradeCoop` | `.building` |
| One slot | `fillCard`, `postCard`, `sellToBuyer` | `.market` (the board by the bakery) |
| One slot, no effect | `rest` | none |
| Waits for evening | `passNight` | none |

- **The first of a kind pays.** The first errand of a kind each day spends a slot. The engine adds the
  kind to `errandsToday`. More errands of the same kind that day are free, also when no slot is left:
  the keeper is already there. Event: `.slotSpent(errand, left:)`.
- **Setting eggs is free.** Candling is the errand. Show day itself runs at night and costs nothing:
  entering is the errand.
- **A refused command spends nothing.** Only a command that goes through spends a slot. A command
  refused for another reason (no coins, no egg, `.notYet`) costs no daylight.
- **No time left.** A new kind of errand with no slot left is refused with `.noTimeLeft(errand)`. The
  words say when to come back ("Too dark to candle now. First thing in the morning."). The time check
  runs after the early-game check. Front ends call `Engine.daylightRefusal(for:in:)` to show the
  words in place of a button.
- **Rest.** `rest` spends one slot and changes nothing else. Event: `.rested(timeOfDay)` and
  `.slotSpent(nil, left:)`. The words pick a line for the time of day from `shopSeed`, the day and
  the slot, not the game RNG. With no slot left, `rest` is refused with `.timeForBed`.
- **The sleep gate.** `passNight` is refused with `.notEveningYet(slotsLeft:)` while a slot is left
  ("The sun's still up. There's time for 2 more things."). `Engine.restUntilEvening` rests until no
  slot is left. The CLI `day N` and the sim use it.
- **Time of day** (`TimeOfDay`: morning, afternoon, evening). The game works it out from the slots. It
  is never stored. Evening: one slot left, or none. Morning: no slot spent yet. Afternoon: any other
  time. The rest line and the app's light follow it.
- **A new day.** The night resets `slotsUsed` to 0 and empties `errandsToday`. This is the first step
  after the new day starts (see "Night order").
- **The day-9 lesson** (`Feature.daylight`). The neighbour says: "There's only so much daylight. Feed
  and cuddle whenever you like, but you'll fit about three errands in a day." Before the lesson,
  nothing is refused for time, no slot is spent, and `passNight` is free. `rest` is refused with
  `.notYet(.daylight)`.
- `Engine.newGame(earlyGame: false)` starts with the lesson known. A save from before daylight existed
  gets the lesson on its next morning, because its day has come.
- Saves: `slotsUsed` and `errandsToday` are saved. An old save loads with a fresh day (0 slots used,
  no errands) and the standard daylight rules (`SaveFormat.fillNewSettings`).
- CLI: the sun prompt, `rest`, `time`. App: the sun mark in the HUD and the "Rest a while" / "Sleep"
  button (see `docs/design/README.md`, "Daylight (HUD)").
- **Day and night in the app** follow game time, not the device clock. Morning and afternoon are day.
  Evening starts a 30-minute crossfade to night. Night lasts from Sleep until the morning report (or the
  farm) shows. Before the lesson there is no evening, so the farm is day until Sleep.

## Realism rules (tested)

- Lacing shows only on a gold (buff) ground ("gold laced"); barring shows only on black-based birds.
  Hidden pattern genes are still passed on.
- White hides pattern genes, which still pass on. Dominant white (I) hides base colour, blue,
  lavender, lacing and barring. No text names a hidden colour. Two I/i+ white birds can hatch a
  coloured chick (about 1 in 4).
- A chick is purebred only if both parents are purebred and the same breed. Crosses are named
  like real keepers name them: olive egger (blue egg x brown egg), easter egger (other blue-egg
  crosses), barnyard mix (everything else).
- An olive egger lays olive or green eggs, by brown depth. An easter egger lays blue. A barnyard mix
  lays white, cream, brown or chocolate. A purebred hen lays her breed's colour; purebred parents pass
  on their exact shell depth (`BreedTableTests`).
- A laced purebred is always a Wyandotte. A purebred has silkie feathering only if it is a Silkie.
  A white bird has yellow down. No bird is both barred and laced.
- `GeneticsRealismTests` breeds tens of thousands of birds over 6 generations and fails on any
  bird a real keeper couldn't breed.

## Design rules

- Real genetics, but no lethal genes. Every egg hatches.
- Seeded random only, so every hatch can be replayed and tested.
- V1 placeholder: a chick takes its mother's breed.
