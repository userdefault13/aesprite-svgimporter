# SVG Importer for Aseprite

A professional SVG importer plugin for Aseprite that handles complex pixel art SVGs with pixel-perfect rendering.

## Features

✅ **Pixel-perfect 1:1 rendering** - Integer-only algorithm for exact pixel mapping  
✅ **CSS class support** - Handles SVG stylesheets with color classes  
✅ **Path holes** - Correctly renders paths with transparent holes (non-zero winding rule)  
✅ **Multi-path support** - Complex paths with multiple sub-paths  
✅ **Epsilon-based boundaries** - Eliminates floating-point precision errors  
✅ **Group inheritance** - Nested `<g>` elements with fill inheritance  

## Installation

1. Download `svg-importer-css-fixed.aseprite-extension`
2. In Aseprite: **Edit → Preferences → Extensions**
3. Click **Add Extension** and select the file
4. Restart Aseprite
5. Use via **File → Scripts → Import SVG**

## Usage

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

### Path Holes

Handles complex paths with holes using non-zero winding rule:
- Outer path winds clockwise → winding +1
- Inner path winds counter-clockwise → winding -1
- Overlap creates hole when winding = 0

## Project Structure

```
svg-importer/
├── svg-importer-css-fixed.aseprite-extension  # Latest extension
├── svg-importer.lua                           # Main plugin
├── svg-parser.lua                             # SVG parsing with CSS
├── svg-renderer-professional.lua              # Scanline rendering
├── examples/                                  # Test SVG files
├── docs/                                      # Technical documentation
└── README.md                                  # This file
```

## Version History

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

## License

Open source - feel free to modify and distribute.