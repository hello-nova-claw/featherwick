# Farm art

Put the farm paintings here as `farm-spring.png`, `farm-summer.png`, `farm-autumn.png` and
`farm-winter.png` (the game season picks one). Same composition in all 4. Portrait
(1290×2796 px at 6:13 is ideal; wider ones sit on white paper). No text, no chickens: the game draws those.

- The farm screen scales it to fill the screen. Night is made from each in code (darker, cooler).
- Place labels sit at `Place.anchor` in `Farm/FarmView.swift`, as fractions of each season's image.
  Change the anchors when the painting changes.
- Without a painting here, the striped stand-in shows.
