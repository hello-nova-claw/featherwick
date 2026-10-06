# Farm art

`farm-day.png` is the farm painting for now (a mockup). Portrait, about 6:13; 1290×2796 px is
ideal. No text, no chickens: the game draws those.

- The farm screen scales it to fill the screen. Night is made from it in code (darker, cooler).
- Seasonal paintings are optional: add `farm-spring.png`, `farm-summer.png`, `farm-autumn.png` or
  `farm-winter.png` and the game season picks it, with a crossfade. Missing seasons use `farm-day.png`.
  Paint them from the same base so the coop, shed, fence and gate stay in place.
- Place labels sit at `Place.anchor` in `Farm/FarmView.swift`, as fractions of the painting.
  Change the anchors when the painting's layout changes.
- Without any painting here, the striped stand-in shows.

## Layers (experiment)

- `farm-layer-1-sky.png` … `farm-layer-4-coop.png` are the same scene cut into layers, back to front.
- Every layer has the same size (707×1536). Each is transparent where the layers behind show.
- When any layer is here, the farm draws the layers and ignores `farm-day.png`.
- A later step can move each layer on its own: sway the trees, swap the season per layer.
