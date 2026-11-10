#!/usr/bin/env python3
"""Fits the kit skeleton to a keeper's own silhouette, so the joints move to the art and not the art to the joints.

A fit folder (art-source/kit-fits/<name>/) holds the source image and fit.json: the joints, the wing and
wattle roots and the tail's aim, all in the source image's pixels. This script writes, into the same folder:

- silhouette-2048.png  the silhouette on a kit canvas, its ground point on the canvas's ground point
- guide-bones.png      the bones, joints, rings and labels on a clear background
- template.png         grid, silhouette and bones on paper
- cut-guide.png        where to cut the silhouette into parts: cut lines, part names and the joints
- kit.json             the starter kit (scripts/make_kit_template.py) with this fit's pivots

The silhouette is every pixel that is clearly warmer than the paper. To move a joint, change fit.json and run:

    python3 scripts/fit_kit_template.py art-source/kit-fits/hen
"""

import json
import math
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

import make_kit_template as t  # noqa: E402

# Each bone's parent, for the bone lines.
PARENTS = {
    "body": None, "thighBack": "body", "shankBack": "thighBack", "toesBack": "shankBack",
    "thighFront": "body", "shankFront": "thighFront", "toesFront": "shankFront",
    "tail": "body", "neckLow": "body", "neckHigh": "neckLow", "head": "neckHigh",
}
# The part that sets each bone's joint. Other parts ride their bone with no pivot.
SETTERS = {
    "shankBack": "shankBack", "toesBack": "toesBack", "thighBack": "thighBack", "tail": "tail", "body": "body",
    "neck": "neckLow", "hackle": "neckHigh", "head": "head", "shankFront": "shankFront",
    "toesFront": "toesFront", "thighFront": "thighFront",
}
SILHOUETTE = "#dcc7aa"
CUT = "#8a3b2a"
# The tail's stub, in bird heights.
TAIL_STUB = 0.2


def main(folder):
    with open(os.path.join(folder, "fit.json")) as f:
        fit = json.load(f)
    gx, gy = fit["groundPoint"]
    height = fit["height"]

    def rig(p):
        return ((p[0] - gx) / height, (gy - p[1]) / height)

    t.GROUND = tuple(fit["canvasGroundPoint"])
    scale = t.UNIT / height

    # The silhouette on the canvas: warm pixels on pale paper.
    src = Image.open(os.path.join(folder, fit["source"])).convert("RGB")
    a = np.asarray(src).astype(int)
    mask = Image.fromarray(((a[..., 0] - a[..., 2] > 40) & (a[..., 0] < 230)).astype("uint8") * 255)
    mask = mask.resize((round(src.width * scale), round(src.height * scale)), Image.LANCZOS)
    silhouette = Image.new("RGBA", (t.CANVAS, t.CANVAS), (0, 0, 0, 0))
    offset = (round(t.GROUND[0] - gx * scale), round(t.GROUND[1] - gy * scale))
    silhouette.paste(Image.new("RGBA", mask.size, t.rgba(SILHOUETTE)), offset, mask)
    silhouette.save(os.path.join(folder, "silhouette-2048.png"), optimize=True)

    joints = fit["joints"]
    colours = {bone: entry[2] for bone, entry in t.BONES.items()}
    t.BONES = {bone: (rig(joints[bone]), PARENTS[bone], colours[bone]) for bone in joints}
    t.WING_ROOT = rig(fit["wingRoot"])
    t.WATTLE_TOP = rig(fit["wattleTop"])
    t.LABEL_AT = {bone: tuple(at) for bone, at in fit["labels"].items()}
    _, bone_ops, grid_ops, _ = t.build_ops()

    # The tail's stub points along this tail, from its base to the middle of the fan.
    base = t.px(rig(joints["tail"]))
    aim = t.px(rig(fit["tailAim"]))
    d = (aim[0] - base[0], aim[1] - base[1])
    k = TAIL_STUB * t.UNIT / math.hypot(*d)
    tail = colours["tail"]
    bone_ops = [("line", base, (base[0] + d[0] * k, base[1] + d[1] * k), tail, 6, False)
                if op[0] == "line" and op[1] == base and op[3] == tail else op for op in bone_ops]

    bones_path = os.path.join(folder, "guide-bones.png")
    grid_path = os.path.join(folder, "template.png")
    t.png([bone_ops], None, bones_path)
    t.png([grid_ops], t.PAPER, grid_path)
    page = Image.alpha_composite(Image.open(grid_path).convert("RGBA"), silhouette)
    page = Image.alpha_composite(page, Image.open(bones_path).convert("RGBA"))
    page.save(grid_path, optimize=True)

    # The cut guide: where one part's layer ends and the next begins, on the silhouette.
    if "cuts" in fit:
        cut_ops = []
        for points in fit["cuts"].values():
            pts = [t.px(rig(p)) for p in points]
            cut_ops += [("line", a, b, CUT, 5, True) for a, b in zip(pts, pts[1:])]
        for name, at in fit.get("regions", {}).items():
            cut_ops.append(("text", t.px(rig(at)), name, 34, t.INK, "middle"))
        joint_ops = [op for op in bone_ops if op[0] == "circle"]
        cut_path = os.path.join(folder, "cut-guide.png")
        t.png([grid_ops], t.PAPER, cut_path)
        layer = os.path.join(folder, "_cuts.png")
        t.png([joint_ops, cut_ops], None, layer)
        page = Image.alpha_composite(Image.open(cut_path).convert("RGBA"), silhouette)
        page = Image.alpha_composite(page, Image.open(layer).convert("RGBA"))
        page.save(cut_path, optimize=True)
        os.remove(layer)

    def follow(name, f):
        if not f:
            return None
        root = {"wing": t.WING_ROOT, "wattle": t.WATTLE_TOP}.get(name)
        return {**f, "root": root} if root else f

    t.PARTS = [(name, bone, rig(joints[SETTERS[name]]) if name in SETTERS else None, token, follow(name, f))
               for name, bone, _, token, f in t.PARTS]
    if "drawOrder" in fit:
        # This drawing's own order: the same parts, back to front.
        by_name = {part[0]: part for part in t.PARTS}
        assert sorted(fit["drawOrder"]) == sorted(by_name), "drawOrder must list every part once"
        t.PARTS = [by_name[name] for name in fit["drawOrder"]]
    t.kit_json(os.path.join(folder, "kit.json"))
    if "motion" in fit or "build" in fit:
        # This bird's own kit name and motion keys (see "Painted parts" in docs/design/README.md), as they are.
        path = os.path.join(folder, "kit.json")
        kit = json.load(open(path))
        kit["build"] = fit.get("build", kit["build"])
        if "motion" in fit:
            kit["motion"] = fit["motion"]
        with open(path, "w") as f:
            json.dump(kit, f, indent=2)
            f.write("\n")
    print("wrote", os.path.relpath(folder))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: fit_kit_template.py <fit folder>")
    main(sys.argv[1])
