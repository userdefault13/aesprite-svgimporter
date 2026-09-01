-- SVG Importer CLI Script
-- Usage: aseprite -b --script svg-importer-cli.lua -- <svg_file> [width] [height] [output_file]
-- Env: SVG_ANIMATED=1 SVG_FPS=8

local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")
local SVGAnimation = dofile("svg-animation.lua")

local SVGAnimation = dofile("svg-animation.lua")

local function frameDurationForFps(fps)
    fps = fps or 8
    if fps <= 0 then fps = 8 end
    return math.max(1, math.floor(100 / fps + 0.5))
end

local function setAnimationFrameDurations(sprite, frameCount, animFps, animationType)
    if animationType ~= "smil" or frameCount < 1 then
        return
    end
    local duration = frameDurationForFps(animFps)
    for i = 1, frameCount do
        sprite.frames[i].duration = duration
    end
end

local svgFile = os.getenv("SVG_FILE")
local canvasWidth = os.getenv("SVG_WIDTH") and tonumber(os.getenv("SVG_WIDTH")) or nil
local canvasHeight = os.getenv("SVG_HEIGHT") and tonumber(os.getenv("SVG_HEIGHT")) or nil
local outputFile = os.getenv("SVG_OUTPUT")
local importMode = os.getenv("SVG_IMPORT_MODE") or "Auto"
local animFps = tonumber(os.getenv("SVG_FPS") or "8") or 8

if os.getenv("SVG_ANIMATED") == "1" then
    importMode = "Animation Frames"
end

if not svgFile or svgFile == "" then
    local args = {...}
    local filteredArgs = {}
    for _, arg in ipairs(args) do
        if arg ~= "--" then
            table.insert(filteredArgs, arg)
        end
    end
    args = filteredArgs

    if #args >= 1 then
        svgFile = args[1]
        canvasWidth = args[2] and tonumber(args[2]) or nil
        canvasHeight = args[3] and tonumber(args[3]) or nil
        outputFile = args[4] or (svgFile:gsub("%.svg$", ""):gsub("%.SVG$", "") .. ".aseprite")
        if args[5] == "--animated" or args[5] == "--animation" then
            importMode = "Animation Frames"
        end
        if args[6] and tonumber(args[6]) then
            animFps = tonumber(args[6])
        end
    end
end

if not svgFile or svgFile == "" then
    print("SVG Importer CLI")
    print("Usage: aseprite -b --script svg-importer-cli.lua -- <svg_file> [width] [height] [output_file] [--animated] [fps]")
    print("")
    print("Environment variables:")
    print("  SVG_IMPORT_MODE  Auto | Single Frame | Animation Frames")
    print("  SVG_ANIMATED=1   Same as --animated")
    print("  SVG_FPS=8        SMIL sampling rate")
    return
end

if not outputFile or outputFile == "" then
    outputFile = svgFile:gsub("%.svg$", ""):gsub("%.SVG$", "") .. ".aseprite"
end

local function drawPixelsToCel(sprite, layer, frameIndex, pixels, width, height)
    local cel = sprite:newCel(layer, frameIndex)
    local image = cel.image
    image:clear(Color{r = 0, g = 0, b = 0, a = 0})
    for _, pixel in ipairs(pixels) do
        if pixel.x >= 0 and pixel.x < width and pixel.y >= 0 and pixel.y < height then
            local color = Color{r = pixel.color.r, g = pixel.color.g, b = pixel.color.b, a = 255}
            image:drawPixel(pixel.x, pixel.y, color)
        end
    end
end

local file = io.open(svgFile, "r")
if not file then
    print("ERROR: Could not open file: " .. svgFile)
    return
end

local svgContent = file:read("*all")
file:close()

if not svgContent or svgContent == "" then
    print("ERROR: File is empty: " .. svgFile)
    return
end

local svgData = SVGParser.parse(svgContent)
if not svgData or not svgData.viewBox then
    print("ERROR: Could not parse SVG viewBox")
    return
end

local finalWidth = canvasWidth or math.floor(svgData.viewBox.width)
local finalHeight = canvasHeight or math.floor(svgData.viewBox.height)
local animationInfo = SVGAnimation.detect(svgContent, animFps)
local useAnimation = importMode == "Animation Frames"
    or (importMode == "Auto" and animationInfo.frames and #animationInfo.frames >= 2)

print("SVG Importer CLI")
print("Input:  " .. svgFile)
print("Output: " .. outputFile)
print("Canvas: " .. finalWidth .. "x" .. finalHeight)
print("Mode:   " .. (useAnimation and ("animation (" .. #animationInfo.frames .. " frames)") or "single frame"))

local sprite = Sprite(finalWidth, finalHeight, ColorMode.RGB)
local layer = sprite.layers[1]

app.transaction(function()
    if useAnimation then
        for frameIndex, frame in ipairs(animationInfo.frames) do
            if frameIndex > 1 then
                sprite:newFrame()
            end
            local frameData = SVGParser.parse(frame.svg or svgContent)
            local renderResult = SVGRenderer.render(frameData, finalWidth, finalHeight)
            drawPixelsToCel(sprite, layer, frameIndex, renderResult.pixels, finalWidth, finalHeight)
        end
        if #animationInfo.frames >= 2 then
            sprite:newTag(1, #animationInfo.frames, "animation")
        end
        setAnimationFrameDurations(sprite, #animationInfo.frames, animFps, animationInfo.type)
    else
        local renderResult = SVGRenderer.render(svgData, finalWidth, finalHeight)
        drawPixelsToCel(sprite, layer, 1, renderResult.pixels, finalWidth, finalHeight)
    end
end)

app.command.SaveFileAs{ui = false, filename = outputFile}
sprite:close()
print("SUCCESS: saved " .. outputFile)
