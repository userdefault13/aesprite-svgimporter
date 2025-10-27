# Integer-Only Rendering for Pixel-Perfect SVGs

## Overview

When rendering SVG files where the viewBox dimensions match the canvas dimensions exactly (scale = 1.0), the renderer now uses an optimized **integer-only scanline fill algorithm**. This eliminates floating-point rounding ambiguity and provides cleaner, more predictable results for pixel art.

## How It Works

### Coordinate to Pixel Mapping

For a 34×20 canvas with viewBox "0 0 34 20":

- **ViewBox coordinate space**: 0.0 to 34.0 (34 units wide)
- **Pixel indices**: 0 to 33 (34 pixels)
- **Mapping rule**: SVG coordinate X maps to pixel floor(X)

### Example: Black Outline

Given a path that spans from X=0 to X=34:

```
SVG Path: M32 5 ... H0 ... (h commands totaling 34 units) ... z
```

When the scanline algorithm processes this:
1. Finds intersections at scanline y+0.5 (pixel center)
2. Left intersection: x ≈ 0.0
3. Right intersection: x ≈ 34.0

Pixel calculation:
- **Start pixel**: `floor(0.0) = 0`
- **End pixel**: `ceil(34.0) - 1 = 33`
- **Result**: Pixels 0-33 filled (34 pixels total) ✓

## Algorithm Selection

The renderer automatically chooses the optimal algorithm:

```lua
if scale == 1.0 then
    -- Pixel-perfect 1:1 rendering: use integer-only algorithm
    filledPixels = scanlineFillInteger(points, targetWidth, targetHeight, path.fill)
else
    -- Scaled rendering: use non-zero winding rule with floating-point
    filledPixels = scanlineFillNonZero(points, targetWidth, targetHeight, path.fill)
end
```

## Benefits

1. **Cleaner logic**: Direct coordinate-to-pixel mapping without complex rounding
2. **Predictable results**: Integer math eliminates floating-point edge cases
3. **Performance**: Integer operations are faster than floating-point
4. **Correctness**: Matches how pixel art is conceptually drawn

## Pixel Index vs Count

Important to understand:
- **Pixel index 33** = the 34th pixel (0-indexed)
- **Max coordinate 33** = 34 pixels wide (indices 0-33)
- Dialog showing "Max X=33" is **correct** for 34-pixel width

## Testing

To verify correct rendering:
- Black outline: Should span full canvas width (34 pixels)
- Interior fills: Should respect their defined boundaries
- No pixels should exceed canvas bounds (max index = width-1)

## Implementation Details

The integer algorithm:
1. Builds edges with integer Y bounds
2. Tests intersections at pixel centers (y + 0.5)
3. Uses epsilon (0.0001) to handle floating-point precision:
   - Start boundary: `floor(x + epsilon)`
   - End boundary: `floor(x - epsilon)`
4. Applies non-zero winding rule for complex paths
5. Clamps results to canvas bounds [0, width-1]

### Epsilon Handling

The epsilon approach prevents floating-point precision errors:
- **Without epsilon**: x=34.0000001 → ceil(x)-1 = 34 (WRONG!)
- **With epsilon**: x=34.0000001 → floor(x-0.0001) = floor(34.0) = 34, but wait...
- **Actually**: x=34.0 → floor(x-0.0001) = floor(33.9999) = 33 ✓
- **And**: x=34.0000001 → floor(x-0.0001) = floor(34.0) = 34, clamped to 33 ✓

The epsilon ensures that:
1. Exact boundary coordinates (34.0) don't create an extra pixel
2. Small floating-point errors don't cause off-by-one issues
3. Results are clamped to canvas bounds as a safety net

