# SVG Importer for Aseprite

Import SVG files and inline SVG code into Aseprite sprites with pixel-perfect rendering, CSS class support, and animation frame detection.

Built for pixel-art SVGs (paths and rects on a grid). Originally developed for [Aavegotchi](https://aavegotchi.com/) wearables, but works with any compatible SVG.

## Install

1. Download or build the extension:
   - **Release:** `dist/svg-importer.aseprite-extension`
   - **From source:** `./scripts/build-extension.sh`
2. In Aseprite: **Edit → Preferences → Extensions → Add Extension**
3. Select `svg-importer.aseprite-extension`
4. Restart Aseprite
5. Run **File → Import SVG**

Requires Aseprite **1.3.x** (extensions + clipboard API).

## Quick start

### From a file

1. **File → Import SVG**
2. Choose an SVG file
3. Leave **Canvas Size** on **Auto (SVG Size)** for 1:1 pixel mapping
4. Click **Import**

### From pasted code

Aseprite text fields are single-line only, so multi-line SVG must go through the clipboard:

1. Copy your SVG (Cmd+C / Ctrl+C)
2. **File → Import SVG**
3. Click **Paste SVG from Clipboard**
4. Click **Import**

## Animation

| Import Mode | Behavior |
|-------------|----------|
| **Auto** | Creates multiple frames when pose groups or SMIL animation is detected; otherwise single frame |
| **Single Frame** | Always one frame (all visible content combined) |
| **Animation Frames** | Requires detectable animation; errors if none found |

**Pose groups:** sibling top-level `<g class="gotchi-handsUp">` … groups each become a frame (common in Aavegotchi JSON fragments).

**SMIL:** `<animateTransform values="..." dur="...">` is sampled at **SMIL FPS** (default 8). Frame durations are set on the timeline for SMIL imports.

Imported animations get an `animation` tag spanning all frames.

## CLI

Run from the repository root (scripts use `dofile` for sibling modules):

```bash
# Single frame, auto canvas size
aseprite -b --script svg-importer-cli.lua -- input.svg

# Fixed canvas + output path
aseprite -b --script svg-importer-cli.lua -- input.svg 64 64 output.aseprite

# Animated import (pose groups or SMIL)
SVG_FILE=input.svg SVG_ANIMATED=1 SVG_FPS=8 SVG_OUTPUT=out.aseprite \
  aseprite -b --script svg-importer-cli.lua
```

### Environment variables

| Variable | Values | Description |
|----------|--------|-------------|
| `SVG_FILE` | path | Input SVG |
| `SVG_OUTPUT` | path | Output `.aseprite` file |
| `SVG_WIDTH` / `SVG_HEIGHT` | number | Canvas size (optional) |
| `SVG_IMPORT_MODE` | `Auto`, `Single Frame`, `Animation Frames` | Import mode |
| `SVG_ANIMATED` | `1` | Same as Animation Frames mode |
| `SVG_FPS` | number | SMIL sampling rate (default 8) |

## Examples

Curated test SVGs live under `examples/svgItems/`:

| File | Size | Tests |
|------|------|-------|
| `1_CamoHat.svg` | 34×20 | Epsilon boundary handling |
| `22_CaptainAaveSuit.svg` | 50×22 | Path holes (winding rule) |
| `114_RedHawaiianShirt.svg` | 40×18 | CSS class colors |

## Development

```
aesprite-svgimporter/
├── extracted/          # Extension source (packaged by build script)
├── dist/               # Built .aseprite-extension (gitignored)
├── scripts/
│   └── build-extension.sh
├── svg-importer.lua    # Dev copies (keep in sync with extracted/)
├── svg-animation.lua
├── svg-parser.lua
├── svg-renderer-professional.lua
├── svg-importer-cli.lua
├── docs/
│   ├── LIMITATIONS.md
│   └── BATCH_PROCESSING.md
├── CHANGELOG.md
└── LICENSE
```

After editing Lua files in the repo root, copy to `extracted/` and rebuild:

```bash
cp svg-*.lua extracted/
./scripts/build-extension.sh
```

## Limitations

See [docs/LIMITATIONS.md](docs/LIMITATIONS.md). Notable gaps: no gradient/stroke/text support, partial SMIL only.

## Batch processing (Aavegotchi)

Wearables batch tooling, JSON metadata loaders, and collateral converters live in this repo for historical workflows. See [docs/BATCH_PROCESSING.md](docs/BATCH_PROCESSING.md).

## License

[MIT](LICENSE) — Undeadpixel Studio
