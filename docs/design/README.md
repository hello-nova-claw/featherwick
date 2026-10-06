# Handoff: Featherwick UI system

## Overview
Featherwick is a calm, cozy chicken-keeping game for iPhone (portrait, one-handed). The player keeps a backyard flock at their farm, Henhaven, and hatches eggs to fill three collections: breeds, feather colours and egg colours. There is no combat and no death.

This package covers the **menu layer only**: type, colour, spacing, components, sheets and screen layouts. The farm scene, chickens, portraits and backgrounds are hand-painted watercolour sprites made separately. In the mocks they appear as dashed placeholder boxes labelled "farm scene", "bird art", "portrait", "item" and so on.

Architecture: **SwiftUI menus over a SpriteKit farm scene.** The farm is 4 painted panels side by side; swipe left or right between them. Left to right: Barn (Coop, Potting shed), Yard (Yard), Far yard (Back fence), Shop (Farm gate). The game opens on the Yard. Each place opens a SwiftUI bottom sheet.

## About the design files
The `.dc.html` file in this bundle is a **design reference built in HTML**. It is not production code. Recreate the designs natively in **SwiftUI** using its own patterns (`.sheet` with `presentationDetents`, `Font.custom(_:size:relativeTo:)`, asset-catalog colours with light and dark variants, and so on). Do not embed the HTML.

Open `Featherwick UI System v4.dc.html` in a browser; it renders on its own. It is a single scrolling canvas with: intro, Pigments (colour), Type, Marks & components, Screens (1a, 1b, 2a, 2b) and Screens continued (3a–8a).

## Fidelity
**High fidelity** for colour, type, spacing, radii, line styles and layout. Treat hex values, sizes and spacing as final.

Exceptions:
- **Watercolour dabs** (friendliness, age and the colour-section swatches) are procedural SVG-filter stand-ins. In the shipped game they should be **painted by the bird artist** and used as image assets (see Assets).
- All bird, scene, portrait and shop art are placeholders.
- Copy for Mabel, Mr Alder, shop items and judge's notes is placeholder writing. Keep the tone, not necessarily the words.

---

## Design principles
1. **White paper, ink, small dabs of watercolour.** Backgrounds are pure `#FFFFFF`. Colour appears only where it describes a bird or an egg: feathers, eggs, friendliness, age and notices. Everything else is ink.
2. **No large washes, no gradients, no glossy shadows.** Separation comes from white space and dashed rules, not boxes.
3. **Dashed "stitch" lines** are the signature mark. They are used for underlines, dividers, unknown or not-yet states, and tap-area outlines.
4. **Names and speech are serif (Libre Caslon). Everything you read or count is sans (Figtree).**
5. **Never colour alone.** Every state also has a word, a shape (filled or hollow, solid or dashed) or a position.

---

## Design tokens

### Colour — day (default, 06:00–17:59)
| Token | Hex | Use |
|---|---|---|
| `paper` | `#FFFFFF` | All sheet and page backgrounds |
| `ink` | `#2A2320` | Primary text, primary button fill, filled marks, outlines on swatches |
| `inkSoft` | `#5A4D45` | Secondary body text, quiet actions (Rename, Later) |
| `inkMuted` | `#7A6A5F` | Labels, captions, unselected tabs (4.6:1 on white) |
| `hairline` | `#E6DCCF` | Secondary button outline, dashed row dividers |
| `hairlineSoft` | `#ECE5DB` | Sheet grabber |
| `unknown` | `#C9BBAE` | Dashed "not yet" outlines, `?` glyph |
| `unknownBox` | `#D8CDBF` | Dashed outline of unfound collection tiles and the egg carton |
| `artPlaceholder` | `rgba(122,106,95,0.30)` | 1px dashed outline of art placeholders |
| `coin` | `#D6A65E` | Coin disc |
| `scrim` | farm dimmed to ~`#DDD8D0` | Background behind open sheets (implement as a dim layer over the scene) |

Underline and selected-tab stroke: `ink` at 50–75% opacity (`rgba(42,35,32,.5)` for headline underlines, `.75` for tab underlines).

