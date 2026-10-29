#!/usr/bin/env python3
"""Cuts a fit's silhouette into kit parts along the cut lines in fit.json, with no hand cutting.

A test of the hand pipeline (scripts/extract_kit_parts.py). This script:

1. Unmixes the source into kraft and paper, as the hand pipeline does, so the soft outline stays.
2. Draws each cut line (`cuts`) as a wall, run on at both ends to the outline or the next cut, and floods
   each part from a point inside it (`seeds`, else its label point in `regions`). Wall pixels go to the
   nearest part.
3. Softens each cut by SOFT source pixels. The parts still add up to the silhouette.
4. Takes out the split parts (`pieces` > `splits`) and adds the joint caps (`pieces` > `caps`), and writes the kit into `<folder>/auto/`: parts/,
   parts-colour/ and parts-preview.png, the same files as the hand pipeline.
5. Scores the cut against the hand cut in `<folder>/parts/`, if there is one: for each part, how much of
   the silhouette both put on top, and the same past a band (BAND) each side of the cuts, where a hand
   part's soft edge runs over. Writes auto/compare.png: the auto cut, with the misses in red.

The cuts are hard: no part is painted on under the next one yet.

    python3 scripts/cut_kit_parts.py art-source/kit-fits/hen
"""

import json
import math
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

import extract_kit_parts as x  # noqa: E402

# How far past its ends a cut line may run, in source pixels, to reach the outline or another cut.
EXTEND = 200
# The wall's width, in source pixels.
WALL = 3
# How soft a cut is, in source pixels (a Gaussian radius).
SOFT = 1.5
# Coverage above this is labelled; the rest is clear paper.
FLOOR = 0.02
# The score's band each side of a cut, in kit-canvas pixels. A hand cut part on top runs past its line by
# about this much (its soft edge), so a miss inside the band is a soft edge, not a cut in the wrong place.
BAND = 24


def walls(fit, cover):
    """Every cut line as a wall (0) on an open page (255). A line drawn for a person may stop short of the
    outline or the next cut, so each end runs on, in its own direction, until it meets one of them."""
    img = Image.new("L", (cover.shape[1], cover.shape[0]), 255)
    draw = ImageDraw.Draw(img)
    # A split part (the wattle) comes out after the cut, by its `take` shape, so its cut lines are left out.
    splits = fit["pieces"].get("splits", {})
    lines = [[np.array(p, float) for p in points] for key, points in fit["cuts"].items()
             if not splits.keys() & set(key.split(" | "))]
    for pts in lines:
        draw.line([tuple(p) for p in pts], fill=0, width=WALL)
    page = np.asarray(img.copy())
    h, w = cover.shape
    for pts in lines:
        for end, inner in ((0, 1), (-1, -2)):
            d = pts[end] - pts[inner]
            d /= np.linalg.norm(d)
            reach = EXTEND
            for step in range(WALL + 1, EXTEND):
                q = np.round(pts[end] + d * step).astype(int)
                if not (0 <= q[0] < w and 0 <= q[1] < h) or cover[q[1], q[0]] <= FLOOR or page[q[1], q[0]] == 0:
                    reach = step + WALL
                    break
            draw.line([tuple(pts[end]), tuple(pts[end] + d * reach)], fill=0, width=WALL)
    return np.asarray(img) > 0


def label(fit, cover):
    """Each pixel's part (an index into the region names, -1 for paper)."""
    names = [n for n in fit["regions"] if n not in fit["pieces"].get("splits", {})]
    seeds = {**fit["regions"], **fit.get("seeds", {})}
    inside = cover > FLOOR
    open_ = inside & walls(fit, cover)
    # Flood from each label point. PIL's flood fill is fast; 255 is open, 0 is wall or paper, i + 1 is part i.
    page = Image.fromarray((open_ * 255).astype("uint8")).copy()  # fromarray shares read-only memory
    for i, name in enumerate(names):
        px, py = (round(v) for v in seeds[name])
        if not open_[py, px]:
            ys, xs = np.nonzero(open_)
            k = np.argmin((xs - px) ** 2 + (ys - py) ** 2)
            print("%s: label point (%d, %d) is off the silhouette; using (%d, %d)" % (name, px, py, xs[k], ys[k]))
            px, py = xs[k], ys[k]
        if page.getpixel((px, py)) != 255:
            sys.exit("%s: its label point is in %s's part. A cut line does not close." % (
                name, names[page.getpixel((px, py)) - 1]))
        ImageDraw.floodfill(page, (px, py), i + 1)
    labels = np.asarray(page).astype(int) - 1
    labels[~open_ | (labels == 254)] = -1
    if len(open_.nonzero()[0]) and (labels[open_] == -1).mean() > 0.01:
        print("warning: %.1f%% of the silhouette has no label point" % (100 * (labels[open_] == -1).mean()))

    # Walls and stray bits go to the nearest part, one pixel ring at a time.
    for _ in range(200):
        todo = inside & (labels == -1)
        if not todo.any():
            break
        grown = labels.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            moved = np.roll(labels, (dy, dx), (0, 1))
            take = (grown == -1) & (moved >= 0)
            grown[take] = moved[take]
        labels = np.where(todo, grown, labels)
    return names, labels


