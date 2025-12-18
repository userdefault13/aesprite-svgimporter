#!/bin/bash

# Batch Import All Collateral Base JSONs
# Usage: ./batch-import-all-collateral-bases.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATCH_SCRIPT="$SCRIPT_DIR/batch-import-collateral-base.sh"
JSON_DIR="$SCRIPT_DIR/../AavegotchiQuerey/cli/exports/Body"

# Find all collateral base JSON files
JSON_FILES=(
  "$JSON_DIR/collateral-base-amdai-1764615568184.json"
  "$JSON_DIR/collateral-base-amusdc-1764615570708.json"
  "$JSON_DIR/collateral-base-amusdt-1764615570086.json"
  "$JSON_DIR/collateral-base-amwbtc-1764615571349.json"
  "$JSON_DIR/collateral-base-amweth-1764615568822.json"
  "$JSON_DIR/collateral-base-amwmatic-1764615571975.json"
  "$JSON_DIR/collateral-base-maaave-1764615563759.json"
  "$JSON_DIR/collateral-base-madai-1764615562504.json"
  "$JSON_DIR/collateral-base-mauni-1764615566920.json"
  "$JSON_DIR/collateral-base-malink-1764615564389.json"
  "$JSON_DIR/collateral-base-matusd-1764615566285.json"
  "$JSON_DIR/collateral-base-mausdc-1764615565635.json"
  "$JSON_DIR/collateral-base-mausdt-1764615565007.json"
  "$JSON_DIR/collateral-base-maweth-1764615563133.json"
  "$JSON_DIR/collateral-base-mayfi-1764615567551.json"
)

echo "Batch Import All Collateral Base JSONs"
echo "======================================="
echo "Total files: ${#JSON_FILES[@]}"
echo ""

cd "$SCRIPT_DIR"

success_count=0
error_count=0

for i in "${!JSON_FILES[@]}"; do
  json_file="${JSON_FILES[$i]}"
  filename=$(basename "$json_file")
  
  if [ ! -f "$json_file" ]; then
    echo "[$((i+1))/${#JSON_FILES[@]}] ✗ File not found: $filename"
    error_count=$((error_count + 1))
    continue
  fi
  
  echo "[$((i+1))/${#JSON_FILES[@]}] Processing: $filename"
  
  if "$BATCH_SCRIPT" "$json_file" > /tmp/batch_import_$$.log 2>&1; then
    echo "  ✓ Success"
    success_count=$((success_count + 1))
  else
    echo "  ✗ Failed (check log)"
    cat /tmp/batch_import_$$.log | grep -i "error" | head -3
    error_count=$((error_count + 1))
  fi
  echo ""
done

rm -f /tmp/batch_import_$$.log

echo "======================================="
echo "BATCH IMPORT COMPLETE"
echo "======================================="
echo "Successfully processed: $success_count/${#JSON_FILES[@]}"
echo "Errors: $error_count/${#JSON_FILES[@]}"
echo "======================================="

