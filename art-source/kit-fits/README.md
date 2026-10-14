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

A part painted into another one (the hen's wattle is in her head) is split out by `pieces` > `splits` in
`fit.json`: `take` is its shape and `leave` is what the other part loses, both in source pixels. The other
part keeps a band under the join, so the split part can swing with no hole behind it.

## Fits

- `hen/`: the first hen silhouette (14 Oct 2026). 11 joints. No wing in the silhouette: paint a `wing`
  inside the body, or leave it out of `kit.json`. Cut so far (14): `body`, `tail`, `neck`, `hackle`,
  `head`, `comb`, `wattle` (split from the head), `beak`, `thighBack`, `thighFront`, `shankBack`,
  `shankFront`, `toesBack`, `toesFront`. Not cut yet: `eye`, `wing`. `parts/` loads as a kit now: with no
  eye part, the bird does not blink. 
