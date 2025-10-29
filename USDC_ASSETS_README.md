# USDC Aavegotchi Assets

This document explains the USDC (maUSDC) collateral color conversion for Aavegotchi assets.

## Color Scheme

The USDC color scheme replaces the original Aavegotchi colors:

| Original Color | USDC Color | Usage |
|----------------|------------|-------|
| `#64438e` (dark purple) | `#2664ba` (blue) | Primary color (`.gotchi-primary`) |
| `#edd3fd` (light purple) | `#d4e0f1` (light blue) | Secondary color (`.gotchi-secondary`) |
| `#f696c6` (pink) | `#f696c6` (pink) | Cheek color (`.gotchi-cheek`) |
| `#fff` (white) | `#fff` (white) | Accent/highlight (unchanged) |

## Hands System

**Important:** Each hands file contains **both left and right hands** in the same pose. These are not separate left/right hand assets.

### Hands Poses

1. **`hands_down_closed_maUSDC.aseprite`** (270 pixels)
   - Both hands down with closed fists
   - CSS class: `gotchi-handsDownClosed`

2. **`hands_down_open_maUSDC.aseprite`** (108 pixels)
   - Both hands down with open palms
   - CSS class: `gotchi-handsDownOpen`

3. **`hands_up_maUSDC.aseprite`** (212 pixels)
   - Both hands raised up
   - CSS class: `gotchi-handsUp`

4. **`hands_down_open_alt_maUSDC.aseprite`** (108 pixels)
   - Alternative hands down open pose
   - CSS class: `gotchi-handsDownOpen`

## Body Parts

1. **`body_00_maUSDC.aseprite`** (3,803 pixels)
   - Main body with USDC colors
   - Contains primary, secondary, and white elements

## Canvas Layout

All assets are designed for a **64x64 pixel canvas** and align properly when layered:

- **Body**: Base layer with primary/secondary colors
- **Hands**: Overlay layer with pose-specific positioning
- **Mouth**: Overlay layer for facial expressions
- **Eyes**: Overlay layer for eye expressions
- **Shadow**: Bottom layer for ground shadow

## Usage in Game

The Aavegotchi system uses CSS classes to control which hands pose is visible:

```css
.gotchi-handsDownClosed { display: block; }
.gotchi-handsDownOpen { display: none; }
.gotchi-handsUp { display: none; }
```

## File Structure

```
output/
├── body_00_maUSDC.aseprite
├── hands_down_closed_maUSDC.aseprite
├── hands_down_open_maUSDC.aseprite
├── hands_up_maUSDC.aseprite
├── hands_down_open_alt_maUSDC.aseprite
└── [additional body parts...]
```

## Technical Details

- **Format**: Aseprite (.aseprite)
- **Canvas Size**: 64x64 pixels
- **Color Mode**: RGB
- **Transparency**: Supported (alpha channel)
- **ViewBox**: 0 0 64 64

## Conversion Process

1. Load SVG templates from `aavegotchi_db_main.json`
2. Apply USDC color mapping to CSS classes
3. Wrap in proper SVG document structure
4. Render to 64x64 pixel canvas
5. Save as Aseprite file

## Next Steps

- Complete remaining body parts (mouth, eyes, shadow)
- Verify alignment between all parts
- Scale to other collaterals once USDC is complete