### Colour — night (18:00–05:59, ~30 min crossfade)
| Token | Hex |
|---|---|
| `paper` | `#1B1817` |
| `ink` | `#F3EEE6` |
| `inkMuted` | `#C2B6AA` |
| `coin` | `#E8C894` |
| Place-label / HUD backing | `rgba(27,24,23,0.88)` |
| Toast | background `#F3EEE6`, text `#1B1817` (inverts against the night scene) |

Implement as asset-catalog colours with an "Any / Dark" pair, driven by the game clock rather than system appearance (or both, per product decision).

### Feather colours (swatch fill, always with name beside)
| Name | Hex |
|---|---|
| Black | `#2A2320` |
| Blue | `#7E8F9C` |
| Splash | pale grey `#D6DBDE` with blue `#7E8F9C` flecks |
| Lavender | `#B5AEBB` |
| Buff | `#DDAE6E` |

### Egg colours
| Name | Base hex | Shade range used in Egg Book |
|---|---|---|
| Cream | `#EFE3CB` | `#F6EEDD`, `#EFE3CB`, `#E6D5B4` |
| Brown | `#A86E45` | `#C99A73`, `#A86E45`, `#8A5534`, `#6B3E25` |
| Blue | `#B4CFCB` | `#CFE0DD`, `#B4CFCB` |
| Olive | `#868755` | with darker speckles `#5C5D37` so it never reads as brown |

### Typography
Fonts (Google Fonts, OFL): **Libre Caslon Display**, **Libre Caslon Text** (regular and italic), **Figtree** (300, 400, 500).
Enable ligatures on serif text (`liga`, `dlig`, `hlig`). Libre Caslon has only a few, which is fine.

