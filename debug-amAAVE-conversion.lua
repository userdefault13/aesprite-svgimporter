-- Debug converter to see what's happening with the conversion

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")

-- amAAVE colors
local amAAVEColors = {
    primaryColor = "#b6509e",
    secondaryColor = "#cfeef4",
    cheekColor = "#f696c6"
}

-- Test SVG (just the body and eyes part)
local testSVG = [[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><g class="gotchi-body"><path d="M47 14v-2h-2v-2h-4V8h-4V6H27v2h-4v2h-4v2h-2v2h-2v41h4v-2h5v2h5v-2h6v2h5v-2h5v2h4V14z" class="gotchi-primary"/><path d="M45 14v-2h-4v-2h-4V8H27v2h-4v2h-4v2h-2v39h2v-2h5v2h5v-2h6v2h5v-2h5v2h2V14z" class="gotchi-secondary"/><path d="M18,49h2v-1h2v1h2v2h5v-2h2v-1h2v1h2v2h5v-2h2v-1h2v1h1V14h-4v-2h-4v-2h-5V9h-5v2h-4v2h-4v2h-1V49z" fill="#fff"/></g><g class="gotchi-eyeColor"><rect x="22" y="28" width="6" height="6" transform="rotate(-90 22 28)" /><rect x="36" y="22" width="6" height="6" /></g></svg>]]

print("=== Original SVG ===")
print(testSVG)
print("")

-- Step 1: Remove style blocks
local step1 = testSVG:gsub('<style>.-</style>', '')
print("=== After removing style blocks ===")
print(step1)
print("")

-- Step 2: Replace classes on groups
local step2 = step1
step2 = step2:gsub('(<g[^>]*class="gotchi%-primary"[^>]*>)', function(match)
    return match:gsub('class="gotchi%-primary[^"]*"', 'fill="' .. amAAVEColors.primaryColor .. '"')
end)
step2 = step2:gsub('(<g[^>]*class="gotchi%-secondary"[^>]*>)', function(match)
    return match:gsub('class="gotchi%-secondary[^"]*"', 'fill="' .. amAAVEColors.secondaryColor .. '"')
end)
step2 = step2:gsub('(<g[^>]*class="gotchi%-eyeColor"[^>]*>)', function(match)
    return match:gsub('class="gotchi%-eyeColor[^"]*"', 'fill="' .. amAAVEColors.primaryColor .. '"')
end)
print("=== After replacing group classes ===")
print(step2)
print("")

-- Step 3: Replace classes on paths
local step3 = step2
step3 = step3:gsub('(<path[^>]*class="gotchi%-primary"[^>]*>)', function(match)
    return match:gsub('class="gotchi%-primary[^"]*"', 'fill="' .. amAAVEColors.primaryColor .. '"')
end)
step3 = step3:gsub('(<path[^>]*class="gotchi%-secondary"[^>]*>)', function(match)
    return match:gsub('class="gotchi%-secondary[^"]*"', 'fill="' .. amAAVEColors.secondaryColor .. '"')
end)
print("=== After replacing path classes ===")
print(step3)
print("")

-- Step 4: Parse
print("=== Parsing SVG ===")
local svgData = SVGParser.parse(step3)
if svgData then
    print("Elements found: " .. #svgData.elements)
    for i, elem in ipairs(svgData.elements) do
        print(string.format("  Element %d: type=%s, fill=r:%d g:%d b:%d", 
            i, elem.type, elem.fill.r, elem.fill.g, elem.fill.b))
        if elem.type == "rect" then
            print(string.format("    rect: x=%.1f y=%.1f w=%.1f h=%.1f", 
                elem.x, elem.y, elem.width, elem.height))
        end
    end
else
    print("ERROR: Failed to parse")
end
print("")

-- Step 5: Render
if svgData then
    print("=== Rendering ===")
    local renderResult = SVGRenderer.render(svgData, 64, 64)
    if renderResult then
        print("Pixels rendered: " .. #renderResult.pixels)
        
        -- Count pixels by color
        local colorCounts = {}
        for _, pixel in ipairs(renderResult.pixels) do
            local key = string.format("%d,%d,%d", pixel.color.r, pixel.color.g, pixel.color.b)
            colorCounts[key] = (colorCounts[key] or 0) + 1
        end
        
        print("Color distribution:")
        for color, count in pairs(colorCounts) do
            print("  " .. color .. ": " .. count .. " pixels")
        end
    else
        print("ERROR: Failed to render")
    end
end




