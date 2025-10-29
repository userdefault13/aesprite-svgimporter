-- Batch SVG Importer for Aseprite CLI
-- Processes multiple SVGs with metadata-driven positioning and saves as .aseprite files

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")
local JsonMetadataLoader = dofile("json-metadata-loader.lua")
local config = dofile("batch-config.lua")

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

-- Extract wearable ID from filename
local function extractWearableId(filename)
    local id = filename:match("^(%d+)_")
    return id and tonumber(id) or nil
end

-- Get output filename with view suffix
local function getOutputFilename(inputFilename, viewIndex)
    local baseName = inputFilename:match("^(.+)%.svg$")
    if not baseName then
        baseName = inputFilename:match("^(.+)%.SVG$")
    end
    
    if not baseName then
        return inputFilename .. ".aseprite"
    end
    
    local viewName = config.views[viewIndex + 1] or "unknown"
    return baseName .. "_" .. viewName .. ".aseprite"
end

-- Process a single SVG file
local function processSVGFile(svgPath, outputDir, viewIndex, targetSize)
    local fileStartTime = os.clock()
    local filename = app.fs.fileName(svgPath)
    
    logInfo("Processing: " .. filename)
    
    -- Extract wearable ID
    local wearableId = extractWearableId(filename)
    if not wearableId then
        logError("Could not extract wearable ID from filename: " .. filename)
        return false
    end
    
    -- Get offset for this wearable and view
    local offset = JsonMetadataLoader.getOffsetForWearable(wearableId, viewIndex)
    local wearableName = JsonMetadataLoader.getWearableName(wearableId)
    
    logInfo("Wearable ID: " .. wearableId .. " (" .. wearableName .. "), View: " .. (viewIndex + 1) .. ", Offset: (" .. offset.x .. "," .. offset.y .. ")")
    
    -- Read SVG file
    local file = io.open(svgPath, "r")
    if not file then
        logError("Could not open file: " .. svgPath)
        return false
    end
    
    local svgContent = file:read("*all")
    file:close()
    
    if not svgContent or svgContent == "" then
        logError("File is empty: " .. svgPath)
        return false
    end
    
    -- Parse SVG to get native dimensions
    local svgData = SVGParser.parse(svgContent)
    if not svgData or not svgData.viewBox then
        logError("Could not parse SVG: " .. svgPath)
        return false
    end
    
    -- Use SVG's native dimensions for initial import
    local nativeWidth = math.floor(svgData.viewBox.width)
    local nativeHeight = math.floor(svgData.viewBox.height)
    
    logInfo("Native SVG size: " .. nativeWidth .. "x" .. nativeHeight)
    
    -- Render SVG to pixels at native size
    local renderResult = SVGRenderer.render(svgData, nativeWidth, nativeHeight)
    
    if not renderResult or not renderResult.pixels or #renderResult.pixels == 0 then
        logError("No pixels rendered from SVG: " .. svgPath)
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
    
    -- Position and draw SVG pixels with offset
    local pixelsPlaced = 0
    app.transaction(function()
        for _, pixel in ipairs(renderResult.pixels) do
            -- Calculate target position with offset
            local targetX = pixel.x + offset.x
            local targetY = pixel.y + offset.y
            
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
    local outputFilename = getOutputFilename(filename, viewIndex)
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

-- Parse command line arguments
local function parseArguments()
    -- Try to get arguments from environment variables or use defaults
    local inputPath = os.getenv("BATCH_INPUT_PATH") or "examples"
    local outputDir = os.getenv("BATCH_OUTPUT_DIR") or "output"
    local viewIndex = tonumber(os.getenv("BATCH_VIEW_INDEX")) or config.default_view_index
    local targetSize = tonumber(os.getenv("BATCH_TARGET_SIZE")) or config.default_target_size
    
    -- Debug output removed for cleaner logs
    
    if not inputPath or not outputDir then
        print("Usage: aseprite -b --script batch-svg-importer.lua --script-param input_path=examples --script-param output_dir=output [--script-param view_index=0] [--script-param target_size=64]")
        print("")
        print("Parameters:")
        print("  input_path   - Directory path or comma-separated file list (e.g., 'examples' or '1,2,22')")
        print("  output_dir   - Directory to save .aseprite files")
        print("  view_index   - View index: 0=front, 1=left, 2=right, 3=back (default: 0)")
        print("  target_size  - Final canvas size (default: 64)")
        print("")
        print("Examples:")
        print("  aseprite -b --script batch-svg-importer.lua --script-param input_path=examples --script-param output_dir=output --script-param view_index=0")
        print("  aseprite -b --script batch-svg-importer.lua --script-param input_path=\"1,2,22\" --script-param output_dir=output --script-param view_index=1")
        return nil
    end
    
    -- Validate view index
    if viewIndex < 0 or viewIndex > 3 then
        logError("Invalid view index: " .. viewIndex .. ". Must be 0-3 (front/left/right/back)")
        return nil
    end
    
    -- Validate target size
    if targetSize <= 0 or targetSize > 1024 then
        logError("Invalid target size: " .. targetSize .. ". Must be 1-1024")
        return nil
    end
    
    return {
        inputPath = inputPath,
        outputDir = outputDir,
        viewIndex = viewIndex,
        targetSize = targetSize
    }
end

-- Get list of SVG files to process
local function getSVGFiles(inputPath)
    local svgFiles = {}
    
    if inputPath:find(",") then
        -- Comma-separated file list mode
        for id in inputPath:gmatch("([^,]+)") do
            id = id:match("^%s*(.-)%s*$") -- trim whitespace
            local pattern = "^" .. id .. "_.*%.svg$"
            
            -- Look for matching files in examples/svgItems directory
            if app.fs.isDirectory("examples/svgItems") then
                for _, file in ipairs(app.fs.listFiles("examples/svgItems")) do
                    if file:match(pattern) then
                        table.insert(svgFiles, app.fs.joinPath("examples/svgItems", file))
                    end
                end
            end
            
            -- Also check examples directory
            if app.fs.isDirectory("examples") then
                for _, file in ipairs(app.fs.listFiles("examples")) do
                    if file:match(pattern) then
                        table.insert(svgFiles, app.fs.joinPath("examples", file))
                    end
                end
            end
            
            -- Check current directory
            for _, file in ipairs(app.fs.listFiles(".")) do
                if file:match(pattern) then
                    table.insert(svgFiles, file)
                end
            end
        end
    else
        -- Directory mode
        if not app.fs.isDirectory(inputPath) then
            logError("Input path is not a directory: " .. inputPath)
            return {}
        end
        
        for _, filename in ipairs(app.fs.listFiles(inputPath)) do
            if filename:match("%.svg$") or filename:match("%.SVG$") then
                table.insert(svgFiles, app.fs.joinPath(inputPath, filename))
            end
        end
    end
    
    return svgFiles
end

-- Ensure output directory exists
local function ensureOutputDir(outputDir)
    if not app.fs.isDirectory(outputDir) then
        app.fs.makeDirectory(outputDir)
        logInfo("Created output directory: " .. outputDir)
    end
end

-- Main batch processing function
local function batchProcess()
    startTime = os.clock()
    
    -- Parse arguments
    local args = parseArguments()
    if not args then
        return
    end
    
    -- Open log file
    logFile = io.open(config.log_file, "w")
    if not logFile then
        logWarn("Could not open log file: " .. config.log_file)
    end
    
    logInfo("Batch SVG Import Started")
    logInfo("Config: input=" .. args.inputPath .. ", output=" .. args.outputDir .. 
            ", view=" .. args.viewIndex .. " (" .. config.views[args.viewIndex + 1] .. ")" ..
            ", size=" .. args.targetSize .. "x" .. args.targetSize)
    logInfo("---")
    
    -- Ensure output directory exists
    ensureOutputDir(args.outputDir)
    
    -- Get list of SVG files to process
    local svgFiles = getSVGFiles(args.inputPath)
    
    if #svgFiles == 0 then
        logError("No SVG files found to process")
        return
    end
    
    logInfo("Found " .. #svgFiles .. " SVG files to process")
    
    -- Process each file
    for _, svgPath in ipairs(svgFiles) do
        processedCount = processedCount + 1
        
        local success, pixelsPlaced, fileTime = pcall(processSVGFile, svgPath, args.outputDir, args.viewIndex, args.targetSize)
        
        if success then
            successCount = successCount + 1
            logInfo("[OK] " .. app.fs.fileName(svgPath) .. " → " .. getOutputFilename(app.fs.fileName(svgPath), args.viewIndex))
        else
            errorCount = errorCount + 1
            logError("[FAIL] " .. app.fs.fileName(svgPath) .. " - " .. tostring(success))
        end
        
        -- Check error limit
        if errorCount >= config.max_errors then
            logError("Too many errors (" .. errorCount .. "), stopping batch processing")
            break
        end
    end
    
    -- Final summary
    local totalTime = os.clock() - startTime
    local successRate = processedCount > 0 and (successCount / processedCount * 100) or 0
    
    logInfo("---")
    logInfo("Summary: " .. successCount .. "/" .. processedCount .. " successful (" .. 
            string.format("%.1f", successRate) .. "%), Total time: " .. 
            string.format("%.2f", totalTime) .. "s")
    
    if logFile then
        logFile:close()
        logFile = nil
    end
end

-- Run batch processing
batchProcess()
