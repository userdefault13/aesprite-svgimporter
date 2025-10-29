-- Batch All Collaterals Converter V2
-- Modified: Body = body only, Mouth = mouth + cheek

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
    
    -- Extract shadow templates
    local shadowArray = content:match('"shadow"%s*:%s*%[(.-)%]')
    templates.shadow = extractSVGStrings(shadowArray)
    
    return templates
end

-- Extract body only (remove cheek, mouth, shadow)
local function extractBodyOnly(bodySVG)
    -- Check if this is the structured body with gotchi-body group
    -- Use a more specific pattern to capture everything until the closing gotchi-body tag
    local bodyGroup = bodySVG:match('<g class="gotchi%-body">(.*)</g><path class="gotchi%-cheek"')
    if bodyGroup then
        -- This is the structured body - extract the complete gotchi-body group
        -- The bodyGroup should include gotchi-primary, gotchi-secondary, and white fill
        return '<g class="gotchi-body">' .. bodyGroup .. '</g>'
    end
    
    -- Try alternative pattern if the first one doesn't match
    bodyGroup = bodySVG:match('<g class="gotchi%-body">(.*)</g><g class="gotchi%-primary%-mouth"')
    if bodyGroup then
        return '<g class="gotchi-body">' .. bodyGroup .. '</g>'
    end
    
    -- For other body structures, remove unwanted elements but keep all body content
    local bodyOnly = bodySVG
    
    -- Remove cheek elements (both with and without self-closing tags)
    bodyOnly = bodyOnly:gsub('<path class="gotchi%-cheek"[^>]*/?>.-</path>', '')
    bodyOnly = bodyOnly:gsub('<path class="gotchi%-cheek"[^>]*/>', '')
    
    -- Remove mouth elements
    bodyOnly = bodyOnly:gsub('<g class="gotchi%-primary%-mouth"[^>]*>.-</g>', '')
    
    -- Remove shadow elements
    bodyOnly = bodyOnly:gsub('<g class="gotchi%-shadow"[^>]*>.-</g>', '')
    
    return bodyOnly
end

-- Add cheek to mouth SVG
local function addCheekToMouth(mouthSVG)
    -- Cheek element pattern
    local cheekElement = '<path class="gotchi-cheek" d="M21 32v2h2v-2h-1zm21 0h-1v2h2v-2z"/>'
    
    -- Combine mouth and cheek
    local mouthWithCheek = mouthSVG .. cheekElement
    
    return mouthWithCheek
end

-- Apply collateral color replacement
local function applyCollateralColors(svgString, collateral)
    local processedSVG = svgString
    
    -- Apply color replacement with proper regex escaping
    processedSVG = processedSVG:gsub('class="gotchi%-primary"', 'fill="' .. collateral.primaryColor .. '"')
    processedSVG = processedSVG:gsub('class="gotchi%-secondary"', 'fill="' .. collateral.secondaryColor .. '"')
    processedSVG = processedSVG:gsub('class="gotchi%-cheek"', 'fill="' .. collateral.cheekColor .. '"')
    processedSVG = processedSVG:gsub('class="gotchi%-primary%-mouth"', 'fill="' .. collateral.primaryColor .. '"')
    processedSVG = processedSVG:gsub('class="gotchi%-eyeColor"', 'fill="' .. collateral.primaryColor .. '"')
    
    return processedSVG
end

