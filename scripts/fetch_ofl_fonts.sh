#!/usr/bin/env bash
# Verifies the bundled SIL Open Font License IBM Plex faces used by
# packages/core. The binaries are committed under packages/core/assets/fonts/.

set -euo pipefail

FONT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/packages/core/assets/fonts"

required=(
  IBMPlexSerif-Regular.ttf
  IBMPlexSerif-Medium.ttf
  IBMPlexSerif-Italic.ttf
  IBMPlexSans-Regular.ttf
  IBMPlexSans-SemiBold.ttf
  IBMPlexMono-Regular.ttf
  IBMPlexMono-Medium.ttf
  OFL-IBMPlex.txt
)

for f in "${required[@]}"; do
  test -s "$FONT_DIR/$f" || {
    echo "Missing font asset: $FONT_DIR/$f" >&2
    exit 1
  }
done

echo "Verified ${#required[@]} IBM Plex / OFL files in $FONT_DIR"
