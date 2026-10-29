# Kit fits

A fit puts the kit skeleton on a keeper's own silhouette. The joints move to the art, so the art keeps its
shape. Each folder is one fit. `python3 scripts/fit_kit_template.py <folder>` makes its files from its
`fit.json`.

| File | What |
| --- | --- |
| `source.jpg` | The silhouette as drawn. Warm on pale paper. |
| `fit.json` | Joints, the wing and wattle roots, the tail's aim, cut lines and part names, in the source's pixels. |
| `silhouette-2048.png` | The silhouette on a kit canvas (2048 × 2048), with its feet on the ground point. |
| `guide-bones.png` | The bones, joints and rings on a clear background. |
| `template.png` | Grid, silhouette and bones. |
| `cut-guide.png` | Where to cut the silhouette into parts. |
| `kit.json` | The starter kit, with this fit's pivots. |
| `pieces/` | The keeper's cut parts, as Procreate exports (one part on each, paper erased round it). |
| `parts/` | A whole kit: each cut part on the kit canvas (grey value and alpha), and a `kit.json` with only the parts cut so far. Copy the folder to the app. |
| `parts-colour/` | The same parts in their own colour, to paint on further. |
| `parts-preview.png` | Every cut part in colour over the faint silhouette and the joints. |

## How to use a fit

1. Import `silhouette-2048.png` into a 2048 × 2048 canvas as the base layer.
2. Cut each part on its own layer, along the red lines in `cut-guide.png`. Use the names in `kit.json`.
3. At each cut, paint the part underneath on past the line, to the dashed ring. The part on top gets a
   soft, feathery edge. The thighs paint up under the body to the hip rings.
4. Copy `kit.json` and the PNGs to `App/Featherwick/Art/Parts/<build>/`. Set `"build"` to that body shape.

To move a joint or a cut line, change `fit.json` (source pixels: x right, y down) and run the script again.

## Cut parts

Export each cut part from Procreate as its own image, with the source image where it was. List them in
`fit.json` under `pieces` > `files`, then run:

    python3 scripts/extract_kit_parts.py art-source/kit-fits/hen

The script takes out any paper that is left, finds where the source image sits on the exports, and puts
each part on the kit canvas. A part's soft edges stay soft. Only the crisp edges (the silhouette's own
outline) are used to find the place, so long soft cuts do not pull it. Small specks of other parts left on
an export are dropped.

A part cut out of another one leaves a hole in it. The best fix is in the art: paint the part underneath
on, behind the cut part (the hen's body now runs down behind her drumsticks). Where that is not done yet,
`pieces` > `underfill` fills the hole with the cut part's shape (pulled in by `inset` export pixels), so a
swinging part never shows the background behind it. `drawOrder` in `fit.json` sets this drawing's own order; the
hen's back drumstick draws in front of her filled body.

`pieces` > `caps` gives a part that turns a long way (the neck in a peck) a disc round its joint, in its
own colour, cut to the bird's outline at rest. A disc looks the same at any turn, so the joint never opens.
`motion` in `fit.json` goes into `kit.json` as it is: this bird's own peck and walk (see "Painted parts" in
`docs/design/README.md`).

A part painted into another one (the hen's wattle is in her head) is split out by `pieces` > `splits` in
`fit.json`: `take` is its shape and `leave` is what the other part loses, both in source pixels. The other
part keeps a band under the join, so the split part can swing with no hole behind it.

## Auto cut (test)

A test: cut the silhouette into parts with a script, not by hand. Run:

    python3 scripts/cut_kit_parts.py art-source/kit-fits/hen

The script uses the cut lines in `fit.json`. Each line end runs on until it meets the outline or another
cut, so a line drawn a little short still closes its part. Each part fills from its label point in
`regions`. If that point is off the silhouette, the nearest silhouette pixel is used. To set the point,
add it to `seeds` (source pixels). Split parts (the wattle) and caps work as in the hand pipeline.

The output goes into `auto/`: the same `parts/`, `parts-colour/` and `parts-preview.png` as a hand cut.
`auto/compare.png` shows the auto cut, with the pixels that differ from the hand cut in red. The script
prints a score for each part.

The cuts are hard: no part is painted on under the next one yet. A hand-cut part on top runs past its
line with a soft edge. The auto cut stops on the line.

Hen, first run: 91.2% of the silhouette matches the hand cut. Past a 24 px band each side of the cuts,
96.8% matches. The remaining misses are hand parts painted far past their line (the back thigh up toward
the hip, the neck down over the body).

## Fits

- `hen/`: the first hen silhouette (14 Oct 2026). 11 joints. No wing in the silhouette: paint a `wing`
  inside the body, or leave it out of `kit.json`. Cut so far (14): `body`, `tail`, `neck`, `hackle`,
  `head`, `comb`, `wattle` (split from the head), `beak`, `thighBack`, `thighFront`, `shankBack`,
  `shankFront`, `toesBack`, `toesFront`. Not cut yet: `eye`, `wing`. `parts/` loads as a kit now: with no
  eye part, the bird does not blink.
- `hen-b/`: the same hen silhouette, cut along other lines (17 Oct 2026). A larger head, a band of neck
  under the hackle, and drumsticks that hang below the body. It uses the `hen` fit's joints and kit.json.
  The cuts come as slices, not Procreate exports: see "Slices" below.

## Slices

A slice is one part, cropped, hard-edged and in colour, cut from a silhouette that already sits on the kit
canvas. `slices/slices.json` gives the canvas, the ground point and each part's place (x, y, w, h). The
fit's `fit.json` names the fit whose joints the slices were cut on (`slices` > `from`), and the draw order.
Run:

    python3 scripts/make_kit_from_slices.py art-source/kit-fits/hen-b

Each part runs on under the parts drawn in front of it, `band` canvas pixels past the join, so a part that
turns shows no gap. Where a slice is already painted on under its neighbour (the body under the neck, the
tail and the drumsticks), its own paint stays. `caps` work as in the hen fit. `motion` in `fit.json`
replaces those keys of the hen's motion. The script writes `parts/` (a whole kit) and `parts-preview.png`
(each part in its own colour, bands and caps lighter, over the bones).

hen-b's peck sends the throat forward (`peckReach` 0.45, -0.8) and tips the body 40°. With the hen's reach
(throat straight down), the lower neck turns about 130° against the body at the bottom of the peck. Its
neck part runs down the front of the breast, so that block flips up over the back as a box. With the throat
forward, the lower neck turns about 55°, and the neck tips down in one line.

`round` gives a part a rounded end: its cut becomes an arc round its own joint, from edge to edge, filled
with the paint of the other part (`from`). As the part turns, its end slides along itself, so it never lifts
out of the outline as a step. The radius reaches the far end of the cut, or `radius` (canvas pixels). A part
in front (the neck over the body) grows to the arc. A part behind (the tail under the body) takes the body's
paint inside the arc, and the body is cut back to the arc. hen-b rounds four ends, so it needs no caps:

| Part | Joint | From | Radius |
| --- | --- | --- | --- |
| `neck` | `neckLow` | `body` | 270 px |
| `hackle` | `neckHigh` | `neck` | 182 px |
| `head` | `head` | `hackle` | 170 px |
| `tail` | `tail` | `body` | 120 px |

The tail's cut runs from the back (110 px from its joint) down to the rump (440 px). An arc that reaches the
rump gives the tail half the body: it opens a step on the back in the peck and sways in the walk. So the
tail's arc rounds only the top, where the back line is.

Paint added under a join or in an arc takes the slices' own paper there, so it keeps the texture.
