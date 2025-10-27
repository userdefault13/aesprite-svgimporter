-- Test winding number for specific point
dofile('svg-parser.lua')
dofile('svg-renderer.lua')

local svgContent = [[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 34 20"><path d="M32 5V3h-2V2h-2V0H6v2H4v1H2v2H0v9h1v1h1v1h1v1h1v1h1v1h3v1h18v-1h3v-1h1v-1h1v-1h1v-1h1v-1h1V5z"/></svg>]]

print("=== WINDING NUMBER DEBUG ===\n")

local svgData = SVGParser.parse(svgContent)
local viewBox = svgData.viewBox
local targetWidth, targetHeight = 64, 64

-- Calculate scale and offset (same as renderer)
local scaleX = targetWidth / viewBox.width
local scaleY = targetHeight / viewBox.height
local scale = math.min(scaleX, scaleY)
local offsetX = math.floor((targetWidth - viewBox.width * scale) / 2)
local offsetY = math.floor((targetHeight - viewBox.height * scale) / 2)

print(string.format("Scale: %.3f", scale))
print(string.format("Offset: (%.2f, %.2f)\n", offsetX, offsetY))

-- Test point in canvas coordinates
local testX, testY = 2, 40

-- Convert to SVG coordinates
local svgX = (testX - offsetX) / scale + (viewBox.x or 0)
local svgY = (testY - offsetY) / scale + (viewBox.y or 0)

print(string.format("Test point (canvas): (%d, %d)", testX, testY))
print(string.format("Test point (SVG): (%.2f, %.2f)\n", svgX, svgY))

-- Create a simple test polygon representing the staircase section
local testPolygon = {
    {x = 0, y = 14},
    {x = 1, y = 14},
    {x = 1, y = 15},
    {x = 2, y = 15},
    {x = 2, y = 16},
    {x = 3, y = 16},
    -- Close back
    {x = 3, y = 10},
    {x = 0, y = 10}
}

print("Simple test polygon (staircase section):")
for i, p in ipairs(testPolygon) do
    print(string.format("  %d: (%.1f, %.1f)", i, p.x, p.y))
end
print()

-- Manual winding number calculation
local function testWindingNumber(x, y, polygon)
    local winding = 0
    local n = #polygon
    
    print(string.format("Testing point (%.2f, %.2f):", x, y))
    
    for i = 1, n do
        local j = (i % n) + 1
        local xi, yi = polygon[i].x, polygon[i].y
        local xj, yj = polygon[j].x, polygon[j].y
        
        print(string.format("  Edge %d: (%.1f,%.1f) → (%.1f,%.1f)", i, xi, yi, xj, yj))
        
        if yi <= y then
            if yj > y then
                local cross = (xj - xi) * (y - yi) - (x - xi) * (yj - yi)
                print(string.format("    Upward crossing candidate. Cross product: %.3f", cross))
                if cross > 0 then
                    winding = winding + 1
                    print("    → Winding +1")
                end
            end
        else
            if yj <= y then
                local cross = (xj - xi) * (y - yi) - (x - xi) * (yj - yi)
                print(string.format("    Downward crossing candidate. Cross product: %.3f", cross))
                if cross < 0 then
                    winding = winding - 1
                    print("    → Winding -1")
                end
            end
        end
    end
    
    print(string.format("\nFinal winding number: %d", winding))
    print(string.format("Inside: %s\n", winding ~= 0 and "YES" or "NO"))
    
    return winding ~= 0
end

testWindingNumber(svgX, svgY, testPolygon)
