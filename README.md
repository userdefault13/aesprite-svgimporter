# SVG Importer for Aseprite

A professional SVG importer plugin for Aseprite that handles complex pixel art SVGs with pixel-perfect rendering.

## Features

✅ **Pixel-perfect 1:1 rendering** - Integer-only algorithm for exact pixel mapping
✅ **CSS class support** - Handles SVG stylesheets with color classes
✅ **Path holes** - Correctly renders paths with transparent holes (non-zero winding rule)
✅ **Multi-path support** - Complex paths with multiple sub-paths
✅ **Epsilon-based boundaries** - Eliminates floating-point precision errors
✅ **Group inheritance** - Nested `<g>` elements with fill inheritance
✅ **Nested SVG positioning** - Supports `<svg x="7" y="31">` positioning for wearables  

## Installation

1. Download `svg-importer-positioning-fix-v2.aseprite-extension`
2. In Aseprite: **Edit → Preferences → Extensions**
3. Click **Add Extension** and select the file
4. Restart Aseprite
5. Use via **File → Scripts → Import SVG**

## Usage


### Batch: Generate Eye Shapes for All Collaterals

A bash helper runs `eye-shapes-batch.lua` for every collateral found across Haunt 1/2 JSONs.

```
./batch-eye-shapes-all-collaterals.sh
```

- Skips collaterals that already have any eye-shape outputs in `output/<collateral>/eye shape/` by default.
- Override the Aseprite CLI path if needed:

```
ASEPRITE_BIN="/usr/local/bin/aseprite" ./batch-eye-shapes-all-collaterals.sh
```

- To force regeneration for all collaterals (ignore existing outputs):

```
ONLY_MISSING=0 ./batch-eye-shapes-all-collaterals.sh
```

### Auto Size (Recommended)
- Select **"Auto (SVG Size)"** for pixel-perfect 1:1 rendering
- Canvas dimensions match SVG viewBox exactly
- Uses optimized integer-only algorithm

### Custom Size
- Choose specific canvas dimensions
- SVG scales to fit with padding
- Uses floating-point algorithm

## Examples

See the `examples/` directory for test SVGs:

- **`1_CamoHat.svg`** (34×20) - Tests epsilon fix for 35-pixel bug
- **`22_CaptainAaveSuit.svg`** (50×22) - Tests path holes ("A" logo)
- **`114_RedHawaiianShirt.svg`** (40×18) - Tests CSS classes (pink, teal, lime green)
- **Aavegotchi SVGs** - Complex multi-path examples

## Technical Details

### Rendering Algorithms

1. **Integer-only** (scale = 1.0) - Pixel-perfect with epsilon boundaries
2. **Non-zero winding** (scaled) - Browser-compatible with floating-point

### CSS Support

Parses CSS stylesheets:
```css
<style><![CDATA[
.T{fill:#f122ad}    /* Pink */
.S{fill:#2234cb}    /* Teal */
.b{fill:#28ff3c}    /* Lime green */
]]></style>
```

Applied to paths:
```svg
<path d="..." class="T"/>  /* Gets pink #f122ad */
```

### Nested SVG Positioning

Supports wearable positioning with nested `<svg>` elements:
```svg
<svg viewBox="0 0 64 64">
  <g class="gotchi-wearable wearable-body">
    <svg x="7" y="31">
      <!-- Wearable content positioned at (7,31) -->
      <path d="..." fill="#0fa9c9"/>
    </svg>
  </g>
</svg>
```

All coordinates in nested SVGs are automatically offset by the parent SVG's x,y position.

### Path Holes

Handles complex paths with holes using non-zero winding rule:
- Outer path winds clockwise → winding +1
- Inner path winds counter-clockwise → winding -1
- Overlap creates hole when winding = 0

## Project Structure

```
svg-importer/
├── svg-importer-positioning-fix-v2.aseprite-extension  # Latest extension (positioning fix)
├── svg-importer.lua                           # Main plugin
├── svg-parser.lua                             # SVG parsing with CSS + nested SVG
├── svg-renderer-professional.lua              # Scanline rendering
├── examples/                                  # Test SVG files
├── docs/                                      # Technical documentation
└── README.md                                  # This file
```

## Version History

- **v1.8.0** - Added nested SVG positioning support for wearables
- **v1.7.0** - Fixed CSS color parsing (semicolon handling)
- **v1.6.0** - CSS class support, path holes, epsilon fix
- **v1.5.0** - Epsilon-based boundary handling
- **v1.4.0** - Non-zero winding rule
- **v1.3.0** - Scanline fill algorithm
- **v1.2.0** - Sub-path handling
- **v1.1.0** - Initial release

## Troubleshooting

**Missing colors?** Ensure CSS classes are properly defined in `<style>` block.

**Wrong pixel count?** Use "Auto (SVG Size)" for 1:1 pixel mapping.

**Missing holes?** Check that sub-paths have opposite winding directions.

**Performance issues?** Large SVGs use floating-point algorithm; consider breaking into smaller files.

## Batch Processing

The SVG importer now includes a powerful CLI-based batch processing tool for converting multiple SVGs to Aseprite files with metadata-driven positioning.

### Features

✅ **Batch directory processing** - Process all SVGs in a directory  
✅ **Specific file processing** - Process individual files by ID  
✅ **Multi-view support** - Front, left, right, back views with proper offsets  
✅ **Metadata-driven positioning** - Uses Aavegotchi wearables database for accurate placement  
✅ **Comprehensive logging** - Detailed logs with timing and error reporting  
✅ **Flexible output sizing** - Configurable canvas sizes (default 64x64)  