-- Process a single SVG part
local function processSVGPart(partType, partIndex, svgString, collateral, outputDir)
    local baseName = string.format("%s_%02d_%s", partType, partIndex, collateral.name)
    
    print("  Processing: " .. baseName)
    
    -- Apply collateral colors
    local coloredSVG = applyCollateralColors(svgString, collateral)
    
    -- Wrap in proper SVG structure
    local wrappedSVG = string.format([[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">%s</svg>]], coloredSVG)
    
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

-- Process hands poses using proven extraction method
local function processHandsPoses(handsSVG, collateral, outputDir)
    local successCount = 0
    local totalPixels = 0
    
    -- Process each pose using proven pattern matching
    local poses = {
        {name = "down_open", pattern = '<g class="gotchi%-handsDownOpen">(.-)</g><g class="gotchi%-handsUp">'},
        {name = "down_closed", pattern = '<g class="gotchi%-handsDownClosed">(.-)</g><g class="gotchi%-handsDownOpen">'},
        {name = "up", pattern = '<g class="gotchi%-handsUp">(.-)</g>$'}
    }
    
    for _, pose in ipairs(poses) do
        print("  Processing hands_" .. pose.name .. "_" .. collateral.name)
        
        -- Extract the complete pose group
        local poseGroup = handsSVG:match(pose.pattern)
        
        if not poseGroup or poseGroup == "" then
            print("    ERROR: Could not extract pose group for: " .. pose.name)
        else
            -- Apply collateral colors to the extracted pose group
            local coloredPose = applyCollateralColors(poseGroup, collateral)
            
            -- Wrap in proper SVG structure
            local wrappedSVG = string.format([[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><g class="gotchi-%s">%s</g></svg>]], 
                pose.name == "down_open" and "handsDownOpen" or 
                pose.name == "down_closed" and "handsDownClosed" or "handsUp", 
                coloredPose)
            
            -- Parse and render
            local svgData = SVGParser.parse(wrappedSVG)
            if svgData and svgData.viewBox then
                local renderResult = SVGRenderer.render(svgData, 64, 64)
                if renderResult and renderResult.pixels and #renderResult.pixels > 0 then
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
                    
                    -- Save file
                    local outputPath = outputDir .. "/hands_" .. pose.name .. "_" .. collateral.name .. ".aseprite"
                    app.command.SaveFileAs{
                        ui = false,
                        filename = outputPath
                    }
                    
                    sprite:close()
                    
                    print("    Saved: " .. outputPath .. " (" .. pixelsPlaced .. " pixels)")
                    successCount = successCount + 1
                    totalPixels = totalPixels + pixelsPlaced
                else
                    print("    ERROR: No pixels rendered for " .. pose.name)
                end
            else
                print("    ERROR: Could not parse SVG for " .. pose.name)
            end
        end
    end
    
    return successCount, totalPixels
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
    
    -- Process body part (BODY ONLY - no cheek, no mouth)
    print("  === Body Part (Body Only) ===")
    if templates.body and #templates.body > 0 then
        local bodyOnly = extractBodyOnly(templates.body[1])
        local coloredBody = applyCollateralColors(bodyOnly, collateral)
        local wrappedSVG = string.format([[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">%s</svg>]], coloredBody)
        
        -- Parse and render
        local svgData = SVGParser.parse(wrappedSVG)
        if svgData and svgData.viewBox then
            local renderResult = SVGRenderer.render(svgData, 64, 64)
            if renderResult and renderResult.pixels and #renderResult.pixels > 0 then
                local sprite = Sprite(64, 64, ColorMode.RGB)
                local layer = sprite.layers[1]
                local cel = sprite:newCel(layer, 1)
                local image = cel.image
                
                app.transaction(function()
                    for y = 0, 63 do
                        for x = 0, 63 do
                            image:drawPixel(x, y, Color{r = 0, g = 0, b = 0, a = 0})
                        end
                    end
                end)
                
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
                
                local outputPath = outputDir .. "/body_00_" .. collateral.name .. ".aseprite"
                app.command.SaveFileAs{
                    ui = false,
                    filename = outputPath
                }
                
                sprite:close()
                
                print("    Saved: " .. outputPath .. " (" .. pixelsPlaced .. " pixels)")
                successCount = successCount + 1
                totalPixels = totalPixels + pixelsPlaced
            end
        end
    end
    
    -- Process hands parts using pose extraction
    print("  === Hands Parts ===")
    if templates.hands and #templates.hands > 0 then
        local handsSuccess, handsPixels = processHandsPoses(templates.hands[1], collateral, outputDir)
        successCount = successCount + handsSuccess
        totalPixels = totalPixels + handsPixels
    end
    
    -- Process mouth parts (MOUTH + CHEEK)
    print("  === Mouth Parts (Mouth + Cheek) ===")
    if templates.mouth_neutral and #templates.mouth_neutral > 0 then
        local mouthWithCheek = addCheekToMouth(templates.mouth_neutral[1])
        local success, pixelsPlaced = processSVGPart("mouth_neutral", 0, mouthWithCheek, collateral, outputDir)
        if success then
            successCount = successCount + 1
            totalPixels = totalPixels + pixelsPlaced
        end
    end
    
    if templates.mouth_happy and #templates.mouth_happy > 0 then
        local mouthWithCheek = addCheekToMouth(templates.mouth_happy[1])
        local success, pixelsPlaced = processSVGPart("mouth_happy", 0, mouthWithCheek, collateral, outputDir)
        if success then
            successCount = successCount + 1
            totalPixels = totalPixels + pixelsPlaced
        end
    end
    
    -- Process shadow parts
    print("  === Shadow Parts ===")
    if templates.shadow and #templates.shadow > 0 then
        for i, shadowSVG in ipairs(templates.shadow) do
            local success, pixelsPlaced = processSVGPart("shadow", i - 1, shadowSVG, collateral, outputDir)
            if success then
                successCount = successCount + 1
                totalPixels = totalPixels + pixelsPlaced
            end
        end
    end
    
    print("  Collateral " .. collateral.name .. " completed: " .. successCount .. " files, " .. totalPixels .. " pixels")
    print("")
    
    return successCount, totalPixels
end

-- Main batch conversion function
local function convertAllCollaterals()
    print("Starting batch conversion of all collaterals (V2 - Body Only, Mouth + Cheek)...")
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
    
    print("=== BATCH CONVERSION SUMMARY (V2) ===")
    print("Collaterals processed: " .. processedCollaterals .. " out of " .. #allCollaterals)
    print("Total files generated: " .. totalSuccessCount)
    print("Total pixels rendered: " .. totalPixels)
    print("Average files per collateral: " .. math.floor(totalSuccessCount / math.max(processedCollaterals, 1)))
    print("Average pixels per collateral: " .. math.floor(totalPixels / math.max(processedCollaterals, 1)))
    print("")
    print("Batch conversion completed!")
    
    return totalSuccessCount > 0
end

-- Run the batch conversion
convertAllCollaterals()
