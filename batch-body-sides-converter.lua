-- Batch Body Sides Converter
-- Processes front, left, and right body views for all collaterals

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
    
    -- Extract body templates (should have 4 different views)
    local bodyArray = content:match('"body"%s*:%s*%[(.-)%]')
    templates.body = extractSVGStrings(bodyArray)
    
    return templates
end

-- Extract body only (remove cheek, mouth, shadow) - works for all body types
local function extractBodyOnly(bodySVG)
    -- Check if this is the structured body with gotchi-body group
    local bodyGroup = bodySVG:match('<g class="gotchi%-body">(.*)</g><path class="gotchi%-cheek"')
    if bodyGroup then
        -- This is the structured body - extract the complete gotchi-body group
        return '<g class="gotchi-body">' .. bodyGroup .. '</g>'
    end
    
    -- Try alternative pattern if the first one doesn't match
    bodyGroup = bodySVG:match('<g class="gotchi%-body">(.*)</g><g class="gotchi%-primary%-mouth"')
    if bodyGroup then
        return '<g class="gotchi-body">' .. bodyGroup .. '</g>'
    end
    
    -- For simpler body structures (left/right sides), remove unwanted elements but keep all body content
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

-- Process a single body view
local function processBodyView(collateral, bodySVG, viewName, outputDir)
    local baseName = string.format("body_%s_%s", viewName, collateral.name)
    
    print("  Processing: " .. baseName)
    
    -- Extract body only (remove cheek, mouth, shadow)
    local bodyOnly = extractBodyOnly(bodySVG)
    
    -- Apply collateral colors
    local coloredBody = applyCollateralColors(bodyOnly, collateral)
    
    -- Wrap in proper SVG structure
    local wrappedSVG = string.format([[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">%s</svg>]], coloredBody)
    
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
    
    -- Process all body views
    print("  === Body Views ===")
    if templates.body and #templates.body >= 3 then
        -- Front view (index 0)
        local frontResult, frontPixels = processBodyView(collateral, templates.body[1], "front", outputDir)
        if frontResult then
            successCount = successCount + 1
            totalPixels = totalPixels + frontPixels
        end
        
        -- Left side view (index 1)
        local leftResult, leftPixels = processBodyView(collateral, templates.body[2], "left", outputDir)
        if leftResult then
            successCount = successCount + 1
            totalPixels = totalPixels + leftPixels
        end
        
        -- Right side view (index 2)
        local rightResult, rightPixels = processBodyView(collateral, templates.body[3], "right", outputDir)
        if rightResult then
            successCount = successCount + 1
            totalPixels = totalPixels + rightPixels
        end
    else
        print("    ERROR: Not enough body templates found")
    end
    
    print("  Collateral " .. collateral.name .. " completed: " .. successCount .. " files, " .. totalPixels .. " pixels")
    print("")
    
    return successCount, totalPixels
end

-- Main batch conversion function
local function convertAllBodySides()
    print("Starting batch conversion of body sides for all collaterals...")
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
    print("Body views available: " .. (templates.body and #templates.body or 0))
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
    
    print("=== BODY SIDES CONVERSION SUMMARY ===")
    print("Collaterals processed: " .. processedCollaterals .. " out of " .. #allCollaterals)
    print("Total files generated: " .. totalSuccessCount)
    print("Total pixels rendered: " .. totalPixels)
    print("Average files per collateral: " .. math.floor(totalSuccessCount / math.max(processedCollaterals, 1)))
    print("Average pixels per collateral: " .. math.floor(totalPixels / math.max(processedCollaterals, 1)))
    print("")
    print("Body sides conversion completed!")
    
    return totalSuccessCount > 0
end

-- Run the batch conversion
convertAllBodySides()
