# Farm art

`Parts/` holds the painted parts kits, one folder for each body shape (now only `heavy/`). See "Painted parts"
in `docs/design/README.md` for the format. The app reads each kit from its own folder (a folder reference).
Every PNG has the same canvas. RGB is a greyscale value, alpha is coverage. In each kit folder:

- `kit.json`: the canvas, the ground point, the bird height (`unit`), each part's pivot and bone (or joint,
  in format 1), the draw order, the overlays, the landmarks and the build's motion angles. In format 2 a
  kit can cut a leg into thigh, shank and toes, and a neck into `neckLow` and `neckHigh`.
- `body.png`: the body. It tilts at its pivot to peck. The tail, neck and head ride on it.
- `tail.png`: the tail. It rides on the body.
- `neck.png`: the neck (hackle). It rides on the body.
- `head.png`: the head. It dips at its pivot (the throat) to peck. The comb, beak and eye ride on it.
- `comb.png`, `beak.png`, `eye.png`: in the comb, beak and eye tokens. They ride on the head.
- `leg_back.png`, `leg_front.png`: the legs. Each swings at its hip, behind and in front of the body.
- `lacing.png`: a multiply map for laced birds (255 changes nothing, darker makes darker).
- `barring.png`: a lighten map for barred birds (255 is a full light bar in the pattern colour).

`Scene/` holds the placeholder 2.5D scene art for the Yard and the Far yard: a landscape (value +
material) and a walk mask per panel. Do not edit them by hand: they come from
`python3 scripts/make_scene_art.py`. See "Farm scene (2.5D)" in `docs/design/README.md`.

**The files below are not in use now.** The Barn and the Shop are a flat colour until their painting
exists (`FarmPanel` in `Farm/FarmView.swift`). No code loads these files. XcodeGen still copies
them into the app bundle. The files are kept for the panel paintings to come.

`farm-day.png` is the old farm painting (a mockup). Portrait, about 6:13; 1290×2796 px is
ideal. No text, no chickens: the game draws those.

## Layers (experiment)

- `farm-layer-1-sky.png` … `farm-layer-4-coop.png` are the same scene cut into layers, back to front.
- Every layer has the same size (707×1536). Each is transparent where the layers behind show.
