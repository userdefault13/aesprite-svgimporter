-- Batch Import Collateral Base JSON
-- Reads a collateral base JSON file and imports all SVGs to Aseprite as individual sprite files

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")

-- Simple JSON parser - extracts SVG arrays from JSON
local function extractSVGArray(jsonContent, key)
    local pattern = '"' .. key .. '"%s*:%s*%[(.-)%]'
    local arrayContent = jsonContent:match(pattern)
    if not arrayContent then return {} end
    
    local svgs = {}
    local i = 1
    while i <= #arrayContent do
        local start = arrayContent:find('"', i)
        if not start then break end
        
        local j = start + 1
        local svg = ""
        local escaped = false
        while j <= #arrayContent do
            local char = arrayContent:sub(j, j)
            if char == '\\' and not escaped then
                escaped = true
                svg = svg .. char
            elseif char == '"' then
                if escaped then
                    svg = svg .. char
                    escaped = false
                else
                    break
                end
            else
                svg = svg .. char
                escaped = false
            end
            j = j + 1
        end
        
        if #svg > 0 then
            -- Unescape common escape sequences
            local unescapedSVG = svg:gsub('\\"', '"')
                          :gsub('\\\\', '\\')
                          :gsub('\\n', '\n')
                          :gsub('\\t', '\t')
            table.insert(svgs, unescapedSVG)
        end
        
        i = j + 1
    end
    
    return svgs
end

-- Parse JSON file
local function parseCollateralBaseJSON(jsonPath)
    local file = io.open(jsonPath, "r")
    if not file then
        return nil, "Could not open JSON file: " .. jsonPath
    end
    
    local jsonContent = file:read("*all")
    file:close()
    
    if not jsonContent or jsonContent == "" then
        return nil, "JSON file is empty"
    end
    
    return {
        body = extractSVGArray(jsonContent, "body"),
        hands = extractSVGArray(jsonContent, "hands"),
        mouth_neutral = extractSVGArray(jsonContent, "mouth_neutral"),
        mouth_happy = extractSVGArray(jsonContent, "mouth_happy"),
        eyes_mad = extractSVGArray(jsonContent, "eyes_mad"),
        eyes_happy = extractSVGArray(jsonContent, "eyes_happy"),
        eyes_sleepy = extractSVGArray(jsonContent, "eyes_sleepy"),
        shadow = extractSVGArray(jsonContent, "shadow")
    }
end

-- Process a single SVG and save as Aseprite file
local function processSVG(svgCode, outputPath, partName)
    if not svgCode or svgCode == "" then
        print("  ERROR: Empty SVG code for " .. partName)
        return false, 0
    end
    
    -- Parse SVG
    local svgData = SVGParser.parse(svgCode)
    if not svgData or not svgData.viewBox then
        print("  ERROR: Could not parse SVG for " .. partName)
        return false, 0
    end
    
    -- Get viewBox dimensions
    local canvasWidth = math.floor(svgData.viewBox.width)
    local canvasHeight = math.floor(svgData.viewBox.height)
    
    -- Render SVG to pixels
    local renderResult = SVGRenderer.render(svgData, canvasWidth, canvasHeight)
    if not renderResult or not renderResult.pixels or #renderResult.pixels == 0 then
        print("  ERROR: No pixels rendered for " .. partName)
        return false, 0
    end
    
    -- Create sprite
    local sprite = Sprite(canvasWidth, canvasHeight, ColorMode.RGB)
    local layer = sprite.layers[1]
    local cel = sprite:newCel(layer, 1)
    local image = cel.image
    
    -- Clear canvas to transparent
    app.transaction(function()
        for y = 0, canvasHeight - 1 do
            for x = 0, canvasWidth - 1 do
                image:drawPixel(x, y, Color{r = 0, g = 0, b = 0, a = 0})
            end
        end
    end)
    
    -- Draw SVG pixels
    local pixelsPlaced = 0
    app.transaction(function()
        for _, pixel in ipairs(renderResult.pixels) do
            if pixel.x >= 0 and pixel.x < canvasWidth and pixel.y >= 0 and pixel.y < canvasHeight then
                local color = Color{r = pixel.color.r, g = pixel.color.g, b = pixel.color.b}
                image:drawPixel(pixel.x, pixel.y, color)
                pixelsPlaced = pixelsPlaced + 1
            end
        end
    end)
    
    -- Ensure output directory exists
    local fileOutputDir = outputPath:match("^(.+)/[^/]+$")
    if fileOutputDir then
        -- Create directory if needed
        local dirPath = fileOutputDir:gsub("'", "'\\''") -- Escape single quotes for shell
        os.execute("mkdir -p '" .. dirPath .. "' 2>/dev/null")
    end
    
    -- Save as .aseprite file
    app.command.SaveFileAs{
        ui = false,
        filename = outputPath
    }
    
    sprite:close()
    
    print("  ✓ Saved: " .. outputPath .. " (" .. pixelsPlaced .. " pixels)")
    return true, pixelsPlaced
