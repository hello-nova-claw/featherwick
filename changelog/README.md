# Changelog fragments

Each pull request adds one file here, `<issue>-<slug>.txt`, for example `58-string-catalog.txt`. It holds one line a player would understand, such as "Hens now remember who fed them." A pull request with no effect a player can see has the `no-changelog` label instead.

At release time, `bin/changelog` folds every fragment into `CHANGELOG.md` under "Unreleased" and deletes them. See `docs/release-checklist.md`.
