#!/usr/bin/env python3
"""Draws the painted-kit template: the skeleton's bones and joints, with the path rig's part shapes traced
under them, at a kit's canvas size. Paint the parts over it, one layer per part.

Writes to art-source/kit-template/ (it does not ship):

- template.png        everything on paper: grid, part shapes, bones, joints, labels, key
- guide-shapes.png    the part shapes only, on a clear background (a layer to paint over)
- guide-bones.png     the bones, joints and labels only, on a clear background (a layer to keep on top)
- template.svg        the same, as vectors, one group per layer
- kit.json            a starter kit.json: every part, its bone, and the pivots of this template

The numbers are the path rig's adult build (`ChickenRigMetrics.adult` in App/Featherwick/Scene/ChickenPose.swift).
Run this again after changing them. See "Painted parts" in docs/design/README.md.

    python3 scripts/make_kit_template.py
"""

import json
import math
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art-source", "kit-template")
FONT = os.path.join(ROOT, "App", "Featherwick", "Fonts", "Figtree-Medium.ttf")

# The canvas. One rig unit (the bird's height) is UNIT pixels. The ground point is between the feet.
CANVAS = 2048
UNIT = 1600
GROUND = (1088, 1840)
# Drawn at this many times the size, then made smaller, for soft edges.
SS = 2

# The path rig's adult build, in rig units (x right of the ground point, y up). Copied from ChickenRigMetrics.adult.
B = dict(
    backHip=(-0.04, 0.40), frontHip=(0.04, 0.40),
    backHock=(-0.12, 0.23), frontHock=(-0.04, 0.23),
    backFoot=(-0.04, 0.03), frontFoot=(0.04, 0.03),
    legWidth=0.035, thighSize=(0.10, 0.17), toe=0.10, backToe=0.04,
    hip=(0.0, 0.40),
    bodyCentre=(-0.05, 0.54), bodySize=(0.60, 0.38),
    wingCentre=(-0.08, 0.54), wingSize=(0.34, 0.20),
    tail=[(-0.22, 0.70), (-0.40, 0.90), (-0.47, 0.80), (-0.32, 0.52)],
    tailRoot=(-0.24, 0.62),
    shoulder=(0.16, 0.64), neckMid=(0.22, 0.74),
    neck=[(0.06, 0.60), (0.24, 0.62), (0.30, 0.84), (0.17, 0.88)],
    throat=(0.25, 0.80),
    headCentre=(0.24, 0.86), headRadius=0.085,
    beak=[(0.31, 0.885), (0.31, 0.845), (0.385, 0.862)],
    eyeCentre=(0.26, 0.875), eyeRadius=0.017,
    combBumps=[(0.19, 0.94), (0.235, 0.96), (0.28, 0.94)], combBumpRadius=0.032, combBase=(0.235, 0.925),
    wattleCentre=(0.31, 0.80), wattleSize=(0.045, 0.075),
)
WATTLE_TOP = (B["wattleCentre"][0], B["wattleCentre"][1] + B["wattleSize"][1] / 2)
WING_ROOT = (B["wingCentre"][0] + B["wingSize"][0] / 2, B["wingCentre"][1])

# Each bone: its joint, its parent (for the bone line), and its colour.
BONES = {
    "thighBack": (B["backHip"], "body", "#7d93b8"),
    "shankBack": (B["backHock"], "thighBack", "#7d93b8"),
    "toesBack": (B["backFoot"], "shankBack", "#7d93b8"),
    "body": (B["hip"], None, "#d9822b"),
    "tail": (B["tailRoot"], "body", "#c9a227"),
    "neckLow": (B["shoulder"], "body", "#5a9e5a"),
    "neckHigh": (B["neckMid"], "neckLow", "#3f8a6e"),
    "head": (B["throat"], "neckHigh", "#b0476a"),
    "thighFront": (B["frontHip"], "body", "#3d6bb3"),
    "shankFront": (B["frontHock"], "thighFront", "#3d6bb3"),
    "toesFront": (B["frontFoot"], "shankFront", "#3d6bb3"),
}

# Where each joint's label sits, from the joint, in rig units: so labels do not cover each other.
LABEL_AT = {
    "thighBack": (-0.20, 0.02), "shankBack": (-0.22, 0.0), "toesBack": (-0.26, -0.02),
    "body": (0.10, 0.06), "tail": (-0.10, -0.06), "neckLow": (0.07, -0.03), "neckHigh": (0.10, -0.02),
    "head": (0.17, -0.10), "thighFront": (0.06, 0.02), "shankFront": (0.08, 0.0), "toesFront": (0.12, -0.03),
}

