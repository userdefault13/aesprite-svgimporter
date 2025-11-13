# Generate Single Item All Views

A Python script to generate Aseprite sprite files for all 4 views (front, left, right, back) of Aavegotchi wearable items from SVG data.

## Overview

This script processes wearable items from the Aavegotchi database and converts them into `.aseprite` files with proper positioning and naming conventions. It automatically detects whether an item is a body item (with sleeves) or a non-body item and applies the appropriate structure.

## Features

- **Automatic Item Type Detection**: Detects body items vs non-body items based on `slotPositions[0]` in the database
- **Complete View Generation**: Generates all 4 views (Front, Left, Right, Back) for each item
- **Sleeve Handling**: For body items, generates separate files for body and sleeve components with different arm poses
- **Proper Naming Convention**: Applies consistent naming conventions for files and directories
- **Metadata-Driven Positioning**: Uses offset data from the JSON database to correctly position sprites

## Requirements

- Python 3.x
- Aseprite CLI (must be installed and accessible)
- Required JSON files:
  - `wearables-1-20.json` (or similar wearable data file)
  - `aavegotchi_db_wearables.json` (for body item detection)
- Required Lua scripts (in the same directory):
  - `batch-process.sh`
  - `batch-svg-importer.lua`
  - `json-metadata-loader.lua`
  - `svg-renderer-professional.lua`
  - `svg-parser.lua`

## Usage

```bash
python3 generate-single-item-all-views.py [item_id]
```

### Examples

```bash
# Process item 8 (Marine Jacket)
python3 generate-single-item-all-views.py 8

# Process item 11 (Link Mess Dress)
python3 generate-single-item-all-views.py 11

# Process item 1 (Camo Hat - non-body item)
python3 generate-single-item-all-views.py 1

# Default (processes item 8 if no ID provided)
python3 generate-single-item-all-views.py
```

## Output Structure

### Body Items

Body items (items with `slotPositions[0] = true`) are organized with separate body and sleeve files:

```
output/{item_id}_{item_name}/
├── Back/
│   ├── {item_id}_{item_name}_Back.aseprite
│   ├── {item_id}_{item_name}_BackLeft.aseprite
│   ├── {item_id}_{item_name}_BackRight.aseprite
│   ├── {item_id}_{item_name}_Back_LeftUp.aseprite
│   └── {item_id}_{item_name}_Back_RightUp.aseprite
├── Front/
│   ├── {item_id}_{item_name}_Front.aseprite
│   ├── {item_id}_{item_name}_FrontLeft.aseprite
│   ├── {item_id}_{item_name}_FrontRight.aseprite
│   ├── {item_id}_{item_name}_Front_LeftUp.aseprite
│   └── {item_id}_{item_name}_Front_RightUp.aseprite
├── Left/
│   ├── {item_id}_{item_name}_SideLeft.aseprite
│   ├── {item_id}_{item_name}_SideLeftDown.aseprite
│   └── {item_id}_{item_name}_SideLeftUp.aseprite
└── Right/
    ├── {item_id}_{item_name}_SideRight.aseprite
    ├── {item_id}_{item_name}_SideRightDown.aseprite
    └── {item_id}_{item_name}_SideRightUp.aseprite
```

**Example (Item 8 - Marine Jacket):**
```
output/8_MarineJacket/
├── Back/
│   ├── 8_MarineJacket_Back.aseprite
│   ├── 8_MarineJacket_BackLeft.aseprite
│   ├── 8_MarineJacket_BackRight.aseprite
│   ├── 8_MarineJacket_Back_LeftUp.aseprite
│   └── 8_MarineJacket_Back_RightUp.aseprite
├── Front/
│   ├── 8_MarineJacket_Front.aseprite
│   ├── 8_MarineJacket_FrontLeft.aseprite
│   ├── 8_MarineJacket_FrontRight.aseprite
│   ├── 8_MarineJacket_Front_LeftUp.aseprite
│   └── 8_MarineJacket_Front_RightUp.aseprite
├── Left/
│   ├── 8_MarineJacket_SideLeft.aseprite
│   ├── 8_MarineJacket_SideLeftDown.aseprite
│   └── 8_MarineJacket_SideLeftUp.aseprite
└── Right/
    ├── 8_MarineJacket_SideRight.aseprite
    ├── 8_MarineJacket_SideRightDown.aseprite
    └── 8_MarineJacket_SideRightUp.aseprite
```

### Non-Body Items

Non-body items (items with `slotPositions[0] = false`) have a simpler structure with just 4 files:

