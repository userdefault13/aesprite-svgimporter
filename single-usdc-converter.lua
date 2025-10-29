-- Single USDC Color Converter
-- Converts Aavegotchi-Gen0-Front-Body-ETH.svg to Aseprite with USDC colors

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")

-- USDC color scheme (maUSDC from haunt1)
local usdcColors = {
    primaryColor = "#2664ba",    -- Blue (replaces dark purple #64438e)
    secondaryColor = "#d4e0f1",  -- Light blue (replaces light purple #edd3fd)
    cheekColor = "#f696c6"       -- Pink (for cheek elements)
}

-- Load the base SVG file
local function loadBaseSVG()
    local file = io.open("examples/body/Aavegotchi-Gen0-Front-Body-ETH.svg", "r")
    if not file then
        print("ERROR: Could not open Aavegotchi-Gen0-Front-Body-ETH.svg")
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content or content == "" then
        print("ERROR: SVG file is empty")
        return nil
    end
    
    return content
end

-- Replace colors in SVG content
local function replaceColors(svgContent)
    -- Replace dark purple with USDC primary blue
    local updated = svgContent:gsub("#64438e", usdcColors.primaryColor)
    
    -- Replace light purple with USDC secondary light blue
    updated = updated:gsub("#edd3fd", usdcColors.secondaryColor)
    
    -- Keep white (#fff) and other colors unchanged
    
    return updated
end

-- Main conversion function
local function convertUSDCBody()
    print("Starting USDC body conversion...")
    
    -- Load base SVG
    local svgContent = loadBaseSVG()
    if not svgContent then
        return false
    end
    
    print("Loaded base SVG: " .. #svgContent .. " characters")
    
    -- Replace colors
    local updatedSVG = replaceColors(svgContent)
    print("Applied USDC color scheme")
    print("Primary: " .. usdcColors.primaryColor .. " (was #64438e)")
    print("Secondary: " .. usdcColors.secondaryColor .. " (was #edd3fd)")
    
    -- Parse SVG
    local svgData = SVGParser.parse(updatedSVG)
    if not svgData or not svgData.viewBox then
        print("ERROR: Could not parse SVG")
        return false
    end
    
    print("SVG parsed successfully")
    print("ViewBox: " .. svgData.viewBox.width .. "x" .. svgData.viewBox.height)
    print("Elements: " .. #svgData.elements)
    
    -- Render SVG to pixels
    local renderResult = SVGRenderer.render(svgData, 64, 64)
    if not renderResult or not renderResult.pixels or #renderResult.pixels == 0 then
        print("ERROR: No pixels rendered")
        return false
    end
    
    print("Rendered " .. #renderResult.pixels .. " pixels")
    
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
    
    print("Placed " .. pixelsPlaced .. " pixels on 64x64 canvas")
    
    -- Save as Aseprite file
    local outputPath = "output/body_00_maUSDC.aseprite"
    app.command.SaveFileAs{
        ui = false,
        filename = outputPath
    }
    
    sprite:close()
    
    print("Successfully saved: " .. outputPath)
    print("Conversion completed!")
    
    return true
end

-- Run the conversion
convertUSDCBody()
