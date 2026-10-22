#!/usr/bin/env bash
# Fetches the exact SIL Open Font License (OFL 1.1) .ttf binaries required by
# `packages/core/pubspec.yaml` for 100% air-gapped F-Droid & Store builds.

set -euo pipefail

FONT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/packages/core/assets/fonts"
mkdir -p "$FONT_DIR"

curl -fsSL "https://github.com/google/fonts/raw/main/ofl/newsreader/Newsreader%5Bopsz,wght%5D.ttf" -o "$FONT_DIR/Newsreader-Regular.ttf"
cp "$FONT_DIR/Newsreader-Regular.ttf" "$FONT_DIR/Newsreader-Medium.ttf"
curl -fsSL "https://github.com/google/fonts/raw/main/ofl/newsreader/Newsreader-Italic%5Bopsz,wght%5D.ttf" -o "$FONT_DIR/Newsreader-Italic.ttf"

curl -fsSL "https://github.com/google/fonts/raw/main/ofl/plusjakartasans/PlusJakartaSans%5Bwght%5D.ttf" -o "$FONT_DIR/PlusJakartaSans-Regular.ttf"
cp "$FONT_DIR/PlusJakartaSans-Regular.ttf" "$FONT_DIR/PlusJakartaSans-SemiBold.ttf"

curl -fsSL "https://github.com/google/fonts/raw/main/ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf" -o "$FONT_DIR/JetBrainsMono-Regular.ttf"
cp "$FONT_DIR/JetBrainsMono-Regular.ttf" "$FONT_DIR/JetBrainsMono-Medium.ttf"

echo "Verified all 7 OFL font binaries in $FONT_DIR"