```
output/{item_id}_{item_name}/
├── {item_id}_{item_name}_front.aseprite
├── {item_id}_{item_name}_back.aseprite
├── {item_id}_{item_name}_left.aseprite
└── {item_id}_{item_name}_right.aseprite
```

**Example (Item 1 - Camo Hat):**
```
output/1_CamoHat/
├── 1_CamoHat_front_front.aseprite
├── 1_CamoHat_back_back.aseprite
├── 1_CamoHat_left_left.aseprite
└── 1_CamoHat_right_right.aseprite
```

## Naming Conventions

### Body Items

- **Body files**: `{item_id}_{item_name}_{View}.aseprite`
  - Example: `8_MarineJacket_Back.aseprite`

- **Sleeve files (down position)**: `{item_id}_{item_name}_{View}{Side}.aseprite`
  - Example: `8_MarineJacket_BackLeft.aseprite`, `8_MarineJacket_FrontRight.aseprite`

- **Sleeve files (up position)**: `{item_id}_{item_name}_{View}_{Side}Up.aseprite`
  - Example: `8_MarineJacket_Back_LeftUp.aseprite`, `8_MarineJacket_Front_RightUp.aseprite`

- **Side view files**: `{item_id}_{item_name}_Side{Left|Right}[Up|Down].aseprite`
  - Example: `8_MarineJacket_SideLeft.aseprite`, `8_MarineJacket_SideRightUp.aseprite`

### Non-Body Items

- **View files**: `{item_id}_{item_name}_{view}.aseprite`
  - Example: `1_CamoHat_front.aseprite`

## File Locations

The script searches for JSON files in the following locations (in order):

1. `wearables-1-20.json` (current directory)
2. `../AavegotchiQuerey/wearables-1-20.json`
3. `/Users/juliuswong/Dev/AavegotchiQuerey/wearables-1-20.json`

For body item detection:
1. `aavegotchi_db_wearables.json` (current directory)
2. `../AavegotchiQuerey/aavegotchi_db_wearables.json`
3. `/Users/juliuswong/Dev/AavegotchiQuerey/aavegotchi_db_wearables.json`

## How It Works

1. **Load Item Data**: Reads the wearable item data from `wearables-1-20.json`
2. **Detect Item Type**: Checks `aavegotchi_db_wearables.json` to determine if `slotPositions[0]` is `true` (body item)
3. **Extract SVG Components**:
   - For body items: Extracts body groups and sleeve groups from the JSON data
   - For non-body items: Extracts all wearable groups from each view
4. **Create SVG Files**: Wraps extracted components in 64x64 SVG containers
5. **Batch Convert**: Uses `batch-process.sh` to convert SVGs to Aseprite format
6. **Rename Files**: Removes duplicate view suffixes added by the batch converter
7. **Organize Output**: Places files in the appropriate directory structure

## Sleeve Extraction

For body items, sleeves are extracted from:
- The `sleeves` array in the JSON data (for front/back views)
- External SVG files in `examples/svgItems/` (for left/right side views)

The script automatically finds the correct sleeve files using glob patterns:
- `{item_id}_*SideLeftUp.svg`
- `{item_id}_*SideLeftDown.svg`
- `{item_id}_*BackLeftUp.svg`
- etc.

## Error Handling

- Validates that the item exists in the JSON data
- Checks for required files and directories
- Handles missing sleeve files gracefully
- Strips backticks from SVG strings (some JSON entries have them)
- Provides clear error messages if conversion fails

## Notes

- Item names are sanitized for filenames (spaces, apostrophes, hyphens, and dots are removed)
- The script creates temporary directories in `tmp/` for intermediate SVG files
- All output is saved to `output/` directory
- The batch converter automatically applies offsets from the metadata JSON

## Troubleshooting

**Issue**: "Error: Item X not found in wearables JSON"
- **Solution**: Ensure the item ID exists in `wearables-1-20.json`

**Issue**: "Aseprite CLI not found"
- **Solution**: Install Aseprite and ensure the CLI is accessible in your PATH

**Issue**: Files have duplicate suffixes (e.g., `_back_back`)
- **Solution**: The script should automatically rename these. If not, check the renaming logic in the script.

**Issue**: Missing sleeve files
- **Solution**: Ensure the corresponding SVG files exist in `examples/svgItems/` with the correct naming pattern

## See Also

- `batch-process.sh` - Batch processing script
- `batch-svg-importer.lua` - Aseprite batch importer
- `json-metadata-loader.lua` - Metadata loader for offsets

