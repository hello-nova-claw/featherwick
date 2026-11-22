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

### Manual App Store archive

CI has no archive or upload step. The maintainer archives on their own Mac.

1. Raise `CURRENT_PROJECT_VERSION` in `App/project.yml`. App Store Connect refuses a build number it has seen before, so every upload needs a new one. Merge the change into `main` in its own pull request, wait for every check to pass, then pull `main` and archive from it. Then `main` holds the number that was uploaded, and the next upload cannot reuse it.
2. `cd App && xcodegen`. The project is generated, so a change to `project.yml` reaches Xcode only after this step.
3. From `App`, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`, if that is not done yet. Set the team ID, and set `PRODUCT_BUNDLE_IDENTIFIER` to the bundle ID of the app record in App Store Connect: the example's placeholder does not match it, and the upload then has no app to join. The file is git-ignored, so neither value is committed.
4. In Xcode, choose the "Featherwick" scheme and "Any iOS Device (arm64)", then Product ▸ Archive. Never archive "Featherwick Beta" for the App Store: it compiles in the beta questions and the testing aids.
5. In the Organizer, select the archive and choose Validate App. The report must list no missing icon and no missing privacy manifest reason.
6. Choose Distribute App ▸ App Store Connect ▸ Upload.
7. Check a Release build has none of the testing aids: Settings shows no "Open test tools", no Time of day and no Fast forward.

## The listing

7. The App Store or TestFlight text, screenshots and "What to test" match `CHANGELOG.md`.
8. **The listing and the licence notes agree.** The game's name and icon are reserved (`TRADEMARKS.md`); the art, sound and writing are all rights reserved (`ASSETS-LICENSE.md`); the code is MIT (`LICENSE`). Nothing in the listing says the game itself is open source.
9. The privacy answers in App Store Connect still say no data is collected (design principle 4).
10. The third-party notices (`THIRD-PARTY-NOTICES.md`) list every bundled font and library.

## After

11. Tag the commit `v<version>-<build>` and push the tag.
12. Close the milestone.
