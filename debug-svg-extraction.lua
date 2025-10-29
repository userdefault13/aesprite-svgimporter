-- Debug SVG extraction from JSON
local file = io.open("aavegotchi_db_main.json", "r")
local content = file:read("*all")
file:close()

-- Extract body array
local bodyArray = content:match('"body"%s*:%s*%[(.-)%]')
print("Body array length: " .. #bodyArray)
print("First 200 chars of body array:")
print(string.sub(bodyArray, 1, 200))
print("...")

-- Try to extract first SVG
local svg = bodyArray:match('"([^"]*)"')
print("\nExtracted SVG length: " .. #svg)
print("First 200 chars of extracted SVG:")
print(string.sub(svg, 1, 200))
print("...")

-- Check for escaped quotes
local escapedCount = 0
for _ in svg:gmatch('\\"') do
    escapedCount = escapedCount + 1
end
print("\nEscaped quotes found: " .. escapedCount)

-- Try unescaping
local unescapedSVG = svg:gsub('\\"', '"'):gsub('\\\\', '\\')
print("Unescaped SVG length: " .. #unescapedSVG)
print("First 200 chars of unescaped SVG:")
print(string.sub(unescapedSVG, 1, 200))
print("...")
