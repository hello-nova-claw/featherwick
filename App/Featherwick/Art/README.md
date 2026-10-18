# Farm art

`Parts/` holds the painted parts kits. `Parts/hen/` is the kit every grown hen uses, copied from
`art-source/kit-fits/hen/parts/` (run `scripts/extract_kit_parts.py` there first). `Parts/hen-b/` is a
second hen kit, from `art-source/kit-fits/hen-b/parts/` (`scripts/make_kit_from_slices.py`). No bird uses
it yet: pick it in the rig lab. A folder named for a body
shape (`heavy/`...) is the kit for other grown birds of that shape; none is here yet, so the path rig draws
them, and every chick. See "Painted parts" in `docs/design/README.md` for the kit format. The app reads
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

**The files below are not in use now.** The Barn and the Shop are a flat colour until their painting
exists (`FarmPanel` in `Farm/FarmView.swift`). No code loads these files. XcodeGen still copies
them into the app bundle. The files are kept for the panel paintings to come.

`farm-day.png` is the old farm painting (a mockup). Portrait, about 6:13; 1290×2796 px is
ideal. No text, no chickens: the game draws those.

## Layers (experiment)

- `farm-layer-1-sky.png` … `farm-layer-4-coop.png` are the same scene cut into layers, back to front.
- Every layer has the same size (707×1536). Each is transparent where the layers behind show.
