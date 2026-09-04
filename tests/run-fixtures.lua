-- Fixture-based unit tests for the parser + renderer. Each fixture targets one
-- specific capability and asserts exact pixel colors, so a regression shows up
-- as a named failure instead of "the corpus hash changed, go figure out why".
-- Run from the repo root: aseprite -b --script tests/run-fixtures.lua

local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")

local FIXTURES_DIR = "tests/fixtures/"

local passCount = 0
local failCount = 0
local currentFile = nil

local function renderFixture(name)
    local path = FIXTURES_DIR .. name
    local f = io.open(path, "r")
    if not f then
        error("fixture not found: " .. path)
    end
    local content = f:read("*all")
    f:close()
    local svgData = SVGParser.parse(content)
    local w = math.floor(svgData.viewBox.width)
    local h = math.floor(svgData.viewBox.height)
    local result = SVGRenderer.render(svgData, w, h)
    local lookup = {}
    for _, p in ipairs(result.pixels) do
        lookup[p.x .. "," .. p.y] = p.color
    end
    return {
        pixelAt = function(x, y) return lookup[x .. "," .. y] end,
        width = w,
        height = h,
        elementCount = #svgData.elements
    }
end

local function fail(msg)
    failCount = failCount + 1
    print(string.format("FAIL [%s] %s", currentFile, msg))
end

local function pass()
    passCount = passCount + 1
end

local function assertFilled(scene, x, y, r, g, b, label)
    local c = scene.pixelAt(x, y)
    label = label or string.format("(%d,%d)", x, y)
    if not c then
        fail(string.format("%s expected rgb(%d,%d,%d), got transparent", label, r, g, b))
        return
    end
    if c.r ~= r or c.g ~= g or c.b ~= b then
        fail(string.format("%s expected rgb(%d,%d,%d), got rgb(%d,%d,%d)", label, r, g, b, c.r, c.g, c.b))
        return
    end
    pass()
end

local function assertTransparent(scene, x, y, label)
    local c = scene.pixelAt(x, y)
    label = label or string.format("(%d,%d)", x, y)
    if c then
        fail(string.format("%s expected transparent, got rgb(%d,%d,%d)", label, c.r, c.g, c.b))
        return
    end
    pass()
end

local function test(name, fn)
    currentFile = name
    local ok, err = pcall(fn)
    if not ok then
        fail("threw: " .. tostring(err))
    end
end

-- Basic shapes -----------------------------------------------------------

test("ellipse.svg", function()
    local s = renderFixture("ellipse.svg")
    assertFilled(s, 10, 5, 255, 0, 0, "center")
    assertTransparent(s, 0, 0, "corner")
    assertTransparent(s, 19, 9, "corner")
end)

test("polygon.svg", function()
    local s = renderFixture("polygon.svg")
    assertFilled(s, 10, 10, 0, 255, 0, "center")
    assertTransparent(s, 0, 0, "outside")
end)

test("polyline.svg (open stroke, no auto-close segment)", function()
    local s = renderFixture("polyline.svg")
    assertFilled(s, 2, 10, 51, 102, 255, "vertical leg")
    assertFilled(s, 10, 18, 51, 102, 255, "horizontal leg")
    -- The implicit closing segment (18,18)->(2,2) must NOT be stroked.
    assertTransparent(s, 10, 10, "diagonal midpoint (would be on the closing segment)")
end)

test("polyline-filled.svg (fill treats polyline as closed)", function()
    local s = renderFixture("polyline-filled.svg")
    assertFilled(s, 10, 10, 0, 153, 0, "center, filled as if closed")
end)

test("line.svg", function()
    local s = renderFixture("line.svg")
    assertFilled(s, 10, 10, 0, 0, 0, "on the line")
    assertTransparent(s, 10, 2, "well above the line")
end)

-- Transforms ---------------------------------------------------------------

test("element-rotate.svg (element-level rotate(), not just matrix())", function()
    local s = renderFixture("element-rotate.svg")
    assertFilled(s, 10, 10, 255, 136, 0, "diamond center")
    assertTransparent(s, 6, 6, "original bbox corner, outside the rotated diamond")
    assertTransparent(s, 10, 3, "above the diamond's topmost vertex")
end)

