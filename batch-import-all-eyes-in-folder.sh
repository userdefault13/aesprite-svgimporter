#!/bin/bash

# Batch Import All Eyes JSONs in a Folder
# Usage: ./batch-import-all-eyes-in-folder.sh <folder_path>
# Example: ./batch-import-all-eyes-in-folder.sh ../AavegotchiQuerey/cli/exports/SVGs/Eyes/amaave/Collateral/amAAVECollateral_Range_98-99

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATCH_SCRIPT="$SCRIPT_DIR/batch-import-eyes.sh"

if [ $# -lt 1 ]; then
    echo "Batch Import All Eyes JSONs in a Folder"
    echo "========================================"
    echo ""
    echo "Usage: $0 <folder_path>"
    echo ""
    echo "Arguments:"
    echo "  folder_path  - Path to folder containing eye JSON files (required)"
    echo ""
    echo "Example:"
    echo "  $0 ../AavegotchiQuerey/cli/exports/SVGs/Eyes/amaave/Collateral/amAAVECollateral_Range_98-99"
    echo ""
    exit 1
fi

FOLDER_PATH="$1"

# Check if folder exists
if [ ! -d "$FOLDER_PATH" ]; then
    echo "ERROR: Folder not found: $FOLDER_PATH"
    exit 1
fi

# Get absolute path
FOLDER_PATH_ABS="$(cd "$FOLDER_PATH" && pwd)"

# Find all JSON files in the folder
JSON_FILES=("$FOLDER_PATH_ABS"/*.json)
NUM_FILES=${#JSON_FILES[@]}

if [ "$NUM_FILES" -eq 0 ]; then
    echo "No JSON files found in: $FOLDER_PATH_ABS"
    exit 0
fi

echo "Batch Import All Eyes JSONs"
echo "============================"
echo "Folder: $FOLDER_PATH_ABS"
echo "Total files: $NUM_FILES"
echo ""

SUCCESS_COUNT=0
ERROR_COUNT=0

for (( i=0; i<${NUM_FILES}; i++ )); do
    JSON_FILE="${JSON_FILES[$i]}"
    FILENAME=$(basename "$JSON_FILE")
    
    echo "[$(($i+1))/$NUM_FILES] Processing: $FILENAME"
    
    # Run the batch import script
    if "$BATCH_SCRIPT" "$JSON_FILE" > /tmp/batch_import_eyes_$$.log 2>&1; then
        echo "  ✓ Success"
        SUCCESS_COUNT=$((SUCCESS_COUNT+1))
    else
        echo "  ✗ Failed"
        cat /tmp/batch_import_eyes_$$.log | grep -i "error" | head -3
        ERROR_COUNT=$((ERROR_COUNT+1))
    fi
    echo ""
done

rm -f /tmp/batch_import_eyes_$$.log

echo "======================================="
echo "BATCH IMPORT COMPLETE"
echo "======================================="
echo "Successfully processed: $SUCCESS_COUNT/$NUM_FILES"
echo "Errors: $ERROR_COUNT/$NUM_FILES"
echo "======================================="

if [ "$ERROR_COUNT" -gt 0 ]; then
    exit 1
fi

