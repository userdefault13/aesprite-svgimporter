# Batch Import Collateral Base JSON

This tool batch imports all SVGs from a collateral base JSON file into Aseprite as individual `.aseprite` files.

## Files

- **`batch-import-collateral-base-cli.lua`** - Main CLI script (run via Aseprite)
- **`batch-import-collateral-base.sh`** - Shell wrapper script (easier to use)
- **`batch-import-collateral-base.lua`** - GUI version (run from Aseprite File → Scripts)

## Usage

### Option 1: Using the Shell Script (Recommended)

```bash
cd /Users/juliuswong/Dev/aesprite-svgimporter
./batch-import-collateral-base.sh <json_file> [output_dir]
```

**Examples:**
```bash
# Import from AavegotchiQuerey exports
./batch-import-collateral-base.sh ../AavegotchiQuerey/cli/exports/Body/collateral-base-amaave-1764615569457.json

# Specify custom output directory
./batch-import-collateral-base.sh ../AavegotchiQuerey/cli/exports/Body/collateral-base-amaave-1764615569457.json ./output/amaave-sprites
```

### Option 2: Using Aseprite CLI Directly

```bash
aseprite -b --script batch-import-collateral-base-cli.lua -- <json_file> [output_dir]
```

**Example:**
```bash
cd /Users/juliuswong/Dev/aesprite-svgimporter
aseprite -b --script batch-import-collateral-base-cli.lua -- ../AavegotchiQuerey/cli/exports/Body/collateral-base-amaave-1764615569457.json
```

### Option 3: Using the GUI Version

1. Open Aseprite
2. Go to **File → Scripts → Open Script**
3. Select `batch-import-collateral-base.lua`
4. A dialog will appear - select your JSON file
5. Click **Import**

## Output

The script processes all SVG categories from the JSON:

- **Body** (4 views): `body_front_*.aseprite`, `body_left_*.aseprite`, `body_right_*.aseprite`, `body_back_*.aseprite`
- **Hands** (2 poses): `hands_closed_*.aseprite`, `hands_open_*.aseprite`
- **Mouth**: `mouth-neutral_*.aseprite`, `mouth-happy_*.aseprite`
- **Eyes**: `eyes-mad_*.aseprite`, `eyes-happy_*.aseprite`, `eyes-sleepy_*.aseprite`
- **Shadow**: `shadow_*.aseprite`

Files are saved to:
- Default: `<json_dir>/collateral-base-<name>_sprites/`
- Custom: `<output_dir>/` (if specified)

## Example JSON Structure

The script expects a JSON file with this structure:

```json
{
  "body": [
    "<svg>...</svg>",
    "<svg>...</svg>",
    "<svg>...</svg>",
    "<svg>...</svg>"
  ],
  "hands": [
    "<svg>...</svg>",
    "<svg>...</svg>"
  ],
  "mouth_neutral": ["<svg>...</svg>"],
  "mouth_happy": ["<svg>...</svg>"],
  "eyes_mad": ["<svg>...</svg>"],
  "eyes_happy": ["<svg>...</svg>"],
  "eyes_sleepy": ["<svg>...</svg>"],
  "shadow": ["<svg>...</svg>"]
}
```

## Requirements

- Aseprite installed
- JSON file with SVG strings in the expected format
- All dependencies (svg-parser.lua, svg-renderer-professional.lua) in the same directory

## Notes

- Each SVG is imported as a separate 64x64 sprite file
- SVGs are rendered at their native viewBox dimensions
- The script automatically creates output directories if they don't exist
- Progress is printed to the console during processing

