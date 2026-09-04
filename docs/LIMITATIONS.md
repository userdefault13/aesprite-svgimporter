# Limitations

SVG Importer targets **pixel-art SVGs** (paths, shapes, and rects on a grid). It is not a
general-purpose browser-grade SVG renderer, but it covers the large majority of static and
animated SVG markup you'll encounter in the wild.

## Supported

- Shapes: `<path>`, `<rect>`, `<circle>`, `<ellipse>`, `<line>`, `<polygon>`, `<polyline>`
  (all normalized to path geometry at parse time)
- Fills: inline `fill`, CSS class fills from `<style>` blocks, `<defs>` patterns
  (`fill="url(#id)"`), and `<linearGradient>`/`<radialGradient>` (both `objectBoundingBox`
  and `userSpaceOnUse`, with `<stop>` `offset`/`stop-color`/`stop-opacity`)
- Strokes: `stroke`, `stroke-width`, `stroke-opacity`, inline or via CSS class
- `opacity` with correct alpha compositing (a translucent shape over nothing stays
  translucent; it does not darken toward black)
- `display:none` on classes (elements skipped)
- Full transform support at both group and element level: `translate`, `scale`, `rotate`
  (with optional center), `skewX`, `skewY`, `matrix`, and any combination of these in one
  `transform` list
- Nested `<svg x="..." y="...">` positioning
- `<mask>` and `<clip-path>`/`<clipPath>` (shape-presence coverage, not luminance/alpha
  masking; a mask and a clip-path on the same element intersect)
- `<use href="#id">` / `<use xlink:href="#id">`, including group references
- Pose-group animation (sibling top-level `<g class="...">` groups)
- SMIL animation: `<animateTransform>`, `<animate>`/`<animateColor>` (arbitrary attribute
  keyframing — fill, opacity, stroke, geometry attrs, etc.), and `<animateMotion>`
  (straight-line `path=` sampling). Multiple simultaneous animators are supported, each
  targeting its own element (nesting parent, or `xlink:href`/`href` by id), with proper
  time-based linear interpolation between keyframes (not just stepping through raw values)
  and independent looping for animators shorter than the longest one on the page.

## Not supported

- **Text** (`<text>`, `<tspan>`)
- **Filters** (`<filter>`, `feGaussianBlur`, etc.), **foreignObject**
- **Embedded raster images** (`<image>`)
- **CSS animations** / `@keyframes` (SMIL only — no `animation:`/`transition:` CSS properties)
- Curved `<animateMotion path="...">` — only straight `M`/`L` segments are sampled; `C`/`A`
  motion paths fall back to their control/end points as if they were straight lines
- `gradientTransform` on `<linearGradient>`/`<radialGradient>` is not applied
- Full SMIL timing model — `begin`/`end` offsets, `repeatCount`, `fill="freeze"` vs
  `"remove"` are not honored; every animator is sampled from 0 to its own `dur` and loops
  for the remainder of the shared timeline (the longest animator on the page)
- `<mask>`/`<clip-path>` luminance or alpha (only shape presence — a black stop in a mask
  gradient covers exactly as much as a white one would)
- Arbitrary SVG DOM ordering for pose-group detection — markup outside shapes/groups at the
  root level still prevents pose-group detection

## Import tips

- Use **Auto (SVG Size)** for 1:1 pixel mapping when the SVG has a correct `viewBox`
- Multi-line SVG must be loaded via **Paste SVG from Clipboard**, not the single-line text field
- For JSON-escaped SVG strings, the importer unescapes `\"` automatically
- `gradientUnits="objectBoundingBox"` (the spec default) is resolved from the shape's own
  rendered pixel bounding box, so it's correct under any transform; `userSpaceOnUse`
  gradients are mapped back through the shape's inverse transform and are most reliable at
  1:1 canvas scale (the same scope as the existing mask/clip-path inverse-transform lookup)
