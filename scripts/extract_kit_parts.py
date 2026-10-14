#!/usr/bin/env python3
"""Lifts a keeper's cut parts off the paper and puts each on the kit canvas, at the fit's place.

Each part is a Procreate export (`fit.json` > `pieces` > `files`): the fit's source image placed on a
canvas, with one part kept and the paper around it erased (some paper may stay). This script:

1. Unmixes each pixel into kraft and paper, so leftover paper drops out and the part's own soft edges stay.
2. Finds where the source image sits on the export (scale, turn and shift), by matching the parts' outer
   edges to the source silhouette's edge.
3. Writes each part on the 2048 kit canvas, in the same place as `silhouette-2048.png`:
   - parts/<name>.png         kit-ready: grey value (the game adds the colour) and alpha coverage
   - parts-colour/<name>.png  the same part in its own colour, to paint on further
   - parts-preview.png        every part in colour over the faint silhouette and the joints

    python3 scripts/extract_kit_parts.py art-source/kit-fits/hen
"""

import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

CANVAS = 2048
UNIT = 1600
# Kraft-ness: below LOW a pixel is paper, above LOW + RAMP it is all part. The ramp keeps the paper's
# texture from punching holes in the part.
LOW, RAMP = 0.35, 0.35
# The kit's value for the part's mean colour: light, so the token colour shows, with the texture kept.
VALUE = 230
# Edge match: distances are capped. SHARE is the part of the crisp edge points that counts (all of them:
# `outline` already leaves out the soft cut edges).
CAP, SHARE = 20, 1.0
# An edge is crisp when the coverage goes from almost none to almost all within 5 px.
CRISP = 200


