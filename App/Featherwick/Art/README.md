# Farm art

`Parts/` holds the painted parts kits, one folder for each body shape. It is empty now: the path rig draws
every bird on the skeleton. See "Painted parts" in `docs/design/README.md` for the kit format. The app reads
each kit from its own folder (a folder reference), so everything in `Parts/` ships in the app. Keep source
art (sketches, guides, parts that are not a kit yet) in `art-source/` at the top of the repo.

A kit folder holds `kit.json` and one PNG per part, all on the same canvas. RGB is a greyscale value,
alpha is coverage. `kit.json` gives the canvas, the ground point, the bird height (`unit`), each part's bone
and pivot, the draw order, the overlays, the landmarks and the build's motion angles. Each part rides one
bone (`body`, `tail`, `neckLow`, `neckHigh`, `head`, and `thigh`, `shank` and `toes` for each leg). A part
with `follow` is loose: it sways after its bone (the tail, the wattle, fluff). `lacing.png` is a multiply
map for laced birds; `barring.png` is a lighten map for barred birds.

`Scene/` holds the placeholder 2.5D scene art for the Yard and the Far yard: a landscape (value +
material) and a walk mask per panel. Do not edit them by hand: they come from
`python3 scripts/make_scene_art.py`. See "Farm scene (2.5D)" in `docs/design/README.md`.
