-- Single USDC Hands Poses Converter - FIXED
-- Extracts complete hand poses and renders them with proper USDC colors

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

-- Load hands SVG from JSON
local function loadHandsSVG()
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
    local handsSVGs = extractSVGStrings(handsArray)
    
    if not handsSVGs or #handsSVGs == 0 then
        print("ERROR: No hands SVGs found")
        return nil
    end
    
    -- Return the first hands SVG (should contain all poses)
    return handsSVGs[1]
end

-- Apply USDC color replacement
local function applyUSDColors(svgString)
    local processedSVG = svgString
    
    -- Apply color replacement with proper regex escaping
    processedSVG = processedSVG:gsub('class="gotchi%-primary"', 'fill="' .. usdcColors.primaryColor .. '"')
    processedSVG = processedSVG:gsub('class="gotchi%-secondary"', 'fill="' .. usdcColors.secondaryColor .. '"')
    processedSVG = processedSVG:gsub('class="gotchi%-cheek"', 'fill="' .. usdcColors.cheekColor .. '"')
    processedSVG = processedSVG:gsub('class="gotchi%-primary%-mouth"', 'fill="' .. usdcColors.primaryColor .. '"')
    processedSVG = processedSVG:gsub('class="gotchi%-eyeColor"', 'fill="' .. usdcColors.primaryColor .. '"')
    
    return processedSVG
end

-- Process a single hand pose
local function processHandPose(pose, svgString)
    local baseName = string.format("hands_%s_maUSDC", pose)
    
    print("Processing: " .. baseName)
    
    -- Extract the complete pose group from the SVG using a more robust pattern
    local poseGroup = ""
    if pose == "down_open" then
        -- Find the start of gotchi-handsDownOpen and capture until the next gotchi-hands group or end
        local start = svgString:find('<g class="gotchi%-handsDownOpen">')
        if start then
            local i = start
            local depth = 0
            local inGroup = false
            while i <= #svgString do
                local char = svgString:sub(i, i)
                if char == '<' and svgString:sub(i, i+1) == '<g' then
                    if svgString:sub(i, i+30):find('gotchi%-handsDownOpen') then
                        inGroup = true
                        depth = 1
                    elseif inGroup and svgString:sub(i, i+30):find('gotchi%-hands') then
                        -- Found another hands group, stop here
                        break
                    elseif inGroup then
                        depth = depth + 1
                    end
                elseif char == '<' and svgString:sub(i, i+1) == '</' then
                    if inGroup then
                        depth = depth - 1
                        if depth == 0 then
                            -- Found the closing tag
                            poseGroup = svgString:sub(start, i + 3) -- Include the closing </g>
                            break
                        end
                    end
                end
                i = i + 1
            end
        end
    elseif pose == "down_closed" then
        local start = svgString:find('<g class="gotchi%-handsDownClosed">')
        if start then
            local i = start
            local depth = 0
            local inGroup = false
            while i <= #svgString do
                local char = svgString:sub(i, i)
                if char == '<' and svgString:sub(i, i+1) == '<g' then
                    if svgString:sub(i, i+30):find('gotchi%-handsDownClosed') then
                        inGroup = true
                        depth = 1
                    elseif inGroup and svgString:sub(i, i+30):find('gotchi%-hands') then
                        break
                    elseif inGroup then
                        depth = depth + 1
                    end
                elseif char == '<' and svgString:sub(i, i+1) == '</' then
                    if inGroup then
                        depth = depth - 1
                        if depth == 0 then
                            poseGroup = svgString:sub(start, i + 3)
                            break
                        end
                    end
                end
                i = i + 1
            end
        end
    elseif pose == "up" then
        local start = svgString:find('<g class="gotchi%-handsUp">')
        if start then
            local i = start
            local depth = 0
            local inGroup = false
            while i <= #svgString do
                local char = svgString:sub(i, i)
                if char == '<' and svgString:sub(i, i+1) == '<g' then
                    if svgString:sub(i, i+30):find('gotchi%-handsUp') then
                        inGroup = true
                        depth = 1
                    elseif inGroup and svgString:sub(i, i+30):find('gotchi%-hands') then
                        break
                    elseif inGroup then
                        depth = depth + 1
                    end
                elseif char == '<' and svgString:sub(i, i+1) == '</' then
                    if inGroup then
                        depth = depth - 1
                        if depth == 0 then
                            poseGroup = svgString:sub(start, i + 3)
                            break
                        end
                    end
                end
                i = i + 1
            end
        end
    end
    
    if not poseGroup or poseGroup == "" then
        print("ERROR: Could not extract pose group for: " .. pose)
        return false
    end
    
    print("  Extracted pose group: " .. #poseGroup .. " characters")
    
    -- Apply USDC colors to the extracted pose group
    local coloredPose = applyUSDColors(poseGroup)
    
    -- Wrap in proper SVG structure
    local wrappedSVG = string.format([[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">%s</svg>]], coloredPose)
    
    -- Debug: Check if replacements worked
    local primaryCount = 0
    for _ in wrappedSVG:gmatch('fill="' .. usdcColors.primaryColor .. '"') do
        primaryCount = primaryCount + 1
    end
    
    local secondaryCount = 0
    for _ in wrappedSVG:gmatch('fill="' .. usdcColors.secondaryColor .. '"') do
        secondaryCount = secondaryCount + 1
    end
    
    print("  Color replacements: " .. primaryCount .. " primary, " .. secondaryCount .. " secondary")
    
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
local function convertUSDCHandsPoses()
    print("Starting USDC hands poses conversion (complete pose extraction method)...")
    print("USDC colors:")
    print("  Primary: " .. usdcColors.primaryColor .. " (replaces .gotchi-primary)")
    print("  Secondary: " .. usdcColors.secondaryColor .. " (replaces .gotchi-secondary)")
    print("  Cheek: " .. usdcColors.cheekColor .. " (replaces .gotchi-cheek)")
    print("")
    
    -- Load hands SVG
    local handsSVG = loadHandsSVG()
    if not handsSVG then
        print("ERROR: Could not load hands SVG")
        return false
    end
    
    print("Loaded hands SVG with all poses")
    print("SVG length: " .. #handsSVG .. " characters")
    print("")
    
    local successCount = 0
    local totalPixels = 0
    
    -- Process each pose
    local poses = {
        {name = "down_open", display = "Hands Down Open"},
        {name = "down_closed", display = "Hands Down Closed"},
        {name = "up", display = "Hands Up"}
    }
    
    for _, pose in ipairs(poses) do
        print("=== Processing " .. pose.display .. " ===")
        local success, pixelsPlaced = processHandPose(pose.name, handsSVG)
        if success then
            successCount = successCount + 1
            totalPixels = totalPixels + pixelsPlaced
        end
        print("")
    end
    
    print("=== Conversion Summary ===")
    print("Hand poses processed: " .. successCount .. " out of 3")
    print("Total pixels rendered: " .. totalPixels)
    print("Average pixels per pose: " .. math.floor(totalPixels / math.max(successCount, 1)))
    print("")
    print("USDC hands poses conversion completed!")
    
    return successCount > 0
end

-- Run the conversion
convertUSDCHandsPoses()
