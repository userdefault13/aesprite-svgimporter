-- Analyze Collateral Pixels
-- This script helps identify problematic pixels in a rendered sprite

local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")

-- Get the current sprite
local sprite = app.activeSprite
if not sprite then
    app.alert("No active sprite. Please open the sprite you want to analyze.")
    return
end

local image = sprite.cels[1].image
local width = sprite.width
local height = sprite.height

print("Analyzing sprite: " .. width .. "x" .. height)

-- Count non-transparent pixels
local pixelMap = {}
local totalPixels = 0

for y = 0, height - 1 do
    for x = 0, width - 1 do
        local color = image:getPixel(x, y)
        if color.alpha > 0 then
            totalPixels = totalPixels + 1
            local key = x .. "," .. y
            pixelMap[key] = {
                x = x,
                y = y,
                r = color.red,
                g = color.green,
                b = color.blue,
                alpha = color.alpha
            }
        end
    end
end

print("Total non-transparent pixels: " .. totalPixels)
print("\nPixel coordinates (x, y):")
print("==========================")

local sortedKeys = {}
for key, _ in pairs(pixelMap) do
    table.insert(sortedKeys, key)
end
table.sort(sortedKeys)

for _, key in ipairs(sortedKeys) do
    local pixel = pixelMap[key]
    print(string.format("(%d, %d) RGB(%d, %d, %d)", 
        pixel.x, pixel.y, pixel.r, pixel.g, pixel.b))
end

app.alert("Found " .. totalPixels .. " pixels\nCheck console for coordinates")

