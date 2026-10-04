# Farm art

Put the farm painting here as `farm-day.png` (or `farm-day.jpg`). Portrait, about 6:13
(1290×2796 px is ideal). No text, no chickens: the game draws those.

- The farm screen scales it to fill the screen. Night is made from it in code (darker, cooler).
- Place labels sit at `Place.anchor` in `Farm/FarmView.swift`, as fractions of this image.
  Change the anchors when the painting changes.
- Without a painting here, the striped stand-in shows.
