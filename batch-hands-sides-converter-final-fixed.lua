-- Batch Hands Sides Converter - FINAL FIXED VERSION
-- Handles multiple primary/secondary groups for proper right hand extraction

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")
local CollateralColorsLoader = dofile("collateral-colors-loader.lua")

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

-- Load SVG templates from main JSON
local function loadSVGTemplates()
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
    
    -- Extract hands templates
    local handsArray = content:match('"hands"%s*:%s*%[(.-)%]')
    templates.hands = extractSVGStrings(handsArray)
    
    return templates
end

-- Extract handsDownOpen pose specifically
local function extractHandsDownOpen(handsSVG)
    local downOpenPattern = '<g class="gotchi%-handsDownOpen">(.-)</g><g class="gotchi%-handsUp">'
    local downOpenGroup = handsSVG:match(downOpenPattern)
    
    if downOpenGroup then
        return downOpenGroup
    end
    
    -- Fallback: try to find the end of handsDownOpen group
    local startPattern = '<g class="gotchi%-handsDownOpen">'
    local startPos = handsSVG:find(startPattern)
    if startPos then
        local endPattern = '</g><g class="gotchi%-handsUp">'
        local endPos = handsSVG:find(endPattern, startPos)
        if endPos then
            return handsSVG:sub(startPos + #startPattern, endPos - 1)
        end
    end
    
    return nil
end

-- Extract left hand from handsDownOpen pose (x coordinates < 32)
local function extractLeftHandFromPose(handsDownOpenSVG)
    local leftHandElements = {}
    
    -- Extract ALL primary groups and filter left side paths
    for primaryGroup in handsDownOpenSVG:gmatch('<g class="gotchi%-primary">(.-)</g>') do
        for path in primaryGroup:gmatch('<path d="([^"]*)"[^>]*/?>') do
            local xCoord = path:match("M(%d+)")
            if xCoord and tonumber(xCoord) < 32 then
                table.insert(leftHandElements, '<path d="' .. path .. '" fill="PRIMARY_COLOR"/>')
            end
        end
    end
    
    -- Extract ALL secondary groups and filter left side paths
    for secondaryGroup in handsDownOpenSVG:gmatch('<g class="gotchi%-secondary">(.-)</g>') do
        for path in secondaryGroup:gmatch('<path d="([^"]*)"[^>]*/?>') do
            local xCoord = path:match("M(%d+)")
            if xCoord and tonumber(xCoord) < 32 then
                table.insert(leftHandElements, '<path d="' .. path .. '" fill="SECONDARY_COLOR"/>')
            end
        end
    end
    
    -- Extract white fill paths on the left side
    for path in handsDownOpenSVG:gmatch('<path d="([^"]*)"[^>]*fill="#fff"[^>]*/?>') do
        local xCoord = path:match("M(%d+)")
        if xCoord and tonumber(xCoord) < 32 then
            table.insert(leftHandElements, '<path d="' .. path .. '" fill="#fff"/>')
        end
    end
    
    return table.concat(leftHandElements, "")
end

-- Extract right hand from handsDownOpen pose (x coordinates >= 32)
local function extractRightHandFromPose(handsDownOpenSVG)
    local rightHandElements = {}
    
    -- Extract ALL primary groups and filter right side paths
    for primaryGroup in handsDownOpenSVG:gmatch('<g class="gotchi%-primary">(.-)</g>') do
        for path in primaryGroup:gmatch('<path d="([^"]*)"[^>]*/?>') do
            local xCoord = path:match("M(%d+)")
            if xCoord and tonumber(xCoord) >= 32 then
                table.insert(rightHandElements, '<path d="' .. path .. '" fill="PRIMARY_COLOR"/>')
            end
        end
    end
    
    -- Extract ALL secondary groups and filter right side paths
    for secondaryGroup in handsDownOpenSVG:gmatch('<g class="gotchi%-secondary">(.-)</g>') do
        for path in secondaryGroup:gmatch('<path d="([^"]*)"[^>]*/?>') do
            local xCoord = path:match("M(%d+)")
            if xCoord and tonumber(xCoord) >= 32 then
                table.insert(rightHandElements, '<path d="' .. path .. '" fill="SECONDARY_COLOR"/>')
            end
        end
    end
    
    -- Extract white fill paths on the right side
    for path in handsDownOpenSVG:gmatch('<path d="([^"]*)"[^>]*fill="#fff"[^>]*/?>') do
        local xCoord = path:match("M(%d+)")
        if xCoord and tonumber(xCoord) >= 32 then
            table.insert(rightHandElements, '<path d="' .. path .. '" fill="#fff"/>')
        end
    end
    
    return table.concat(rightHandElements, "")
end

-- Apply collateral color replacement
local function applyCollateralColors(svgString, collateral)
    local processedSVG = svgString
    
    -- Replace placeholder colors with actual collateral colors
    processedSVG = processedSVG:gsub('fill="PRIMARY_COLOR"', 'fill="' .. collateral.primaryColor .. '"')
    processedSVG = processedSVG:gsub('fill="SECONDARY_COLOR"', 'fill="' .. collateral.secondaryColor .. '"')
    
    return processedSVG
end

-- Process a single hand side
local function processHandSide(collateral, handsSVG, sideName, outputDir)
    local baseName = string.format("hands_%s_%s", sideName, collateral.name)
    
    print("  Processing: " .. baseName)
    
    -- First extract the handsDownOpen pose
    local handsDownOpenSVG = extractHandsDownOpen(handsSVG)
    if not handsDownOpenSVG then
        print("    ERROR: Could not extract handsDownOpen pose")
        return false
    end
    
    -- Extract the specific hand side from the pose
    local handSVG
    if sideName == "left" then
        handSVG = extractLeftHandFromPose(handsDownOpenSVG)
    else
        handSVG = extractRightHandFromPose(handsDownOpenSVG)
    end
    
    if handSVG == "" then
        print("    ERROR: No hand elements found for " .. sideName)
        return false
    end
    
    print("    Extracted " .. sideName .. " hand elements: " .. #handSVG .. " characters")
    
    -- Apply collateral colors
    local coloredHand = applyCollateralColors(handSVG, collateral)
    
    print("    Applied colors: " .. collateral.primaryColor .. " / " .. collateral.secondaryColor)
    
    -- Wrap in proper SVG structure
    local wrappedSVG = string.format([[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">%s</svg>]], coloredHand)
    
    -- Parse SVG
    local svgData = SVGParser.parse(wrappedSVG)
    if not svgData or not svgData.viewBox then
        print("    ERROR: Could not parse SVG: " .. baseName)
        return false
    end
    
    -- Render SVG to pixels
    local renderResult = SVGRenderer.render(svgData, 64, 64)
    if not renderResult or not renderResult.pixels or #renderResult.pixels == 0 then
        print("    ERROR: No pixels rendered from SVG: " .. baseName)
        return false
    end
    
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
    
    -- Save as Aseprite file
    local outputPath = outputDir .. "/" .. baseName .. ".aseprite"
    app.command.SaveFileAs{
        ui = false,
        filename = outputPath
    }
    
    sprite:close()
    
    print("    Saved: " .. outputPath .. " (" .. pixelsPlaced .. " pixels)")
    
    return true, pixelsPlaced
end

-- Process a single collateral
local function processCollateral(collateral, templates)
    print("Processing collateral: " .. collateral.name)
    print("  Colors: " .. collateral.primaryColor .. " / " .. collateral.secondaryColor .. " / " .. collateral.cheekColor)
    
    -- Create output directory
    local outputDir = "output/" .. collateral.name
    os.execute("mkdir -p " .. outputDir)
    
    local successCount = 0
    local totalPixels = 0
    
    -- Process hand sides
    print("  === Hand Sides (Final Fixed) ===")
    if templates.hands and #templates.hands > 0 then
        -- Use the first hands template (contains all poses)
        local handsSVG = templates.hands[1]
        
        -- Left hand
        local leftResult, leftPixels = processHandSide(collateral, handsSVG, "left", outputDir)
        if leftResult then
            successCount = successCount + 1
            totalPixels = totalPixels + leftPixels
        end
        
        -- Right hand
        local rightResult, rightPixels = processHandSide(collateral, handsSVG, "right", outputDir)
        if rightResult then
            successCount = successCount + 1
            totalPixels = totalPixels + rightPixels
        end
    else
        print("    ERROR: No hands templates found")
    end
    
    print("  Collateral " .. collateral.name .. " completed: " .. successCount .. " files, " .. totalPixels .. " pixels")
    print("")
    
    return successCount, totalPixels
end

-- Main batch conversion function
local function convertAllHandSides()
    print("Starting FINAL FIXED batch conversion of hand sides for all collaterals...")
    print("")
    
    -- Load all collaterals
    local allCollaterals = CollateralColorsLoader.loadAllCollaterals()
    if not allCollaterals or #allCollaterals == 0 then
        print("ERROR: Could not load collaterals")
        return false
    end
    
    print("Loaded " .. #allCollaterals .. " collaterals")
    print("")
    
    -- Load SVG templates
    local templates = loadSVGTemplates()
    if not templates then
        print("ERROR: Could not load SVG templates")
        return false
    end
    
    print("Loaded SVG templates")
    print("Hands templates available: " .. (templates.hands and #templates.hands or 0))
    print("")
    
    local totalSuccessCount = 0
    local totalPixels = 0
    local processedCollaterals = 0
    
    -- Process each collateral
    for _, collateral in ipairs(allCollaterals) do
        local successCount, pixelsPlaced = processCollateral(collateral, templates)
        totalSuccessCount = totalSuccessCount + successCount
        totalPixels = totalPixels + pixelsPlaced
        processedCollaterals = processedCollaterals + 1
    end
    
    print("=== FINAL FIXED HAND SIDES CONVERSION SUMMARY ===")
    print("Collaterals processed: " .. processedCollaterals .. " out of " .. #allCollaterals)
    print("Total files generated: " .. totalSuccessCount)
    print("Total pixels rendered: " .. totalPixels)
    print("Average files per collateral: " .. math.floor(totalSuccessCount / math.max(processedCollaterals, 1)))
    print("Average pixels per collateral: " .. math.floor(totalPixels / math.max(processedCollaterals, 1)))
    print("")
    print("Final fixed hand sides conversion completed!")
    
    return totalSuccessCount > 0
end

-- Run the batch conversion
convertAllHandSides()
