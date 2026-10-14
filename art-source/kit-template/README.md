# Kit template

A page to paint a new kit over. It is the adult skeleton at a kit's canvas size, facing right. Made by
`python3 scripts/make_kit_template.py` from the path rig's adult build. Do not edit these files by hand: run
the script again.

| File | What |
| --- | --- |
| `template.png` | Everything on paper: grid, part shapes, bones, joints, labels and a key. |
| `guide-shapes.png` | The part shapes only, on a clear background. |
| `guide-bones.png` | The bones, joints and labels only, on a clear background. |
| `template.svg` | The same, as vectors. One group for each layer: grid, shapes, bones, key. |
| `kit.json` | A starter kit: every part, its bone, its pivot, its token and its follow. |

## How to use it

1. Make a new 2048 × 2048 canvas. Import `guide-shapes.png` and `guide-bones.png` as two layers. Put the
   bones on top, at low opacity.
2. Paint each part on its own layer. Use the names in `kit.json` (`body`, `wing`, `thighFront`...). The
   shapes are a guide: change them as you like.
3. Paint across each dashed ring. When two parts meet at a joint, both must cover the ring, so a turn
   shows no gap.
4. Paint in grey: the value is the shade, and the game adds the colour. Export each part as a 2048 × 2048
   PNG with a clear background (`body.png`, `wing.png`...).
5. Copy `kit.json` and the PNGs to `App/Featherwick/Art/Parts/<build>/`. Set `"build"` to that body shape
   (`heavy`, `medium`, `light` or `fluffy`).

## Change a joint

A pivot is in rig units: x is right of the ground point, y is up, in bird heights. To read a pivot from a
pixel: x = (pixel x − 1088) ÷ 1600, y = (1840 − pixel y) ÷ 1600. One grid square is 0.1.

When you move a joint, change the `pivot` of the part that sets it in `kit.json`. Then check the bird in
the rig lab ("Joints" shows each pivot).

## Parts you can leave out

- `hackle`: without it, no part sets the `neckHigh` joint. The whole neck then bends at `neckLow` only.
- `toesBack`, `toesFront`: without them, each foot is straight below its hock.
- `shankBack`, `shankFront`: without them, the thigh is a one-piece stiff leg. Paint the whole leg on it.

Remove a part from both `parts` and `drawOrder`. The full format is "Painted parts" in
`docs/design/README.md`.