end

-- Main function
local function batchImportCollateralBase()
    -- Create dialog to select JSON file
    local dlg = Dialog("Batch Import Collateral Base")
    
    dlg:file{
        id = "json_file",
        label = "JSON File",
        open = true,
        filetypes = {"json"},
        title = "Select Collateral Base JSON File"
    }
    
    dlg:newrow()
    
    dlg:button{
        id = "import",
        text = "Import",
        onclick = function()
            local jsonPath = dlg.data.json_file
            if not jsonPath or jsonPath == "" then
                app.alert("Please select a JSON file")
                return
            end
            dlg:close()
            processJSONFile(jsonPath)
        end
    }
    
    dlg:button{
        id = "cancel",
        text = "Cancel",
        onclick = function()
            dlg:close()
        end
    }
    
    dlg:show{wait = false}
end

-- Process the JSON file
local function processJSONFile(jsonPath)
    
    -- Parse JSON
    print("Reading JSON file: " .. jsonPath)
    local data, err = parseCollateralBaseJSON(jsonPath)
    if not data then
        app.alert("Error parsing JSON: " .. (err or "Unknown error"))
        return
    end
    
    -- Extract collateral name from filename
    local collateralName = jsonPath:match("collateral%-base%-(%w+)%-%d+%.json")
    if not collateralName then
        collateralName = jsonPath:match("([^/\\]+)%.json$")
        if collateralName then
            collateralName = collateralName:gsub("%.json$", "")
        else
            collateralName = "unknown"
        end
    end
    
    -- Create output directory in the same location as the JSON file
    local jsonDir = jsonPath:match("^(.+)/[^/]+$")
    if not jsonDir then
        jsonDir = "."
    end
    local outputDir = app.fs.joinPath(jsonDir, "collateral-base-" .. collateralName .. "_sprites")
    print("Output directory: " .. outputDir)
    
    -- Define view names for body
    local bodyViewNames = {"Front", "Left", "Right", "Back"}
    local handsViewNames = {"Closed", "Open"}
    
    -- Process all categories
    local categories = {
        {
            name = "body",
            array = data.body,
            viewNames = bodyViewNames,
            prefix = "body"
        },
        {
            name = "hands",
            array = data.hands,
            viewNames = handsViewNames,
            prefix = "hands"
        },
        {
            name = "mouth_neutral",
            array = data.mouth_neutral,
            prefix = "mouth-neutral"
        },
        {
            name = "mouth_happy",
            array = data.mouth_happy,
            prefix = "mouth-happy"
        },
        {
            name = "eyes_mad",
            array = data.eyes_mad,
            prefix = "eyes-mad"
        },
        {
            name = "eyes_happy",
            array = data.eyes_happy,
            prefix = "eyes-happy"
        },
        {
            name = "eyes_sleepy",
            array = data.eyes_sleepy,
            prefix = "eyes-sleepy"
        },
        {
            name = "shadow",
            array = data.shadow,
            prefix = "shadow"
        }
    }
    
    local totalProcessed = 0
    local totalPixels = 0
    local totalErrors = 0
    
    -- Process each category
    for _, category in ipairs(categories) do
        print("\n=== Processing " .. category.name .. " ===")
        print("  Found " .. #category.array .. " SVG(s)")
        
        for i, svg in ipairs(category.array) do
            local viewName = category.viewNames and category.viewNames[i] or ""
            local partName = category.prefix
            if viewName and viewName ~= "" then
                partName = partName .. "_" .. viewName:lower()
            end
            
            local outputPath = app.fs.joinPath(outputDir, partName .. "_" .. collateralName .. ".aseprite")
            
            print("  Processing: " .. partName)
            local success, pixels = processSVG(svg, outputPath, partName)
            
            if success then
                totalProcessed = totalProcessed + 1
                totalPixels = totalPixels + pixels
            else
                totalErrors = totalErrors + 1
            end
        end
    end
    
    -- Summary
    print("\n" .. string.rep("=", 50))
    print("BATCH IMPORT COMPLETE")
    print(string.rep("=", 50))
    print("Collateral: " .. collateralName)
    print("Successfully processed: " .. totalProcessed .. " SVG(s)")
    print("Total pixels rendered: " .. totalPixels)
    print("Errors: " .. totalErrors)
    print("Output directory: " .. outputDir)
    print(string.rep("=", 50))
    
    app.alert(string.format(
        "Batch import complete!\n\n" ..
        "Collateral: %s\n" ..
        "Processed: %d SVG(s)\n" ..
        "Pixels: %d\n" ..
        "Errors: %d\n\n" ..
        "Files saved to:\n%s",
        collateralName,
        totalProcessed,
        totalPixels,
        totalErrors,
        outputDir
    ))
end

-- Show the dialog (which will call processJSONFile when user clicks Import)
batchImportCollateralBase()