# The kit's parts, back to front, as the path rig draws them: (part, bone, pivot or None, token, follow).
# A pivot sets its bone's joint; one part on each bone gives it.
PARTS = [
    ("shankBack", "shankBack", B["backHock"], None, None),
    ("toesBack", "toesBack", B["backFoot"], None, None),
    ("thighBack", "thighBack", B["backHip"], None, {"amount": 0.25}),
    ("tail", "tail", B["tailRoot"], None, {"amount": 1}),
    ("body", "body", B["hip"], None, None),
    ("wing", "body", None, None, {"amount": 0.35, "root": WING_ROOT}),
    ("neck", "neckLow", B["shoulder"], None, None),
    ("hackle", "neckHigh", B["neckMid"], "hackle", None),
    ("comb", "head", None, "comb", None),
    ("head", "head", B["throat"], None, None),
    ("wattle", "head", None, "comb", {"amount": 1, "root": WATTLE_TOP}),
    ("beak", "head", None, "beak", None),
    ("eye", "head", None, "eye", None),
    ("shankFront", "shankFront", B["frontHock"], None, None),
    ("toesFront", "toesFront", B["frontFoot"], None, None),
    ("thighFront", "thighFront", B["frontHip"], None, {"amount": 0.25}),
]

PAPER = "#f6f1e7"
INK = "#3b3229"
GRID = "#e4dccb"
GROUND_LINE = "#a89880"
# Paint each part past its joint, to this ring, so a turn opens no gap.
OVERLAP = 0.035


def px(p):
    """Rig units to canvas pixels (y down)."""
    return (GROUND[0] + p[0] * UNIT, GROUND[1] - p[1] * UNIT)


def ellipse_points(centre, size, n=72):
    cx, cy = centre
    return [(cx + size[0] / 2 * math.cos(t), cy + size[1] / 2 * math.sin(t))
            for t in (2 * math.pi * i / n for i in range(n))]


def capsule_points(a, b, width, n=24):
    """A band from a to b with round ends."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    angle = math.atan2(dy, dx)
    r = width / 2
    pts = []
    for i in range(n + 1):
        t = angle + math.pi / 2 + math.pi * i / n
        pts.append((b[0] + r * math.cos(t - math.pi), b[1] + r * math.sin(t - math.pi)))
    for i in range(n + 1):
        t = angle + math.pi / 2 + math.pi * i / n
        pts.append((a[0] + r * math.cos(t), a[1] + r * math.sin(t)))
    return pts


def rounded_rect_points(x0, y0, x1, y1, r, n=8):
    pts = []
    corners = [(x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180), (x1 - r, y0 + r, 270)]
    for cx, cy, start in corners:
        for i in range(n + 1):
            t = math.radians(start + 90 * i / n)
            pts.append((cx + r * math.cos(t), cy + r * math.sin(t)))
    return pts


def leg_shapes(side):
    hip, hock, foot = B[side + "Hip"], B[side + "Hock"], B[side + "Foot"]
    w = B["legWidth"]
    th = B["thighSize"]
    thigh_centre = ((hip[0] + hock[0]) / 2, (hip[1] + hock[1]) / 2 + th[1] * 0.1)
    toe_y0 = max(0, foot[1] - w * 0.8)
    toes = rounded_rect_points(foot[0] - B["backToe"], toe_y0, foot[0] + B["toe"], toe_y0 + w * 0.8, w * 0.4)
    return {
        "shank" + side.title(): capsule_points(hock, foot, w),
        "toes" + side.title(): toes,
        "thigh" + side.title(): ellipse_points(thigh_centre, th),
    }


def comb_points():
    """The comb as one outline: bumps on a bar (an outline round circles, sampled)."""
    r = B["combBumpRadius"]
    bumps = B["combBumps"]
    pts = []
    # The top edge: over each bump; the bottom edge: the bar's base.
    for i, (cx, cy) in enumerate(bumps):
        a0, a1 = (180, 0)
        for k in range(19):
            t = math.radians(a0 + (a1 - a0) * k / 18)
            pts.append((cx + r * math.cos(t), cy + r * math.sin(t)))
    base_y = B["combBase"][1] - r / 2
    pts.append((bumps[-1][0] + r, base_y))
    pts.append((bumps[0][0] - r, base_y))
    return pts


def part_shapes():
    """Each part's outline, in rig units, keyed by part name."""
    shapes = {}
    shapes.update(leg_shapes("back"))
    shapes.update(leg_shapes("front"))
    shapes["tail"] = B["tail"]
    shapes["body"] = ellipse_points(B["bodyCentre"], B["bodySize"])
    shapes["wing"] = ellipse_points(B["wingCentre"], B["wingSize"])
    shapes["neck"] = B["neck"][:2] + [B["neckMid"]] + [(0.12, 0.74)]
    shapes["hackle"] = [(0.12, 0.72), (0.26, 0.70), B["neck"][2], B["neck"][3]]
    shapes["comb"] = comb_points()
    r = B["headRadius"]
    shapes["head"] = ellipse_points(B["headCentre"], (2 * r, 2 * r))
    shapes["wattle"] = ellipse_points(B["wattleCentre"], B["wattleSize"])
    shapes["beak"] = B["beak"]
    er = B["eyeRadius"]
    shapes["eye"] = ellipse_points(B["eyeCentre"], (2 * er, 2 * er), 36)
    return shapes