test("group-rotate.svg (group-level rotate(), previously only translate/scale)", function()
    local s = renderFixture("group-rotate.svg")
    assertFilled(s, 10, 10, 255, 136, 0, "diamond center")
    assertTransparent(s, 6, 6, "original bbox corner, outside the rotated diamond")
end)

test("skew.svg (skewX())", function()
    local s = renderFixture("skew.svg")
    assertTransparent(s, 6, 5, "top row, left of the skewed parallelogram")
    assertFilled(s, 12, 5, 0, 102, 255, "top row, inside the skewed parallelogram")
    assertTransparent(s, 10, 14, "bottom row, left of the skewed parallelogram")
    assertFilled(s, 18, 14, 0, 102, 255, "bottom row, inside the skewed parallelogram")
end)

test("matrix.svg (element-level matrix() still works)", function()
    local s = renderFixture("matrix.svg")
    assertFilled(s, 7, 7, 18, 52, 86, "translated interior")
    assertTransparent(s, 2, 2, "pre-translate origin")
end)

-- Mask / clip-path -----------------------------------------------------------

test("clip-path.svg", function()
    local s = renderFixture("clip-path.svg")
    assertFilled(s, 10, 10, 255, 0, 255, "circle center")
    assertTransparent(s, 1, 1, "corner outside the clip circle")
end)

test("mask-clip-intersect.svg (mask AND clip-path both constrain)", function()
    local s = renderFixture("mask-clip-intersect.svg")
    assertFilled(s, 5, 10, 255, 0, 0, "left half: inside circle AND inside mask")
    assertTransparent(s, 15, 10, "right half: inside circle but outside mask")
    assertTransparent(s, 1, 1, "outside the circle entirely")
end)

-- Stroke ---------------------------------------------------------------------

test("stroke-basic.svg", function()
    local s = renderFixture("stroke-basic.svg")
    assertFilled(s, 10, 10, 0, 255, 0, "interior: fill color, stroke doesn't reach here")
    assertFilled(s, 5, 10, 255, 0, 0, "left edge: stroke painted over the fill")
end)

test("stroke-css-class.svg (stroke via CSS class)", function()
    local s = renderFixture("stroke-css-class.svg")
    assertFilled(s, 5, 10, 255, 0, 255, "left edge stroke")
    assertTransparent(s, 10, 10, "interior: fill is none")
end)

test("fill-none.svg (fill=\"none\" must not render as black)", function()
    local s = renderFixture("fill-none.svg")
    assertTransparent(s, 10, 10, "interior: explicitly unfilled")
    assertFilled(s, 5, 10, 0, 0, 255, "left edge stroke")
end)

-- Gradients --------------------------------------------------------------------

test("gradient-linear-bbox.svg (objectBoundingBox, the spec default)", function()
    local s = renderFixture("gradient-linear-bbox.svg")
    assertFilled(s, 0, 5, 255, 0, 0, "left edge: pure start color")
    assertFilled(s, 19, 5, 0, 0, 255, "right edge: pure end color")
    assertFilled(s, 9, 5, 134, 0, 121, "mid-gradient: interpolated")
end)

test("gradient-linear-userspace.svg (gradientUnits=userSpaceOnUse)", function()
    local s = renderFixture("gradient-linear-userspace.svg")
    assertFilled(s, 0, 5, 255, 0, 0, "left edge: pure start color")
    assertFilled(s, 19, 5, 13, 0, 242, "right edge: nearly pure end color")
end)

test("gradient-radial.svg", function()
    local s = renderFixture("gradient-radial.svg")
    assertFilled(s, 9, 9, 236, 236, 236, "near center: mostly start color")
    assertFilled(s, 0, 0, 0, 0, 0, "corner beyond r: clamped to end color")
end)

-- <use> -----------------------------------------------------------------------

test("use-basic.svg", function()
    local s = renderFixture("use-basic.svg")
    assertFilled(s, 12, 4, 18, 52, 86, "used circle at its translated position")
    assertTransparent(s, 4, 4, "defs original position must not render directly")
end)

print(string.format("\nFixture tests: %d passed, %d failed", passCount, failCount))
if failCount > 0 then
    print("RESULT: FAIL")
else
    print("RESULT: PASS")
end
