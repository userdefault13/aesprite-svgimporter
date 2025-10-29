-- Debug SVG parsing
local SVGParser = dofile("svg-parser.lua")
local CollateralColorsLoader = dofile("collateral-colors-loader.lua")

-- Load collaterals
local collaterals = CollateralColorsLoader.loadAllCollaterals()
local maDAI = CollateralColorsLoader.getCollateralByName(collaterals, "maDAI")

-- Load main SVG templates
local file = io.open("aavegotchi_db_main.json", "r")
local content = file:read("*all")
file:close()

-- Extract first body template
local bodyArray = content:match('"body"%s*:%s*%[(.-)%]')
local bodySVG = bodyArray:match('"([^"]*)"')

print("Original body SVG:")
print(string.sub(bodySVG, 1, 200))
print("...")

-- Wrap SVG with colors
local styleBlock = string.format([[
<style>
  .gotchi-primary { fill: %s; }
  .gotchi-secondary { fill: %s; }
  .gotchi-cheek { fill: %s; }
  .gotchi-primary-mouth { fill: %s; }
</style>]], 
    maDAI.primaryColor,
    maDAI.secondaryColor, 
    maDAI.cheekColor,
    maDAI.primaryColor
)

local wrappedSVG = string.format([[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">%s%s</svg>]], 
    styleBlock, bodySVG)

print("\nWrapped SVG:")
print(string.sub(wrappedSVG, 1, 300))
print("...")

-- Parse SVG
local svgData = SVGParser.parse(wrappedSVG)
print("\nSVG parsed:")
print("ViewBox: " .. svgData.viewBox.width .. "x" .. svgData.viewBox.height)
print("Elements: " .. #svgData.elements)

if #svgData.elements > 0 then
    print("First element type: " .. (svgData.elements[1].type or "unknown"))
    print("First element fill: " .. (svgData.elements[1].fill and 
        string.format("r=%d,g=%d,b=%d", svgData.elements[1].fill.r, svgData.elements[1].fill.g, svgData.elements[1].fill.b) or "none"))
end
