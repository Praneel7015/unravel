# Contributing to Unravel

Thanks for helping. A few things keep the project calm and reviewable.

## PR titles are conventional commits

PRs are squash-merged, so the PR title becomes the commit on `main`, and
[Release Please](https://github.com/googleapis/release-please) builds the
version bump and `CHANGELOG.md` from those titles. The `PR title` check
enforces the format:

```
<type>(<optional scope>): <summary>
```

| Type | Use it for | Release effect (before 1.0) |
| --- | --- | --- |
| `feat` | A user-visible feature | minor bump |
| `fix` | A bug fix | patch bump |
| `perf`, `refactor`, `docs`, `test`, `ci`, `build`, `chore`, `style`, `revert` | Everything else | no release on its own |

Add `!` after the type (`feat!: ...`) or a `BREAKING CHANGE:` footer for a
breaking change. Useful scopes: `core`, `sync_foss`, `sync_store`, `foss`,
`store`, `supabase`, `deps`.

## Before you open a PR

```bash
flutter pub get
dart format $(git ls-files '*.dart' ':!:*.g.dart')
flutter analyze
(cd packages/core && flutter test)
```

CI runs the same checks, the F-Droid purity audit, a FOSS APK build, OSV,
Gitleaks and CodeQL. CodeRabbit reviews every PR against the rules in
`.coderabbit.yaml`.

## Ground rules

- Plaintext journal text, keys and passphrases never get logged or leave the
  device unencrypted.
- No network call without a clear, user-facing reason. The FOSS edition is
  air-gapped by default.
- No streaks, counters, badges or re-engagement nudges. Ever.
- `apps/unravel_foss` and `packages/sync_foss` stay free of proprietary SDKs.
- Don't edit versions by hand; Release Please owns `version:` in
  `pubspec.yaml` and mirrors it into the app pubspecs.