| Style | Font | Size / line height | SwiftUI `relativeTo:` | Use |
|---|---|---|---|---|
| display | Libre Caslon Display 400 | 54 / 1.0 | `.largeTitle` | Bird name on bird card |
| title | Libre Caslon Display 400 | 36–44 / 1.05 | `.largeTitle` | Sheet titles (Breed Book, Today's eggs, Speckle & Down) |
| title2 | Libre Caslon Display 400 | 28–32 / 1.15 | `.title` | Naming question, HUD "Day 12" |
| speech | Libre Caslon Text italic 400 | 24 / 1.3 | `.title2` | Neighbour dialogue |
| epithet | Libre Caslon Text italic 400 | 19–21 / 1.3 | `.title3` | Breed line ("a Buff Orpington hen"), grade word |
| place | Libre Caslon Text 400 | 18 | `.title3` | Tap-place labels on farm (upright, not italic) |
| item | Libre Caslon Text 400 | 15–22 | `.headline` | Collection names, shop items, Egg Book rows |
| body | Figtree 400 | 16–17 / 1.55 | `.body` | Body copy, values |
| action | Figtree 500 | 15–17 | `.body` | Button labels, selected tab |
| label | Figtree 400 | 13 | `.footnote` | Field labels, captions (sentence case, never all caps) |
| caption | Figtree 400 | 12 | `.caption` | Legends, notice text under place labels |
| number | Figtree 500, `.monospacedDigit()` | 15–16 | `.body` | Coins, treats, counts |

Minimum size 12pt. All styles must scale with Dynamic Type. At accessibility sizes, two-column fact grids collapse to one column and button rows stack.

### Spacing (pt)
4, 8, 12, 16, 24, 32.
- Sheet side padding: **28–32**
- Sheet bottom padding: **36** (clears home indicator)
- Gap between fact rows in bird card grid: **26 vertical / 16 horizontal**
- Collection grid: 3 columns, **24 vertical / 14 horizontal**

### Radii
| Element | Radius |
|---|---|
| Sheet (top corners) | 30 |
| Buttons, toasts, place labels, HUD boxes, price buttons | **10** (no pills) |
| Collection tiles, art placeholders | 12–16 |
| Egg carton tray | 14 |
| Swatches, dots, grade ring | full circle |
| Eggs | `50% 50% 50% 50% / 60% 60% 40% 40%` (egg shape) |

### Lines
- **Dashed stitch:** 1.3pt, `hairline` (`#E6DCCF`), for row dividers.
- **Dashed underline:** 1.5–2pt, ink at 50%. Under display names it is drawn as a text decoration with *skip-ink off*, so descenders (the g in Marigold, the p in Pip) cross through the line. In SwiftUI, draw a dashed `Path` at the baseline + ~5pt **behind** the text, not `underline()`.
- **Unknown outline:** 1–1.2pt dashed `unknown` (`#C9BBAE`).
- **Tap-area outlines** on the farm mocks (1px dashed) are for the SpriteKit team only and are **not drawn in the game**.

### Shadows
Only on floating elements over the farm scene (place labels, HUD, toast):
`0 4px 14px -8px rgba(42,35,32,0.35)`; night toast `0 18px 40px -16px rgba(0,0,0,0.8)`.
No shadows inside sheets.

---

## Components

**Primary button**: `ink` fill, white Figtree 500 17pt label, radius 10, min height 52. Pressed: scale 0.97, fill slightly lighter. Only one per screen.

**Secondary button**: white fill, 1pt inset `hairline` outline, ink label, radius 10, height 52.

**Text action**: Figtree 400 15pt `inkSoft`, min 44×44 hit area (Rename, Family tree, Later, Candle the rest).

**Disabled**: drop the fill, keep a dashed outline, and change the label to say why ("No treats left").

**Tabs / filters**: plain words, 44pt tall. Selected is `ink`, weight 500, with a 2pt dashed underline. Unselected is `inkMuted`, weight 400.

**Close**: "×" Figtree 300 26pt `inkMuted` in a 44×44 hit area, top-right of every sheet.

**Sheet**: white, top radius 30, grabber 36×4 `hairlineSoft`. Detents: medium and large. The farm stays visible above, dimmed.

**HUD** (farm): top-left white box (radius 10) holding "Day 12" (Caslon Display 28) and "Autumn · morning" (Figtree 13 `inkSoft`). Top-right white box with coins (gold disc + number) and treats (ink diamond rotated 45° + number). Each count is a 44pt hit area. VoiceOver reads "1,248 coins, 6 treats".

**Place label** (farm): white box at 88–92% opacity, radius 10, place name in Libre Caslon Text 18. Optional notice line underneath: an 8pt dot plus Figtree 12 text.
- Things to collect: brown egg dot, "3 eggs waiting"
- Decisions: buff dot, "a bird needs a name"
- Story: ink dot, "has news"
The text always carries the meaning; the dot only draws the eye.

**Toast**: white (day) or cream (night) rectangle, **radius 10, not pill-shaped**, a small egg or bird glyph, a Figtree 15 sentence, and one action on the right ("View", "Name her"). Appears under the HUD, stays 4 seconds (longer with VoiceOver), at most two stacked.

**Friendliness**: 4 dabs, 16pt, in order wild → skittish → friendly → lap chicken. Earned dabs are filled with watercolour; the rest are dashed `unknown` circles. The stage name is always written underneath.

**Age**: 3 dots of growing size (8, 12, 17pt) for chick → pullet/cockerel → hen/rooster. Filled up to the current stage, dashed after. The stage is written out ("Hen, 8 months").

**Feather swatch (inline)**: a feather outline (1pt ink stroke, filled with the feather colour) 14×24, plus the name.

**Egg swatch (inline)**: an egg shape 14×18 with a 1pt ink inset outline, filled with the egg colour, plus text ("Brown eggs").

**Collection tile**: square art with a 1px dashed placeholder and radius 12, the name in Libre Caslon Text 15, and a row of 8pt colour dots: filled for colours found, dashed for colours still to find. Unfound breed: the tile shows a `?` in `unknown`, with a one-line italic hint ("lays blue eggs").

**Grade**: a 128pt circle drawn as a 1.3pt dashed ink ring, score in Caslon Display 48 with "of 100" underneath, grade word in italic, then a 4-step scale (Fair, Good, Very good, Excellent). Reached steps are solid 2pt ink lines and the current one is labelled in weight 500; unreached steps are dashed `unknown`.

**Dialogue**: a 72pt round portrait overlapping the sheet's top edge, a "Mabel, over the fence" label, the speech in Caslon italic 24, any gift line, then replies as full-width 52pt rows split by dashed rules, each with a → on the right.

---

## Screens

All screens are 393×852 (iPhone 15/16). Sheets sit over the dimmed farm.

### 1a / 1b — Farm (day / night)
- Full-bleed painted scene (SpriteKit).
- HUD top-left and top-right (see Components), 58–62pt from top.
- 4 panels to swipe between: Barn, Yard, Far yard, Shop. Until the paintings exist, each panel is a flat colour with a dashed "scene" box.
- Place labels on each panel, each anchored to the bottom-centre of its tap area. Barn: Coop and Potting shed. Yard: Yard. Far yard: Back fence. Shop: Farm gate.
- Panel rail: a white box down the right side, under the HUD, with one dot per panel in swipe order. Tap a dot to go there. The current panel is an ink dot. A panel off screen with a notice gets a bigger dot in its notice colour (decision, then collect, then story) with a ring. Others are small `unknown` dots. VoiceOver reads the panel name and its notices.
- Bottom: "Books" (Caslon Display 23) bottom-left, then "Today", and a settings button "≡" bottom-right, all white boxes with radius 10, 56pt tall, 24pt above the home indicator.
- Books appears when the early game introduces the Breed Book (the `breedBook` lesson, the morning the first chick's sex shows). Until then, an "added to the Breed Book" toast has no "View". "≡" is always there.
- Today shows how many of today's jobs are left in a buff badge. When all are done, the badge goes: "Today" turns `inkMuted`, with an ink tick and "Done" (Figtree 13). VoiceOver reads "Today, all jobs done".
- Farm gate notice "new in today": stock the early game brought in this morning. It goes when the keeper opens the Farm gate or buys something there. The app keeps what was seen (per save slot); the game does not.
- Night: same layout with night tokens. Place labels can show state ("5 asleep"). A toast example: "A chick has hatched" with the action "Name her".

### 2a / 2b — Bird card (sheet, top at 92pt)
Top to bottom:
1. Grabber, then a context line ("In the yard · 1 of 6") and close.
2. Art area, 240pt tall, art centred (placeholder 200×180).
3. Name, centred, Caslon Display 54, with a dashed underline that descenders cross. Then the breed line in italic ("a Buff Orpington hen" or, for an unknown breed, "breed still a mystery").
4. A 2×2 fact grid: Friendliness · Age · Feathers · Lays (hen) or Hen or rooster (chick: "Shows in ~6 days").
5. Ribbons, only after the bird has been to a show: one line per show, newest first ("1st of 8 · Orpington class, day 84, Harvest Show"). The top three get an ink rosette (1st filled, 2nd outlined, 3rd dashed).
6. Bottom: Cuddle (primary) and Treat (secondary, shows "· 6" remaining) side by side, then Rename and Family tree as text actions. "Enter the show" opens the class choice (see 8a). Each counts once a day per bird. When done today, the button is disabled and says so: "Cuddled today", "Had a treat today" (like "Fed for today" in the yard).
7. Toasts show over the bird card too, so the keeper sees what a cuddle or treat did.
Swipe left or right moves between birds in the same place.

### 3a — Naming prompt (sheet, top at 330pt)
Chick art, "Just hatched in the brooder", the question "What shall we call her?", an editable name field (Caslon Text 30) pre-filled with a suggestion, a dashed underline, and "A suggestion. Try another". Primary button "Name her Clover" (the label repeats the current name). Text action "Later" keeps the "needs a name" notice on the shed.

### 4a — Breed Book (full screen)
Tabs "Breeds | Eggs", close. Title "Breed Book", progress "7 of 24 breeds, 12 of 120 colours". A 3-column grid of collection tiles in a fixed order, so gaps show where unfound breeds belong.

### 4b — Egg Book (full screen)
Same header with the Eggs tab selected. "9 of 20 shades found". One row per egg colour (Cream, Brown, Blue, Olive): name and "n of 5", then 5 egg shapes, filled if found and dashed if not. An italic hint appears on rows that are still empty.

### 5a — Egg carton (sheet, top at 140pt)
Title "Today's eggs", filters (All 7 / Fertile / Clear / Not candled). The carton is a 6×2 grid of 1pt cups inside a dashed tray. Candling mark on each cup: **filled ink dot = fertile, hollow ring = clear, no mark = not candled**, with a legend underneath. Tap cups to choose eggs (1.5pt ink ring); tap again to put one back. One egg chosen: the detail row shows a large egg, "Blue egg" and "From Juniper. Fertile, candled this morning." More than one: "3 eggs chosen". Actions act on exactly the chosen eggs: **Set 3 to hatch** (primary) and **Sell 3** (secondary with price). With none chosen, the secondary is **Sell all**. Before the keeper learns to candle, an unknown egg shows "?" in its cup, the legend says "?: can't tell yet" and the filters are hidden. After the lesson, choose one egg that is not candled and tap "Candle this egg". Setting eggs never candles them: an egg that is not candled goes in, and a clear one comes back on hatch day. When the chosen eggs cannot hatch, replace the Set to hatch button with the reason (clear egg, room for 2 more). With no incubator, there is no Set to hatch button. The potting shed shows no incubator and no hint about one until the keeper has one. The incubator takes more eggs on the same day until it is full.

### 6a — Back fence (sheet, top at 420pt)
See Dialogue. Tapping a reply advances the conversation ("1 of 3"). Gifts are added to the inventory with a toast.

### 7a — Show day (full screen)
Opens over the farm on the morning of a show. A place sheet closes first. Context "The county show, day 84" and close, a show-tent art area, the theme name ("Harvest Show") with a dashed underline, and the featured kind ("Featured: breed classes, bonus prizes"). Then one section per class: the class name (Caslon Display 30), "Hard class" (and "featured" when it is), and each of your entries split by dashed rules: rosette, name, "72 of 100", the placing ("1st of 8", "4th of 6, no ribbon"), what it won, and the judge's notes in italic. The judge's notes appear only here. Then "Taken home" with coins and treats, and the primary button "Back to the farm". With no entries, the page says "You didn't enter this time." and gives the next show day.

### 8a — Speckle & Down (sheet, top at 92pt)
Context "In the village", coin balance and close. A painted shop front (130pt), the title, an italic greeting from the shopkeeper, and tabs Feed / Treats / Hatching / Show. Item rows are 72pt: a 48pt item art, name (Caslon Text 17) with a one-line description, and a price button (coin dot + number, secondary style). If the player can't afford an item, its price button is disabled and says "Not enough coins".

The Show tab: the next show's theme name and day, the entry fee, and the featured kind. Then what is entered, a row per bird that can go (tap → a sheet with one row per class the bird may enter), and a row per matched plate of eggs in the carton. A class row gives the class name, its difficulty (pet: Easy, eggs: Medium, breed: Hard), what 1st place wins (coins, plus treats in the pet class), "Featured: bonus prizes" when the theme features it, and the entry fee as the price button. Past placings are listed last.

---

## Interactions & behaviour
- **Tap place → sheet.** SpriteKit hit-tests the tap area and presents the matching SwiftUI sheet. Sheets dismiss by swipe or ×.
- **Day/night:** follows the device clock. Tokens crossfade over 30 minutes at 18:00 and 06:00.
- **Toasts:** slide down under the HUD over 250ms ease-out, fade out after 4 seconds.
- **Friendliness toasts:** a cuddle or treat that makes a bird tamer gives a small toast ("Juniper liked that", "Juniper enjoyed the mealworm"). A move up a friendliness band gives its own toast instead ("Juniper seems friendly now."). No action on either.
- **Buttons:** pressed scale 0.97 over 120ms. Light haptic on Cuddle, Treat and Set to hatch.

### Birds on the farm
Until the bird art exists, each bird is a soft blob (`BirdSwatch`): feather colour, comb, and lacing or barring from its real look. Chicks are small, growers are medium, adults are full size.
- **Where:** birds stay in a ground band in the lower part of each panel, below the place labels and above Books and ≡. Coop birds stroll between the Yard and the Far yard: each bird stays 20–60 seconds on one, then walks off the shared edge (the Yard's right, the Far yard's left) and walks in on the other. Each bird has its own rhythm from its id and the clock, not the game's dice, so it is the same on every panel. Even one bird strolls. Brooder chicks and hen chicks sit in a dashed "brooder" box on the Barn panel. At night, or with the coop door shut, the coop birds roost in rows on dashed perches on the Barn panel. Lost and boarding birds are not shown.
- **Movement:** every 2–4 seconds a bird walks a short way slowly, or stops to peck (a small bob). A bird held under a finger waits. Reduce Motion: birds stand still and do not stroll. Coop birds then stay in the Yard, and with more than 6, every third bird stands in the Far yard.
- **No labels** by default. Tap a bird (a short touch, no movement) to open its bird card.
- **Petting:** press and rub a bird (3 turns back and forth, or 120pt of rubbing with one turn). One pet per press. The bird squishes and leans with the finger, then 3 small buff dabs float up. A bird already petted today only leans in. It is not an error.
- **VoiceOver:** each bird is a button named for the bird. "Pet" is an action.

### Sound and haptics
Soft and few. Settings (≡) has a switch for each; both start on.
- **Haptics:** light ticks while rubbing, a soft tap when a pet lands, a light tap when opening a bird, success on egg collection and hatching, a gentle warning when the game says no.
- **Sound:** a cluck for tapping or petting a bird; egg, hatch and coin sounds for those events. At most one of each sound per action. The `.ambient` audio session obeys the silent switch. Until the sound files exist (`App/Featherwick/Sounds/README.md`), the game is silent.
- **Unknown → known reveals** (breed, sex): animate the dashed outline to a filled state (~400ms), then show a toast ("Lavender added to the Breed Book").
- **Reduce Motion:** replace slides and scales with fades.
- **VoiceOver:** every dab or dot group reads as text ("Friendliness: friendly, 3 of 4"). Carton cups read "Blue egg, fertile".

## State (sketch)
- `GameClock`: day number, season, time of day, `isNight`.
- `Wallet`: coins, treats.
- `Bird`: id, name?, breed? (nil until revealed), sex? (nil until revealed), featherColour, eggColour, friendliness (0–3), ageStage (0–2), ageDays, parents, location.
- `Egg`: id, colour, shade, mother, candled (`.notCandled / .fertile / .clear`).
- `Collections`: found breeds, found feather colours per breed, found egg shades.
- `PlaceNotices`: per place, a list of `.collect(count) / .decision / .story`.
- `Dialogue`: current neighbour storyline, line index, pending gifts.

## Assets
- **Fonts:** Libre Caslon Display, Libre Caslon Text, Figtree (Google Fonts, SIL OFL). Bundle the TTFs in the app.
- **To be painted by the bird artist** (replace the procedural stand-ins): 6–8 small watercolour dabs (round, ~64px @3x, in feather, egg and buff tones), used for friendliness, age and swatches.
- **Placeholders to be replaced with commissioned art:** farm scene (day and night), bird art (chick, adolescent, adult per breed and colour), neighbour portraits, shop front, shop item art.
- The feather and egg glyphs are simple vector shapes. Recreate them as SwiftUI `Shape`s.

## Files
- `Featherwick UI System v4.dc.html`: **the current design.** Open it directly in a browser.
- `screenshots/`: one PNG per screen (1a–8a), named to match the screen IDs above.
- `support.js`: runtime needed to open the `.dc.html` file. It is not part of the design.
- `reference/` holds earlier explorations (v1–v3), superseded, for context only.
- `reference/inspiration.png`: the chicken illustrations the palette and stitch marks were drawn from.
