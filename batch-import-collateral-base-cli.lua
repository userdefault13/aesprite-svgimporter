-- Batch Import Collateral Base JSON (CLI)
-- Usage: aseprite -b --script batch-import-collateral-base-cli.lua --script-param json_file=<path> [--script-param output_dir=<path>]
-- Example: aseprite -b --script batch-import-collateral-base-cli.lua --script-param json_file=collateral-base-amaave-1764615569457.json

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")

-- Get parameters from environment variables (works better in batch mode)
local jsonPath = os.getenv("BATCH_JSON_FILE")
local customOutputDir = os.getenv("BATCH_OUTPUT_DIR")

-- Fallback to script params if environment variables not set
if not jsonPath or jsonPath == "" then
    local params = app and app.params or {}
    if type(params) == "table" then
        jsonPath = params.json_file or params["json_file"]
        customOutputDir = customOutputDir or params.output_dir or params["output_dir"]
        
        -- Try to parse from string params
        if not jsonPath then
            for k, v in pairs(params) do
                if type(v) == "string" then
                    if k == "json_file" or v:match("^json_file=") then
                        jsonPath = v:match("^json_file=(.+)$") or v
                    end
                    if k == "output_dir" or v:match("^output_dir=") then
                        customOutputDir = customOutputDir or (v:match("^output_dir=(.+)$") or v)
                    end
                end
            end
        end
    end
end

-- Fallback to command line arguments
if not jsonPath or jsonPath == "" then
    local args = {...}
    if #args >= 1 then
        jsonPath = args[1]
        customOutputDir = customOutputDir or args[2]
    end
end

if not jsonPath or jsonPath == "" then
    print("Batch Import Collateral Base JSON (CLI)")
    print("=======================================")
    print("Usage: Set BATCH_JSON_FILE environment variable or use --script-param")
    print("")
    print("Environment variables:")
    print("  BATCH_JSON_FILE  - Path to collateral base JSON file (required)")
    print("  BATCH_OUTPUT_DIR - Output directory for .aseprite files (optional)")
    print("")
    print("Or via script params:")
    print("  aseprite -b --script batch-import-collateral-base-cli.lua --script-param json_file=<path>")
    print("")
    return
end

print("Batch Import Collateral Base JSON")
print("==================================")
print("JSON file: " .. jsonPath)
if customOutputDir then
    print("Output dir: " .. customOutputDir)
end
print("")

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

-- Ensure directory exists
local function ensureDirectory(dirPath)
    -- Escape path for shell command
    local escapedPath = dirPath:gsub("'", "'\\''")
    os.execute("mkdir -p '" .. escapedPath .. "' 2>/dev/null")
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
        ensureDirectory(fileOutputDir)
    end
    
    -- Save as .aseprite file
    app.command.SaveFileAs{
        ui = false,
        filename = outputPath
    }
    
    sprite:close()
    
    print("  ✓ " .. partName .. " (" .. pixelsPlaced .. " pixels) -> " .. outputPath)
    return true, pixelsPlaced
end

-- Main processing function
print("Reading JSON file...")
local data, err = parseCollateralBaseJSON(jsonPath)
if not data then
    print("ERROR: " .. (err or "Unknown error"))
    return
end

-- Extract collateral name from filename
local collateralName = jsonPath:match("collateral%-base%-(%w+)%-%d+%.json")
if not collateralName then
    collateralName = jsonPath:match("([^/\\]+)%.json$")
    if collateralName then
        collateralName = collateralName:gsub("collateral%-base%-", ""):gsub("%-.*", ""):gsub("%.json$", "")
    else
        collateralName = "unknown"
    end
end

-- Determine output directory
local outputDir
if customOutputDir then
    outputDir = customOutputDir
else
    -- Default to output directory in script location
    outputDir = "output/collateral-base-" .. collateralName
end

ensureDirectory(outputDir)
print("Output directory: " .. outputDir)
print("")

-- Define view names for body
local bodyViewNames = {"Front", "Left", "Right", "Back"}
local handsViewNames = {"DownClosed", "DownOpen", "Up"}

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

print("Processing SVGs...")
print("==================")

-- Process each category
for _, category in ipairs(categories) do
    print("\n" .. category.name .. " (" .. #category.array .. " SVG(s)):")
    
    for i, svg in ipairs(category.array) do
        local viewName = category.viewNames and category.viewNames[i] or ""
        local partName = category.prefix
        if viewName and viewName ~= "" then
            partName = partName .. "_" .. viewName:lower()
        end
        
        local filename = partName .. "_" .. collateralName .. ".aseprite"
        local outputPath = outputDir .. "/" .. filename
        
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
print("")
print("==========================================")
print("BATCH IMPORT COMPLETE")
print("==========================================")
print("Collateral: " .. collateralName)
print("Successfully processed: " .. totalProcessed .. " SVG(s)")
print("Total pixels rendered: " .. totalPixels)
print("Errors: " .. totalErrors)
print("Output directory: " .. outputDir)
print("==========================================")

if totalErrors > 0 then
    print("")
    print("WARNING: Some errors occurred during import. Check output above.")
end

