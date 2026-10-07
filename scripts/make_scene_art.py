#!/usr/bin/env python3
"""Make the placeholder farm-scene art for the Yard and Far yard panels.

Run from the repository root (Python 3, Pillow and numpy):

    python3 scripts/make_scene_art.py

The Yard and the Far yard are one landscape: the script paints both as one wide picture and cuts it
in two, so they join without a seam. It writes, for each panel (`yard`, `far-yard`):

- `App/Featherwick/Art/Scene/scene-<panel>-land.png`: the landscape, 660 x 1434 px (half of a
  1320 x 2868 iPhone screen), RGB. R is the value (shading, 0 = dark, 1 = light). G and B are two
  material bits, 0 or 255 (soft only at edges):
      G=0 B=0 sky, G=255 B=0 far hill, G=255 B=255 grass, G=0 B=255 pond.
  Neighbouring materials differ in one bit, so a blended edge pixel mixes only those two.
  The app's `seasonRamp` shader turns value + material into colour through a season ramp.
- `App/Featherwick/Art/Scene/scene-<panel>-walk.png`: the walk mask, 220 x 478 px, greyscale.
  White = chickens can walk. Black = sky, hills above the hill line, the pond, the reserved
  ground for a building, and a strip at the bottom under the buttons.

It also writes `App/Featherwick/Scene/SceneArtLayout.swift`: the hill line and reserved ground per
panel, so the code and the art agree. Do not edit that file by hand.

The output is deterministic: the same script always makes the same files.
"""

import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART_DIR = os.path.join(ROOT, "App", "Featherwick", "Art", "Scene")
SWIFT_OUT = os.path.join(ROOT, "App", "Featherwick", "Scene", "SceneArtLayout.swift")

# Output size (half of a 1320 x 2868 screen) and the 2x working size (for soft material edges).
OUT_W, OUT_H = 660, 1434
SS = 2
W, H = OUT_W * SS, OUT_H * SS
MASK_W, MASK_H = 220, 478

# Walkable ground ends here (fraction of height): below are Books, Today and the settings button.
WALK_BOTTOM = 0.90
# Walkable ground starts this far under the hill line, so feet never touch the hill.
WALK_MARGIN = 0.012

# Material bits (G, B).
SKY, FAR_HILL, GRASS, POND = (0, 0), (1, 0), (1, 1), (0, 1)

# The Yard and the Far yard are one landscape, side by side (Yard left, Far yard right). The script
# paints it as one wide picture and cuts it in two, so the hills, sky and grass meet at the join
# without a seam. X runs 0...2 across the pair (1 = one panel width); Y runs 0...1 down.
SEED = 11
HILL_LINE = 0.39
FAR_RIDGES = [(0.225, 0.021, 0.79), (0.265, 0.017, 0.61)]
NEAR_RIDGE = 0.305

PANELS = [
    {
        "key": "yard",
        "swift": "yard",
        "index": 0,
        # Ground kept for the coop run: x, y, width, height as fractions of this panel.
        "reserved": (0.56, 0.43, 0.34, 0.12),
        "pond": None,
    },
    {
        "key": "far-yard",
        "swift": "farYard",
        "index": 1,
        # The back fence, along the hill line on the left.
        "reserved": (0.06, 0.375, 0.46, 0.07),
        # Centre x, centre y, radius x, radius y (fractions of this panel's width and height).
        "pond": (0.66, 0.70, 0.19, 0.045),
    },
]
COUNT = len(PANELS)


def smooth_noise(rng, cells_x, cells_y, w, h):
    """Soft noise in 0...1: a coarse random grid, upscaled smoothly."""
    grid = rng.random_sample((cells_y + 1, cells_x + 1)).astype(np.float32)
    img = Image.fromarray(grid).resize((w, h), Image.BICUBIC)
    return np.clip(np.asarray(img, dtype=np.float32), 0.0, 1.0)


def ridge(rng, xs, base, amp):
    """A gentle hill top: a few slow waves around `base`, in fractions of the height."""
    y = np.full_like(xs, base)
    for freq in (1.0, 2.3, 4.1):
        phase = rng.uniform(0, 2 * np.pi)
        y += amp / freq * np.sin(xs * freq * 2 * np.pi + phase)
    return y


def to_panel_space(p, x):
    """A panel-local x (0...1) in the shared space of the pair."""
    return p["index"] + x


