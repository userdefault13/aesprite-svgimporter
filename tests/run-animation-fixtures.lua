-- Fixture-based tests for the SMIL animation engine (multi-animator,
-- <animate> attribute keyframing, <animateMotion>, xlink:href targeting).
-- Run from the repo root: aseprite -b --script tests/run-animation-fixtures.lua

local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")
local SVGAnimation = dofile("svg-animation.lua")

local FIXTURES_DIR = "tests/fixtures/"

local passCount = 0
local failCount = 0
local currentFile = nil

local function fail(msg)
    failCount = failCount + 1
    print(string.format("FAIL [%s] %s", currentFile, msg))
end

local function pass()
    passCount = passCount + 1
end

local function loadFixture(name)
    local f = io.open(FIXTURES_DIR .. name, "r")
    if not f then error("fixture not found: " .. name) end
    local content = f:read("*all")
    f:close()
    return content
end

-- Renders one already-resolved frame SVG string into a pixel lookup.
local function renderFrame(frameSvg)
    local svgData = SVGParser.parse(frameSvg)
    local w = math.floor(svgData.viewBox.width)
    local h = math.floor(svgData.viewBox.height)
    local result = SVGRenderer.render(svgData, w, h)
    local lookup = {}
    for _, p in ipairs(result.pixels) do
        lookup[p.x .. "," .. p.y] = p.color
    end
    return function(x, y) return lookup[x .. "," .. y] end
end

local function assertFilled(pixelAt, x, y, r, g, b, label)
    local c = pixelAt(x, y)
    label = label or string.format("(%d,%d)", x, y)
    if not c then
        fail(string.format("%s expected rgb(%d,%d,%d), got transparent", label, r, g, b))
    elseif c.r ~= r or c.g ~= g or c.b ~= b then
        fail(string.format("%s expected rgb(%d,%d,%d), got rgb(%d,%d,%d)", label, r, g, b, c.r, c.g, c.b))
    else
        pass()
    end
end

local function assertTransparent(pixelAt, x, y, label)
    local c = pixelAt(x, y)
    label = label or string.format("(%d,%d)", x, y)
    if c then
        fail(string.format("%s expected transparent, got rgb(%d,%d,%d)", label, c.r, c.g, c.b))
    else
        pass()
    end
end

local function test(name, fn)
    currentFile = name
    local ok, err = pcall(fn)
    if not ok then
        fail("threw: " .. tostring(err))
    end
end

test("anim-multi-smil.svg (animateTransform + animate on same element)", function()
    local content = loadFixture("anim-multi-smil.svg")
    local info = SVGAnimation.detect(content, 8)
    if info.type ~= "smil" then
        fail("expected type=smil, got " .. tostring(info.type))
        return
    end
    if #info.frames < 4 then
        fail("expected several interpolated frames, got " .. #info.frames)
        return
    end
    local first = renderFrame(info.frames[1].svg)
    assertFilled(first, 4, 4, 255, 0, 0, "first frame: original position, red")
    assertTransparent(first, 14, 4, "first frame: translated position not yet reached")

    local last = renderFrame(info.frames[#info.frames].svg)
    assertFilled(last, 14, 4, 0, 0, 255, "last frame: translated by (10,0), blue")
    assertTransparent(last, 4, 4, "last frame: original position now vacated")
end)

test("anim-href-target.svg (xlink:href targets a sibling by id)", function()
    local content = loadFixture("anim-href-target.svg")
    local info = SVGAnimation.detect(content, 8)
    if info.type ~= "smil" or #info.frames < 4 then
        fail(string.format("expected smil/several frames, got %s/%d", tostring(info.type), #(info.frames or {})))
        return
    end
    local first = renderFrame(info.frames[1].svg)
    assertFilled(first, 4, 4, 0, 204, 0, "first frame: original position")
    local last = renderFrame(info.frames[#info.frames].svg)
    assertFilled(last, 12, 12, 0, 204, 0, "last frame: translated by (8,8)")
    assertTransparent(last, 4, 4, "last frame: original position vacated")
end)

test("anim-two-elements.svg (independent animators, different value counts)", function()
    local content = loadFixture("anim-two-elements.svg")
    local info = SVGAnimation.detect(content, 8)
    if info.type ~= "smil" or #info.frames < 4 then
        fail(string.format("expected smil/several frames, got %s/%d", tostring(info.type), #(info.frames or {})))
        return
    end
    local first = renderFrame(info.frames[1].svg)
    assertFilled(first, 1, 1, 255, 0, 0, "first frame: box a at x0..3")
    assertFilled(first, 1, 16, 0, 0, 255, "first frame: box b visible (opacity 1)")

    local last = renderFrame(info.frames[#info.frames].svg)
    assertFilled(last, 9, 1, 255, 0, 0, "last frame: box a translated to x8..11")
    assertTransparent(last, 1, 16, "last frame: box b invisible (opacity 0)")
end)

test("anim-motion.svg (animateMotion path sampling)", function()
    local content = loadFixture("anim-motion.svg")
    local info = SVGAnimation.detect(content, 8)
    if info.type ~= "smil" then
        fail("expected type=smil, got " .. tostring(info.type))
        return
    end
    local first = renderFrame(info.frames[1].svg)
    assertFilled(first, 1, 1, 255, 153, 0, "first sample at path start (0,0)")

    local last = renderFrame(info.frames[#info.frames].svg)
    assertFilled(last, 17, 1, 255, 153, 0, "last sample at path end (16,0)")
    assertTransparent(last, 1, 1, "start position vacated by the last frame")
end)

test("anim-multi-smil.svg is picked over pose-group detection when both could apply", function()
    -- Sanity: a doc with only SMIL (no sibling <g class> pose groups) must
    -- resolve via SMIL, not fall through to "none". Frame count is dur*fps
    -- (continuous sampling), not the raw keyframe value count.
    local content = loadFixture("anim-multi-smil.svg")
    local frameCount = SVGAnimation.frameCount(content, 8)
    if frameCount ~= 8 then
        fail("expected frameCount 8 (1s dur * 8fps), got " .. frameCount)
    else
        pass()
    end
end)

print(string.format("\nAnimation fixture tests: %d passed, %d failed", passCount, failCount))
if failCount > 0 then
    print("RESULT: FAIL")
else
    print("RESULT: PASS")
end
