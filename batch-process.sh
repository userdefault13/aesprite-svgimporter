#!/bin/bash

# Batch SVG to Aseprite Converter
# User-friendly wrapper script for the batch SVG importer
# 
# Usage: ./batch-process.sh [input_path] [output_dir] [view_index] [target_size]
#
# Examples:
#   ./batch-process.sh examples output 0        # Process all SVGs in examples/ directory, front view
#   ./batch-process.sh examples output 1        # Process all SVGs in examples/ directory, left view  
#   ./batch-process.sh "1,2,22" output 0       # Process specific wearable IDs, front view
#   ./batch-process.sh examples output 0 32     # Process with 32x32 output size

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_INPUT="examples"
DEFAULT_OUTPUT="output"
DEFAULT_VIEW=0
DEFAULT_SIZE=64

# Parse arguments
INPUT_PATH=${1:-$DEFAULT_INPUT}
OUTPUT_DIR=${2:-$DEFAULT_OUTPUT}
VIEW_INDEX=${3:-$DEFAULT_VIEW}
TARGET_SIZE=${4:-$DEFAULT_SIZE}

# View names for display
VIEW_NAMES=("front" "left" "right" "back")

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Batch SVG to Aseprite Converter"
    echo ""
    echo "Usage: $0 [input_path] [output_dir] [view_index] [target_size]"
    echo ""
    echo "Arguments:"
    echo "  input_path   - Directory path or comma-separated file list (default: examples)"
    echo "  output_dir   - Directory to save .aseprite files (default: output)"
    echo "  view_index   - View index: 0=front, 1=left, 2=right, 3=back (default: 0)"
    echo "  target_size  - Final canvas size (default: 64)"
    echo ""
    echo "Examples:"
    echo "  $0 examples output 0        # Process all SVGs in examples/, front view"
    echo "  $0 examples output 1        # Process all SVGs in examples/, left view"
    echo "  $0 \"1,2,22\" output 0       # Process specific wearable IDs, front view"
    echo "  $0 examples output 0 32     # Process with 32x32 output size"
    echo ""
    echo "View indices:"
    echo "  0 = front view"
    echo "  1 = left view"
    echo "  2 = right view"
    echo "  3 = back view"
}

# Check if help is requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# Validate view index
if [[ ! "$VIEW_INDEX" =~ ^[0-3]$ ]]; then
    print_error "Invalid view index: $VIEW_INDEX. Must be 0-3 (front/left/right/back)"
    show_usage
    exit 1
fi

# Validate target size
if [[ ! "$TARGET_SIZE" =~ ^[0-9]+$ ]] || [ "$TARGET_SIZE" -lt 1 ] || [ "$TARGET_SIZE" -gt 1024 ]; then
    print_error "Invalid target size: $TARGET_SIZE. Must be 1-1024"
    show_usage
    exit 1
fi

# Check if Aseprite is available
ASEPRITE_CMD=""
if command -v aseprite &> /dev/null; then
    ASEPRITE_CMD="aseprite"
elif [ -f "/Applications/Aseprite.app/Contents/MacOS/aseprite" ]; then
    ASEPRITE_CMD="/Applications/Aseprite.app/Contents/MacOS/aseprite"
else
    print_error "Aseprite CLI not found. Please ensure Aseprite is installed."
    exit 1
fi

# Test Aseprite CLI
if ! $ASEPRITE_CMD -b --version &> /dev/null; then
    print_error "Aseprite CLI is not working properly. Please check your installation."
    exit 1
fi

# Check if required files exist
if [ ! -f "batch-svg-importer.lua" ]; then
    print_error "batch-svg-importer.lua not found in current directory"
    exit 1
fi

if [ ! -f "batch-config.lua" ]; then
    print_error "batch-config.lua not found in current directory"
    exit 1
fi

if [ ! -f "json-metadata-loader.lua" ]; then
    print_error "json-metadata-loader.lua not found in current directory"
    exit 1
fi

if [ ! -f "aavegotchi_db_wearables.json" ]; then
    print_error "aavegotchi_db_wearables.json not found in current directory"
    exit 1
fi

# Check if input path exists (for directory mode)
if [[ ! "$INPUT_PATH" =~ , ]] && [ ! -d "$INPUT_PATH" ]; then
    print_error "Input directory does not exist: $INPUT_PATH"
    exit 1
fi

# Create output directory if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
    print_info "Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
fi

# Display configuration
print_info "Batch SVG Processing Configuration:"
echo "  Input: $INPUT_PATH"
echo "  Output: $OUTPUT_DIR"
echo "  View: $VIEW_INDEX (${VIEW_NAMES[$VIEW_INDEX]})"
echo "  Target Size: ${TARGET_SIZE}x${TARGET_SIZE}"
echo ""

# Run the batch processing
print_info "Starting batch processing..."
echo ""

# Set environment variables for the batch script
export BATCH_INPUT_PATH="$INPUT_PATH"
export BATCH_OUTPUT_DIR="$OUTPUT_DIR"
export BATCH_VIEW_INDEX="$VIEW_INDEX"
export BATCH_TARGET_SIZE="$TARGET_SIZE"

# Execute Aseprite with the batch script
if $ASEPRITE_CMD -b --script batch-svg-importer.lua; then
    echo ""
    print_success "Batch processing completed successfully!"
    
    # Show summary if log file exists
    if [ -f "batch_import_log.txt" ]; then
        echo ""
        print_info "Processing Summary:"
        echo "-------------------"
        tail -n 5 batch_import_log.txt | grep -E "(Summary|successful)"
    fi
    
    # Show output files
    if [ -d "$OUTPUT_DIR" ]; then
        file_count=$(find "$OUTPUT_DIR" -name "*.aseprite" | wc -l)
        if [ "$file_count" -gt 0 ]; then
            echo ""
            print_info "Generated $file_count .aseprite files in $OUTPUT_DIR/"
        fi
    fi
else
    echo ""
    print_error "Batch processing failed!"
    
    # Show error details if log file exists
    if [ -f "batch_import_log.txt" ]; then
        echo ""
        print_error "Error details:"
        echo "--------------"
        tail -n 10 batch_import_log.txt | grep -E "\[ERROR\]"
    fi
    
    exit 1
fi