def lighten(hex_colour, amount):
    r, g, b = (int(hex_colour[i:i + 2], 16) for i in (1, 3, 5))
    return "#%02x%02x%02x" % tuple(round(c + (255 - c) * amount) for c in (r, g, b))


def rgba(hex_colour, alpha=255):
    return tuple(int(hex_colour[i:i + 2], 16) for i in (1, 3, 5)) + (alpha,)


# MARK: - Drawing ops. Each op is drawn to PNG (PIL) and to SVG, so the two match.

def build_ops():
    """Returns (shapes ops, bones ops, grid ops, key ops). Points are canvas pixels."""
    bone_of = {name: bone for name, bone, _, _, _ in PARTS}
    shapes = part_shapes()
    shape_ops = []
    for name, _, _, _, _ in PARTS:
        colour = BONES[bone_of[name]][2]
        pts = [px(p) for p in shapes[name]]
        shape_ops.append(("poly", pts, lighten(colour, 0.80), colour, 3, False, name))
    # Part names in ink. The legs' parts have their bones' names, so only the others are named.
    for name, label_at in (("body", (-0.28, 0.47)), ("wing", (-0.11, 0.535)), ("tail", (-0.40, 0.70)),
                           ("head", (0.20, 0.84)), ("hackle", (0.21, 0.79)), ("neck", (0.10, 0.65)),
                           ("comb", (0.235, 0.995)), ("wattle", (0.35, 0.745)), ("beak", (0.40, 0.875)),
                           ("eye", (0.27, 0.915))):
        shape_ops.append(("text", px(label_at), name, 26, INK, "middle"))

    bone_ops = []
    for bone, (joint, parent, colour) in BONES.items():
        if parent:
            bone_ops.append(("line", px(BONES[parent][0]), px(joint), colour, 6, False))
    # Each bone's own line runs to its child, so the toes and head show a stub forward.
    stubs = {"toesBack": (0.07, 0.0), "toesFront": (0.07, 0.0), "head": (0.12, 0.06), "tail": (-0.14, 0.18)}
    for bone, d in stubs.items():
        joint, _, colour = BONES[bone]
        bone_ops.append(("line", px(joint), px((joint[0] + d[0], joint[1] + d[1])), colour, 6, False))
    for bone, (joint, _, colour) in BONES.items():
        bone_ops.append(("circle", px(joint), OVERLAP * UNIT, None, colour, 3, True))
    for bone, (joint, _, colour) in BONES.items():
        bone_ops.append(("circle", px(joint), 12, colour, "#ffffff", 4, False))
        lx, ly = LABEL_AT[bone]
        x, y = joint
        anchor = "end" if lx < 0 else "start"
        bone_ops.append(("leader", px(joint), px((x + lx, y + ly)), colour))
        bone_ops.append(("text", px((x + lx, y + ly)), bone, 34, colour, anchor))
    for name, root in (("wing", WING_ROOT), ("wattle", WATTLE_TOP)):
        bone_ops.append(("diamond", px(root), 14, BONES["body" if name == "wing" else "head"][2]))

    grid_ops = []
    for i in range(-6, 7):
        x = GROUND[0] + i * 0.1 * UNIT
        grid_ops.append(("line", (x, 0), (x, CANVAS), GRID, 2, False))
    for j in range(0, 12):
        y = GROUND[1] - j * 0.1 * UNIT
        grid_ops.append(("line", (0, y), (CANVAS, y), GRID, 2, False))
    grid_ops.append(("line", (0, GROUND[1]), (CANVAS, GROUND[1]), GROUND_LINE, 4, False))
    top = GROUND[1] - UNIT
    grid_ops.append(("line", (1060, top), (CANVAS, top), GROUND_LINE, 3, True))
    grid_ops.append(("text", (CANVAS - 40, top - 14), "1 bird height (unit)", 28, GROUND_LINE, "end"))
    grid_ops.append(("text", (CANVAS - 40, GROUND[1] - 14), "ground", 28, GROUND_LINE, "end"))
    grid_ops.append(("cross", GROUND, 26, INK))
    grid_ops.append(("text", (GROUND[0] + 20, GROUND[1] + 50), "ground point  [%d, %d]" % GROUND, 30, INK, "start"))

    key_ops = []
    lines = [
        ("Featherwick kit template: adult", 42),
        ("canvas %d x %d px    unit %d px    ground point [%d, %d]" % (CANVAS, CANVAS, UNIT, *GROUND), 28),
        ("Grid: 0.1 bird height. Faces right. Paint each part on its own layer, at canvas size.", 28),
        ("Coloured dot and name: a bone's joint (its pivot). Line: the bone.", 28),
        ("Dashed ring: paint both parts past it, so a turn opens no gap.", 28),
        ("Diamond: where a loose part hangs from (follow root).", 28),
        ("Shapes, named in black: the path rig's parts. A guide, not a rule.", 28),
    ]
    y = 70
    for text, size in lines:
        key_ops.append(("text", (60, y), text, size, INK, "start"))
        y += size + 18
    return shape_ops, bone_ops, grid_ops, key_ops


