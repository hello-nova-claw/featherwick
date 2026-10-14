# Handoff: Featherwick UI system

## Overview
Featherwick is a calm, cozy chicken-keeping game for iPhone (portrait, one-handed). The player keeps a backyard flock at their farm, Henhaven, and hatches eggs to fill three collections: breeds, feather colours and egg colours. There is no combat and no death.

This package covers the **menu layer only**: type, colour, spacing, components, sheets and screen layouts. The farm scene, chickens, portraits and backgrounds are hand-painted watercolour sprites made separately. In the mocks they appear as dashed placeholder boxes labelled "farm scene", "bird art", "portrait", "item" and so on.

Architecture: **SwiftUI menus over a SwiftUI farm scene** (the 2.5D scene with a Metal colour shader, see Farm scene). The farm is 4 painted panels side by side; swipe left or right between them. Left to right: Barn (Coop), Yard (Yard), Far yard (Back fence), Shop (Farm gate). The game opens on the Yard. Each place opens a SwiftUI bottom sheet. The tokens and components are built in `App/Featherwick/Design/`.

## About the design files
The `.dc.html` file in this bundle is a **design reference built in HTML**. It is not production code. Recreate the designs natively in **SwiftUI** using its own patterns (`.sheet` with `presentationDetents`, `Font.custom(_:size:relativeTo:)`, colour tokens with day and night values, and so on). Do not embed the HTML.

Open `Featherwick UI System v4.dc.html` in a browser; it renders on its own. It is a single scrolling canvas with: intro, Pigments (colour), Type, Marks & components, Screens (1a, 1b, 2a, 2b) and Screens continued (3a–8a).

## Fidelity
**High fidelity** for colour, type, spacing, radii, line styles and layout. Treat hex values, sizes and spacing as final.

Exceptions:
- **Watercolour dabs** (friendliness, age and the colour-section swatches) are procedural SVG-filter stand-ins. In the shipped game they should be **painted by the bird artist** and used as image assets (see Assets).
- All bird, scene, portrait and shop art are placeholders.
- Copy for Mabel, Mr Alder, shop items and judge's notes is placeholder writing. Keep the tone, not necessarily the words. In the game, the neighbour is Hazel.

---

## Design principles
1. **White paper, ink, small dabs of watercolour.** Backgrounds are pure `#FFFFFF`. Colour appears only where it describes a bird or an egg: feathers, eggs, friendliness, age and notices. Everything else is ink.
2. **No large washes, no gradients, no glossy shadows.** Separation comes from white space and dashed rules, not boxes.
3. **Dashed "stitch" lines** are the signature mark. They are used for underlines, dividers, unknown or not-yet states, and tap-area outlines.
4. **Names and speech are serif (Libre Caslon). Everything you read or count is sans (Figtree).**
5. **Never colour alone.** Every state also has a word, a shape (filled or hollow, solid or dashed) or a position.

---

## Design tokens

### Colour — day (default: morning and afternoon in game time)
| Token | Hex | Use |
|---|---|---|
| `paper` | `#FFFFFF` | All sheet and page backgrounds |
| `ink` | `#2A2320` | Primary text, primary button fill, filled marks, outlines on swatches |
| `inkSoft` | `#5A4D45` | Secondary body text, quiet actions (Rename, Later) |
| `inkMuted` | `#7A6A5F` | Labels, captions, unselected tabs (4.6:1 on white) |
| `hairline` | `#E6DCCF` | Secondary button outline, dashed row dividers |
| `hairlineSoft` | `#ECE5DB` | Sheet grabber (defined; the app uses the system grabber) |
| `unknown` | `#C9BBAE` | Dashed "not yet" outlines, `?` glyph |
| `unknownBox` | `#D8CDBF` | Dashed outline of unfound collection tiles and the egg carton |
| `artPlaceholder` | `rgba(122,106,95,0.30)` | 1px dashed outline of art placeholders |
| `coin` | `#D6A65E` | Coin disc, sun mark |
| `floating` | white at 90% | Place-label, HUD and bottom-row backing |
| `toast` / `toastText` | `#FFFFFF` / `#2A2320` | Toast |
| `scrim` | farm dimmed to ~`#DDD8D0` | Background behind open sheets (the system sheet dim; not a `Palette` token) |

Underline and selected-tab stroke: `ink` at 50–75% opacity (`rgba(42,35,32,.5)` for headline underlines, `.75` for tab underlines).

### Colour — night (from evening in game time, ~30 min crossfade; night from Sleep until morning)
| Token | Hex |
|---|---|
| `paper` | `#1B1817` |
| `ink` | `#F3EEE6` |
| `inkSoft` | `#D9CFC4` |
| `inkMuted` | `#C2B6AA` |
| `hairline`, `hairlineSoft` | `#3A3330` |
| `unknown` | `#6E625A` |
| `unknownBox` | `#5A504A` |
| `artPlaceholder` | `rgba(194,182,170,0.30)` |
| `coin` | `#E8C894` |
| `floating` (place-label / HUD backing) | `rgba(27,24,23,0.88)` |
| `toast` / `toastText` | background `#F3EEE6`, text `#1B1817` (inverts against the night scene) |

Built as two `Palette` values (`Palette.day`, `Palette.night`) in `Design/Theme.swift`, read through the `\.palette` environment value. Game time picks the palette, not the system appearance; the app then sets the colour scheme to match. In the evening crossfade, `Palette.between` mixes the two palettes (it starts 10% of the way in) and counts as night past halfway.

Notice and speckle pigments (`Pigment`): decision dot buff `#DDAE6E`, collect dot brown `#A86E45`, egg speckles `#6B3E25`.

### Feather colours (swatch fill, always with name beside)
| Name | Hex |
|---|---|
| Black | `#2A2320` |
| Blue | `#7E8F9C` |
| Splash | pale grey `#D6DBDE` with blue `#7E8F9C` flecks |
| Lavender | `#B5AEBB` |
| Buff | `#DDAE6E` |
| White | `#F4F1E8` (warm off-white, so it shows on paper with its ink outline) |

### Egg colours
| Name | Base hex | Shade range used in Egg Book |
|---|---|---|
| Cream | `#EFE3CB` | `#F6EEDD`, `#EFE3CB`, `#E6D5B4` |
| Brown | `#A86E45` | `#C99A73`, `#A86E45`, `#8A5534`, `#6B3E25` |
| Blue | `#B4CFCB` | `#CFE0DD`, `#B4CFCB` |
| Olive | `#868755` | with darker speckles `#5C5D37` so it never reads as brown |
| Chocolate | `#5E3A26` | `#6E4630`, `#5E3A26`, `#4A2B1B` |
| Green | `#9DB58E` | `#B5C9A6`, `#9DB58E` |
| White | `#FAF8F3` (paler and cooler than cream, so the two read apart; the ink outline shows it on paper) | `#FDFCF9`, `#FAF8F3` |

### Typography
Fonts (Google Fonts, OFL): **Libre Caslon Display**, **Libre Caslon Text** (regular and italic), **Figtree** (300, 400, 500).
The design enables ligatures on serif text (`liga`, `dlig`, `hlig`). Libre Caslon has only a few. The app does not set them.

The app's styles are `Typeface` in `Design/Theme.swift`. The sizes below are the app's.

