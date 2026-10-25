# Release checklist

Follow these steps for each TestFlight or App Store build. CI never uploads a build: the maintainer archives and uploads from Xcode.

## Before the build

1. `main` is green: every required check passes on the last commit.
2. Every issue in the release's milestone is Done, or moved to the next milestone with a reason.
3. Run `bin/changelog`. It folds `changelog/*.txt` into `CHANGELOG.md` under "Unreleased" and deletes the fragments. Rename "Unreleased" to the version and date, add an empty "Unreleased" above it, and merge that in its own pull request. That pull request adds no fragment, so it needs the `no-changelog` label.
4. Raise `MARKETING_VERSION` in `App/project.yml` for a new version, and `CURRENT_PROJECT_VERSION` for every upload.

## The build

5. `cd App && xcodegen`, then archive in Xcode: the "Featherwick Beta" scheme for TestFlight, the "Featherwick" scheme for the App Store.
6. Upload from the Organizer. Signing material stays in the keychain; it never enters the repository.

## The listing

7. The App Store or TestFlight text, screenshots and "What to test" match `CHANGELOG.md`.
8. **The listing and the licence notes agree.** The game's name and icon are reserved (`TRADEMARKS.md`); the art, sound and writing are all rights reserved (`ASSETS-LICENSE.md`); the code is MIT (`LICENSE`). Nothing in the listing says the game itself is open source.
9. The privacy answers in App Store Connect still say no data is collected (design principle 4).
10. The third-party notices (`THIRD-PARTY-NOTICES.md`) list every bundled font and library.

## After

11. Tag the commit `v<version>-<build>` and push the tag.
12. Close the milestone.
