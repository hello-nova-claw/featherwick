#!/usr/bin/env python3
"""Makes a whole kit from a keeper's slices: one cropped, hard-edged PNG per part, cut from a silhouette
that already sits on the 2048 kit canvas.

A slice folder holds `slices.json` (the canvas, the ground point, and each part's place: x, y, w, h) and one
PNG per part, in colour. The fit folder holds `fit.json` with the joints, in the source's pixels, and
`slices` > `from` names the fit whose skeleton the slices were cut on. This script:

1. Puts each slice on the kit canvas, at its place, with its edge softened a little.
2. Paints each part on under the parts drawn in front of it, `band` canvas pixels past the join (only where
   that part is), so a part that turns never shows a gap. A part the slices already run on under (the body
   under the neck, tail and thighs) keeps its own paint there.
3. Gives each part in `caps` a disc round its joint, cut to the bird's outline at rest, as the hen fit does.
4. Writes the kit:
   - parts/<name>.png         grey value (the game adds the colour) and alpha coverage
   - parts/kit.json           the skeleton fit's kit.json, with this fit's build and draw order
   - parts-preview.png        every part in colour, the bands and caps shown faintly behind

    python3 scripts/make_kit_from_slices.py art-source/kit-fits/hen-b
"""

import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

# The bird's height in canvas pixels, as in every kit.
UNIT = 1600
# The kit's value for the slices' mean colour: light, so the token colour shows, with the texture kept.
# The same as `extract_kit_parts.py`.
VALUE = 230
# How soft a slice's own edge is, in canvas pixels: enough to take the stair steps off a hard cut.
SOFT = 1.0
# Two parts touch when they come this close, in canvas pixels.
TOUCH = 3


def dilate(mask, r):
    """The mask grown by r pixels (a square reach). Worked on the mask's own box: far faster on a big canvas."""
    ys, xs = np.nonzero(mask)
    out = np.zeros_like(mask)
    if not len(ys):
        return out
    y0, y1 = max(ys.min() - r, 0), min(ys.max() + r + 1, mask.shape[0])
    x0, x1 = max(xs.min() - r, 0), min(xs.max() + r + 1, mask.shape[1])
    img = Image.fromarray((mask[y0:y1, x0:x1] * 255).astype("uint8"))
    while r > 0:
        step = min(r, 3)
        img = img.filter(ImageFilter.MaxFilter(2 * step + 1))
        r -= step
    out[y0:y1, x0:x1] = np.asarray(img) > 127
    return out


def disc(centre, r, shape):
    ys, xs = np.ogrid[: shape[0], : shape[1]]
    d = np.hypot(xs - centre[0], ys - centre[1])
    return np.clip(r + 1.5 - d, 0, 1)


def main(folder):
    fit = json.load(open(os.path.join(folder, "fit.json")))
    sl = fit["slices"]
    slice_dir = os.path.join(folder, sl["folder"])
    meta = json.load(open(os.path.join(slice_dir, "slices.json")))
    skeleton = os.path.join(os.path.dirname(os.path.normpath(folder)), sl["from"])
    bones = json.load(open(os.path.join(skeleton, "fit.json")))
    size = meta["canvas"]
    shape = (size[1], size[0])

    # 1. Each slice on the canvas: colour, and hard coverage softened at its edge.
    colour, solid = {}, {}
    for name, p in meta["pieces"].items():
        img = np.asarray(Image.open(os.path.join(slice_dir, name + ".png")).convert("RGBA")).astype(float)
        rgb = np.zeros(shape + (3,))
        a = np.zeros(shape, bool)
        rgb[p["y"]:p["y"] + p["h"], p["x"]:p["x"] + p["w"]] = img[..., :3]
        a[p["y"]:p["y"] + p["h"], p["x"]:p["x"] + p["w"]] = img[..., 3] > 127
        colour[name], solid[name] = rgb, a
    order = [n for n in fit["drawOrder"] if n in solid]
    missing = sorted(set(solid) - set(order))
    if missing:
        sys.exit("parts not in drawOrder: " + ", ".join(missing))
    mean = np.mean([colour[n][solid[n]].mean(0) for n in order], 0)

    # 2. Under each join, the part behind runs on under the part in front, inside that part only.
    band = sl["band"]
    cover = {n: solid[n].copy() for n in order}
    for i, back in enumerate(order):
        near = dilate(solid[back], TOUCH)
        reach = dilate(solid[back], band)
        for front in order[i + 1:]:
            if (near & solid[front]).any():
                cover[back] |= reach & solid[front]

    # Kit canvas from the skeleton fit's source pixels.
    gx, gy = bones["groundPoint"]
    cx, cy = bones["canvasGroundPoint"]
    k = UNIT / bones["height"]

    def canvas(p):
        return (cx + (p[0] - gx) * k, cy + (p[1] - gy) * k)

    alpha = {n: np.asarray(Image.fromarray((cover[n] * 255).astype("uint8")).filter(
        ImageFilter.GaussianBlur(SOFT))) / 255 for n in order}

    # 3. Joint caps, cut to the outline at rest.
    outline = np.maximum.reduce([alpha[n] for n in order])
    for name, cap in sl.get("caps", {}).items():
        d = disc(canvas(bones["joints"][cap["joint"]]), cap["radius"] * k, shape) * outline
        alpha[name] = np.maximum(alpha[name], d)

    # Where a band or a cap adds paint, it takes the part's own mean colour (the slices are flat).
    out = os.path.join(folder, "parts")
    os.makedirs(out, exist_ok=True)
    lum = np.array([0.299, 0.587, 0.114])
    preview = Image.new("RGBA", (size[0], size[1]), (246, 241, 231, 255))
    for name in order:
        own = colour[name][solid[name]].mean(0)
        rgb = np.where(solid[name][..., None], colour[name], own)
        grey = np.clip(rgb @ lum / (mean @ lum) * VALUE, 0, 255)
        kit = np.dstack([grey, grey, grey, alpha[name] * 255]).astype("uint8")
        Image.fromarray(kit, "RGBA").save(os.path.join(out, name + ".png"), optimize=True)
        # Preview: each part in its own hue so the cuts show, bands and caps lighter.
        hue = np.array(sl["previewColours"].get(name, [200, 160, 120]), float)
        tint = np.where(solid[name][..., None], hue, hue * 0.55 + 255 * 0.45)
        layer = np.dstack([tint, alpha[name] * 255]).astype("uint8")
        preview = Image.alpha_composite(preview, Image.fromarray(layer, "RGBA"))

    spec = json.load(open(os.path.join(skeleton, "kit.json")))
    spec["build"] = fit["build"]
    spec["parts"] = {n: spec["parts"][n] for n in order}
    spec["drawOrder"] = order
    with open(os.path.join(out, "kit.json"), "w") as f:
        json.dump(spec, f, indent=2)
        f.write("\n")
    guide = os.path.join(skeleton, "guide-bones.png")
    if os.path.exists(guide):
        preview.alpha_composite(Image.open(guide).convert("RGBA"))
    preview.convert("RGB").save(os.path.join(folder, "parts-preview.png"), optimize=True)
    print("wrote", len(order), "parts to", os.path.relpath(out))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: make_kit_from_slices.py <fit folder>")
    main(sys.argv[1])
