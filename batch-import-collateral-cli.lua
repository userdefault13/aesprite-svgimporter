-- Batch Import Collateral JSON (CLI)
-- Usage: aseprite -b --script batch-import-collateral-cli.lua
-- Environment Variables:
--   BATCH_JSON_FILE   - Path to collateral JSON file (required)
--   BATCH_OUTPUT_DIR  - Output directory for .aseprite files (optional, defaults to <script_dir>/output/collateral-<name>)
-- Example:
--   BATCH_JSON_FILE=collateral-amaave-1764616862816.json aseprite -b --script batch-import-collateral-cli.lua

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")

-- Get environment variables
local jsonPath = os.getenv("BATCH_JSON_FILE")
local customOutputDir = os.getenv("BATCH_OUTPUT_DIR")

if not jsonPath or jsonPath == "" then
    print("Batch Import Collateral JSON (CLI)")
    print("====================================")
    print("Environment Variables:")
    print("  BATCH_JSON_FILE   - Path to collateral JSON file (required)")
    print("  BATCH_OUTPUT_DIR  - Output directory for .aseprite files (optional, defaults to <script_dir>/output/collateral-<name>)")
    print("")
    return
end

print("Batch Import Collateral JSON")
print("=============================")
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
local function parseCollateralJSON(jsonPath)
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
        collateral = extractSVGArray(jsonContent, "collateral")
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
local data, err = parseCollateralJSON(jsonPath)
if not data then
    print("ERROR: " .. (err or "Unknown error"))
    return
end

-- Extract collateral name from filename
local collateralName = jsonPath:match("collateral%-(%w+)%-%d+%.json")
if not collateralName then
    collateralName = jsonPath:match("([^/\\]+)%.json$")
    if collateralName then
        collateralName = collateralName:gsub("collateral%-", ""):gsub("%-.*", ""):gsub("%.json$", "")
    else
        collateralName = "unknown"
    end
end

-- Determine output directory
local outputDir
if customOutputDir then
    outputDir = customOutputDir
else
    -- Default to 'output' directory relative to the script's location
    local scriptPath = app.fs.normalizePath(app.fs.filePath(""))
    local scriptDir = scriptPath:match("^(.+)/[^/]+$") or scriptPath
    outputDir = app.fs.joinPath(scriptDir, "output", "collateral-" .. collateralName)
end

ensureDirectory(outputDir)
print("Output directory: " .. outputDir)
print("")

-- Define view names for collateral (Front, Left, Right - no Back)
local collateralViewNames = {"Front", "Left", "Right"}

-- Process collateral category
local categories = {
    {
        name = "collateral",
        array = data.collateral,
        viewNames = collateralViewNames,
        prefix = "collateral"
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

