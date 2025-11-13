#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/juliuswong/Dev/aesprite-svgimporter"
JSON="$ROOT/wearables-1-20.json"
OUT_DIR="$ROOT/tmp/item8-test"

mkdir -p "$OUT_DIR"

# Front body
jq -r '.wearables["8"].sides.Front.svg' "$JSON" \
  > "$OUT_DIR/8_front_body.svg"

# Sleeves (array order: left up, left down, right up, right down)
jq -r '.wearables["8"].sleeves[0]' "$JSON" \
  > "$OUT_DIR/8_front_sleeve_left_up.svg"

jq -r '.wearables["8"].sleeves[1]' "$JSON" \
  > "$OUT_DIR/8_front_sleeve_left_down.svg"

jq -r '.wearables["8"].sleeves[2]' "$JSON" \
  > "$OUT_DIR/8_front_sleeve_right_up.svg"

jq -r '.wearables["8"].sleeves[3]' "$JSON" \
  > "$OUT_DIR/8_front_sleeve_right_down.svg"

echo "Wrote SVGs to $OUT_DIR"