| Style (`Typeface`) | Font | Size / line height | SwiftUI `relativeTo:` | Use |
|---|---|---|---|---|
| display (`displayName`) | Libre Caslon Display 400 | 54 / 1.0 | `.largeTitle` | Bird name on bird card |
| title | Libre Caslon Display 400 | 38 / 1.05 | `.largeTitle` | Sheet titles (Breed Book, Today's eggs, Speckle & Down) |
| title2 | Libre Caslon Display 400 | 30 / 1.15 | `.title` | Naming question, class names on Show day, "This season" |
| speech | Libre Caslon Text italic 400 | 24 / 1.3 | `.title2` | Neighbour dialogue |
| epithet | Libre Caslon Text italic 400 | 20 / 1.3 | `.title3` | Breed line ("a Buff Orpington hen") |
| note | Libre Caslon Text italic 400 | 17 | `.title3` | Quiet asides: judge's notes on the bird card, quirks, planner reasons |
| place | Libre Caslon Text 400 | 18 | `.title3` | Place labels on the farm (upright, not italic), morning report headings |
| item | Libre Caslon Text 400 | 17 | `.headline` | Collection names, shop items, Egg Book rows |
| rowName | Libre Caslon Text 400 | 15 | `.headline` | A name in a table row (Record Book, arc titles) |
| body | Figtree 400 | 16 / 1.55 | `.body` | Body copy, values |
| action | Figtree 500 | 16 | `.body` | Button labels, selected tab |
| label | Figtree 400 | 13 | `.footnote` | Field labels, captions (sentence case, never all caps) |
| caption | Figtree 400 | 12 | `.caption` | Legends, notice text under place labels |
| number | Figtree 500, `.monospacedDigit()` | 15 | `.body` | Coins, treats, counts |

Minimum size 12pt. All styles must scale with Dynamic Type. At accessibility sizes, two-column fact grids collapse to one column and button rows stack.

### Spacing (pt)
4, 8, 12, 16, 24, 32 (`Space.xs` to `Space.xxl`).
- Sheet side padding: **28** (`Space.sheetSide`)
- Sheet bottom padding: **36** (`Space.sheetBottom`, clears home indicator)
- Gap between fact rows in bird card grid: **26 vertical / 16 horizontal**
- Collection grid: 3 columns, **24 vertical / 14 horizontal**

### Radii
| Element | Radius |
|---|---|
| Sheet (top corners) | 30 (`Radius.sheet`) |
| Buttons, toasts, place labels, HUD boxes, price buttons | **10** (`Radius.control`, no pills) |
| Collection tiles, art placeholders | 12 (`Radius.tile`) |
| Egg carton tray | 14 (`Radius.tray`) |
| Swatches, dots, grade ring | full circle |
| Eggs | `50% 50% 50% 50% / 60% 60% 40% 40%` (egg shape) |

### Lines
Stroke styles are `Stitch` in `Design/Theme.swift`.
- **Dashed stitch** (`Stitch.divider`): 1.3pt, dash 4/4, `hairline` (`#E6DCCF`), for row dividers (`StitchDivider`).
- **Dashed underline** (`Stitch.underline`): 1.5pt, dash 5/4, ink at 50%. Under display names it is drawn as a text decoration with *skip-ink off*, so descenders (the g in Marigold, the p in Pip) cross through the line. In SwiftUI, draw a dashed line **behind** the text (`UnderlinedName`), not `underline()`.
- **Unknown outline** (`Stitch.unknown`): 1.1pt, dash 3/3, `unknown` (`#C9BBAE`).
- **Tick** (`Stitch.tick`): 1.8pt solid with round ends, `inkMuted` (`TickMark`). It shows that something is done, always next to a word ("Done").
- **Tap-area outlines** on the farm mocks (1px dashed) are for the farm scene work only and are **not drawn in the game**.

### Shadows
Only on floating elements over the farm scene (place labels, HUD, toast):
`0 4px 14px -8px rgba(42,35,32,0.35)`; night toast `0 18px 40px -16px rgba(0,0,0,0.8)`.
In the app: `shadow(color: #2A2320 at 35%, radius: 7, y: 4)` (`FloatingBox`, `PlaceLabel`, day toast); night toast black at 80%, radius 20, y 4.
No shadows inside sheets.

---

## Components

Components are in `Design/Components.swift` and `Design/Marks.swift`.

**Primary button** (`.primary`): `ink` fill, `paper` Figtree 500 16pt label, radius 10, min height 52. Pressed: scale 0.97, fill at 85%. Only one per screen.

**Secondary button** (`.secondary`): no fill, 1pt inset `hairline` outline, ink label, radius 10, min height 52.

**Text action** (`.textAction`): Figtree 400 15pt `inkSoft`, min 44×44 hit area (Rename, Family tree, Later, Candle this egg).

**Disabled**: drop the fill, keep a dashed `unknown` outline, an `inkMuted` label, and change the label to say why ("No treats left").

**Tabs / filters** (`WordTabs`): plain words, 44pt tall. Selected is `ink`, weight 500, with a 1.5pt dashed underline (ink at 75%). Unselected is `inkMuted`, weight 400.

**Close** (`CloseButton`): "×" Figtree 300 26pt `inkMuted` in a 44×44 hit area, top-right of every sheet.

**Sheet** (`SheetPage`): `paper`, top radius 30, a context line (`label`, `inkMuted`) and close at the top. The grabber is the system one. Detents: large, or medium and large (each screen says which). The farm stays visible above, dimmed.

**HUD** (farm): top-left white box (radius 10) holding "Day 12" (Caslon Display 28) and "Autumn · morning" (Figtree 13 `inkSoft`). Top-right white box with coins (gold disc + number) and treats (ink diamond rotated 45° + number). Each count is a 44pt hit area. VoiceOver reads "1,248 coins, 6 treats".

**Place label** (farm): white box at 90% opacity, radius 10, place name in Libre Caslon Text 18. Optional notice line underneath: an 8pt dot plus Figtree 12 text.
- Things to collect: brown egg dot, "3 eggs waiting"
- Decisions: buff dot, "a bird needs a name"
- Story: ink dot, "has news"
The text always carries the meaning; the dot only draws the eye.

**Toast**: white (day) or cream (night) rectangle, **radius 10, not pill-shaped**, a small faint egg glyph, a Figtree 15 sentence, and at most one action on the right ("View", "Name"). Appears under the HUD, stays 4 seconds (10 with VoiceOver), at most two stacked.

**Friendliness**: 4 dabs, 16pt, in order wild → skittish → friendly → lap chicken. Earned dabs are filled (the stand-in `Dab` in `inkMuted` until the painted dabs exist); the rest are dashed `unknown` circles. The stage name is always written underneath.

**Age**: 3 dots of growing size (8, 12, 17pt) for chick → pullet/cockerel → hen/rooster. Filled with buff up to the current stage, dashed after. The stage and age in days are written out ("Hen, 40 days"). Before the sex shows, the word is "Growing" or "Grown".

**Feather swatch (inline)** (`FeatherSwatch`): a feather outline (1pt ink stroke and quill, filled with the feather colour) 14×24, plus the name.

**Egg swatch (inline)** (`EggSwatch`): an egg shape 14×18 with a 1pt ink inset outline, filled with the egg colour, plus text ("Brown eggs").

**Collection tile** (`BreedTile`): square art with a 1px dashed placeholder and radius 12, the name in Libre Caslon Text 15, and a row of 8pt colour dots: filled for colours found, dashed for colours still to find. Unfound breed: the tile shows a `?` in `unknown` in a dashed `unknownBox` square, with a one-line italic hint ("lays blue eggs").

**Grade** (not built in the app yet; Show day writes the score as "72 of 100"): a 128pt circle drawn as a 1.3pt dashed ink ring, score in Caslon Display 48 with "of 100" underneath, grade word in italic, then a 4-step scale (Fair, Good, Very good, Excellent). Reached steps are solid 2pt ink lines and the current one is labelled in weight 500; unreached steps are dashed `unknown`.

**Dialogue**: a 72pt round portrait overlapping the sheet's top edge, a "Hazel, over the fence" label, the speech in Caslon italic 24, then replies as full-width 52pt rows split by dashed rules, each with a → on the right.

---

## Screens

All screens are 393×852 (iPhone 15/16). Sheets sit over the dimmed farm. The mocks place each sheet's top edge; the app uses detents, given with each screen.

### 1a / 1b — Farm (day / night)
- Full-bleed painted scene (SwiftUI, see Farm scene).
- HUD top-left and top-right (see Components), 58–62pt from top.
- 4 panels to swipe between: Barn, Yard, Far yard, Shop. The Yard and the Far yard draw a placeholder 2.5D scene (see Farm scene). Until their paintings exist, the Barn and the Shop are a flat colour with a dashed "scene" box.
- One place per panel: Barn: Coop. Yard: Yard. Far yard: Back fence. Shop: Farm gate. Its button sits in the bottom row after Today, so it never covers the scene, and it changes as you swipe. The Coop sheet holds the brooder, chicks with their mothers, broody hens and the incubator too (there is no separate potting shed).
- Panel rail: a white box down the right side, under the HUD, with one dot per panel in swipe order. Tap a dot to go there. The current panel is an ink dot. A panel off screen with a notice gets a bigger dot in its notice colour (decision, then collect, then story) with a ring. Others are small `unknown` dots. VoiceOver reads the panel name and its notices.
- Bottom: "Books" (Caslon Display 23) bottom-left, then "Today", then the place of the panel on screen (Coop, Yard, Back fence or Farm gate), then "Rest a while" ("Sleep" when the last slot is spent; only after the daylight lesson, before it Sleep is in the Coop sheet), and a settings button "≡" bottom-right, all white boxes with radius 10, 56pt tall, 24pt above the home indicator.
- Books appears when the early game introduces the Breed Book (the `breedBook` lesson, the morning the first chick's sex shows). Until then, an "added to the Breed Book" toast has no "View". "≡" is always there.
- Today shows how many of today's jobs are left in a buff badge. When all are done, the badge goes: "Today" turns `inkMuted`, with an ink tick and "Done" (Figtree 13). VoiceOver reads "Today, all jobs done".
- Farm gate notice "new in today": stock the early game brought in this morning. It goes when the keeper opens the Farm gate or buys something there. The app keeps what was seen (per save slot); the game does not.
- Farm gate village notice (story dot): a village day in the next 7 days ("Longest Day in 3 days", "Moult Week tomorrow", "Midwinter Lights today"), or "Hatch-along: bring an egg" while the Hatch-along week is on and the keeper has an egg they know is fertile. The words come from `villageNotice` (FeatherwickText). It asks for nothing: no egg costs nothing.
- Farm gate: once the market board opens, a "Market board · N cards" text button under the shop opens `MarketBoardSheet` ("By the bakery"): each wanted card (person, want, coins, until day, their line in Caslon italic, and a "Bring them" or per-bird "Give" button), then "Your card" (pin a card per breed, or the buyer and a "Sell · N" button per bird). Notices: "a buyer is here" (decision) or "a card you can fill" (collect).
- Night: same layout with night tokens. Place labels can show state ("5 asleep", "door still open"). A toast example: "A chick has hatched" with the action "Name".

### 2a / 2b — Bird card (sheet, large)
Top to bottom:
1. A context line ("In the flock") and close.
2. Art placeholder 200×180, centred, 16pt above and below.
3. Name, centred, Caslon Display 54, with a dashed underline that descenders cross. Then the breed line in italic ("a Buff Orpington hen" or, for an unknown breed, "breed still a mystery"). A bird on loan gets one more line under it, in italic `inkMuted`: whose she is and how long she stays ("Hazel's hen, staying a week"). A bird on loan has no Rename, Rehome or Pen: she is not the keeper's yet.
4. A 2×2 fact grid: Friendliness · Age · Feathers · Lays (hen) or Hen or rooster (chick: "Shows in ~6 days").
5. The bird's quirks (`note`), one line each. Then carrier lines once the keeper knows the planner ("carries lavender", tap for why). Then "Next show" (how the bird should look on the day) and the last "Judge's notes, day N".
6. Ribbons, only after the bird has been to a show: one line per show, newest first ("1st of 8 · Orpington class, day 84, Harvest Show"). The top three get an ink rosette (1st filled, 2nd outlined, 3rd dashed).
7. Bottom: Cuddle (primary) and Treat (secondary, shows "· 6" remaining) side by side. While a chick's sex does not show, "Hen or roo?" with Hen and Roo buttons (one free guess; after it, "You said …"). Then text actions: Rename and Family tree; Set eggs under her (a broody hen); Enter the show; Rehome; Pen or Take out of the pen (once the breeding pen is open). "Enter the show" opens the class choice (see 8a). It shows only once the county show has opened in the early game, and becomes "Entered in the show" (disabled) after entry. Each counts once a day per bird. When done today, the button is disabled and says so: "Cuddled today", "Had a treat today" (like "Fed for today" in the yard).
8. The last log line, then toasts over the bird card too, so the keeper sees what a cuddle or treat did.

### 3a — Naming prompt (sheet, large)
Chick art, "Just hatched in the brooder", the question "What shall we call this chick?" ("her" or "him" only once the sex shows), an editable name field (Caslon Text 30) pre-filled with a suggestion, a dashed underline, and "A suggestion. Try another". Primary button "Name it Clover" ("Name her Clover" once the sex shows; the label repeats the current name). Text action "Later" keeps the "needs a name" notice on the Coop.

### 4a — Breed Book (Books sheet, large)
Tabs "Breeds | Eggs | Inheritance | Records | People", close. Title "Breed Book", progress "7 of 24 breeds, 12 of 120 colours". A 3-column grid of collection tiles in a fixed order, so gaps show where unfound breeds belong. Colour dots on a tile: filled for a colour you have owned, pale with a dashed rim for a colour only seen on a show podium, dashed and empty for a colour still to find. A breed only seen at a show gets its tile, with "seen at a show" in italic under the name. Under the grid, "Seen at shows" lists each seen look with its show ("Seen at the Summer Fete, day 28"). A look you own later moves out of that list. A tile with an owned colour opens the breed's page (a sheet): art box, name, "Found on day N", "n of N colours found", each found colour as a feather swatch with its name, then the lore under headings. Other tiles stay closed.

### 4b — Egg Book (Books sheet)
Same header with the Eggs tab selected. "5 of 14 eggs found" (each `EggColour`, plain and speckled: 7 × 2). One row per egg colour, in `EggColour` order (Cream, Brown, Blue, Olive, Chocolate, Green, White): name and "n of 2", then 2 egg shapes (plain, speckled), filled if found and dashed if not. An italic hint appears on rows that are still empty.

### 4c — Inheritance (Books sheet)
Same header with the Inheritance tab selected. Title "Inheritance", then "What your pairs have shown" (label, `inkMuted`). One row per rule, in the order first seen, each in body type with a stitch divider under it: "Blue × blue → 1 black : 2 blue : 1 splash". Before the first rule, a dashed box (`Stitch.unknown`, radius `tile`) holds "Set eggs from a pair in the pen and what you learn ends up here." in italic.

### 4d — People (Books sheet)
Same header with the People tab selected. The five tabs scroll sideways on a narrow phone; the close button stays put. Title "People". One entry per person met, in `Person` order, each with a stitch divider under it: name (`item`), role (label, `inkMuted`), the about line (body). Then "Finished" and "Under way" (label, `inkMuted`), one arc title each (`rowName`), with what the keeper chose in italic under it ("You let Teddy name a chick."). A choice the person waits on shows "Dot asks you to choose:" in italic and one secondary button per option. Eggs the person asked for show a secondary button, "Hand over the eggs". The last words show at the bottom. On a breed's page (4a), the breed Dot showed the keeper gets a section "What Dot looks for" (`item`), with her notes in italic.

### 4e — Record Book (Books sheet)
Same header with the Records tab selected. Title "Record Book", then three tables (`RecordBook`, from Core's `Records`). Names in `rowName`, numbers in `number`, column heads in `label` / `inkMuted`.
- "Eggs": one row per hen: Hen, Total, "Last N days", First egg. A hen who has not laid yet reads "none yet" in italic, not 0. With no hens: "No hens laying yet."
- "Ribbons": one row per bird: Bird, 1st, 2nd, 3rd. With none: "No ribbons yet. The county show gives them for 1st, 2nd and 3rd."
- "The flock": Birds now, Hatched here, Bought, Rehomed, Retired, First hatch, First ribbon, Days kept. A day not reached yet reads "not yet".

### 5a — Egg carton (Coop sheet, large)
Context "From the nest boxes". Title "Today's eggs", then the eggs in the nest boxes with a Collect button, then filters (All 7 / Fertile / Clear / Not candled). The carton is a grid of 1pt cups, 6 across and at least 2 rows, inside a dashed tray. Candling mark on each cup: **filled ink dot = fertile, hollow ring = clear, no mark = not candled**, with a legend underneath. Tap cups to choose eggs (1.5pt ink ring); tap again to put one back. One egg chosen: the detail row shows a large egg, "Blue egg" and "From Juniper. Fertile." More than one: "3 eggs chosen". Actions act on exactly the chosen eggs: **Set 3 to hatch** (primary) and **Sell 3** (secondary with price). With none chosen, the secondary is **Sell all**. Before the keeper learns to candle, an unknown egg shows "?" in its cup, the legend says "?: can't tell yet" and the filters are hidden. After the lesson, choose one egg that is not candled and tap "Candle this egg". "Sell all but fertile" is a text action next to it. Setting eggs never candles them: an egg that is not candled goes in, and a clear one comes back on hatch day. When the chosen eggs cannot hatch, replace the Set to hatch button with the reason (clear egg, room for 2 more). With no incubator, there is no Set to hatch button. The coop shows no incubator and no hint about one until the keeper has one. The incubator takes more eggs on the same day until it is full.

Under the carton, the same sheet holds:
- **Brooder** (title): "Name the new birds" (primary) while one waits, "n of N places in the brooder", the brooder chicks as rows (swatch, name, → to the bird card), "With their mother", the incubator (only once the keeper has one) and hens sitting on eggs.
- **The coop**: "n of N perches taken · door open", birds waiting for a perch, "Breeding pen" (text action, once it is open), "Shut the door" (secondary), and Sleep (secondary) when the sun is down, else the reason in its place. A caption says an open door lets the fox visit.

### 6a — Back fence (sheet, medium and large)
See Dialogue. The speech is the line of Hazel's newest open storyline, or a quiet hello. Reply rows, top to bottom: "Hand over the eggs" for each delivery waiting (with the person's name when it is not Hazel's), each choice option, "Yes, let's trade" when a trade is offered, the Hatch-along row, and "Bye for now". A reply sends its command; it does not advance a conversation.
- A choice a person asked for waits here: one reply row per option, after the person's name ("Hazel: Send Marigold home", "Hazel: Keep Marigold"). The same buttons are in her note the morning she asks, with the option's words under each. "Decide later" closes the note. Nothing is lost by waiting.
- Settings (≡) has a "You owe" list when the keeper owes someone: one line per debt ("Hazel, 40 coins") and a Pay button, disabled until the keeper has the coins. No hurry and no interest.

The Hatch-along: while its week is on and the keeper has an egg they know is fertile, the Back fence label says "has news", and the sheet has the reply row "Bring an egg for the Hatch-along" above "Bye for now". It sends `giveHatchAlongEgg` with the first known-fertile egg. Once the egg is given (or the week ends), the row and the news go.

### 7a — Show day (full screen)
Opens over the farm on the morning of a show. A place sheet closes first. Context "The county show, day 84" and close, a show-tent art area, the theme name ("Harvest Show") with a dashed underline, and the featured kind ("Featured: breed classes, bonus prizes"). Then one section per class: the class name (Caslon Display 30), "Hard class" (and "featured" when it is), then "The top three": one row per podium place, rivals included. A row has the rosette, a small bird drawing (the chicken rig, coloured from the bird's genes) or an egg for a plate, who it is ("Mrs Pennywhistle's buff Orpington hen", "your Clover"), "1st, 88 of 100", and a "Why?" text action that opens the judge's notes in italic. Your own places have a thin ink frame. Then each of your entries split by dashed rules: rosette, name, "72 of 100", the placing ("1st of 8", "4th of 6, no ribbon"), what it won, and the judge's notes in italic. The bird card keeps the last judge's notes too. Then "Taken home" with coins and treats, and the primary button "Back to the farm". With no entries, the page says "You didn't enter this time." and gives the next show day.

### 8a — Speckle & Down (Farm gate sheet, large)
Context "In the village", coin balance and close. A painted shop front (130pt), the title, an italic greeting from the shopkeeper, and tabs Feed / Treats / Hatching / Show (Show only once the early game opens the show). Stock the early game has not brought in yet shows a "not yet" line instead. Item rows are 72pt: a 48pt item art, name (Caslon Text 17) with a one-line description, and a price button (coin dot + number, secondary style). If the player can't afford an item, its price button is disabled and says "Not enough coins".

The Show tab: the next show's theme name and day, the entry fee, and the featured kind. Then Hazel's tip when she has one (a bird and a class, and an "Enter … · N coins" button). Then what is entered, a row per bird that can go (tap → a sheet with one row per class the bird may enter), and a row per matched plate of eggs in the carton. A class row gives the class name, its difficulty (pet: Easy, eggs: Medium, breed: Hard), what 1st place wins (coins, plus treats in the pet class), how it is judged, "Featured: bonus prizes" when the theme features it, and the entry fee as the price button. Past shows come next.

Under them, "Village calendar" (Figtree item style): the next two village days, one line each in `label` / `inkSoft`, with when and what the day does ("The Longest Day, in 12 days (day 41). The longest day of the year. The fox stays home that night."). While the Hatch-along week is on, or a Hatch-along chick is on its way, its lines follow. Nothing here is a button.

### 9a — Morning report (sheet, large)
Opens once each morning after Sleep, before the farm. Context "Overnight" and close. Title "Day 12" (Caslon Display 38) and "Autumn morning" (Figtree 13 `inkMuted`). The quiet night and the turn of the season sit under the title. Then one section per group, split by dashed rules: Hatched, The fox, Came home, From the neighbours, Post, In the village, New at Speckle & Down, The county show, Today's jobs, Goals, In the nest boxes, Around the flock. A section has a heading (Caslon Text 18) and, where one number says it best, a count (Figtree 15): chicks hatched, birds scared, birds home, eggs laid. The lines are the game's own words (Figtree 16 `inkSoft`). Empty groups are hidden. Primary button "Back to the farm".
- The groups come from `MorningReport` in Core. Every night event lands in exactly one group, so nothing is dropped.
- While the report tells the night, that night gives no toasts. The log still has every line.
- The neighbour's words from the night (the report's "neighbour" group, lessons and show news) also come as her own note. It opens when the keeper closes the report (after the show, on a show night). With the report off, the note opens at once.
- On a show night, Show day (7a) opens after the keeper goes back to the farm.
- Settings (≡) has a "Morning report" switch. It starts on. Off: the night gives toasts as before.
- Fast forward and the test tools make no report.

### Screens with no mock
These screens exist in the app (`App/Featherwick/`) but not in the design file. They use the same tokens and components.

**Day 1** (`RootView.swift`, full screen, then `Sheets/TourSheet.swift`). First, "Henhaven", a 72pt round portrait placeholder for Hazel, her welcome in `speech`, "Hazel, over the fence", a name field (Caslon Text 30, dashed underline) and "That's me" (primary, disabled while empty). Then "Henhaven", her chick offer, three chick tiles (art placeholder and the down colour; the chosen one has a 1.5pt ink ring), "What shall we call this chick?", a name field and "Take this chick home". Then the tour sheet (detents 45% and medium): context "A walk round with Hazel", the stop's title, her words in `speech`, "Hazel · 1 of 4", "Next" (primary; "Thank you, Hazel" at the last stop) and "Skip the tour" (secondary). The farm moves to each stop's place under the sheet.

**Today** (`Sheets/JobsSheet.swift`, medium and large). Opened from the Today button. Context "Day 12, autumn", title "Today". One row per job (`item`): a filled dab when done (struck through, `inkMuted`), a dashed circle while it waits. Then the reward line in `label`. Then "This season" (`title2`): the season goal (`item`), a buff dab per step when there are 8 or fewer, "2 of 3" (`number`), and when it ends. Nothing can be failed.

**Yard** (`YardSheet`, medium and large). Context "In the yard", title "The flock". "Feed the flock" (primary; "Fed for today" when done), premium feed as a text action when there is some, the coop birds as rows (swatch, name, a short label, →), then "Wandered off" and "Staying with Hazel" when they apply.

**Breeding pen** (`Sheets/BreedingPenSheet.swift`, large). Opened from the Coop sheet. Context "In the coop", title "Breeding pen", one line on how the pen works. "Rooster" and "Hens · n of N": each place shows the bird (tap for its card) and "Take out", or a dashed empty box. Then "What might hatch" (`Sheets/WhatMightHatchSection.swift`): closed until the keeper first taps its heading; then, per penned hen, "Hen & Rooster" and one line per outcome, each with its reason a tap away (`WhyLine`). Then "From the coop": each bird that can go in, with "Pen". A bird whose sex does not show yet is never listed.

**Neighbour's note** (`Sheets/NeighbourNoteSheet.swift`, medium and large). Opens on its own (see 9a). Context "Over the back fence", title "A word over the fence", each note in `body` / `inkSoft` split by stitches. "Thank you" (primary), or, when a choice waits, one secondary button per option with its words under it, and "Decide later" (text action).

**Market board** (`Sheets/MarketBoardSheet.swift`, large). See 1a. Context "By the bakery", coin balance, title "Market board", a line in italic, "Wanted" cards split by stitches, then "Your card".

**Settings** (≡, `SettingsSheet` in `Sheets/BooksView.swift`, medium and large). Title "Henhaven", the keeper's name field, "You owe" (see 6a), "Open test tools", Sound and Haptics switches, the Morning report switch, Time of day (Game, Day, Night), beta notes (beta builds only), Fast forward ("1 day", "7 days", and "To show day" or "To the show news"), and "Start a new game".

---

## Interactions & behaviour
- **Tap place → sheet.** The place button of the panel on screen sits in the bottom row; a tap presents the matching SwiftUI sheet. Sheets dismiss by swipe or ×.
- **Day/night:** follows game time, not the device clock. Morning and afternoon use the day tokens. Evening starts a 30-minute crossfade to the night tokens. Night starts when the keeper taps Sleep and lasts until the morning report (or the farm) shows. Before the daylight lesson (day 9) there is no evening, so the farm is day until Sleep. For testing, Settings ▸ Time of day pins Day or Night (Game goes back to game time).
- **Daylight (HUD):** after the daylight lesson, the HUD shows a sun mark on a dashed track, one place per slot. Tap it for the time in words ("Afternoon. Time for 2 more errands."). The button left of "≡" says "Rest a while" until the last slot is spent, then "Sleep". A rest plays for about 4 seconds (1 second with Reduce Motion) and cannot be skipped: the sun slides one place, the light moves on, and the yard birds stop to peck. Price buttons at Speckle & Down and show entry rows disable when no slot is left, and show why. The show tip and "Enter the show" on the bird card show the reason in place of the button. "No time left" and "not evening yet" come as a note from the neighbour, not a toast.
- **Toasts:** slide down under the HUD over 250ms ease-out, fade out after 4 seconds (10 with VoiceOver).
- **Friendliness toasts:** a cuddle or treat that makes a bird tamer gives a small toast ("Juniper liked that", "Juniper enjoyed the mealworm"). A move up a friendliness band gives its own toast instead ("Juniper seems friendly now."). No action on either.
- **Buttons:** pressed scale 0.97 over 120ms. Light haptic on Cuddle and Treat.

### Birds on the farm
Until the bird art exists, birds are placeholders. In the Yard and the Far yard, each coop bird is a rigged chicken (see Chicken rig) inside the 2.5D scene. On the Barn panel, each bird is a soft blob (`BirdSwatch`). Both take their colours from the bird's real look: feather colour, comb, and lacing or barring. The colour for each look token is a placeholder in `Design/ToneColours.swift` (`Tone.artColour`), shared by both, until the art direction picks the real ones. Chicks are small, growers are medium, adults are full size.
- **Where:** coop birds stroll between the Yard and the Far yard: each bird stays 20–60 seconds on one, then walks off the shared edge (the Yard's right, the Far yard's left) and walks in on the other. Each bird has its own rhythm from its id and the clock, not the game's dice, so it is the same on every panel. Even one bird strolls. Brooder chicks sit in a dashed "brooder" box on the Barn panel. A hen's chicks go with her. They keep her stroll, so they change yards with her. At night, or with the coop door shut, the coop birds roost in rows on dashed perches on the Barn panel. Each hen's chicks roost next to her. If a chick's mother is not shown, the chick sits in the brooder box. Lost and boarding birds are not shown.
- **In the scene** (`Scene/SceneChicken.swift`): the chickens are in the scene's middle group, with the trees (see Farm scene).
  - **Ground point:** each chicken stands with its feet on one point. Its Y sets the draw order and the size (`SceneDepth`). So a chicken walks behind a tree when its feet are above the tree's base, and in front when they are below. A grown chicken is 64pt tall at the bottom of the panel and 0.45 of that at the hill line. Chicks and growers keep the blob ratios.
  - **Walking:** a chicken walks only to targets on white ground in the walk mask (`WalkMask.randomTarget`), at most 0.18 of the panel at a time. Without a mask, it stays in the old ground band. It faces the way it walks, its legs move, and it ambles at about 26pt a second at full size (slower when far). Then it stands, and sometimes pecks. The draw order changes halfway through a walk.
  - **Start:** each chicken has the same start every time, from its id, moved to the nearest walkable ground.
  - **Chicks with their mother:** a chick trails its mother. It stands a small gap behind the way she faces, one gap per chick, and the chicks step up and down in turn. About every half second it looks where she is heading and walks to its spot behind her. So it follows with a short lag. With Reduce Motion on, it stands behind her start.
  - **Strolling:** to leave, a chicken walks off the edge at its own height. It comes in on the other panel from the edge, at the nearest height where the ground at the edge is walkable.
  - **Touch:** the touch area is at least 44pt, also for a small chicken near the hill.
  - **Ripple:** tap walkable ground, not a bird. Three dashed ink rings spread from the tap over 600ms (Reduce Motion: one ring, 200ms). A light haptic plays. Each bird on the panel reacts by its friendliness band (`RippleReaction`). A wild bird runs far away. A skittish bird walks a few steps away. A friendly bird walks toward the tap and stops one body length short. A lap chicken runs to the tap and sits by it. A hen's chicks follow her. A bird that was walking stops where it is, then reacts. After 3 seconds the birds wander again. A ripple sends no command and changes nothing in the game. With Reduce Motion, no bird walks: each answers in place with a pose that fades in (200ms). A friendly bird or a lap chicken turns to the tap, and a lap chicken also sits. A wild or skittish bird turns its back on it. After 3 seconds it stands as before. The numbers are in `Scene/SceneConstants.swift`.
- **On the Barn:** birds stay in a ground band in the lower part of the panel, above the bottom row. A grown bird with a painted kit is painted at rest (see Painted parts); other birds are blobs.
- **Movement:** every 2–4 seconds a bird walks a short way slowly, or stops to peck. A bird held under a finger waits. Reduce Motion: birds stand still at their start and do not stroll. Coop birds then stay in the Yard, and with more than 6, every third bird stands in the Far yard.
- **No labels** by default. Tap a bird (a short touch, no movement) to open its bird card.
- **Petting:** press and rub a bird (3 turns back and forth, or 120pt of rubbing with one turn). One pet per press. The bird squishes and leans with the finger, then 3 small buff dabs float up. A bird already petted today only leans in. It is not an error.
- **VoiceOver:** each bird is a button named for the bird. "Pet" is an action.

### Chicken rig
Every chicken moves on one shared skeleton (`App/Featherwick/Scene/ChickenSkeleton.swift`). The skeleton is pure maths with no views, so it builds and is tested on Linux too. The path rig (simple shapes, `ChickenRig`) and each painted kit put their own art on the same bones, at their own joint positions.
- **Bones**, each turning about its own joint, relative to its parent:
  - `body`: tilts at the hip. The hip itself lifts and drops (a walking bounce, a crouch, sitting).
  - `tail`: flicks at its root. It rides on the body.
  - `neckLow`: swings at the shoulder. `neckHigh` bends at mid-neck. The head rides on them.
  - `head`: dips at the throat, and turns to look (-1 back, 0 side, 1 at the viewer). The comb, beak, eye and wattle ride on it. The eyelid grows down over the eye to blink.
  - Each leg: `thigh` (the feathered drumstick) swings at the hip, `shank` bends at the hock (backwards, as a chicken's does), `toes` curl at the foot.
- **A missing bone:** a rig need not have every bone. A part on a missing bone moves with the nearest bone above it. A one-piece leg is a stiff thigh: it swings at the hip and cannot bend.
- **Ground point:** the bottom centre of the rig's frame, between the feet. The scene places each chicken by this point.
- **Numbers:** every joint position is a fraction of the rig height (`ChickenRigMetrics`). The rig faces right; the scene mirrors it to face left.
- **Chicks** use their own build: a round ball of down, short legs, no comb. Colours come from the bird's look, as for `BirdSwatch`.
- **Motion** (`ChickenMotion`, played by `AnimatedChicken`). The motions are written once, for every rig. Each rig's own leg lengths and angles shape them.
  - **Walk:** the feet are placed, not swung. Each foot is planted for 60% of its cycle and slides back under the body. Then it lifts high with its toes curled and swings forward. A solver (two-bone inverse kinematics) finds the thigh and hock angles, so a planted foot stays planted. The body rises over each planted foot and rocks a little. The head bobs once a step: it holds still while the body walks on, then thrusts forward. The lower neck swings it, and the head turns back by the same angle, so it stays level and never leaves its neck. The tail flicks.
  - **Peck** (0.6 s): the hip crouches (the legs bend, the feet stay), the body tilts, the neck swings down and the head dips. On the path rig: 42°, 88° and 10°, with a crouch of 0.12. With these, the beak reaches the ground.
  - **Sit** (0.3 s to sit or get up): the hip drops by 85% of its height, and the legs fold under the body with the feet where they stood. A stiff leg squashes to the ground instead.
  - **Fluff follow** (`FluffFollow`): a loose part is a damped spring on its bone. It lags behind each turn, swings a little past, then settles (3 swings a second, damping 0.4). It never lags more than 20°. The lag comes from the same motion over the last 0.5 s, so it needs no saved state. A still bird has no lag. After a peck, frames run on for 0.5 s so the parts settle. On the path rig the tail and the wattle are fully loose; the wing (0.35) and the drumsticks (0.25) are a little loose. A kit part is loose when it has `follow` (see Painted parts).
  - **Idle:** a blink every 3–6 s, and sometimes a look around.
  - A still bird does not redraw. Reduce Motion: no walk cycle, peck, looks or sway. Blinks stay.
- **How a part moves:** `BoneEffect` places each part by its bone and every bone above it, as nested groups would. It is one animatable effect per part, so a pose set inside `withAnimation` eases every bone together.
- **Rig lab:** ≡ ▸ Open test tools ▸ Debug ▸ Rig lab has a slider for each bone (greyed out when the rig on the stage does not have it), the hip's lift, head turn, blink and sit. It also has a painted kit picker (none, or a body shape; a shape with no kit shows the path rig), a feather colour picker (black, blue, splash, lavender, buff, white), a pattern picker (none, lacing, barring), a "Joints" switch and "Reload kit" (see Painted parts).

#### Painted parts
A grown bird whose body shape has a kit is drawn from painted parts (`Scene/PaintedChickenRig.swift`). Without a kit, the path rig draws it. Chicks always use the path rig: there is no chick kit yet. The scene and the show podium draw through one view, `ChickenView`, which makes this choice. On the Barn and on the bird card, a bird with a kit is painted at rest. Without a kit it is a blob (Barn) or a placeholder (bird card). These two places, and the rig lab, make the choice themselves, because their fallback is not the path rig.
- **Kits:** `App/Featherwick/Art/Parts/<build>/`, one folder for each body shape (`BodyShape`). No body shape has a kit now: the path rig draws every bird. The old heavy kit (one-piece parts, no bones) was removed. Source art that is not a kit is kept outside the app, in `art-source/`. The folder goes into the app as a folder reference, so a new kit needs no project change. `PartKit` reads a kit once and keeps it.
- **Template:** `art-source/kit-template/` is a page to paint a new kit over. `template.png` shows the skeleton's bones and joints, with the path rig's parts traced under them, at canvas size. `guide-shapes.png` and `guide-bones.png` are the same layers on a clear background, to import as layers. `kit.json` there is a starter kit: every part, its bone, its pivot and its token, with the path rig's joints. `python3 scripts/make_kit_template.py` makes them from the path rig's adult build. Run it again after a change to `ChickenRigMetrics.adult`. To keep a drawing's own shape, fit the skeleton to it instead: `art-source/kit-fits/<name>/fit.json` places each joint on the silhouette, and `python3 scripts/fit_kit_template.py <folder>` makes the same files for it, plus `cut-guide.png` (where to cut each part). `python3 scripts/extract_kit_parts.py <folder>` takes the keeper's cut parts (Procreate exports in `pieces/`) off the paper and puts each on the kit canvas, ready for the kit (`parts/`).
- **Canvas:** every PNG in a kit has the same canvas (`canvas`, 2048 × 2048). `groundPoint` is the pixel between the feet. `unit` is the bird's height in pixels.
- **Frame:** the frame is the path rig's frame: `height × widthRatio` wide, with the ground point at the bottom centre. Each part image covers the whole canvas, with the canvas's ground point on the frame's ground point. So the scene places painted birds and path birds in the same way.
- **Value and alpha:** in a part PNG, RGB is a greyscale value (0 dark, 255 light) and alpha is coverage. The part's colour on screen is the token × the value, clipped to the alpha (`colorMultiply`). This is the token rule from `Look.swift`, applied to pixels. A part with `token` (comb, beak, eye, legs) takes that token. A part with no `token` on the bare leg (a shank, the toes, or the thigh of a one-piece leg, that is a leg with no shank) takes the leg token, so the legs follow the bird's genes. A thigh is the feathered drumstick, so it takes the feather token. Other parts take a feather token: the tail takes the tail token, the neck and head take the hackle, and the rest take the body feathers. `tokenScale` multiplies the token (1.07 makes the hackle a little lighter).
- **Joints:** each part names the skeleton `bone` it rides, by its name in `Bone`: `body`, `tail`, `neckLow`, `neckHigh`, `head`, `thighBack`, `shankBack`, `toesBack`, `thighFront`, `shankFront`, `toesFront`. A part with a `pivot` sets that bone's joint (in rig units: x right of the ground point, y up, in bird heights). Only one part can set each joint. Other parts on the same bone (the comb, the beak and the eye on `head`) need no pivot. A bone that no part sets is missing; parts on it ride the bone above. A leg's foot is its toes' joint. With no toes, the foot is straight below the hock, or below the hip for a one-piece leg. A part with a pivot must name a bone. A kit with no `body` joint does not load: every bird tilts at the hip. `drawOrder` is back to front. The kit's skeleton is `KitSpec.skeleton` (`Scene/KitSpec.swift`, pure, tested on Linux). No pivot is fixed in code.
- **Loose parts:** `"follow": {"amount": 1, "root": [x, y]}` makes a part loose: it sways after its bone (see Fluff follow). `amount` is 0 to 2: 1 is the full spring, less is stiffer. `root` is where the part hangs from, in rig units; without it, the part sways about its bone's joint. Good for the tail, the wattle, the hackle cape and thigh fluff. A loose part must ride a bone.
- **Names the code knows:** the parts `tail`, `neck` and `head` (for the feather token), `eye` (for the eyelid) and `comb` (for where the comb grows from). The landmarks `combBase`, `eyelidTop` and `eye`. The code uses the painted eye and comb before these landmarks.
- **Motion:** `motion` gives this build's angles: `peckBodyTilt`, `peckNeckSwing`, `peckHeadDip` and `peckCrouch` (the hip's drop, in bird heights) at the bottom of a peck. `legSwing` sets the step: a stiff leg swings that far either side. While walking, each foot steps around the middle of the two drawn feet, `footSpread` behind or in front of it (missing: 0.04 bird heights, scaled by hip height). So a kit drawn mid-stride, feet wide apart, still walks with its legs passing each other. Standing keeps the drawn feet. The path rig steps on its own drawn feet. A leg with a shank bends instead, by the same solver as the path rig. A missing angle takes the path rig's angle as it is. Only the crouch, the step and the bounce scale with this build's hip height. A kit whose neck rides on the body pecks with its head alone, at the head's pivot (`peckHeadDip`). A kit with a `neckLow` joint swings the neck by `peckNeckSwing` instead, and `peckNeckBend` bends the upper neck too. A kit with both neck bones can peck by reach instead: `peckReach` (`[x, y]`, rig units) is where the throat goes at the bottom of a peck, from its rest place. The throat goes round the base of the neck, coming a little nearer it halfway (`peckTuck`, 0.25 of the neck), and the two neck bones are solved to follow, so the head neither swings out forward nor folds the neck. `peckHeadDip` is then the head's whole turn on screen. `peckTail` turns the tail at the bottom of a peck: negative lowers it against the tilt. A heavy bird needs this neck hinge to reach the ground: with a body hinge and a head hinge only, the beak stops about halfway down. Looking narrows the head group about the head's pivot. Sitting drops the body by `sitDrop` × the body pivot's height, and the legs fold, as on the path rig. `stride` is seconds per stride (the path rig: 0.6). A slower stride takes fewer, longer steps: the step length grows with it, so the bird keeps the scene's walking speed. `glanceHeadDip` is read but not used yet: no motion dips the head to glance. The head bob needs `neckLow` and `head` bones; a kit without a neck bone does not bob.
- **Overlays:** `lacing.png` is a multiply map (RGB 255 changes nothing, darker makes the feathers darker). `barring.png` is a lighten map (RGB 255 is a full light bar, 0 changes nothing). Alpha says where each applies. An overlay is drawn only when the bird's look shows that pattern, only over the parts in its `on` list, and only inside those parts' coverage. Barring uses the bird's pattern colour. A barred chick's head spot stays on the path rig.
- **Comb:** a kit paints an adult hen's comb. The look's comb size for an adult hen is 0.6 (`PartKit.paintedCombSize`), so the comb part scales by comb size ÷ 0.6: a grown hen shows the comb as painted, a pullet's comb is smaller, and a rooster's is larger. It scales about its own painted base (the bottom centre of its alpha). A kit with no comb art uses the `combBase` landmark.
- **Eyelid:** a comb-coloured patch over the painted eye's own bounds (from the eye part's alpha). It grows down from its top edge to blink, as on the path rig. A kit with no eye part uses the `eyelidTop` landmark.
- **Working size:** at load, each PNG is made smaller once, so the bird is `PartKit.workingHeight` (512) pixels tall. The full-size PNGs stay on disk; `fullSizeImage(of:)` reads one when a larger view needs it.
- **Loading:** the app reads every kit off the main thread at launch (`PartKit.preload`). A bird that is drawn before this ends loads its kit itself.
- **Frame budget:** measured once, on an iPhone 17 on iOS 26.6.1: 10 painted birds walking with the old heavy kit (the stage below), Animation Hitches template. In a steady 8 s window: 2 hitches of 1 frame each, a hitch time ratio of 4.2 ms/s (Apple calls under 5 good), and a steady 60 fps. Over the whole 25 s recording, with app start and navigation: 18 hitches of 1 or 2 frames, 10.5 ms/s. The hitches come in groups, probably when birds turn at the edge. The target is 10 birds walking on a yard panel at 60 fps on an iPhone 12. To measure: ≡ ▸ Open test tools ▸ Debug ▸ "10 walking birds (frame budget)". It shows sample birds walking at yard size (64 pt) and speed, all the time, some laced and some barred, with a bird count (1 to 30) and a painted kit picker. It is view only: no command, no save. Profile it on that phone with Instruments, the Animation Hitches template (add the SwiftUI instrument), and record 20 s with no touches. Each painted bird is about 9 image layers with one joint effect each, plus one offscreen pass for each laced or barred part. A moving bird also works out 16 earlier poses each frame for fluff follow (pure maths, no drawing). If it drops frames, tint once instead: keep one tinted image for each part and token, at working size.
- **A broken kit:** if `kit.json` does not decode, a part has no PNG, a PNG is not the canvas size, an overlay names a part that is not in the kit, a part names an unknown bone or has a pivot but no bone, no part sets the `body` joint, two parts set one joint, a `follow` amount is not 0 to 2, or a pivot is outside the canvas, the kit does not load. The log says why, one time, and the path rig draws the bird. The app never stops because of art.
- **Checking a part:** in the rig lab, "Joints" shows the kit's pivots (dots) and landmarks (rings) at rest. "Reload kit" reads the kit again. The app bundle changes only with a build. A Debug build on the simulator reads `App/Featherwick/Art/Parts` on the Mac, so a new PNG shows at once.

### Sound and haptics
Soft and few. Settings (≡) has a switch for each; both start on.
- **Haptics:** light ticks while rubbing, a soft tap when a pet lands (a softer one when the bird only leans in), a light tap when opening a bird, a lighter tap for a ripple on the ground, success on egg collection, hatching, and coins earned or spent, a gentle warning when the game says no (not for running out of daylight).
- **Sound:** a cluck for tapping or petting a bird; egg, hatch and coin sounds for those events (`Feedback/GameFeedback.swift`). At most one of each sound per action. The `.ambient` audio session obeys the silent switch. Until the sound files exist (`App/Featherwick/Sounds/README.md`), the game is silent.
- **Unknown → known reveals** (breed, sex): show a toast ("Clover is a pullet", "Lavender … added to the Breed Book"). The design also animates the dashed outline to a filled state (~400ms); the app does not do this yet.
- **Reduce Motion:** replace slides and scales with fades.
- **VoiceOver:** every dab or dot group reads as text ("Friendliness: friendly, 3 of 4"). Carton cups read "Blue egg, fertile".

## Farm scene (2.5D)
The Yard and the Far yard draw a 2.5D scene (`App/Featherwick/Scene/`). The art is a placeholder: a basic hill and sky, simple tree shapes and grass tufts. But it uses the same tools as the real paintings will. The Barn and the Shop stay flat colours for now.

**One landscape.** The Yard and the Far yard are one landscape, side by side. The script paints both as one wide picture and cuts it in two, so the hills, sky and grass meet at the join without a seam. They share one hill line and one tree line: a tree near the join shows on both panels. Lower trees stand only by the outer edges, never at the join.

**Three rules.** Each thing in the scene has a ground point: a bird's feet, a trunk's base. Its Y on screen sets everything (`SceneDepth`).
- **Draw order = ground Y.** Lower on screen is nearer, so it draws on top. A bird walks behind a tree while its feet are above the tree's base, and in front when they are below.
- **Size = ground Y.** Things are smallest at the hill line (scale 0.45) and full size at the bottom edge (1.0). A bird that walks up the yard gets smaller. The two numbers are `SceneDepth.farScale` and `nearScale`.
- **Walk area = a mask.** White ground is walkable; black is not (sky, hills, the pond, the ground kept for the coop run and the back fence, the strip under the buttons). Birds pick targets only inside white (`WalkMask.randomTarget`).

**Three layer groups.**
1. **Back:** sky, far hills and the yard ground, from one landscape PNG. Never sorted.
2. **Middle:** the trees and the birds, in one stack, each sorted by its ground Y (`.zIndex(depth.zIndex(forGroundY:))`). Fences and the coop will join them when they are drawn; for now the walk mask only keeps their ground clear.
3. **Front:** grass tufts along the bottom edge. Always on top.

**Trees.** Five designs (`TreeKind`: oak, poplar, pine, apple, birch), each a trunk and a canopy in separate materials. Code places them along the hill line with random spacing, size and left/right flip, plus one or two lower in the yard near the outer edges (`TreeLine.makeJoined`). The dice are seeded per panel, never the game's, so a panel always has the same trees. A new panel gets its own tree line with no new painting. Each tree sways slowly on its own about its trunk base. Reduce Motion: no sway.

**Colour: ramps and masks.** The art holds value (light and dark) and material, not colour. One shader (`SeasonRamp.metal`) maps each value along the ramp of its material for the season (`SeasonRamp.swift`). So one painting serves every season:
- Spring: fresh green. Summer: deep green. Autumn: gold grass under red and orange trees. Winter: pale.
- Each tree turns its leaf hue a little, so autumn trees differ. Pines are evergreen.
- Night: the same shader takes colour out and multiplies a blue-grey, as on the flat panels.

**Art files.** Per panel, two PNGs in `App/Featherwick/Art/Scene/`:
- `scene-<panel>-land.png` (660 × 1434, half of a 1320 × 2868 screen). R = value. G and B = two material bits: 00 sky, 10 far hill, 11 grass, 01 pond. Neighbouring materials differ in one bit, so a soft edge never mixes in a third. Drawn trees and tufts use the same channels (trees: 00 leaves, 10 trunk, 11 evergreen).
- `scene-<panel>-walk.png` (220 × 478, greyscale): the walk mask.
- The scene stretches both to the panel, so the hill line and the mask are fractions of the screen.

The masks are made once, before the build, by a script. The app only loads the PNGs. To change the art, edit and run:

```sh
python3 scripts/make_scene_art.py   # needs Pillow and numpy; same output every run
```

It also writes `Scene/SceneArtLayout.swift` (hill line and building ground per panel), so code and art agree. Commit the PNGs and that file together.

**Performance.** Nothing in the scene runs on a timer. Only the tree sway animates (one repeating animation per tree). A redraw every second made swiping between panels stutter.

## State (sketch)
The designers' model. The app reads Core's `GameState` instead.
- `GameClock`: day number, season, time of day, `isNight`.
- `Wallet`: coins, treats.
- `Bird`: id, name?, breed? (nil until revealed), sex? (nil until revealed), featherColour, eggColour, friendliness (0–3), ageStage (0–2), ageDays, parents, location.
- `Egg`: id, colour, shade, mother, candled (`.notCandled / .fertile / .clear`).
- `Collections`: found breeds, found feather colours per breed, found egg shades.
- `PlaceNotices`: per place, a list of `.collect(count) / .decision / .story`.
- `Dialogue`: current neighbour storyline, line index, pending gifts.

## Assets
- **Fonts:** Libre Caslon Display, Libre Caslon Text, Figtree (Google Fonts, SIL OFL). The TTFs and their licences are bundled in `App/Featherwick/Fonts/` and registered at launch (`Typeface.registerBundledFonts`).
- **To be painted by the bird artist** (replace the procedural stand-ins): 6–8 small watercolour dabs (round, ~64px @3x, in feather, egg and buff tones), used for friendliness, age and swatches.
- **Placeholders to be replaced with commissioned art:** farm scene (day and night), bird art (chick, adolescent, adult per breed and colour), neighbour portraits, shop front, shop item art.
- The feather and egg glyphs are simple vector shapes, built as SwiftUI `Shape`s (`FeatherShape`, `EggShape` in `Design/Marks.swift`).
- **Scene art:** placeholder landscape and walk-mask PNGs in `App/Featherwick/Art/Scene/`, made by `scripts/make_scene_art.py` (see Farm scene).
- **Sounds:** none yet. `App/Featherwick/Sounds/README.md` lists the files to add.

## Files
- `Featherwick UI System v4.dc.html`: **the current design.** Open it directly in a browser.
- `screenshots/`: one PNG per mocked screen (1a, 1b, 2a, 2b, 3a, 4a, 4b, 5a, 6a, 7a, 8a), named to match the screen IDs above. Screens 4c–4e and 9a have none.
- `support.js`: runtime needed to open the `.dc.html` file. It is not part of the design.
- In the app: tokens in `App/Featherwick/Design/Theme.swift`, components in `Design/Components.swift` and `Design/Marks.swift`, screens in `Farm/` and `Sheets/`.
