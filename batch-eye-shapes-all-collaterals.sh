#!/usr/bin/env bash
set -euo pipefail

# Resolve repo root relative to this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$SCRIPT_DIR"

# Configurable Aseprite binary (override with ASEPRITE_BIN env var)
ASEPRITE_BIN="${ASEPRITE_BIN:-/Applications/Aseprite.app/Contents/MacOS/aseprite}"
LUA_SCRIPT="$ROOT/eye-shapes-batch.lua"

echo "== Batch Eye Shapes for All Collaterals =="
echo "ROOT=$ROOT"
echo "ASEPRITE_BIN=$ASEPRITE_BIN"

if [[ ! -x "$ASEPRITE_BIN" ]]; then
  echo "ERROR: Aseprite binary not found or not executable at: $ASEPRITE_BIN" >&2
  echo "Hint: export ASEPRITE_BIN=\"/path/to/aseprite\"" >&2
  exit 1
fi

if [[ ! -f "$LUA_SCRIPT" ]]; then
  echo "ERROR: Script not found: $LUA_SCRIPT" >&2
  exit 1
fi

cd "$ROOT"

# Collect collateral names (prefer examples/collaterals, fallback to JSONs)
NAMES=()
tmp_names_file="$(mktemp -t eyeshapes.XXXXXX)" || { echo "ERROR: mktemp failed" >&2; exit 1; }

if [[ -d "$ROOT/examples/collaterals" ]]; then
  for entry in "$ROOT/examples/collaterals"/*; do
    if [[ -d "$entry" ]]; then
      base_name="$(basename "$entry")"
      case "$base_name" in *.meta) continue ;; esac
      echo "$base_name"
    fi
  done | awk '/^(am|ma)[A-Z]+$/' | sort -u > "$tmp_names_file"
elif [[ -f "$ROOT/aavegotchi_db_collaterals_haunt1.json" || -f "$ROOT/aavegotchi_db_collaterals_haunt2.json" ]]; then
  cat "$ROOT"/aavegotchi_db_collaterals_haunt{1,2}.json 2>/dev/null \
    | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]\+\)".*/\1/p' \
    | awk '/^(am|ma)[A-Z]+$/' \
    | sort -u \
    > "$tmp_names_file"
fi

while IFS= read -r line; do
  [ -n "$line" ] && NAMES+=("$line")
done < "$tmp_names_file"
rm -f "$tmp_names_file"

if [[ ${#NAMES[@]} -eq 0 ]]; then
  echo "ERROR: No collateral names found in haunt JSONs." >&2
  exit 1
fi

echo "Found ${#NAMES[@]} collaterals:"
printf ' - %s\n' "${NAMES[@]}"

# Skip mode: if output exists and non-empty, skip
ONLY_MISSING="${ONLY_MISSING:-1}"

fail_count=0
processed_count=0
skipped_count=0

for name in "${NAMES[@]}"; do
  out_dir="$ROOT/output/$name/eye shape"
  if [[ "$ONLY_MISSING" == "1" && -d "$out_dir" && -n "$(ls -A "$out_dir" 2>/dev/null || true)" ]]; then
    echo "[SKIP] $name — existing outputs in: $out_dir"
    skipped_count=$((skipped_count+1))
    continue
  fi

  echo "[RUN ] $name"
  if "$ASEPRITE_BIN" -b --script "$LUA_SCRIPT" --script-param "collateral=$name"; then
    echo "[DONE] $name"
    processed_count=$((processed_count+1))
  else
    echo "[FAIL] $name" >&2
    fail_count=$((fail_count+1))
  fi
done

echo "== Summary =="
echo "Processed: $processed_count"
echo "Skipped:   $skipped_count"
echo "Failures:  $fail_count"

if [[ $fail_count -gt 0 ]]; then
  exit 1
fi

exit 0


