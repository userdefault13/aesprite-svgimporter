# Limitations

SVG Importer targets **pixel-art SVGs** (Aavegotchi-style paths and rects). It is not a general-purpose SVG renderer.

## Supported

- `<path>`, `<rect>`, `<circle>` (circles converted to paths)
- Inline `fill` and CSS class fills from `<style>` blocks
- `display:none` on classes (elements skipped)
- Nested `<g>` with `translate` / `scale` transforms
- Nested `<svg x="..." y="...">` positioning
- `<defs>` patterns referenced via `fill="url(#id)"`
- `<mask>` coverage
- Pose-group animation (sibling top-level `<g class="...">` groups)
- Basic SMIL `<animateTransform>` (translate, scale, rotate)

## Not supported

- **Gradients** (`linearGradient`, `radialGradient`) — use solid fills or pattern fills
- **Strokes** — only filled shapes are rendered
- **Text** (`<text>`, `<tspan>`)
- **Filters**, **clip-path** (except masks), **foreignObject**
- **CSS animations** / `@keyframes`
- Full SMIL spec (motion paths, sync bases, multiple simultaneous animators)
- **Embedded images** (`<image>`)
- Arbitrary SVG DOM — markup outside paths/rects/circles at the root level prevents pose-group detection

## Import tips

- Use **Auto (SVG Size)** for 1:1 pixel mapping when the SVG has a correct `viewBox`
- Multi-line SVG must be loaded via **Paste SVG from Clipboard**, not the single-line text field
- For JSON-escaped SVG strings, the importer unescapes `\"` automatically
