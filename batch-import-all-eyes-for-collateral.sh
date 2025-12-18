#!/bin/bash

# Batch Import All Eyes for a Collateral
# Usage: ./batch-import-all-eyes-for-collateral.sh <collateral_name>
# Example: ./batch-import-all-eyes-for-collateral.sh amaave

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATCH_SCRIPT="$SCRIPT_DIR/batch-import-all-eyes-in-folder.sh"
BASE_DIR="/Users/juliuswong/Dev/AavegotchiQuerey/cli/exports/SVGs/Eyes"

if [ $# -lt 1 ]; then
    echo "Batch Import All Eyes for a Collateral"
    echo "======================================="
    echo ""
    echo "Usage: $0 <collateral_name>"
    echo ""
    echo "Arguments:"
    echo "  collateral_name  - Name of the collateral (e.g., amaave, amdai)"
    echo ""
    echo "Example:"
    echo "  $0 amaave"
    echo ""
    exit 1
fi

COLLATERAL_NAME="$1"
COLLATERAL_DIR="$BASE_DIR/$COLLATERAL_NAME"

if [ ! -d "$COLLATERAL_DIR" ]; then
    echo "ERROR: Collateral directory not found: $COLLATERAL_DIR"
    exit 1
fi

echo "Batch Import All Eyes for Collateral: $COLLATERAL_NAME"
echo "======================================================"
echo "Base directory: $COLLATERAL_DIR"
echo ""

# Find all eye shape folders (folders containing JSON files)
SHAPE_FOLDERS=($(find "$COLLATERAL_DIR" -type d -name "*Range*" | sort))

if [ ${#SHAPE_FOLDERS[@]} -eq 0 ]; then
    echo "No eye shape folders found in: $COLLATERAL_DIR"
    exit 0
fi

echo "Found ${#SHAPE_FOLDERS[@]} eye shape folders"
echo ""

SUCCESS_COUNT=0
ERROR_COUNT=0

for (( i=0; i<${#SHAPE_FOLDERS[@]}; i++ )); do
    FOLDER="${SHAPE_FOLDERS[$i]}"
    FOLDER_NAME=$(basename "$FOLDER")
    RELATIVE_PATH=$(echo "$FOLDER" | sed "s|$COLLATERAL_DIR/||")
    
    echo "[$(($i+1))/${#SHAPE_FOLDERS[@]}] Processing: $RELATIVE_PATH"
    
    # Count JSON files in this folder
    JSON_COUNT=$(ls -1 "$FOLDER"/*.json 2>/dev/null | wc -l | tr -d ' ')
    echo "  Found $JSON_COUNT JSON files"
    
    # Run the batch import script
    if "$BATCH_SCRIPT" "$FOLDER" > /tmp/batch_import_eyes_collateral_$$.log 2>&1; then
        echo "  ✓ Success"
        SUCCESS_COUNT=$((SUCCESS_COUNT+1))
    else
        echo "  ✗ Failed"
        cat /tmp/batch_import_eyes_collateral_$$.log | grep -i "error" | head -3
        ERROR_COUNT=$((ERROR_COUNT+1))
    fi
    echo ""
done

rm -f /tmp/batch_import_eyes_collateral_$$.log

echo "======================================="
echo "BATCH IMPORT COMPLETE"
echo "======================================="
echo "Collateral: $COLLATERAL_NAME"
echo "Folders processed: ${#SHAPE_FOLDERS[@]}"
echo "Successfully processed: $SUCCESS_COUNT/${#SHAPE_FOLDERS[@]}"
echo "Errors: $ERROR_COUNT/${#SHAPE_FOLDERS[@]}"
echo "======================================="

if [ "$ERROR_COUNT" -gt 0 ]; then
    exit 1
fi

