# SVG Importer - Epsilon Fix Extension

**File**: `svg-importer-epsilon-fix.aseprite-extension`  
**Version**: 1.5.0  
**Date**: October 27, 2025

## What's Fixed

This extension fixes the **35-pixel rendering bug** where SVG files with a 34-pixel viewBox were incorrectly rendering at 35 pixels wide, causing:
- Extra column of pixels on the right edge
- Missing or distorted right outline
- Horizontal stretching of fill patterns
- Misaligned shapes

## Key Changes

### 1. Epsilon-Based Boundary Handling
All three fill algorithms now use epsilon (±0.0001) to handle floating-point precision:

```lua
local epsilon = 0.0001
local xStart = math.max(0, math.floor(fillStart + epsilon))
local xEnd = math.min(width - 1, math.floor(crossing.x - epsilon))
```

This prevents floating-point errors like `34.0000001` from creating an extra pixel.

### 2. Integer-Only Rendering for 1:1 Scale
When viewBox dimensions match canvas dimensions (scale = 1.0), uses optimized integer-only algorithm for:
- Cleaner logic
- Predictable results
- Better performance

### 3. Correct Coordinate-to-Pixel Mapping
- **Pixel indices**: 0 to 33 (34 pixels)
- **SVG coordinates**: 0.0 to 34.0 (34 units)
- **Mapping**: Coordinate X → pixel floor(X - epsilon)

## Installation

1. In Aseprite, go to **Edit → Preferences → Extensions**
2. Click **Add Extension**
3. Select `svg-importer-epsilon-fix.aseprite-extension`
4. Restart Aseprite
5. Import SVG: **File → Import SVG** or **File → Scripts → svg-importer**

## Testing

To verify the fix works:

### Test 1: Camo Hat (34×20)
```
1. Import 1_CamoHat.svg with "Auto (SVG Size)" or 34×20 canvas
2. Check Canvas Size dialog shows 34×20
3. Verify black outline spans full width (no extra column on right)
4. Confirm camouflage patterns are not horizontally stretched
5. Check max pixel coords show X=33, Y=19 (correct for 34×20)
```

### Test 2: Custom Size
```
1. Import same SVG with 35×20 canvas
2. Should now scale properly with padding
3. Black outline should be visible on all sides
```

## What's Included

- `svg-importer.lua` - Main plugin file
- `svg-parser.lua` - SVG path parsing
- `svg-renderer-professional.lua` - Scanline fill algorithms with epsilon fix
- `package.json` - Extension metadata

## Technical Details

### Scanline Fill Algorithms

1. **Even-odd rule** - For simple paths
2. **Non-zero winding rule** - For complex paths (default)
3. **Integer-only** - For pixel-perfect 1:1 rendering

All three now use epsilon-based boundary calculation to eliminate the floating-point precision bug.

### Coordinate Examples

For a path spanning X=0.0 to X=34.0 on a 34-pixel canvas:

**Before (broken)**:
- Left: floor(0.0) = 0 ✓
- Right: ceil(34.0000001) - 1 = 34 ✗ (35th pixel!)
- Result: 35 pixels rendered

**After (fixed)**:
- Left: floor(0.0 + 0.0001) = 0 ✓
- Right: floor(34.0 - 0.0001) = 33 ✓
- Result: 34 pixels rendered (0-33)

## Known Working Files

- `1_CamoHat.svg` (34×20)
- `Aavegotchi-Gen0-Front-Body-ETH.svg`
- `Aavegotchi-Gen0-Side-Views-Left-Body-ETH.svg`
- `Aavegotchi-Gen0-Side-Views-Right-Body-ETH.svg`

## Troubleshooting

**Q: Still seeing 35 pixels?**
A: Make sure you installed the new extension and restarted Aseprite. Uninstall any older versions first.

**Q: Black outline still missing on right?**
A: Check that the canvas size matches the viewBox (use "Auto (SVG Size)" option).

**Q: Patterns still look stretched?**
A: Verify in the debug dialog that max X coordinate is 33 (not 34) for a 34-pixel canvas.

## Version History

- **1.5.0** - Epsilon fix for 35-pixel bug, integer-only rendering
- **1.4.0** - Non-zero winding rule support
- **1.3.0** - Scanline fill algorithm
- **1.2.0** - Sub-path handling
- **1.1.0** - Initial release

