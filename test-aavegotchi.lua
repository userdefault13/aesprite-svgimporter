-- Test the clean SVG parser with Aavegotchi SVG
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer.lua")

-- The Aavegotchi SVG content
local aavegotchiSVG = [[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><path d="M47 14v-2h-2v-2h-4V8h-4V6H27v2h-4v2h-4v2h-2v2h-2v41h4v-2h5v2h5v-2h6v2h5v-2h5v2h4V14z" fill="#64438e"/><path d="M45 14v-2h-4v-2h-4V8H27v2h-4v2h-4v2h-2v39h2v-2h5v2h5v-2h6v2h5v-2h5v2h2V14z" fill="#edd3fd"/><path d="M18,49h2v-1h2v1h2v2h5v-2h2v-1h2v1h2v2h5v-2h2v-1h2v1h1V14h-4v-2h-4v-2h-5V9h-5v2h-4v2h-4v2h-1V49z" fill="#fff"/></svg>]]

print("=== TESTING CLEAN AAVEGOTCHI PARSER ===")
print("SVG Content Length:", #aavegotchiSVG)

-- Parse the SVG
local svgData = SVGParser.parse(aavegotchiSVG)
print("ViewBox:", svgData.viewBox.width, "x", svgData.viewBox.height)
print("Elements found:", #svgData.elements)

-- Debug each element
for i, element in ipairs(svgData.elements) do
    print("\n--- Element", i, "---")
    print("Type:", element.type)
    print("Fill:", string.format("#%02x%02x%02x", element.fill.r, element.fill.g, element.fill.b))
    print("Path commands:", #element.pathCommands)
    
    -- Show first few commands
    for j = 1, math.min(3, #element.pathCommands) do
        local cmd = element.pathCommands[j]
        print("  Command", j, ":", cmd.type, "relative:", cmd.isRelative, "params:", table.concat(cmd.params, ", "))
    end
    if #element.pathCommands > 3 then
        print("  ... and", #element.pathCommands - 3, "more commands")
    end
end

-- Test rendering
print("\n=== TESTING RENDER ===")
local renderResult = SVGRenderer.render(svgData, 64, 64)
print("Rendered pixels:", #renderResult.pixels)

if #renderResult.pixels > 0 then
    print("SUCCESS: Found", #renderResult.pixels, "pixels!")
    
    -- Count pixels by color
    local colorCounts = {}
    for _, pixel in ipairs(renderResult.pixels) do
        local colorKey = string.format("#%02x%02x%02x", pixel.color.r, pixel.color.g, pixel.color.b)
        colorCounts[colorKey] = (colorCounts[colorKey] or 0) + 1
    end
    
    print("\nColor distribution:")
    for color, count in pairs(colorCounts) do
        print("  ", color, ":", count, "pixels")
    end
else
    print("FAILED: No pixels rendered!")
end

print("\n=== TEST COMPLETE ===")
