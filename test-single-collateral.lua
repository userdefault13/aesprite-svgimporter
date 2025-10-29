-- Test script for single collateral processing
-- Tests with maDAI and body_00

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")
local CollateralColorsLoader = dofile("collateral-colors-loader.lua")

-- Test function
local function testSingleCollateral()
    print("Testing single collateral processing...")
    
    -- Load collaterals
    local collaterals = CollateralColorsLoader.loadAllCollaterals()
    if not collaterals or #collaterals == 0 then
        print("ERROR: No collaterals loaded")
        return false
    end
    
    print("Loaded " .. #collaterals .. " collaterals")
    
    -- Find maDAI
    local maDAI = CollateralColorsLoader.getCollateralByName(collaterals, "maDAI")
    if not maDAI then
        print("ERROR: maDAI not found")
        return false
    end
    
    print("Found maDAI: " .. maDAI.primaryColor .. ", " .. maDAI.secondaryColor .. ", " .. maDAI.cheekColor)
    
    -- Load main SVG templates
    local file = io.open("aavegotchi_db_main.json", "r")
    if not file then
        print("ERROR: Could not open aavegotchi_db_main.json")
        return false
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Extract first body template using the same helper function
    local bodyArray = content:match('"body"%s*:%s*%[(.-)%]')
    if not bodyArray then
        print("ERROR: Could not find body array")
        return false
    end
    
    -- Use the same extraction logic as the main processor
    local svgs = {}
    local i = 1
    while i <= #bodyArray do
        local start = bodyArray:find('"', i)
        if not start then break end
        
        local j = start + 1
        local svg = ""
        while j <= #bodyArray do
            local char = bodyArray:sub(j, j)
            if char == '"' then
                if j > 1 and bodyArray:sub(j-1, j-1) == '\\' then
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
            table.insert(svgs, unescapedSVG)
        end
        
        i = j + 1
    end
    
    if #svgs == 0 then
        print("ERROR: Could not extract any body SVGs")
        return false
    end
    
    local bodySVG = svgs[1]  -- Use first body SVG
    print("Extracted body SVG: " .. string.sub(bodySVG, 1, 100) .. "...")
    print("Full SVG length: " .. #bodySVG)
    
    -- Wrap SVG with colors
    local styleBlock = string.format([[
<style>
  .gotchi-primary { fill: %s; }
  .gotchi-secondary { fill: %s; }
  .gotchi-cheek { fill: %s; }
  .gotchi-primary-mouth { fill: %s; }
</style>]], 
        maDAI.primaryColor,
        maDAI.secondaryColor, 
        maDAI.cheekColor,
        maDAI.primaryColor
    )
    
    local wrappedSVG = string.format([[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">%s%s</svg>]], 
        styleBlock, bodySVG)
    
    print("Wrapped SVG created")
    
    -- Parse SVG
    local svgData = SVGParser.parse(wrappedSVG)
    if not svgData or not svgData.viewBox then
        print("ERROR: Could not parse SVG")
        return false
    end
    
    print("SVG parsed successfully")
    print("ViewBox: " .. svgData.viewBox.width .. "x" .. svgData.viewBox.height)
    print("Elements: " .. #svgData.elements)
    
    -- Render SVG
    local renderResult = SVGRenderer.render(svgData, 64, 64)
    if not renderResult or not renderResult.pixels or #renderResult.pixels == 0 then
        print("ERROR: No pixels rendered")
        return false
    end
    
    print("Rendered " .. #renderResult.pixels .. " pixels")
    
    -- Create sprite
    local sprite = Sprite(64, 64, ColorMode.RGB)
    local layer = sprite.layers[1]
    local cel = sprite:newCel(layer, 1)
    local image = cel.image
    
    -- Clear canvas
    app.transaction(function()
        for y = 0, 63 do
            for x = 0, 63 do
                image:drawPixel(x, y, Color{r = 0, g = 0, b = 0, a = 0})
            end
        end
    end)
    
    -- Draw pixels
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
    
    print("Placed " .. pixelsPlaced .. " pixels")
    
    -- Save sprite
    app.command.SaveFileAs{
        ui = false,
        filename = "test_output/body_00_maDAI.aseprite"
    }
    
    sprite:close()
    
    print("Test completed successfully!")
    return true
end

-- Run test
testSingleCollateral()