def make_landscape():
    """The whole pair as one picture: value, material bits, the hill line, and the walk mask."""
    rng = np.random.RandomState(SEED)
    WW = W * COUNT
    xs = (np.arange(WW, dtype=np.float32) + 0.5) / W
    ys = (np.arange(H, dtype=np.float32) + 0.5) / H
    X, Y = np.meshgrid(xs, ys)

    value = np.zeros((H, WW), np.float32)
    g = np.zeros((H, WW), np.float32)
    b = np.zeros((H, WW), np.float32)

    # Sky: lighter toward the horizon, with a few soft clouds.
    sky = 0.45 + 0.45 * np.clip(Y / 0.32, 0, 1)
    clouds = smooth_noise(rng, 5 * COUNT, 9, WW, H)
    sky += 0.18 * np.clip((clouds - 0.6) / 0.4, 0, 1) * np.clip(1 - Y / 0.3, 0, 1)
    value[:] = sky

    # Far hills, back to front. Farther is lighter (the air between).
    for base, amp, tone in FAR_RIDGES:
        top = ridge(rng, xs, base, amp)[None, :]
        inside = Y >= top
        shade = tone - 0.25 * np.clip((Y - top) / 0.12, 0, 1)
        value = np.where(inside, shade, value)
        g = np.where(inside, 1.0, g)

    # The near hill (grass): lit from the upper left, so slopes facing left are lighter.
    near_top_1d = ridge(rng, xs, NEAR_RIDGE, 0.014)
    near_top = near_top_1d[None, :]
    slope = np.gradient(near_top_1d)[None, :] * W
    hill_line_1d = ridge(rng, xs, HILL_LINE, 0.006)
    hill_line = hill_line_1d[None, :]
    inside = Y >= near_top
    lit = 0.66 - 0.8 * slope - 0.18 * np.clip((Y - near_top) / (hill_line - near_top + 1e-3), 0, 1)
    texture = smooth_noise(rng, 18 * COUNT, 40, WW, H)
    near = lit + 0.06 * (texture - 0.5)
    # A darker band just above the hill line: the hedge bottom where the yard begins.
    band = np.exp(-(((Y - hill_line + 0.006) / 0.006) ** 2))
    near -= 0.14 * band
    # The yard below the hill line: light near the line, a little deeper toward the viewer.
    yard = 0.70 - 0.16 * np.clip((Y - hill_line) / (1 - hill_line), 0, 1)
    # Broad mounds, then finer grass texture.
    yard += 0.08 * (smooth_noise(rng, 3 * COUNT, 6, WW, H) - 0.5) + 0.06 * (texture - 0.5)
    yard += 0.04 * (smooth_noise(rng, 60 * COUNT, 120, WW, H) - 0.5)
    ground = np.where(Y >= hill_line, yard, near)
    value = np.where(inside, ground, value)
    g = np.where(inside, 1.0, g)
    b = np.where(inside, 1.0, b)

    for p in PANELS:
        # The reserved ground: a little worn, so the empty spot reads until the building is drawn.
        rx, ry, rw, rh = p["reserved"]
        cx, cy = to_panel_space(p, rx + rw / 2), ry + rh / 2
        worn = np.clip(1 - np.maximum(np.abs(X - cx) / (rw / 2), np.abs(Y - cy) / (rh / 2)), 0, 1)
        value -= 0.06 * np.clip(worn * 4, 0, 1)

        # The pond: a darker rim, a light middle and two streaks of sky.
        if p["pond"]:
            px, py, prx, pry = p["pond"]
            px = to_panel_space(p, px)
            d = np.sqrt(((X - px) / prx) ** 2 + ((Y - py) / pry) ** 2)
            pond_mask = d <= 1.0
            shore = np.clip(1 - np.abs(d - 1.0) / 0.12, 0, 1)
            value -= 0.12 * shore * (d > 1.0)
            water = 0.35 + 0.35 * (1 - d)
            streaks = np.exp(-(((Y - py + pry * 0.3) / (pry * 0.08)) ** 2)) * (np.abs(X - px) < prx * 0.5)
            water += 0.25 * streaks
            value = np.where(pond_mask, water, value)
            g = np.where(pond_mask, 0.0, g)
            b = np.where(pond_mask, 1.0, b)

    value = np.clip(value, 0, 1)
    rgb = np.stack([value, g, b], axis=-1)
    land = Image.fromarray((rgb * 255 + 0.5).astype(np.uint8))
    land = land.resize((OUT_W * COUNT, OUT_H), Image.BOX)

    # Walk mask, at its own small size: tested at pixel centres.
    mx = (np.arange(MASK_W * COUNT, dtype=np.float32) + 0.5) / MASK_W
    my = (np.arange(MASK_H, dtype=np.float32) + 0.5) / MASK_H
    MX, MY = np.meshgrid(mx, my)
    line_at = np.interp(mx, xs, hill_line_1d)[None, :]
    walk = (MY >= line_at + WALK_MARGIN) & (MY <= WALK_BOTTOM)
    for p in PANELS:
        rx, ry, rw, rh = p["reserved"]
        rx = to_panel_space(p, rx)
        walk &= ~((MX >= rx) & (MX <= rx + rw) & (MY >= ry) & (MY <= ry + rh))
        if p["pond"]:
            px, py, prx, pry = p["pond"]
            px = to_panel_space(p, px)
            # A little room around the water, so feet stay on the bank.
            walk &= np.sqrt(((MX - px) / (prx + 0.02)) ** 2 + ((MY - py) / (pry + 0.01)) ** 2) > 1.0
    mask = Image.fromarray((walk * 255).astype(np.uint8))
    return land, mask, float(np.mean(hill_line_1d))


