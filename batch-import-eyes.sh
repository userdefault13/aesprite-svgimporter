#!/bin/bash

# Batch Import Eyes JSON
# Usage: ./batch-import-eyes.sh <json_file> [output_dir]
# Example: ./batch-import-eyes.sh ../AavegotchiQuerey/cli/exports/SVGs/Eyes/amaave/Collateral/amAAVECollateral_Range_98-99/eyes-common-1764652572034.json

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_FILE="$SCRIPT_DIR/batch-import-eyes-cli.lua"

if [ $# -lt 1 ]; then
    echo "Batch Import Eyes JSON"
    echo "======================"
    echo ""
    echo "Usage: $0 <json_file> [output_dir]"
    echo ""
    echo "Arguments:"
    echo "  json_file   - Path to eyes JSON file (required)"
    echo "  output_dir  - Output directory for .aseprite files (optional)"
    echo ""
    echo "Example:"
    echo "  $0 ../AavegotchiQuerey/cli/exports/SVGs/Eyes/amaave/Collateral/amAAVECollateral_Range_98-99/eyes-common-1764652572034.json"
    echo ""
    exit 1
fi

JSON_FILE="$1"
OUTPUT_DIR="$2"

# Check if JSON file exists
if [ ! -f "$JSON_FILE" ]; then
    echo "ERROR: JSON file not found: $JSON_FILE"
    exit 1
fi

# Get absolute path of JSON file
JSON_FILE_ABS="$(cd "$(dirname "$JSON_FILE")" && pwd)/$(basename "$JSON_FILE")"

# Find aseprite executable
ASEPRITE=""
if command -v aseprite &> /dev/null; then
    ASEPRITE="aseprite"
elif [ -f "/Applications/Aseprite.app/Contents/MacOS/aseprite" ]; then
    ASEPRITE="/Applications/Aseprite.app/Contents/MacOS/aseprite"
else
    echo "ERROR: Aseprite not found. Please install Aseprite or add it to your PATH."
    exit 1
fi

echo "Batch Import Eyes JSON"
echo "======================"
echo "Aseprite: $ASEPRITE"
echo "Script: $SCRIPT_FILE"
echo "JSON file: $JSON_FILE_ABS"
if [ -n "$OUTPUT_DIR" ]; then
    echo "Output dir: $OUTPUT_DIR"
fi
echo ""

# Change to script directory for relative paths
cd "$SCRIPT_DIR"

# Set environment variables for the batch script
export BATCH_JSON_FILE="$JSON_FILE_ABS"
if [ -n "$OUTPUT_DIR" ]; then
    export BATCH_OUTPUT_DIR="$OUTPUT_DIR"
fi

# Run aseprite with the script
"$ASEPRITE" -b --script "$SCRIPT_FILE"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✓ Batch import completed successfully!"
else
    echo ""
    echo "✗ Batch import failed with exit code $EXIT_CODE"
    exit $EXIT_CODE
fi