# MARK: - PNG

_fonts = {}


def font(size):
    if size not in _fonts:
        _fonts[size] = ImageFont.truetype(FONT, size * SS)
    return _fonts[size]


def dashed(draw, a, b, colour, width, dash=18, gap=14):
    length = math.dist(a, b)
    if length == 0:
        return
    ux, uy = (b[0] - a[0]) / length, (b[1] - a[1]) / length
    t = 0
    while t < length:
        e = min(length, t + dash * SS)
        draw.line([(a[0] + ux * t, a[1] + uy * t), (a[0] + ux * e, a[1] + uy * e)], fill=colour, width=width)
        t = e + gap * SS


def draw_png(ops, image):
    draw = ImageDraw.Draw(image)
    s = lambda p: (p[0] * SS, p[1] * SS)
    for op in ops:
        kind = op[0]
        if kind == "poly":
            _, pts, fill, stroke, width, _, _ = op
            pts = [s(p) for p in pts]
            draw.polygon(pts, fill=rgba(fill, 150))
            draw.line(pts + [pts[0]], fill=rgba(stroke), width=width * SS, joint="curve")
        elif kind == "line":
            _, a, b, colour, width, is_dashed = op
            if is_dashed:
                dashed(draw, s(a), s(b), rgba(colour), width * SS)
            else:
                draw.line([s(a), s(b)], fill=rgba(colour), width=width * SS)
        elif kind == "leader":
            _, a, b, colour = op
            dashed(draw, s(a), s(b), rgba(colour, 160), 2 * SS, dash=6, gap=6)
        elif kind == "circle":
            _, c, r, fill, stroke, width, is_dashed = op
            cx, cy = s(c)
            r *= SS
            if is_dashed:
                n = 28
                for i in range(n):
                    if i % 2:
                        continue
                    t0, t1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
                    draw.arc([cx - r, cy - r, cx + r, cy + r], math.degrees(t0), math.degrees(t1),
                             fill=rgba(stroke), width=width * SS)
            else:
                draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rgba(fill) if fill else None,
                             outline=rgba(stroke), width=width * SS)
        elif kind == "diamond":
            _, c, r, colour = op
            cx, cy = s(c)
            r *= SS
            draw.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=rgba(colour),
                         outline=rgba("#ffffff"), width=2 * SS)
        elif kind == "cross":
            _, c, r, colour = op
            cx, cy = s(c)
            r *= SS
            draw.line([(cx - r, cy), (cx + r, cy)], fill=rgba(colour), width=4 * SS)
            draw.line([(cx, cy - r), (cx, cy + r)], fill=rgba(colour), width=4 * SS)
        elif kind == "text":
            _, p, text, size, colour, anchor = op
            a = {"start": "ls", "middle": "ms", "end": "rs"}[anchor]
            draw.text(s(p), text, font=font(size), fill=rgba(colour), anchor=a,
                      stroke_width=3 * SS, stroke_fill=rgba(PAPER, 220))


def png(layers, background, path):
    image = Image.new("RGBA", (CANVAS * SS, CANVAS * SS), rgba(background) if background else (0, 0, 0, 0))
    for ops in layers:
        layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
        draw_png(ops, layer)
        image = Image.alpha_composite(image, layer)
    image = image.resize((CANVAS, CANVAS), Image.LANCZOS)
    image.save(path, optimize=True)


