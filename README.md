# Featherwick

A cozy chicken-keeping game for iPhone, with real chicken genetics. Keep a backyard flock, hatch eggs, and fill your Breed Book with breeds, feather colours and egg colours. Every colour comes from real genes, so you can work out what your birds carry and plan what will hatch. Nothing dies, and nothing can be failed.

Featherwick is in development and not yet on the App Store.

## Build it

You need Xcode 26 or later. The game logic also builds on Linux with Swift 6.

```sh
swift build
swift test
swift run featherwick 2026     # play in the terminal; 2026 is the seed for a new game
```

The iOS app is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
cd App && xcodegen
open Featherwick.xcodeproj
```

It runs in the Simulator with no Apple account. To run it on your own iPhone, copy `App/Config/Local.xcconfig.example` to `App/Config/Local.xcconfig` and set your team ID and a bundle ID of your own.

## Layout

- `Sources/FeatherwickCore`: every rule of the game. Pure Swift, seeded, no clock.
- `Sources/FeatherwickText`: every word the player reads.
- `Sources/FeatherwickCLI`: a text front end, `featherwick`.
- `App/`: the iOS app, in SwiftUI with a Metal season shader.
- `Tests/`: Swift Testing suites, one per system.
- `docs/design.md`: the design record, with the principles and how each system works.

## Licensing

The code is under the [MIT licence](LICENSE). The art, sound, writing, name and icon are not: they are all rights reserved ([ASSETS-LICENSE.md](ASSETS-LICENSE.md), [TRADEMARKS.md](TRADEMARKS.md)). You are welcome to learn from the code and reuse it in your own projects, but not to publish this game or a reskin of it.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) first. Open an issue and wait for it to be accepted before you write code. Report security problems as [SECURITY.md](SECURITY.md) says.
