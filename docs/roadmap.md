# Roadmap

Work in progress and ideas, newest decisions first. Move an item to "Done" when it merges.

## In progress

- In review (#13): chickens on the farm as blobs (tap opens the card, rub to pet); sound and
  haptics with on/off in settings; today's jobs and season goals; Rehome hidden when not
  possible; no incubator shown until the keeper has one.
- Tune the rub-to-pet thresholds on a real phone (`RubTracker` constants).

## Next

- Breeding planner: pick a hen and a rooster and see the likely chicks. Uses only genes the
  keeper can see.
- Trade codes: share a bird or an egg as a short signed code. No server needed. First step to
  playing with friends.
- Balance pass: run `sim` over the early game, shows and shop; tune coins, prices and difficulty.

## Later

- Notifications ("eggs are waiting") and a home-screen widget.
- iCloud save sync.
- Game Center friends.
- Live trading and a shared county show with other players (needs a server; builds on trade codes).
- Art: the 4 panel paintings (Barn, Yard, Far yard, Shop) at 1320 × 2868 px; bird art from the
  shared parts kit (`Look`). The Yard and the Far yard already have a placeholder 2.5D scene
  (value + material art, season ramps, walk mask, seeded swaying trees). The paintings replace its
  PNGs and tree shapes with the same channels. See "Farm scene (2.5D)" in `docs/design/README.md`.
- Birds in the 2.5D scene: walk targets from the walk mask, scale and draw order from ground Y.
- Sounds: 4 files (cluck, egg, hatch, coins). See `App/Featherwick/Sounds/README.md`.
- Parallax between layers when swiping. (Trees that sway and season colours: done in the 2.5D scene.)

## Done

- Swipe farm with 4 panels; the neighbour's lessons as notes (#12).
- Early game timeline (#11). Layered farm backdrop (#10).
- County show overhaul, daily shop special, quality rehome value, candling from stories (#9).
- Birds never wait forever, auto-naming (#8). Choose exact eggs, learn candling (#7).