### Installation

1. Ensure you have Aseprite CLI installed and in your PATH
2. Place all required files in your project directory:
   - `batch-svg-importer.lua`
   - `batch-config.lua`
   - `json-metadata-loader.lua`
   - `aavegotchi_db_wearables.json`
   - `batch-process.sh` (make executable: `chmod +x batch-process.sh`)

### Usage

#### Shell Script (Recommended)

```bash
# Process all SVGs in examples/ directory, front view
./batch-process.sh examples output 0

# Process all SVGs in examples/ directory, left view
./batch-process.sh examples output 1

# Process specific wearable IDs, front view
./batch-process.sh "1,2,22" output 0

# Process with custom canvas size (32x32)
./batch-process.sh examples output 0 32

# Show help
./batch-process.sh --help
```

#### Direct Aseprite CLI

```bash
# Process directory
aseprite -b --script batch-svg-importer.lua -- examples output 0

# Process specific files
aseprite -b --script batch-svg-importer.lua -- "1,2,22" output 1

# Custom size
aseprite -b --script batch-svg-importer.lua -- examples output 0 32
```

### Arguments

- **input_path**: Directory path or comma-separated file list (e.g., `examples` or `1,2,22`)
- **output_dir**: Directory to save .aseprite files
- **view_index**: View index (0=front, 1=left, 2=right, 3=back)
- **target_size**: Final canvas size (default: 64)

### View Mapping

The batch processor supports four views with proper offset positioning:

| Index | View | Description |
|-------|------|-------------|
| 0 | Front | Default front-facing view |
| 1 | Left | Left side view |
| 2 | Right | Right side view |
| 3 | Back | Back-facing view |

### File Naming

- **Input**: `{id}_{name}.svg` (e.g., `1_CamoHat.svg`)
- **Output**: `{id}_{name}_{view}.aseprite` (e.g., `1_CamoHat_front.aseprite`)

### Offset Positioning

The batch processor uses metadata from `aavegotchi_db_wearables.json` to position SVGs correctly:

1. **Native rendering**: SVG renders at its natural size
2. **Offset application**: Top-left corner positioned at `(offset.x, offset.y)` on target canvas
3. **Canvas creation**: Creates target-size canvas with transparent background
4. **Pixel placement**: Places rendered pixels with proper offset, clipping to canvas bounds

### Logging

The batch processor creates detailed logs in `batch_import_log.txt`:

```
[2025-10-27 10:30:15] [INFO] Batch SVG Import Started
[2025-10-27 10:30:15] [INFO] Config: input=examples, output=output, view=0 (front), size=64x64
[2025-10-27 10:30:15] [INFO] ---
[2025-10-27 10:30:15] [INFO] Processing: 1_CamoHat.svg
[2025-10-27 10:30:15] [INFO] Wearable ID: 1 (Camo Hat), View: 1, Offset: (15,2)
[2025-10-27 10:30:15] [INFO] Native SVG size: 34x20
[2025-10-27 10:30:15] [INFO] Rendered 4523 pixels
[2025-10-27 10:30:15] [INFO] Placed 4523 pixels on 64x64 canvas
[2025-10-27 10:30:15] [INFO] Saved: output/1_CamoHat_front.aseprite (Time: 0.32s)
[2025-10-27 10:30:15] [INFO] [OK] 1_CamoHat.svg → 1_CamoHat_front.aseprite
[2025-10-27 10:30:15] [INFO] ---
[2025-10-27 10:30:15] [INFO] Summary: 8/9 successful (88.9%), Total time: 2.4s
```

### Configuration

Modify `batch-config.lua` to customize behavior:

```lua
return {
  metadata_file = "aavegotchi_db_wearables.json",
  default_target_size = 64,
  default_view_index = 0,  -- front
  log_file = "batch_import_log.txt",
  views = {"front", "left", "right", "back"},
  max_errors = 100,
  continue_on_error = true
}
```

### Troubleshooting

**"Aseprite CLI not found"**
- Ensure Aseprite is installed and `aseprite` command is in your PATH
- On macOS: Add Aseprite to Applications and create symlink: `sudo ln -s /Applications/Aseprite.app/Contents/MacOS/Aseprite /usr/local/bin/aseprite`

**"No metadata found for wearable ID"**
- Check that `aavegotchi_db_wearables.json` exists and contains the wearable ID
- Verify filename format: `{id}_{name}.svg`

**"Could not parse SVG"**
- Ensure SVG files are valid and readable
- Check that SVG contains proper viewBox attribute

**"No pixels rendered"**
- Verify SVG contains visible path elements
- Check that paths have valid fill colors

**Performance issues**
- Large SVGs take longer to process
- Consider processing smaller batches
- Monitor `batch_import_log.txt` for timing information

### Examples

Process all examples with different views:

```bash
# Front view
./batch-process.sh examples output_front 0

# Left view  
./batch-process.sh examples output_left 1

# Right view
./batch-process.sh examples output_right 2

# Back view
./batch-process.sh examples output_back 3
```

Process specific wearables:

```bash
# Process Camo Hat, Captain Aave Suit, and 3D Glasses
./batch-process.sh "1,22,351" output 0
```

## License

Open source - feel free to modify and distribute.