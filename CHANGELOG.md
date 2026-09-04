# Changelog

All notable changes to SVG Importer for Aseprite are documented here.

## [Unreleased]

### Added
- Shapes: `<ellipse>`, `<line>`, `<polygon>`, `<polyline>` (previously only path/rect/circle)
- Stroke rendering: `stroke`, `stroke-width`, `stroke-opacity`, inline or via CSS class
- Gradient fills: `<linearGradient>` and `<radialGradient>`, both `objectBoundingBox` and
  `userSpaceOnUse`, with multi-stop `offset`/`stop-color`/`stop-opacity`
- Full transform support: `rotate()`, `skewX()`, `skewY()`, `matrix()` at both group and
  element level (previously only `translate`/`scale` on groups and `matrix()` on elements)
- Real `clip-path`/`<clipPath>` support, composable with `<mask>`
- `<use href="#id">` / `<use xlink:href="#id">` resolution
- SMIL animation rewrite: `<animate>`/`<animateColor>` (arbitrary attribute keyframing) and
  `<animateMotion>` (straight-line path sampling), multiple simultaneous animators each
  targeting their own element (nesting parent or `xlink:href`/`href` by id), and proper
  time-based linear interpolation between keyframes instead of stepping through raw values
- Test suite: `tests/run-fixtures.lua`, `tests/run-animation-fixtures.lua` (pixel-exact
  assertions per capability) and `tests/run-golden.lua` (regression snapshot over the full
  `examples/svgItems/` corpus)

### Fixed
- `fill="none"` rendered as solid black instead of not rendering at all
- Rotated/skewed `<rect>` rendered as its axis-aligned bounding box instead of the actual
  rotated shape (rects are now normalized to path geometry like every other shape)
- `opacity` blended a lone translucent shape toward black instead of true alpha
  transparency (the renderer now tracks per-pixel alpha end-to-end)
- `--script-param` (the only reliable way to pass args to an Aseprite 1.3.x batch script)
  was accepted by no code path in `svg-importer-cli.lua`; the documented `-- arg1 arg2`
  positional form never actually reached the script's `...`

## [1.0.0] - 2026-09-01

### Added
- Aseprite extension with **File → Import SVG** command
- Pixel-perfect SVG rendering for path, rect, and circle elements
- CSS class fill support via embedded `<style>` blocks
- Nested `<g>` transforms, group fill inheritance, and nested `<svg x/y>` positioning
- Pattern fills (`url(#pattern)`) and mask support
- Clipboard paste workflow for multi-line SVG (Aseprite entry fields are single-line)
- Animation import:
  - **Pose groups**: sibling top-level `<g class="...">` elements become frames
  - **SMIL**: basic `<animateTransform>` sampling with configurable FPS
- CLI script (`svg-importer-cli.lua`) for headless batch conversion
- Build script: `scripts/build-extension.sh`

### Notes
- Requires Aseprite 1.3.x with extension and clipboard API support
- See [docs/LIMITATIONS.md](docs/LIMITATIONS.md) for unsupported SVG features
