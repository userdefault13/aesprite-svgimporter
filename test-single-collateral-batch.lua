-- Test Single Collateral Batch Converter
-- Test the batch converter with just maDAI to verify it works

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
            print("    Extracted pose group: " .. #poseGroup .. " characters")
            
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
                print("    SVG parsed: " .. #svgData.elements .. " elements")
                
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

-- Test with maDAI
local function testSingleCollateral()
    print("Testing batch converter with maDAI...")
    print("")
    
    -- Load collaterals
    local allCollaterals = CollateralColorsLoader.loadAllCollaterals()
    if not allCollaterals or #allCollaterals == 0 then
        print("ERROR: Could not load collaterals")
        return false
    end
    
    -- Find maDAI
    local maDAI = nil
    for _, collateral in ipairs(allCollaterals) do
        if collateral.name == "maDAI" then
            maDAI = collateral
            break
        end
    end
    
    if not maDAI then
        print("ERROR: Could not find maDAI collateral")
        return false
    end
    
    print("Found maDAI collateral:")
    print("  Primary: " .. maDAI.primaryColor)
    print("  Secondary: " .. maDAI.secondaryColor)
    print("  Cheek: " .. maDAI.cheekColor)
    print("")
    
    -- Load SVG templates
    local templates = loadSVGTemplates()
    if not templates then
        print("ERROR: Could not load SVG templates")
        return false
    end
    
    print("Loaded SVG templates")
    print("")
    
    -- Create output directory
    local outputDir = "output/maDAI"
    os.execute("mkdir -p " .. outputDir)
    
    -- Test hands processing
    print("Testing hands processing...")
    if templates.hands and #templates.hands > 0 then
        local successCount, totalPixels = processHandsPoses(templates.hands[1], maDAI, outputDir)
        print("Hands processing result: " .. successCount .. " files, " .. totalPixels .. " pixels")
    else
        print("ERROR: No hands templates found")
    end
    
    print("")
    print("Test completed!")
    
    return true
end

-- Run the test
testSingleCollateral()
