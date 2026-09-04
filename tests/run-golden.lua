-- Golden-master regression runner.
-- Parses + renders every SVG listed in tests/golden/manifest.txt (pure Lua, no Aseprite
-- Sprite needed) and writes a stable per-file hash to tests/golden/current.txt.
-- Run from the repo root: aseprite -b --script tests/run-golden.lua
--
-- Compare against a committed baseline with:
--   diff tests/golden/baseline.txt tests/golden/current.txt

local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")

-- FNV-1a 32-bit
local function fnv1a(str)
    local hash = 0x811c9dc5
    for i = 1, #str do
        hash = (hash ~ str:byte(i)) & 0xFFFFFFFF
        hash = (hash * 0x01000193) & 0xFFFFFFFF
    end
    return hash
end

local function readManifest(path)
    local files = {}
    local f = io.open(path, "r")
    if not f then error("manifest not found: " .. path) end
    for line in f:lines() do
        if line ~= "" then table.insert(files, line) end
    end
    f:close()
    return files
end

local manifestPath = (app and app.params and app.params.manifest) or "tests/golden/manifest.txt"
local outputPath = (app and app.params and app.params.output) or "tests/golden/current.txt"

local files = readManifest(manifestPath)
local out = io.open(outputPath, "w")
if not out then error("could not open output: " .. outputPath) end

local errors = 0
local startClock = os.clock()

for _, path in ipairs(files) do
    local f = io.open(path, "r")
    if not f then
        out:write(string.format("%s\tERROR\topen-failed\n", path))
        errors = errors + 1
    else
        local content = f:read("*all")
        f:close()

        local okParse, svgData = pcall(SVGParser.parse, content)
        if not okParse or not svgData or not svgData.viewBox then
            out:write(string.format("%s\tERROR\tparse-failed\n", path))
            errors = errors + 1
        else
            local w = math.max(1, math.floor(svgData.viewBox.width))
            local h = math.max(1, math.floor(svgData.viewBox.height))
            local okRender, renderResult = pcall(SVGRenderer.render, svgData, w, h)
            if not okRender or not renderResult then
                out:write(string.format("%s\tERROR\trender-failed\n", path))
                errors = errors + 1
            else
                -- Sort pixels for a stable order, then hash.
                local pixels = renderResult.pixels
                table.sort(pixels, function(a, b)
                    if a.y ~= b.y then return a.y < b.y end
                    return a.x < b.x
                end)
                local parts = {}
                for _, p in ipairs(pixels) do
                    parts[#parts + 1] = string.format("%d,%d,%d,%d,%d;", p.x, p.y, p.color.r, p.color.g, p.color.b)
                end
                local blob = table.concat(parts)
                local hash = fnv1a(blob)
                out:write(string.format("%s\t%dx%d\t%d\t%d\t%08x\n", path, w, h, #svgData.elements, #pixels, hash))
            end
        end
    end
end

out:close()

local elapsed = os.clock() - startClock
print(string.format("Golden run: %d files, %d errors, %.2fs -> %s", #files, errors, elapsed, outputPath))
