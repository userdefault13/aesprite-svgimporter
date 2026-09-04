-- SVG Importer CLI Script
-- Usage: aseprite -b --script-param file=<svg> --script-param output=<out.aseprite> --script svg-importer-cli.lua
-- (Aseprite 1.3.x does not forward `-- arg1 arg2 ...` to script `...` — script-param and
--  env vars are the only reliable ways to pass arguments to a batch script.)
-- Env: SVG_FILE SVG_OUTPUT SVG_WIDTH SVG_HEIGHT SVG_IMPORT_MODE SVG_ANIMATED=1 SVG_FPS=8

local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")
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

-- app.params is populated by --script-param name=value; prefer it over env vars.
local params = app and app.params or {}

local function paramOrEnv(paramName, envName)
    local p = params[paramName]
    if p and p ~= "" then return p end
    local e = os.getenv(envName)
    if e and e ~= "" then return e end
    return nil
end

local svgFile = paramOrEnv("file", "SVG_FILE")
local canvasWidth = tonumber(paramOrEnv("width", "SVG_WIDTH"))
local canvasHeight = tonumber(paramOrEnv("height", "SVG_HEIGHT"))
local outputFile = paramOrEnv("output", "SVG_OUTPUT")
local importMode = paramOrEnv("mode", "SVG_IMPORT_MODE") or "Auto"
local animFps = tonumber(paramOrEnv("fps", "SVG_FPS") or "8") or 8

local animatedFlag = paramOrEnv("animated", "SVG_ANIMATED")
if animatedFlag == "1" or animatedFlag == "true" then
    importMode = "Animation Frames"
end

if not svgFile or svgFile == "" then
    print("SVG Importer CLI")
    print("Usage: aseprite -b --script-param file=<svg> [--script-param width=N] [--script-param height=N]")
    print("       [--script-param output=<out.aseprite>] [--script-param mode=Auto|Single Frame|Animation Frames]")
    print("       [--script-param fps=8] --script svg-importer-cli.lua")
    print("")
    print("Environment variable equivalents (used when the matching --script-param is absent):")
    print("  SVG_FILE SVG_OUTPUT SVG_WIDTH SVG_HEIGHT")
    print("  SVG_IMPORT_MODE  Auto | Single Frame | Animation Frames")
    print("  SVG_ANIMATED=1   Same as mode=Animation Frames")
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
            local alpha = pixel.alpha or 1
            local color = Color{r = pixel.color.r, g = pixel.color.g, b = pixel.color.b, a = math.floor(alpha * 255 + 0.5)}
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
