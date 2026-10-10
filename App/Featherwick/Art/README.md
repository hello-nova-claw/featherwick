# Farm art

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
