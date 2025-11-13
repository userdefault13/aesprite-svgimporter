-- Batch Collateral Sides Converter
-- Processes front, left, right, and back collateral body views for all 16 collaterals

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")

-- Collateral list (all 16)
local collaterals = {
    "amAAVE", "amDAI", "amUSDC", "amUSDT", "amWBTC", "amWETH", "amWMATIC",
    "maAAVE", "maDAI", "maLINK", "maTUSD", "maUNI", "maUSDC", "maUSDT", "maWETH", "maYFI"
}

-- View mapping (index to name)
local views = {
    {index = "00", name = "front"},
    {index = "01", name = "left"},
    {index = "02", name = "right"},
    {index = "03", name = "back"}
}

-- Remove .5 half-pixel coordinates to force integer rendering
-- This ensures 1-pixel wide shapes stay 1-pixel (not 2-pixel) thick
local function fixHalfPixelCoordinates(svgContent)
    -- Simply remove .5 from all coordinates
    -- This makes M30.5 become M30, keeping shapes aligned to pixel grid
    local fixed = svgContent:gsub("([0-9])%.5", "%1")
    return fixed
end

-- Load collateral SVG from filesystem
local function loadCollateralSVG(collateralName, viewIndex)
    local filePath = string.format("examples/collaterals/%s/body/%s_body_%s.svg", 
                                   collateralName, collateralName, viewIndex)
    
    local file = io.open(filePath, "r")
    if not file then
        print("    ERROR: Could not open file: " .. filePath)
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content or content == "" then
        print("    ERROR: File is empty: " .. filePath)
        return nil
    end
    
    -- Remove .5 half-pixel coordinates for correct 1px rendering
    content = fixHalfPixelCoordinates(content)
    
    return content
end

-- Process a single collateral view
local function processCollateralView(collateralName, svgContent, viewName, outputDir)
    local baseName = string.format("collateral_%s_%s", viewName, collateralName)
    
    print("  Processing: " .. baseName)
    
    -- Parse SVG (already has proper structure, no wrapping needed)
    local svgData = SVGParser.parse(svgContent)
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

-- Process a single collateral (all 4 views)
local function processCollateral(collateralName)
    print("Processing collateral: " .. collateralName)
    
    -- Create output directory
    local outputDir = "output/" .. collateralName
    os.execute("mkdir -p " .. outputDir)
    
    local successCount = 0
    local totalPixels = 0
    
    -- Process all 4 views
    print("  === Collateral Views ===")
    for _, view in ipairs(views) do
        -- Load SVG
        local svgContent = loadCollateralSVG(collateralName, view.index)
        if not svgContent then
            print("    Skipping view: " .. view.name)
            goto continue
        end
        
        -- Process view
        local result, pixelsPlaced = processCollateralView(collateralName, svgContent, view.name, outputDir)
        if result then
            successCount = successCount + 1
            totalPixels = totalPixels + pixelsPlaced
        end
        
        ::continue::
    end
    
    print("  Collateral " .. collateralName .. " completed: " .. successCount .. " files, " .. totalPixels .. " pixels")
    print("")
    
    return successCount, totalPixels
end

-- Main batch conversion function
local function convertAllCollateralSides()
    print("Starting batch conversion of collateral sides for all collaterals...")
    print("")
    
    local totalSuccessCount = 0
    local totalPixels = 0
    local processedCollaterals = 0
    
    -- Process each collateral
    for _, collateralName in ipairs(collaterals) do
        local successCount, pixelsPlaced = processCollateral(collateralName)
        totalSuccessCount = totalSuccessCount + successCount
        totalPixels = totalPixels + pixelsPlaced
        processedCollaterals = processedCollaterals + 1
    end
    
    print("=== COLLATERAL SIDES CONVERSION SUMMARY ===")
    print("Collaterals processed: " .. processedCollaterals .. " out of " .. #collaterals)
    print("Total files generated: " .. totalSuccessCount)
    print("Total pixels rendered: " .. totalPixels)
    print("Average files per collateral: " .. math.floor(totalSuccessCount / math.max(processedCollaterals, 1)))
    print("Average pixels per collateral: " .. math.floor(totalPixels / math.max(processedCollaterals, 1)))
    print("")
    print("Collateral sides conversion completed!")
    
    return totalSuccessCount > 0
end

-- Run the batch conversion
convertAllCollateralSides()

