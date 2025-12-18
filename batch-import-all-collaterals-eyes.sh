#!/bin/bash

# Batch Import All Eyes for All Collaterals
# This script processes eyes for all 16 collaterals

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATCH_SCRIPT="$SCRIPT_DIR/batch-import-all-eyes-for-collateral.sh"
BASE_DIR="/Users/juliuswong/Dev/AavegotchiQuerey/cli/exports/SVGs/Eyes"

echo "Batch Import All Eyes for All Collaterals"
echo "=========================================="
echo ""

# Get all collateral directories
COLLATERAL_DIRS=($(find "$BASE_DIR" -maxdepth 1 -type d | grep -v "^$BASE_DIR$" | sed "s|$BASE_DIR/||" | sort))

if [ ${#COLLATERAL_DIRS[@]} -eq 0 ]; then
    echo "ERROR: No collateral directories found in: $BASE_DIR"
    exit 1
fi

echo "Found ${#COLLATERAL_DIRS[@]} collaterals to process"
echo ""

TOTAL_SUCCESS=0
TOTAL_ERROR=0

for (( i=0; i<${#COLLATERAL_DIRS[@]}; i++ )); do
    COLLATERAL="${COLLATERAL_DIRS[$i]}"
    
    echo "=========================================="
    echo "[$(($i+1))/${#COLLATERAL_DIRS[@]}] Processing: $COLLATERAL"
    echo "=========================================="
    echo ""
    
    # Check if collateral directory exists and has eye folders
    COLLATERAL_PATH="$BASE_DIR/$COLLATERAL"
    if [ ! -d "$COLLATERAL_PATH" ]; then
        echo "  ⚠ Skipping: Directory not found"
        echo ""
        continue
    fi
    
    EYE_FOLDERS=($(find "$COLLATERAL_PATH" -type d -name "*Range*" | wc -l | tr -d ' '))
    if [ "$EYE_FOLDERS" -eq 0 ]; then
        echo "  ⚠ Skipping: No eye shape folders found"
        echo ""
        continue
    fi
    
    echo "  Found $EYE_FOLDERS eye shape folders"
    echo ""
    
    # Run the batch import script for this collateral
    if "$BATCH_SCRIPT" "$COLLATERAL" > /tmp/batch_import_collateral_${COLLATERAL}_$$.log 2>&1; then
        echo "  ✓ Successfully processed all eyes for $COLLATERAL"
        TOTAL_SUCCESS=$((TOTAL_SUCCESS+1))
    else
        echo "  ✗ Failed to process $COLLATERAL"
        cat /tmp/batch_import_collateral_${COLLATERAL}_$$.log | grep -i "error\|failed" | head -5
        TOTAL_ERROR=$((TOTAL_ERROR+1))
    fi
    
    rm -f /tmp/batch_import_collateral_${COLLATERAL}_$$.log
    echo ""
done

echo "=========================================="
echo "BATCH IMPORT COMPLETE"
echo "=========================================="
echo "Total collaterals: ${#COLLATERAL_DIRS[@]}"
echo "Successfully processed: $TOTAL_SUCCESS/${#COLLATERAL_DIRS[@]}"
echo "Errors: $TOTAL_ERROR/${#COLLATERAL_DIRS[@]}"
echo "=========================================="

if [ "$TOTAL_ERROR" -gt 0 ]; then
    exit 1
fi

