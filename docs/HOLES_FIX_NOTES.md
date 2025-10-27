# SVG Importer - Holes Fixed

**File**: `svg-importer-holes-fixed.aseprite-extension`  
**Version**: 1.6.0  
**Date**: October 27, 2025

## What's New in This Version

### ✅ Fixed: Paths with Holes (Non-Zero Winding Rule)

This update fixes the rendering of **paths with holes**, such as the "A" logo that should have a transparent center but was rendering solid.

**Problem**: When SVG paths contain multiple sub-paths (like an outer "A" shape and an inner hole), the renderer was filling each sub-path independently, causing the hole to be filled too.

**Solution**: All sub-paths are now combined and filled together, allowing the non-zero winding rule to correctly create holes where paths overlap.

### Example: Captain Aave Suit

The white "A" logo on the Captain Aave Suit (50×22) previously rendered as:
- ❌ Solid white "A" with no hole
- ❌ Missing blue 2×2 pixel in the center

Now renders correctly as:
- ✅ "A" with transparent center hole
- ✅ Blue background visible through the hole

## How It Works

### Multi-Path Rendering

The renderer now processes paths in two stages:

1. **Collect all sub-paths**: Gather all points from all sub-paths with separator markers
2. **Fill with winding rule**: Build edges from all sub-paths and apply non-zero winding rule across the entire shape

### Non-Zero Winding Rule

For paths with holes to work correctly:
- **Outer path** winds in one direction (e.g., clockwise) → winding +1
- **Inner path** winds in opposite direction (e.g., counter-clockwise) → winding -1
- **Overlap area**: winding count goes to 0 → hole created!

### Example Path

```svg
<path d="M27 14...H27z      ← outer "A" shape (winding +1)
         m-1 0h-2v-2h2v2z"/> ← inner hole (winding -1)
```

When the scanline crosses:
- Enters outer path: winding = +1 (start fill)
- Enters inner path: winding = 0 (stop fill → hole!)
- Exits inner path: winding = +1 (resume fill)
- Exits outer path: winding = 0 (stop fill)

## Previous Fixes (Still Included)

### ✅ Epsilon Fix (v1.5.0)
- 35-pixel rendering bug eliminated
- Epsilon-based boundary handling for floating-point precision
- Integer-only mode for 1:1 pixel-perfect rendering

## Installation

1. In Aseprite, go to **Edit → Preferences → Extensions**
2. If you have the previous version, **uninstall it first**
3. Click **Add Extension**
4. Select `svg-importer-holes-fixed.aseprite-extension`
5. Restart Aseprite
6. Import SVG: **File → Scripts → Import SVG**

## Testing

### Test 1: Camo Hat (34×20)
```
✓ Black outline spans 34 pixels (0-33)
✓ No extra column on right edge
✓ Patterns not horizontally stretched
```

### Test 2: Captain Aave Suit (50×22)
```
✓ White "A" logo has visible hole in center
✓ Blue background shows through 2×2 hole
✓ All colors render correctly
✓ No missing pixels
```

## Technical Details

### New Functions

1. **`scanlineFillNonZeroMultiPath()`**  
   Handles multiple sub-paths with non-zero winding rule

2. **`scanlineFillIntegerMultiPath()`**  
   Integer-only version for pixel-perfect 1:1 rendering

3. **`buildEdgesFromMultiPath()`**  
   Builds unified edge list from all sub-paths

### Algorithm Flow

```lua
-- Collect all sub-paths with separators
allPoints = {{x,y}, {x,y}, {isSubPathEnd=true}, {x,y}, ...}

-- Build edges from all sub-paths
edges = buildEdgesFromMultiPath(allPoints)

-- Process scanline with winding rule
for each scanline:
    find all edge crossings
    track winding count
    fill when winding ≠ 0
    create holes when winding = 0
```

## Known Working Files

- ✅ `1_CamoHat.svg` (34×20) - Epsilon fix
- ✅ `22_CaptainAaveSuit.svg` (50×22) - Holes fix  
- ✅ `Aavegotchi-Gen0-Front-Body-ETH.svg`
- ✅ All Aavegotchi side views

## Troubleshooting

**Q: "A" logo still shows no hole?**  
A: Make sure you installed the new `svg-importer-holes-fixed.aseprite-extension` and restarted Aseprite.

**Q: Still seeing 35 pixels for camo hat?**  
A: The epsilon fix is included. Check that canvas size matches viewBox (use "Auto (SVG Size)").

**Q: Some other paths have missing fills?**  
A: The multi-path algorithm requires sub-paths to have opposite winding directions. If your SVG uses same-direction paths, they won't create holes (this matches browser behavior).

## Version History

- **1.6.0** - Multi-path holes fix
- **1.5.0** - Epsilon fix for 35-pixel bug
- **1.4.0** - Non-zero winding rule support
- **1.3.0** - Scanline fill algorithm
- **1.2.0** - Sub-path handling
- **1.1.0** - Initial release

