#!/bin/bash

# Batch Import All Collateral JSONs
# Usage: ./batch-import-all-collaterals.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATCH_SCRIPT="$SCRIPT_DIR/batch-import-collateral.sh"
JSON_DIR="$SCRIPT_DIR/../AavegotchiQuerey/cli/exports/Collaterals"

# Find all collateral JSON files
JSON_FILES=(
  "$JSON_DIR/collateral-amaave-1764616862816.json"
  "$JSON_DIR/collateral-amdai-1764616861561.json"
  "$JSON_DIR/collateral-amusdc-1764616864098.json"
  "$JSON_DIR/collateral-amusdt-1764616863452.json"
  "$JSON_DIR/collateral-amwbtc-1764616864727.json"
  "$JSON_DIR/collateral-amweth-1764616862185.json"
  "$JSON_DIR/collateral-amwmatic-1764616865374.json"
  "$JSON_DIR/collateral-maaave-1764616857068.json"
  "$JSON_DIR/collateral-madai-1764616855782.json"
  "$JSON_DIR/collateral-malink-1764616857710.json"
  "$JSON_DIR/collateral-matusd-1764616859639.json"
  "$JSON_DIR/collateral-mauni-1764616860279.json"
  "$JSON_DIR/collateral-mausdc-1764616859006.json"
  "$JSON_DIR/collateral-mausdt-1764616858350.json"
  "$JSON_DIR/collateral-maweth-1764616856434.json"
  "$JSON_DIR/collateral-mayfi-1764616860916.json"
)

echo "Batch Import All Collateral JSONs"
echo "=================================="
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
  
  if "$BATCH_SCRIPT" "$json_file" > /tmp/batch_import_collateral_$$.log 2>&1; then
    echo "  ✓ Success"
    success_count=$((success_count + 1))
  else
    echo "  ✗ Failed (check log)"
    cat /tmp/batch_import_collateral_$$.log | grep -i "error" | head -3
    error_count=$((error_count + 1))
  fi
  echo ""
done

rm -f /tmp/batch_import_collateral_$$.log

echo "======================================="
echo "BATCH IMPORT COMPLETE"
echo "======================================="
echo "Successfully processed: $success_count/${#JSON_FILES[@]}"
echo "Errors: $error_count/${#JSON_FILES[@]}"
echo "======================================="

