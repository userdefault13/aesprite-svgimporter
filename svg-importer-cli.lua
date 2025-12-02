-- SVG Importer CLI Script
-- Usage: aseprite -b --script svg-importer-cli.lua -- <svg_file> [width] [height] [output_file]
-- Example: aseprite -b --script svg-importer-cli.lua -- input.svg 64 64 output.aseprite

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")

-- Get command line arguments
local args = {...}

if #args < 1 then
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
    os.exit(1)
end

local svgFile = args[1]
local canvasWidth = args[2] and tonumber(args[2]) or nil
local canvasHeight = args[3] and tonumber(args[3]) or nil
local outputFile = args[4] or svgFile:gsub("%.svg$", ""):gsub("%.SVG$", "") .. ".aseprite"

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
    os.exit(1)
end

local svgContent = file:read("*all")
file:close()

if not svgContent or svgContent == "" then
    print("ERROR: File is empty: " .. svgFile)
    os.exit(1)
end

-- Parse SVG
print("Parsing SVG...")
local svgData = SVGParser.parse(svgContent)
if not svgData or not svgData.viewBox then
    print("ERROR: Could not parse SVG viewBox")
    os.exit(1)
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

