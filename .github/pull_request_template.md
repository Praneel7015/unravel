<!-- PR title: use a conventional commit, e.g. `feat(core): ...`, `fix(sync_foss): ...`. It becomes the squash commit and the changelog entry. -->

## What and why

## How it was tested

- [ ] `dart format`, `flutter analyze` and `flutter test` pass locally
- [ ] New encryption or storage code has a round-trip and a tamper test

## Unravel principles

- [ ] No plaintext, keys or passphrases are logged or leave the device
- [ ] No new network call, or the reason is stated above
- [ ] No streaks, counters or engagement mechanics
- [ ] The FOSS tree (`apps/unravel_foss`, `packages/sync_foss`) still has no proprietary SDKs
