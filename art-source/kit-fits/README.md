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

## How to use a fit

1. Import `silhouette-2048.png` into a 2048 × 2048 canvas as the base layer.
2. Cut each part on its own layer, along the red lines in `cut-guide.png`. Use the names in `kit.json`.
3. At each cut, paint the part underneath on past the line, to the dashed ring. The part on top gets a
   soft, feathery edge. The thighs paint up under the body to the hip rings.
4. Copy `kit.json` and the PNGs to `App/Featherwick/Art/Parts/<build>/`. Set `"build"` to that body shape.

To move a joint or a cut line, change `fit.json` (source pixels: x right, y down) and run the script again.

## Fits

- `hen/`: the first hen silhouette (14 Oct 2026). 11 joints. No wing in the silhouette: paint a `wing`
  inside the body, or leave it out of `kit.json`.
