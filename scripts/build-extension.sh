#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/extracted"
DIST="$ROOT/dist"
OUT="$DIST/svg-importer.aseprite-extension"

mkdir -p "$DIST"
rm -f "$OUT"

(
  cd "$SRC"
  zip -j "$OUT" \
    package.json \
    svg-importer.lua \
    svg-animation.lua \
    svg-parser.lua \
    svg-renderer-professional.lua
)

echo "Built $OUT"
unzip -l "$OUT"
