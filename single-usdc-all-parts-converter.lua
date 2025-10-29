-- Single USDC All Parts Converter
-- Converts all remaining body parts (mouth, eyes, shadow) with USDC colors

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")

-- USDC color scheme (maUSDC from haunt1)
local usdcColors = {
    primaryColor = "#2664ba",    -- Blue (replaces .gotchi-primary)
    secondaryColor = "#d4e0f1",  -- Light blue (replaces .gotchi-secondary)
    cheekColor = "#f696c6"       -- Pink (for cheek elements)
}

-- Helper function to extract SVG strings from JSON array
local function extractSVGStrings(arrayContent)
    local svgs = {}
    if not arrayContent then return svgs end
    
    -- Split by quotes and process each SVG
    local i = 1
    while i <= #arrayContent do
        local start = arrayContent:find('"', i)
        if not start then break end
        
        local j = start + 1
        local svg = ""
        while j <= #arrayContent do
            local char = arrayContent:sub(j, j)
            if char == '"' then
                if j > 1 and arrayContent:sub(j-1, j-1) == '\\' then
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
    
    return svgs
end

-- Load main SVG templates from JSON
local function loadMainSVGTemplates()
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
    
    local templates = {}
    
    -- Extract mouth templates
    local mouthNeutralArray = content:match('"mouth_neutral"%s*:%s*%[(.-)%]')
    templates.mouth_neutral = extractSVGStrings(mouthNeutralArray)
    
    local mouthHappyArray = content:match('"mouth_happy"%s*:%s*%[(.-)%]')
    templates.mouth_happy = extractSVGStrings(mouthHappyArray)
    
    -- Extract eyes templates
    local eyesMadArray = content:match('"eyes_mad"%s*:%s*%[(.-)%]')
    templates.eyes_mad = extractSVGStrings(eyesMadArray)
    
    local eyesHappyArray = content:match('"eyes_happy"%s*:%s*%[(.-)%]')
    templates.eyes_happy = extractSVGStrings(eyesHappyArray)
    
    local eyesSleepyArray = content:match('"eyes_sleepy"%s*:%s*%[(.-)%]')
    templates.eyes_sleepy = extractSVGStrings(eyesSleepyArray)
    
    -- Extract shadow templates
    local shadowArray = content:match('"shadow"%s*:%s*%[(.-)%]')
    templates.shadow = extractSVGStrings(shadowArray)
    
    return templates
end

-- Wrap SVG with colors and proper SVG structure
local function wrapSVGWithColors(svgString)
    local styleBlock = string.format([[
<style>
  .gotchi-primary { fill: %s; }
  .gotchi-secondary { fill: %s; }
  .gotchi-cheek { fill: %s; }
  .gotchi-primary-mouth { fill: %s; }
  .gotchi-eyeColor { fill: %s; }
</style>]], 
        usdcColors.primaryColor,
        usdcColors.secondaryColor, 
        usdcColors.cheekColor,
        usdcColors.primaryColor,
        usdcColors.primaryColor
    )
    
    return string.format([[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">%s%s</svg>]], 
        styleBlock, svgString)
end

-- Process a single SVG part
local function processSVGPart(partType, partIndex, svgString)
    local baseName = string.format("%s_%02d_maUSDC", partType, partIndex)
    
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
local function convertUSDCAllParts()
    print("Starting USDC all parts conversion...")
    print("USDC colors:")
    print("  Primary: " .. usdcColors.primaryColor .. " (replaces .gotchi-primary)")
    print("  Secondary: " .. usdcColors.secondaryColor .. " (replaces .gotchi-secondary)")
    print("  Cheek: " .. usdcColors.cheekColor .. " (replaces .gotchi-cheek)")
    print("")
    
    -- Load templates
    local templates = loadMainSVGTemplates()
    if not templates then
        print("ERROR: Could not load templates")
        return false
    end
    
    local successCount = 0
    local totalPixels = 0
    
    -- Process mouth parts
    print("=== Processing Mouth Parts ===")
    if templates.mouth_neutral and #templates.mouth_neutral > 0 then
        for i, svgString in ipairs(templates.mouth_neutral) do
            local success, pixelsPlaced = processSVGPart("mouth_neutral", i - 1, svgString)
            if success then
                successCount = successCount + 1
                totalPixels = totalPixels + pixelsPlaced
            end
            print("")
        end
    end
    
    if templates.mouth_happy and #templates.mouth_happy > 0 then
        for i, svgString in ipairs(templates.mouth_happy) do
            local success, pixelsPlaced = processSVGPart("mouth_happy", i - 1, svgString)
            if success then
                successCount = successCount + 1
                totalPixels = totalPixels + pixelsPlaced
            end
            print("")
        end
    end
    
    -- Process eyes parts
    print("=== Processing Eyes Parts ===")
    if templates.eyes_mad and #templates.eyes_mad > 0 then
        for i, svgString in ipairs(templates.eyes_mad) do
            local success, pixelsPlaced = processSVGPart("eyes_mad", i - 1, svgString)
            if success then
                successCount = successCount + 1
                totalPixels = totalPixels + pixelsPlaced
            end
            print("")
        end
    end
    
    if templates.eyes_happy and #templates.eyes_happy > 0 then
        for i, svgString in ipairs(templates.eyes_happy) do
            local success, pixelsPlaced = processSVGPart("eyes_happy", i - 1, svgString)
            if success then
                successCount = successCount + 1
                totalPixels = totalPixels + pixelsPlaced
            end
            print("")
        end
    end
    
    if templates.eyes_sleepy and #templates.eyes_sleepy > 0 then
        for i, svgString in ipairs(templates.eyes_sleepy) do
            local success, pixelsPlaced = processSVGPart("eyes_sleepy", i - 1, svgString)
            if success then
                successCount = successCount + 1
                totalPixels = totalPixels + pixelsPlaced
            end
            print("")
        end
    end
    
    -- Process shadow parts
    print("=== Processing Shadow Parts ===")
    if templates.shadow and #templates.shadow > 0 then
        for i, svgString in ipairs(templates.shadow) do
            local success, pixelsPlaced = processSVGPart("shadow", i - 1, svgString)
            if success then
                successCount = successCount + 1
                totalPixels = totalPixels + pixelsPlaced
            end
            print("")
        end
    end
    
    print("=== Conversion Summary ===")
    print("Parts processed: " .. successCount)
    print("Total pixels rendered: " .. totalPixels)
    print("Average pixels per part: " .. math.floor(totalPixels / math.max(successCount, 1)))
    print("")
    print("USDC conversion completed!")
    
    return successCount > 0
end

-- Run the conversion
convertUSDCAllParts()