def silhouette(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(int)
    return (a[..., 0] - a[..., 2] > 40) & (a[..., 0] < 230)


def edge_distance(mask):
    img = Image.fromarray((mask * 255).astype("uint8"))
    edge = np.asarray(img.filter(ImageFilter.MaxFilter(3))) != np.asarray(img.filter(ImageFilter.MinFilter(3)))
    dist = np.full(mask.shape, CAP, float)
    grow = Image.fromarray((edge * 255).astype("uint8"))
    for r in range(CAP):
        hit = np.asarray(grow) > 0
        dist[hit & (dist == CAP)] = r
        grow = grow.filter(ImageFilter.MaxFilter(3))
    return dist


def unmix(path, paper, kraft):
    """The part's colour and coverage, with the paper taken out."""
    a = np.asarray(Image.open(path).convert("RGBA")).astype(float)
    rgb, layer = a[..., :3], a[..., 3] / 255
    d = kraft - paper
    t = ((rgb - paper) @ d) / (d @ d)
    cover = layer * np.clip((t - LOW) / RAMP, 0, 1)
    colour = paper + (rgb - paper) / np.maximum(t, LOW)[..., None]
    return np.clip(colour, 0, 255), cover


def outline(cover):
    """The part's crisp edge points: its outline from the silhouette. Soft eraser edges (the cuts) change
    slowly, so they are left out of the fit."""
    m = Image.fromarray(((cover > 0.5) * 255).astype("uint8"))
    edge = np.asarray(m.filter(ImageFilter.MaxFilter(3))) != np.asarray(m.filter(ImageFilter.MinFilter(3)))
    c = Image.fromarray((cover * 255).astype("uint8"))
    spread = np.asarray(c.filter(ImageFilter.MaxFilter(5))).astype(int) - np.asarray(c.filter(ImageFilter.MinFilter(5)))
    ys, xs = np.nonzero(edge & (spread > CRISP))
    return np.stack([xs, ys], 1).astype(float)


def to_source(points, p):
    s, turn, tx, ty = p
    c, sn = math.cos(turn), math.sin(turn)
    x, y = (points[:, 0] - tx) / s, (points[:, 1] - ty) / s
    return np.stack([c * x + sn * y, -sn * x + c * y], 1)


def fit_placement(points, dist, start):
    def score(p):
        q = np.round(to_source(points, p)).astype(int)
        h, w = dist.shape
        d = dist[np.clip(q[:, 1], 0, h - 1), np.clip(q[:, 0], 0, w - 1)]
        d.sort()
        return d[: int(len(d) * SHARE)].mean()

    p, steps = np.array(start, float), np.array([0.01, math.radians(0.3), 6, 6])
    best = score(p)
    while steps[2] > 0.25:
        better = False
        for k in range(4):
            for sign in (1, -1):
                q = p.copy()
                q[k] += sign * steps[k]
                sc = score(q)
                if sc < best:
                    best, p, better = sc, q, True
        if not better:
            steps /= 2
    return p, best


def start_guess(export_size, source_size):
    """The source image fills the export, a little turned: Procreate's usual import."""
    return [export_size / source_size * 0.96, math.radians(1.0), export_size * 0.025, export_size * 0.007]


def main(folder):
    fit = json.load(open(os.path.join(folder, "fit.json")))
    pieces = fit["pieces"]
    paper, kraft = np.array(pieces["paper"], float), np.array(pieces["kraft"], float)
    mask = silhouette(os.path.join(folder, fit["source"]))
    parts = {name: unmix(os.path.join(folder, f), paper, kraft) for name, f in pieces["files"].items()}

    size = next(iter(parts.values()))[1].shape[0]
    points = np.concatenate([outline(cover) for _, cover in parts.values()])
    placement, err = fit_placement(points, edge_distance(mask), start_guess(size, mask.shape[0]))
    s, turn, tx, ty = placement
    print("placement: scale %.4f, turn %.2f°, shift (%.1f, %.1f), edge error %.2f px"
          % (s, math.degrees(turn), tx, ty, err))

    # Kit canvas -> source -> export, as one affine map for Image.transform.
    gx, gy = fit["groundPoint"]
    cx, cy = fit["canvasGroundPoint"]
    k = UNIT / fit["height"]
    c, sn = math.cos(turn), math.sin(turn)
    a, b, d, e = s / k * c, -s / k * sn, s / k * sn, s / k * c
    ox, oy = gx - cx / k, gy - cy / k
    affine = (a, b, s * (c * ox - sn * oy) + tx, d, e, s * (sn * ox + c * oy) + ty)

    for sub in ("parts", "parts-colour"):
        os.makedirs(os.path.join(folder, sub), exist_ok=True)
    mean = (kraft * [0.299, 0.587, 0.114]).sum()
    preview = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    for name, (colour, cover) in parts.items():
        rgba = np.dstack([colour, cover * 255]).astype("uint8")
        placed = Image.fromarray(rgba, "RGBA").transform(
            (CANVAS, CANVAS), Image.AFFINE, affine, resample=Image.BICUBIC)
        placed.save(os.path.join(folder, "parts-colour", name + ".png"), optimize=True)
        arr = np.asarray(placed).astype(float)
        grey = arr[..., :3] @ [0.299, 0.587, 0.114] / mean * VALUE
        kit = np.dstack([np.repeat(np.clip(grey, 0, 255)[..., None], 3, 2), arr[..., 3]]).astype("uint8")
        Image.fromarray(kit, "RGBA").save(os.path.join(folder, "parts", name + ".png"), optimize=True)
        preview = Image.alpha_composite(preview, placed)

    base = Image.open(os.path.join(folder, "template.png")).convert("RGBA")
    veil = Image.new("RGBA", base.size, (246, 241, 231, 150))
    page = Image.alpha_composite(Image.alpha_composite(base, veil), preview)
    page.alpha_composite(Image.open(os.path.join(folder, "guide-bones.png")).convert("RGBA"))
    page.save(os.path.join(folder, "parts-preview.png"), optimize=True)
    print("wrote", len(parts), "parts to", os.path.relpath(folder))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: extract_kit_parts.py <fit folder>")
    main(sys.argv[1])
