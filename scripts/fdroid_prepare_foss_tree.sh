#!/usr/bin/env bash
# Strip the store edition from a checkout so F-Droid only sees the FOSS tree.
# Run from the repository root (or from apps/unravel_foss with REPO_ROOT set).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

rm -rf apps/unravel_store packages/sync_store

cat > pubspec.yaml <<'EOF'
name: unravel
publish_to: none

environment:
  sdk: ^3.6.0

workspace:
  - packages/core
  - packages/sync_foss
  - apps/unravel_foss
EOF

echo "Prepared FOSS-only workspace at $ROOT"