def split(names, labels, colour, cover):
    """Each part's colour and coverage. Each cut is soft, and the parts add up to the whole cover."""
    weights = []
    for i in range(len(names)):
        one = Image.fromarray(((labels == i) * 255).astype("uint8"))
        weights.append(np.asarray(one.filter(ImageFilter.GaussianBlur(SOFT))) / 255)
    total = np.maximum(sum(weights), 1e-6)
    return {name: (colour, cover * w / total) for name, w in zip(names, weights)}


def on_canvas(fit):
    """The affine map from kit canvas to source pixels, for Image.transform."""
    gx, gy = fit["groundPoint"]
    cx, cy = fit["canvasGroundPoint"]
    k = x.UNIT / fit["height"]
    return (1 / k, 0, gx - cx / k, 0, 1 / k, gy - cy / k)


def top_part(folder, order):
    """Which part shows on top at each kit-canvas pixel (-1 for none), from a parts/ folder."""
    top = np.full((x.CANVAS, x.CANVAS), -1)
    for i, name in enumerate(order):
        path = os.path.join(folder, name + ".png")
        if os.path.exists(path):
            top[np.asarray(Image.open(path))[..., 3] > 127] = i
    return top


def compare(folder, out):
    hand_dir, auto_dir = os.path.join(folder, "parts"), os.path.join(out, "parts")
    if not os.path.exists(os.path.join(hand_dir, "kit.json")):
        return
    order = json.load(open(os.path.join(hand_dir, "kit.json")))["drawOrder"]
    hand, auto = top_part(hand_dir, order), top_part(auto_dir, order)
    both = hand >= 0
    edge = np.zeros(auto.shape, bool)
    for shift in ((1, 0), (0, 1)):
        edge |= auto != np.roll(auto, shift, (0, 1))
    near = np.asarray(Image.fromarray((edge * 255).astype("uint8")).filter(ImageFilter.MaxFilter(2 * BAND + 1))) > 0
    far = both & ~near
    print("\npart          agree  past the bands  (of the silhouette the hand cut gives this part)")
    for i, name in enumerate(order):
        mine = both & (hand == i)
        if mine.any():
            rest = far & (hand == i)
            print("%-12s %5.1f%%  %5.1f%%" % (name, 100 * (auto[mine] == i).mean(),
                                              100 * (auto[rest] == i).mean() if rest.any() else 100))
    print("all          %5.1f%%  %5.1f%%" % (100 * (auto[both] == hand[both]).mean(),
                                            100 * (auto[far] == hand[far]).mean()))

    # The auto cut in soft colours, the misses in red.
    rng = np.random.default_rng(7)
    tints = rng.integers(120, 240, (len(order), 3))
    page = np.full((x.CANVAS, x.CANVAS, 3), 250, "uint8")
    page[auto >= 0] = tints[auto[auto >= 0]]
    page[both & (auto != hand)] = (200, 30, 30)
    Image.fromarray(page).save(os.path.join(out, "compare.png"), optimize=True)
    print("wrote", os.path.relpath(os.path.join(out, "compare.png")))


def main(folder):
    fit = json.load(open(os.path.join(folder, "fit.json")))
    pieces = fit["pieces"]
    paper, kraft = np.array(pieces["paper"], float), np.array(pieces["kraft"], float)
    colour, cover = x.unmix(os.path.join(folder, fit["source"]), paper, kraft)
    names, labels = label(fit, cover)
    parts = split(names, labels, colour, cover)
    x.add_splits(parts, fit, (1, 0, 0, 0))
    x.add_caps(parts, fit, (1, 0, 0, 0))
    out = os.path.join(folder, "auto")
    x.write_kit(folder, out, parts, on_canvas(fit), kraft)
    compare(folder, out)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: cut_kit_parts.py <fit folder>")
    main(sys.argv[1])