def cut(image, index, width):
    """One panel's part of the shared picture."""
    return image.crop((index * width, 0, (index + 1) * width, image.height))


def swift_number(x):
    """A short Swift literal: 0.4, not 0.4000."""
    return f"{x:.4f}".rstrip("0").rstrip(".")


def swift_layout(results):
    lines = [
        "// Generated by scripts/make_scene_art.py. Do not edit: change the script and run it again.",
        "",
        "import CoreGraphics",
        "",
        "/// The layout baked into the scene art, so the code and the PNGs agree.",
        "/// Every number is a fraction of the panel: 0 is the top (or left) edge, 1 the bottom (or right).",
        "enum SceneArtLayout {",
        "    /// The landscape PNGs are this many pixels. The scene stretches them to the panel.",
        f"    static let pixelSize = CGSize(width: {OUT_W}, height: {OUT_H})",
        "    /// The walk mask PNGs are this many pixels.",
        f"    static let maskSize = CGSize(width: {MASK_W}, height: {MASK_H})",
        "    /// Walkable ground ends here: below are the buttons and the grass tufts.",
        f"    static let walkBottom: CGFloat = {swift_number(WALK_BOTTOM)}",
        "",
        "    /// The art's name for a panel (`scene-<key>-land.png`, `scene-<key>-walk.png`). Nil: no scene yet.",
        "    static func key(_ panel: FarmPanel) -> String? {",
        "        switch panel {",
    ]
    for p, _ in results:
        lines.append(f'        case .{p["swift"]}: "{p["key"]}"')
    lines += [
        "        default: nil",
        "        }",
        "    }",
        "",
        "    /// Where the hill meets the yard (the mean of its gentle curve). Trees stand along it;",
        "    /// birds there are smallest.",
        "    static func hillLine(_ panel: FarmPanel) -> CGFloat? {",
        "        switch panel {",
    ]
    for p, hill in results:
        lines.append(f'        case .{p["swift"]}: {swift_number(hill)}')
    lines += [
        "        default: nil",
        "        }",
        "    }",
        "",
        "    /// Ground kept clear for a building (the coop run, the back fence). Black in the walk mask.",
        "    static func reserved(_ panel: FarmPanel) -> CGRect? {",
        "        switch panel {",
    ]
    for p, _ in results:
        x, y, w, h = (swift_number(v) for v in p["reserved"])
        lines.append(f'        case .{p["swift"]}: CGRect(x: {x}, y: {y}, width: {w}, height: {h})')
    lines += [
        "        default: nil",
        "        }",
        "    }",
        "}",
        "",
    ]
    return "\n".join(lines)


def main():
    os.makedirs(ART_DIR, exist_ok=True)
    land, mask, hill = make_landscape()
    results = []
    for p in PANELS:
        cut(land, p["index"], OUT_W).save(os.path.join(ART_DIR, f"scene-{p['key']}-land.png"), optimize=True)
        cut(mask, p["index"], MASK_W).save(os.path.join(ART_DIR, f"scene-{p['key']}-walk.png"), optimize=True)
        # One hill line for the pair, so depth and size match when a bird crosses the join.
        results.append((p, hill))
        print(f"{p['key']}: hill line {hill:.4f}")
    with open(SWIFT_OUT, "w") as f:
        f.write(swift_layout(results))
    print(f"wrote {ART_DIR} and {SWIFT_OUT}")


if __name__ == "__main__":
    main()
