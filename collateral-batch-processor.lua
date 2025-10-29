-- Collateral Color Batch Processor for Aseprite CLI
-- Processes Aavegotchi SVG body parts with different collateral color schemes

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")
local CollateralColorsLoader = dofile("collateral-colors-loader.lua")

-- Global variables for batch processing
local logFile = nil
local startTime = 0
local processedCount = 0
local successCount = 0
local errorCount = 0

-- Logging functions
local function logMessage(level, message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local logEntry = string.format("[%s] [%s] %s", timestamp, level, message)
    
    print(logEntry)
    
    if logFile then
        logFile:write(logEntry .. "\n")
        logFile:flush()
    end
end

local function logInfo(message)
    logMessage("INFO", message)
end

local function logWarn(message)
    logMessage("WARN", message)
end

local function logError(message)
    logMessage("ERROR", message)
end

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
                -- Check if it's escaped
                if j > 1 and arrayContent:sub(j-1, j-1) == '\\' then
                    svg = svg .. char
                else
                    -- End of SVG string
                    break
                end
            else
                svg = svg .. char
            end
            j = j + 1
        end
        
        if #svg > 0 then
            -- Unescape the SVG string
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
        logError("Could not open aavegotchi_db_main.json")
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content or content == "" then
        logError("aavegotchi_db_main.json is empty")
        return nil
    end
    
    -- Simple JSON parsing for our structure
    local templates = {}
    
    -- Extract body templates
    local bodyArray = content:match('"body"%s*:%s*%[(.-)%]')
    templates.body = extractSVGStrings(bodyArray)
    
    -- Extract hands templates
    local handsArray = content:match('"hands"%s*:%s*%[(.-)%]')
    templates.hands = extractSVGStrings(handsArray)
    
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

-- Wrap SVG string in proper SVG document with color injection
local function wrapSVGWithColors(svgString, collateral)
    local styleBlock = string.format([[
<style>
  .gotchi-primary { fill: %s; }
  .gotchi-secondary { fill: %s; }
  .gotchi-cheek { fill: %s; }
  .gotchi-primary-mouth { fill: %s; }
</style>]], 
        collateral.primaryColor or "#FF6B9D",
        collateral.secondaryColor or "#F4AFDD", 
        collateral.cheekColor or "#F696C6",
        collateral.primaryColor or "#FF6B9D"
    )
    
    return string.format([[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">%s%s</svg>]], 
        styleBlock, svgString)
end

-- Process a single SVG template with collateral colors
local function processSVGTemplate(templateName, templateIndex, svgString, collateral, outputDir, targetSize)
    local fileStartTime = os.clock()
    local baseName = string.format("%s_%02d_%s", templateName, templateIndex, collateral.name)
    
    logInfo(string.format("Processing: %s with %s colors", baseName, collateral.name))
    
    -- Wrap SVG with colors
    local wrappedSVG = wrapSVGWithColors(svgString, collateral)
    
    -- Parse SVG
    local svgData = SVGParser.parse(wrappedSVG)
    if not svgData or not svgData.viewBox then
        logError("Could not parse SVG: " .. baseName)
        return false
    end
    
    -- Use SVG's native dimensions
    local nativeWidth = math.floor(svgData.viewBox.width)
    local nativeHeight = math.floor(svgData.viewBox.height)
    
    logInfo("Native SVG size: " .. nativeWidth .. "x" .. nativeHeight)
    
    -- Render SVG to pixels
    local renderResult = SVGRenderer.render(svgData, nativeWidth, nativeHeight)
    
    if not renderResult or not renderResult.pixels or #renderResult.pixels == 0 then
        logError("No pixels rendered from SVG: " .. baseName)
        return false
    end
    
    logInfo("Rendered " .. #renderResult.pixels .. " pixels")
    
    -- Create target size sprite with transparent background
    local sprite = Sprite(targetSize, targetSize, ColorMode.RGB)
    local layer = sprite.layers[1]
    local cel = sprite:newCel(layer, 1)
    local image = cel.image
    
    -- Clear canvas to transparent
    app.transaction(function()
        for y = 0, targetSize - 1 do
            for x = 0, targetSize - 1 do
                image:drawPixel(x, y, Color{r = 0, g = 0, b = 0, a = 0})
            end
        end
    end)
    
    -- Center the rendered content on the canvas
    local offsetX = math.floor((targetSize - nativeWidth) / 2)
    local offsetY = math.floor((targetSize - nativeHeight) / 2)
    
    -- Draw SVG pixels
    local pixelsPlaced = 0
    app.transaction(function()
        for _, pixel in ipairs(renderResult.pixels) do
            local targetX = pixel.x + offsetX
            local targetY = pixel.y + offsetY
            
            -- Only draw pixels that fit within the target canvas
            if targetX >= 0 and targetX < targetSize and targetY >= 0 and targetY < targetSize then
                local color = Color{r = pixel.color.r, g = pixel.color.g, b = pixel.color.b}
                image:drawPixel(targetX, targetY, color)
                pixelsPlaced = pixelsPlaced + 1
            end
        end
    end)
    
    logInfo("Placed " .. pixelsPlaced .. " pixels on " .. targetSize .. "x" .. targetSize .. " canvas")
    
    -- Generate output filename
    local outputFilename = baseName .. ".aseprite"
    local outputPath = app.fs.joinPath(outputDir, outputFilename)
    
    -- Save as .aseprite file
    app.command.SaveFileAs{
        ui = false,
        filename = outputPath
    }
    
    sprite:close()
    
    local fileTime = os.clock() - fileStartTime
    logInfo("Saved: " .. outputPath .. " (Time: " .. string.format("%.2f", fileTime) .. "s)")
    
    return true, pixelsPlaced, fileTime
end

-- Main batch processing function
local function processBatch()
    -- Configuration
    local outputDir = "output"
    local targetSize = 64
    
    -- Initialize logging
    logFile = io.open("collateral_batch_log.txt", "w")
    startTime = os.clock()
    
    logInfo("Starting collateral color batch processing")
    logInfo("Output directory: " .. outputDir)
    logInfo("Target size: " .. targetSize .. "x" .. targetSize)
    
    -- Load collateral colors
    local collaterals = CollateralColorsLoader.loadAllCollaterals()
    if not collaterals or #collaterals == 0 then
        logError("No collateral colors loaded. Exiting.")
        return
    end
    
    logInfo("Loaded " .. #collaterals .. " collateral color sets")
    
    -- Load main SVG templates
    local templates = loadMainSVGTemplates()
    if not templates then
        logError("Could not load main SVG templates. Exiting.")
        return
    end
    
    logInfo("Loaded main SVG templates")
    
    -- Create output directory if it doesn't exist
    if not app.fs.isDirectory(outputDir) then
        app.fs.makeDirectory(outputDir)
        logInfo("Created output directory: " .. outputDir)
    end
    
    -- Process each template type
    local templateTypes = {
        "body", "hands", "mouth_neutral", "mouth_happy", 
        "eyes_mad", "eyes_happy", "eyes_sleepy", "shadow"
    }
    
    for _, templateType in ipairs(templateTypes) do
        if templates[templateType] and #templates[templateType] > 0 then
            logInfo("Processing template type: " .. templateType .. " (" .. #templates[templateType] .. " variants)")
            
            for templateIndex, svgString in ipairs(templates[templateType]) do
                for _, collateral in ipairs(collaterals) do
                    local success, pixelsPlaced, fileTime = processSVGTemplate(
                        templateType, templateIndex - 1, svgString, collateral, outputDir, targetSize
                    )
                    
                    processedCount = processedCount + 1
                    
                    if success then
                        successCount = successCount + 1
                        logInfo(string.format("Success: %s_%02d -> %s (%d pixels, %.2fs)", 
                            templateType, templateIndex - 1, collateral.name, pixelsPlaced, fileTime))
                    else
                        errorCount = errorCount + 1
                        logError(string.format("Failed: %s_%02d -> %s", 
                            templateType, templateIndex - 1, collateral.name))
                    end
                end
            end
        else
            logWarn("No templates found for type: " .. templateType)
        end
    end
    
    -- Final statistics
    local totalTime = os.clock() - startTime
    logInfo("Batch processing completed")
    logInfo("Total files processed: " .. processedCount)
    logInfo("Successful: " .. successCount)
    logInfo("Errors: " .. errorCount)
    logInfo("Total time: " .. string.format("%.2f", totalTime) .. "s")
    logInfo("Average time per file: " .. string.format("%.2f", totalTime / math.max(processedCount, 1)) .. "s")
    
    if logFile then
        logFile:close()
    end
end

-- Run the batch processing
processBatch()
