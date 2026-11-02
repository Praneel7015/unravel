# Shipping Unravel on F-Droid

This repo is prepared for the official F-Droid client. F-Droid builds
`app.unravel.foss` from source. The store edition is never part of that build.

## What is already in place

| Piece | Location |
| --- | --- |
| Copyleft license | [`LICENSE`](../LICENSE) (GPL-3.0-or-later) |
| Third-party notices | [`NOTICE`](../NOTICE) |
| Fastlane listing text | [`fastlane/metadata/android/en-US/`](../fastlane/metadata/android/en-US/) |
| Starter fdroiddata recipe | [`metadata/app.unravel.foss.yml`](../metadata/app.unravel.foss.yml) |
| FOSS-only tree helper | [`scripts/fdroid_prepare_foss_tree.sh`](../scripts/fdroid_prepare_foss_tree.sh) |
| Pinned Flutter version | [`.flutter-version`](../.flutter-version) |

## Before you open the merge request

1. Keep developing in public for a while (F-Droid normally wants ~3 months of active work, unless you already have users or other apps there).
2. Tag a release that matches `apps/unravel_foss/pubspec.yaml` (`version: x.y.z+code`), for example `v0.1.0`.
3. Replace the `commit:` hash in `metadata/app.unravel.foss.yml` with that tag’s full commit.
4. Confirm a clean FOSS tree:

```bash
bash scripts/fdroid_prepare_foss_tree.sh   # on a throwaway clone
flutter pub get
cd apps/unravel_foss && flutter build apk --release
```

5. Fork [fdroiddata](https://gitlab.com/fdroid/fdroiddata), copy `metadata/app.unravel.foss.yml` into their `metadata/` folder, run `fdroid lint` / `fdroid build` if you can, then open a merge request titled something like `New App: app.unravel.foss`.

Official guides:

- [Inclusion Policy](https://f-droid.org/docs/Inclusion_Policy/)
- [Submitting to F-Droid Quick Start](https://f-droid.org/docs/Submitting_to_F-Droid_Quick_Start_Guide/)
- [Reproducible Builds](https://f-droid.org/docs/Reproducible_Builds/) (encouraged for new apps)

## Ideals that Unravel already matches

- No proprietary SDKs in the FOSS package
- Public source, rebuildable APK
- Fastlane descriptions without store-only claims
- Optional WebDAV / local model fields stay on the device; they do not create a cloud account

## AI-assisted work

F-Droid does not ban generative AI. Their discussed interim stance (adapted from Debian) is that AI tools are neither endorsed nor prohibited, and that the human contributor remains responsible for quality, licensing, and review. Disclose AI help if you want; it is not a hard requirement. Blind, unreviewed dumps are not how they ship software.
