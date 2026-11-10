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
3. Gives each part in `round` a rounded end: an arc round its joint, edge to edge, from the part behind.
4. Cuts each part in `limbs` down to a rounded drumstick along its bone, and gives what lay outside it to a
   part that does not turn with the leg. Gives each part in `knobs` a round end at its joint.
5. Gives each part in `caps` a disc round its joint, cut to the bird's outline at rest, as the hen fit does.
6. With `feather`, softens every edge inside the bird, so where one part turns over another no hard line shows.
7. Writes the kit:
   - parts/<name>.png         grey value (the game adds the colour) and alpha coverage
   - parts/kit.json           the skeleton fit's kit.json, with this fit's build, draw order and motion
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


def segment(a, b, shape):
    """Each pixel's distance to the segment a-b, and how far along it (0 at a, 1 at b) its nearest point is."""
    ys, xs = np.ogrid[: shape[0], : shape[1]]
    vx, vy = b[0] - a[0], b[1] - a[1]
    t = np.clip(((xs - a[0]) * vx + (ys - a[1]) * vy) / (vx * vx + vy * vy), 0, 1)
    return np.hypot(xs - (a[0] + t * vx), ys - (a[1] + t * vy)), t


def blur(mask, r):
    return np.asarray(Image.fromarray((mask * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(r))) / 255


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
        img = np.asarray(Image.open(os.path.join(slice_dir, name + ".png")).convert("RGBA"))
        rgb = np.zeros((*shape, 3), dtype=np.uint8)
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

    # A rounded end: the part's cut becomes an arc round its own joint, edge to edge, so as the part turns
    # its end slides along itself and never lifts out of the outline as a step. The radius reaches the far
    # end of the cut (or `radius`, in canvas pixels); the arc is filled with the other part's own paint.
    # A part in front (the neck over the body) just grows to the arc. A part behind (the tail under the
    # body) takes the body's visible paint inside the arc, and the body is cut back to the arc, so the arc
    # is what shows.
    bird = np.maximum.reduce([solid[n] for n in order])
    outside = dilate(~bird, 2)
    for name, end in sl.get("round", {}).items():
        jx, jy = canvas(bones["joints"][end["joint"]])
        donor = end["from"]
        behind = order.index(name) < order.index(donor)
        front, back = (donor, name) if behind else (name, donor)
        cut = dilate(solid[front], 1) & ~solid[front] & solid[back] & outside
        ys, xs = np.nonzero(cut)
        radius = end["radius"] if "radius" in end else np.hypot(xs - jx, ys - jy).max()
        inside = disc((jx, jy), radius, shape) > 0.5
        take = inside & solid[donor] & ~solid[name]
        if behind:
            # The donor goes inside the arc, also where it was painted over this part, but not under the
            # parts drawn in front of it.
            over = np.maximum.reduce([solid[n] for n in order[order.index(donor) + 1:]])
            lose = inside & ~over
            # This part's paint runs a few pixels past the arc, under the donor's soft edge, so the two soft
            # edges do not meet on one line and leave a light hairline.
            take = (disc((jx, jy), radius + 4, shape) > 0.5) & solid[donor] & ~solid[name] & ~over
            solid[donor] &= ~lose
            cover[donor] &= ~lose
        colour[name][take] = colour[donor][take]
        solid[name] |= take
        cover[name] |= take
        print("round end: %s, %.0f px round %s" % (name, radius, end["joint"]))

    # A limb: a wide band of thigh fluff turned with the leg swings its far ends out of the outline. So the
    # part keeps only a drumstick round its bone, from its joint (`from`) to the next one down (`to`), `top`
    # canvas pixels each side at the top and `bottom` at the bottom, with round ends. The drumstick runs up
    # inside the body to the hip, so its top turns out of sight. The whole band also goes to `rest`, a part
    # that does not turn with the leg: it stays put, and the drumstick swings over it with no hole behind.
    for name, limb in sl.get("limbs", {}).items():
        d, t = segment(canvas(bones["joints"][limb["from"]]), canvas(bones["joints"][limb["to"]]), shape)
        core = d <= limb["top"] + (limb["bottom"] - limb["top"]) * t
        rest = limb["rest"]
        band_only = solid[name] & ~solid[rest]
        colour[rest][band_only] = colour[name][band_only]
        solid[rest] |= solid[name]
        cover[rest] |= cover[name]
        solid[name] &= core
        cover[name] = core
        print("limb: %s, %s to %s, the rest to %s" % (name, limb["from"], limb["to"], rest))

    # A knob: a leg part's top becomes a disc round its joint, `radius` canvas pixels, so as the joint bends
    # the top turns on itself and no corner shows. Its paint above the joint, outside the disc, goes. (A leg
    # part hangs down from its joint, so "above" is up the canvas.)
    rows = np.arange(shape[0])[:, None]
    for name, knob in sl.get("knobs", {}).items():
        jx, jy = canvas(bones["joints"][knob["joint"]])
        ball = disc((jx, jy), knob["radius"], shape) > 0.5
        cut = (rows < jy) & ~ball
        solid[name] &= ~cut
        cover[name] = (cover[name] & ~cut) | ball
        print("knob: %s, %d px round %s" % (name, knob["radius"], knob["joint"]))

    # Under a soft join the part behind must stay solid, or two half-clear edges leave a light line: each
    # part runs on `feather` canvas pixels under every part in front of it.
    feather = sl.get("feather", 0)
    if feather:
        for i, back in enumerate(order[:-1]):
            front = np.maximum.reduce([cover[n] for n in order[i + 1:]])
            cover[back] |= dilate(cover[back], feather) & front

    alpha = {n: blur(cover[n], SOFT) for n in order}

    # 3. Joint caps, cut to the outline at rest.
    outline = np.maximum.reduce([alpha[n] for n in order])
    for name, cap in sl.get("caps", {}).items():
        d = disc(canvas(bones["joints"][cap["joint"]]), cap["radius"] * k, shape) * outline
        alpha[name] = np.maximum(alpha[name], d)

    # Soft joins: inside the bird, each part's edge fades over about `feather` canvas pixels, so where one
    # part turns over another no hard line or step shows. Near the bird's outline at rest the edge stays as
    # crisp as the slice, and so do the parts in `crisp` (a comb or wattle is drawn with a hard edge).
    if feather:
        bird = np.maximum.reduce([cover[n] for n in order])
        crisp = blur(dilate(~bird, feather), feather / 2)
        for n in order:
            if n in sl.get("crisp", []):
                continue
            alpha[n] = alpha[n] * crisp + blur(cover[n], feather / 2) * (1 - crisp)

    # Where a band or a cap adds paint, it takes the slices' own paper there (whichever slice shows at that
    # spot), so it keeps the texture; outside every slice, the part's mean colour.
    paper = np.zeros(shape + (3,))
    seen = np.zeros(shape, bool)
    for n in order:
        paper[solid[n]] = colour[n][solid[n]]
        seen |= solid[n]
    out = os.path.join(folder, "parts")
    os.makedirs(out, exist_ok=True)
    lum = np.array([0.299, 0.587, 0.114])
    preview = Image.new("RGBA", (size[0], size[1]), (246, 241, 231, 255))
    for name in order:
        own = colour[name][solid[name]].mean(0)
        rgb = np.where(solid[name][..., None], colour[name], np.where(seen[..., None], paper, own))
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
    # This fit's own motion numbers replace the skeleton fit's, one key at a time.
    spec["motion"] = {**spec.get("motion", {}), **fit.get("motion", {})}
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
