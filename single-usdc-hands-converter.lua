-- Single USDC Hands Converter
-- Converts hands SVGs from aavegotchi_db_main.json to Aseprite with USDC colors

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")

-- USDC color scheme (maUSDC from haunt1)
local usdcColors = {
    primaryColor = "#2664ba",    -- Blue (replaces .gotchi-primary)
    secondaryColor = "#d4e0f1",  -- Light blue (replaces .gotchi-secondary)
    cheekColor = "#f696c6"       -- Pink (for cheek elements)
}

-- Load hands SVGs from JSON
local function loadHandsSVGs()
    local file = io.open("aavegotchi_db_main.json", "r")
    if not file then
        print("ERROR: Could not open aavegotchi_db_main.json")
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content or content == "" then
        print("ERROR: JSON file is empty")
        return nil
    end
    
    -- Extract hands array
    local handsArray = content:match('"hands"%s*:%s*%[(.-)%]')
    if not handsArray then
        print("ERROR: Could not find hands array in JSON")
        return nil
    end
    
    -- Extract SVG strings with proper escaping
    local hands = {}
    local i = 1
    while i <= #handsArray do
        local start = handsArray:find('"', i)
        if not start then break end
        
        local j = start + 1
        local svg = ""
        while j <= #handsArray do
            local char = handsArray:sub(j, j)
            if char == '"' then
                if j > 1 and handsArray:sub(j-1, j-1) == '\\' then
                    svg = svg .. char
                else
                    break
                end
            else
                svg = svg .. char
            end
            j = j + 1
        end
        
        if #svg > 0 then
            local unescapedSVG = svg:gsub('\\"', '"'):gsub('\\\\', '\\')
            table.insert(hands, unescapedSVG)
        end
        
        i = j + 1
    end
    
    return hands
end

-- Wrap SVG with colors and proper SVG structure
local function wrapSVGWithColors(svgString)
    local styleBlock = string.format([[
<style>
  .gotchi-primary { fill: %s; }
  .gotchi-secondary { fill: %s; }
  .gotchi-cheek { fill: %s; }
  .gotchi-primary-mouth { fill: %s; }
</style>]], 
        usdcColors.primaryColor,
        usdcColors.secondaryColor, 
        usdcColors.cheekColor,
        usdcColors.primaryColor
    )
    
    return string.format([[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">%s%s</svg>]], 
        styleBlock, svgString)
end

-- Process a single hands SVG
local function processHandsSVG(handsIndex, svgString)
    local baseName = string.format("hands_%02d_maUSDC", handsIndex)
    
    print("Processing: " .. baseName)
    
    -- Wrap SVG with colors
    local wrappedSVG = wrapSVGWithColors(svgString)
    
    -- Parse SVG
    local svgData = SVGParser.parse(wrappedSVG)
    if not svgData or not svgData.viewBox then
        print("ERROR: Could not parse SVG: " .. baseName)
        return false
    end
    
    print("  SVG parsed: " .. #svgData.elements .. " elements")
    
    -- Render SVG to pixels
    local renderResult = SVGRenderer.render(svgData, 64, 64)
    if not renderResult or not renderResult.pixels or #renderResult.pixels == 0 then
        print("ERROR: No pixels rendered from SVG: " .. baseName)
        return false
    end
    
    print("  Rendered " .. #renderResult.pixels .. " pixels")
    
    -- Create 64x64 sprite
    local sprite = Sprite(64, 64, ColorMode.RGB)
    local layer = sprite.layers[1]
    local cel = sprite:newCel(layer, 1)
    local image = cel.image
    
    -- Clear canvas to transparent
    app.transaction(function()
        for y = 0, 63 do
            for x = 0, 63 do
                image:drawPixel(x, y, Color{r = 0, g = 0, b = 0, a = 0})
            end
        end
    end)
    
    -- Draw SVG pixels
    local pixelsPlaced = 0
    app.transaction(function()
        for _, pixel in ipairs(renderResult.pixels) do
            if pixel.x >= 0 and pixel.x < 64 and pixel.y >= 0 and pixel.y < 64 then
                local color = Color{r = pixel.color.r, g = pixel.color.g, b = pixel.color.b}
                image:drawPixel(pixel.x, pixel.y, color)
                pixelsPlaced = pixelsPlaced + 1
            end
        end
    end)
    
    print("  Placed " .. pixelsPlaced .. " pixels on 64x64 canvas")
    
    -- Save as Aseprite file
    local outputPath = "output/" .. baseName .. ".aseprite"
    app.command.SaveFileAs{
        ui = false,
        filename = outputPath
    }
    
    sprite:close()
    
    print("  Saved: " .. outputPath)
    
    return true, pixelsPlaced
end

-- Main conversion function
local function convertUSDCHands()
    print("Starting USDC hands conversion...")
    print("USDC colors:")
    print("  Primary: " .. usdcColors.primaryColor .. " (replaces .gotchi-primary)")
    print("  Secondary: " .. usdcColors.secondaryColor .. " (replaces .gotchi-secondary)")
    print("  Cheek: " .. usdcColors.cheekColor .. " (replaces .gotchi-cheek)")
    print("")
    
    -- Load hands SVGs
    local handsSVGs = loadHandsSVGs()
    if not handsSVGs or #handsSVGs == 0 then
        print("ERROR: No hands SVGs loaded")
        return false
    end
    
    print("Loaded " .. #handsSVGs .. " hands SVGs from JSON")
    print("")
    
    -- Process each hands variant
    local successCount = 0
    local totalPixels = 0
    
    for i, svgString in ipairs(handsSVGs) do
        local success, pixelsPlaced = processHandsSVG(i - 1, svgString)
        if success then
            successCount = successCount + 1
            totalPixels = totalPixels + pixelsPlaced
        end
        print("")
    end
    
    print("=== Conversion Summary ===")
    print("Hands variants processed: " .. #handsSVGs)
    print("Successful conversions: " .. successCount)
    print("Total pixels rendered: " .. totalPixels)
    print("Average pixels per hands: " .. math.floor(totalPixels / math.max(successCount, 1)))
    print("")
    print("Conversion completed!")
    
    return successCount > 0
end

-- Run the conversion
convertUSDCHands()
