# SVG Importer for Aseprite

Import SVG files and inline SVG code into Aseprite sprites with pixel-perfect rendering, gradients, strokes, full transforms, `<use>`, masks/clip-paths, and multi-animator SMIL animation.

Built for pixel-art SVGs (paths and shapes on a grid). Originally developed for [Aavegotchi](https://aavegotchi.com/) wearables, but works with most static and animated SVG markup — see [docs/LIMITATIONS.md](docs/LIMITATIONS.md) for the remaining gaps (text, filters, embedded images, CSS `@keyframes`).

## Install

### npm (recommended)

```bash
npx @userdefault/svg-importer install
```

Restart Aseprite, then use **File → Import SVG**.

### Manual extension file

1. Download `svg-importer.aseprite-extension` from [GitHub Releases](https://github.com/userdefault13/aesprite-svgimporter/releases)
   or build: `./scripts/build-extension.sh` → `dist/svg-importer.aseprite-extension`
2. In Aseprite: **Edit → Preferences → Extensions → Add Extension**
3. Select the `.aseprite-extension` file
4. Restart Aseprite
5. Run **File → Import SVG**

Requires Aseprite **1.3.x** (extensions + clipboard API).

Publishing notes: [docs/NPM.md](docs/NPM.md)

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

**SMIL:** `<animateTransform>`, `<animate>`/`<animateColor>` (any attribute — fill, opacity, geometry, …), and `<animateMotion>` are all sampled at **SMIL FPS** (default 8), with proper time-based interpolation between keyframes. Multiple simultaneous animators are supported — each targets its own element (nesting parent, or `xlink:href`/`href` by id) and can loop independently if its `dur` is shorter than the longest animator on the page. Frame durations are set on the timeline for SMIL imports.

Imported animations get an `animation` tag spanning all frames.

## CLI

Run from the repository root (scripts use `dofile` for sibling modules). Aseprite 1.3.x does not
forward `-- arg1 arg2 ...` to a batch script's `...`, so pass arguments via `--script-param` (or
the equivalent environment variables):

```bash
# Single frame, auto canvas size
aseprite -b --script-param file=input.svg --script svg-importer-cli.lua

# Fixed canvas + output path
aseprite -b --script-param file=input.svg --script-param width=64 --script-param height=64 \
  --script-param output=output.aseprite --script svg-importer-cli.lua

# Animated import (pose groups or SMIL)
SVG_FILE=input.svg SVG_ANIMATED=1 SVG_FPS=8 SVG_OUTPUT=out.aseprite \
  aseprite -b --script svg-importer-cli.lua
```

### Parameters (`--script-param name=value`, or the matching env var)

| `--script-param` | Env var | Values | Description |
|---|---|---|---|
| `file` | `SVG_FILE` | path | Input SVG |
| `output` | `SVG_OUTPUT` | path | Output `.aseprite` file |
| `width` / `height` | `SVG_WIDTH` / `SVG_HEIGHT` | number | Canvas size (optional) |
| `mode` | `SVG_IMPORT_MODE` | `Auto`, `Single Frame`, `Animation Frames` | Import mode |
| `animated` | `SVG_ANIMATED` | `1` | Same as `mode=Animation Frames` |
| `fps` | `SVG_FPS` | number | SMIL sampling rate (default 8) |

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
├── tests/
│   ├── run-fixtures.lua           # Parser/renderer unit tests, pixel-exact
│   ├── run-animation-fixtures.lua # SMIL engine unit tests
│   ├── run-golden.lua             # Regression snapshot over examples/svgItems/
│   ├── fixtures/                  # One SVG per targeted capability
│   └── golden/baseline.txt        # Committed snapshot to diff against
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

### Tests

```bash
aseprite -b --script tests/run-fixtures.lua            # parser + renderer, pixel-exact assertions
aseprite -b --script tests/run-animation-fixtures.lua   # SMIL engine
aseprite -b --script-param output=tests/golden/current.txt --script tests/run-golden.lua
diff tests/golden/baseline.txt tests/golden/current.txt # should be empty (or explainable)
```

## Limitations

See [docs/LIMITATIONS.md](docs/LIMITATIONS.md). Notable gaps: text, filters, embedded raster
images, CSS `@keyframes`, curved `animateMotion` paths.

## Batch processing (Aavegotchi)

Wearables batch tooling, JSON metadata loaders, and collateral converters live in this repo for historical workflows. See [docs/BATCH_PROCESSING.md](docs/BATCH_PROCESSING.md).

## License

[MIT](LICENSE) — Undeadpixel Studio
