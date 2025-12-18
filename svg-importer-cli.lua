-- SVG Importer CLI Script
-- Usage: aseprite -b --script svg-importer-cli.lua -- <svg_file> [width] [height] [output_file]
-- Example: aseprite -b --script svg-importer-cli.lua -- input.svg 64 64 output.aseprite

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")

-- Get parameters from environment variables (works better in batch mode)
local svgFile = os.getenv("SVG_FILE")
local canvasWidth = os.getenv("SVG_WIDTH") and tonumber(os.getenv("SVG_WIDTH")) or nil
local canvasHeight = os.getenv("SVG_HEIGHT") and tonumber(os.getenv("SVG_HEIGHT")) or nil
local outputFile = os.getenv("SVG_OUTPUT")

-- Fallback to command line arguments
if not svgFile or svgFile == "" then
    local args = {...}
    -- Filter out any "--" separator if present
    local filteredArgs = {}
    for i, arg in ipairs(args) do
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
    end
end

if not svgFile or svgFile == "" then
    print("SVG Importer CLI")
    print("Usage: aseprite -b --script svg-importer-cli.lua -- <svg_file> [width] [height] [output_file]")
    print("")
    print("Arguments:")
    print("  svg_file     - Path to SVG file to import (required)")
    print("  width        - Canvas width in pixels (optional, defaults to SVG viewBox width)")
    print("  height       - Canvas height in pixels (optional, defaults to SVG viewBox height)")
    print("  output_file  - Output .aseprite file path (optional, defaults to input filename with .aseprite extension)")
    print("")
    print("Examples:")
    print("  aseprite -b --script svg-importer-cli.lua -- input.svg")
    print("  aseprite -b --script svg-importer-cli.lua -- input.svg 64 64")
    print("  aseprite -b --script svg-importer-cli.lua -- input.svg 64 64 output.aseprite")
    return
end

-- outputFile is set above, or use default
if not outputFile or outputFile == "" then
    outputFile = svgFile:gsub("%.svg$", ""):gsub("%.SVG$", "") .. ".aseprite"
end

print("SVG Importer CLI")
print("=================")
print("Input file:  " .. svgFile)
print("Output file: " .. outputFile)
if canvasWidth and canvasHeight then
    print("Canvas size: " .. canvasWidth .. "x" .. canvasHeight)
else
    print("Canvas size: Auto (from SVG viewBox)")
end
print("")

-- Read SVG file
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

-- Parse SVG
print("Parsing SVG...")
local svgData = SVGParser.parse(svgContent)
if not svgData or not svgData.viewBox then
    print("ERROR: Could not parse SVG viewBox")
    return
end

print("  ViewBox: " .. svgData.viewBox.width .. "x" .. svgData.viewBox.height)
print("  Elements: " .. #svgData.elements)

-- Determine canvas dimensions
local finalWidth = canvasWidth or math.floor(svgData.viewBox.width)
local finalHeight = canvasHeight or math.floor(svgData.viewBox.height)

print("")
print("Rendering to " .. finalWidth .. "x" .. finalHeight .. " canvas...")

-- Render to pixels
local renderResult = SVGRenderer.render(svgData, finalWidth, finalHeight)
print("  Rendered " .. #renderResult.pixels .. " pixels")

-- Create sprite
print("Creating sprite...")
local sprite = Sprite(finalWidth, finalHeight, ColorMode.RGB)
local layer = sprite.layers[1]
local cel = sprite:newCel(layer, 1)
local image = cel.image

-- Draw pixels
app.transaction(
    function()
        for _, pixel in ipairs(renderResult.pixels) do
            if pixel.x >= 0 and pixel.x < finalWidth and pixel.y >= 0 and pixel.y < finalHeight then
                local color = Color{r = pixel.color.r, g = pixel.color.g, b = pixel.color.b}
                image:drawPixel(pixel.x, pixel.y, color)
            end
        end
    end
)

-- Save file
print("Saving to " .. outputFile .. "...")
app.command.SaveFileAs{
    ui = false,
    filename = outputFile
}

sprite:close()

print("")
print("SUCCESS: SVG imported and saved to " .. outputFile)

