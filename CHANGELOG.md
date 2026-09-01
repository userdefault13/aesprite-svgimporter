# Changelog

All notable changes to SVG Importer for Aseprite are documented here.

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