# MARK: - SVG

def esc(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def svg_ops(ops):
    out = []
    for op in ops:
        kind = op[0]
        if kind == "poly":
            _, pts, fill, stroke, width, _, name = op
            d = " ".join("%.1f,%.1f" % p for p in pts)
            out.append('<polygon id="%s" points="%s" fill="%s" fill-opacity="0.6" stroke="%s" stroke-width="%d" '
                       'stroke-linejoin="round"/>' % (name, d, fill, stroke, width))
        elif kind == "line":
            _, a, b, colour, width, is_dashed = op
            dash = ' stroke-dasharray="18 14"' if is_dashed else ""
            out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="%d" '
                       'stroke-linecap="round"%s/>' % (*a, *b, colour, width, dash))
        elif kind == "leader":
            _, a, b, colour = op
            out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-opacity="0.6" '
                       'stroke-width="2" stroke-dasharray="6 6"/>' % (*a, *b, colour))
        elif kind == "circle":
            _, c, r, fill, stroke, width, is_dashed = op
            dash = ' stroke-dasharray="%.1f"' % (math.pi * r / 14) if is_dashed else ""
            out.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="%d"%s/>'
                       % (*c, r, fill or "none", stroke, width, dash))
        elif kind == "diamond":
            _, (cx, cy), r, colour = op
            out.append('<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="%s" stroke="#fff" '
                       'stroke-width="2"/>' % (cx, cy - r, cx + r, cy, cx, cy + r, cx - r, cy, colour))
        elif kind == "cross":
            _, (cx, cy), r, colour = op
            out.append('<path d="M%.1f %.1fH%.1fM%.1f %.1fV%.1f" stroke="%s" stroke-width="4"/>'
                       % (cx - r, cy, cx + r, cx, cy - r, cy + r, colour))
        elif kind == "text":
            _, (x, y), text, size, colour, anchor = op
            out.append('<text x="%.1f" y="%.1f" font-family="Figtree, sans-serif" font-size="%d" fill="%s" '
                       'text-anchor="%s" paint-order="stroke" stroke="%s" stroke-width="6">%s</text>'
                       % (x, y, size, colour, anchor, PAPER, esc(text)))
    return "\n    ".join(out)


def svg(groups, path):
    body = "\n  ".join('<g id="%s">\n    %s\n  </g>' % (name, svg_ops(ops)) for name, ops in groups)
    with open(path, "w") as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n'
                '  <rect id="paper" width="100%%" height="100%%" fill="%s"/>\n  %s\n</svg>\n'
                % (CANVAS, CANVAS, CANVAS, CANVAS, PAPER, body))


# MARK: - kit.json

def rounded(p):
    return [round(p[0], 3), round(p[1], 3)]


def kit_json(path):
    parts = {}
    for name, bone, pivot, token, follow in PARTS:
        part = {"bone": bone}
        if pivot:
            part["pivot"] = rounded(pivot)
        if token:
            part["token"] = token
        if follow:
            f = {"amount": follow["amount"]}
            if "root" in follow:
                f["root"] = rounded(follow["root"])
            part["follow"] = f
        parts[name] = part
    kit = {
        "build": "heavy",
        "canvas": [CANVAS, CANVAS],
        "groundPoint": list(GROUND),
        "unit": UNIT,
        "parts": parts,
        "drawOrder": [name for name, _, _, _, _ in PARTS],
    }
    # One part per line: easy to read and to edit by hand.
    lines = ['  "%s": %s' % (k, json.dumps(v)) for k, v in kit.items() if k != "parts"]
    part_lines = ",\n".join('    "%s": %s' % (k, json.dumps(v)) for k, v in parts.items())
    lines.insert(4, '  "parts": {\n%s\n  }' % part_lines)
    with open(path, "w") as f:
        f.write("{\n" + ",\n".join(lines) + "\n}\n")


def main():
    os.makedirs(OUT, exist_ok=True)
    shape_ops, bone_ops, grid_ops, key_ops = build_ops()
    png([grid_ops, shape_ops, bone_ops, key_ops], PAPER, os.path.join(OUT, "template.png"))
    png([shape_ops], None, os.path.join(OUT, "guide-shapes.png"))
    png([bone_ops], None, os.path.join(OUT, "guide-bones.png"))
    svg([("grid", grid_ops), ("shapes", shape_ops), ("bones", bone_ops), ("key", key_ops)],
        os.path.join(OUT, "template.svg"))
    kit_json(os.path.join(OUT, "kit.json"))
    print("wrote", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
