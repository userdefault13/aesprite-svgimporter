-- Debug pose extraction to see what's being captured
local SVGParser = dofile("svg-parser.lua")

-- Load hands SVG from JSON
local file = io.open("aavegotchi_db_main.json", "r")
local content = file:read("*all")
file:close()

-- Extract hands array
local handsArray = content:match('"hands"%s*:%s*%[(.-)%]')

-- Extract SVG strings
local function extractSVGStrings(arrayContent)
    local svgs = {}
    if not arrayContent then return svgs end
    
    local i = 1
    while i <= #arrayContent do
        local start = arrayContent:find('"', i)
        if not start then break end
        
        local j = start + 1
        local svg = ""
        while j <= #arrayContent do
            local char = arrayContent:sub(j, j)
            if char == '"' then
                if j > 1 and arrayContent:sub(j-1, j-1) == '\\' then
                    svg = svg .. char
                else
                    break
                end
            else
                svg = svg .. char
            end
            j = j + 1
        end
        
        if #svg > 0 then
            local unescapedSVG = svg:gsub('\\"', '"'):gsub('\\\\', '\\')
            table.insert(svgs, unescapedSVG)
        end
        
        i = j + 1
    end
    
    return svgs
end

local handsSVGs = extractSVGStrings(handsArray)
local handsSVG = handsSVGs[1]

print("Full hands SVG:")
print(handsSVG)
print("")
print("SVG length: " .. #handsSVG)
print("")

-- Test pattern matching for each pose
print("=== Testing Pattern Matching ===")

-- Test handsDownOpen
local downOpenMatch = handsSVG:match('<g class="gotchi%-handsDownOpen">(.-)</g>')
print("Hands Down Open match:")
print("Length: " .. (downOpenMatch and #downOpenMatch or 0))
if downOpenMatch then
    print("Content: " .. downOpenMatch)
end
print("")

-- Test handsDownClosed  
local downClosedMatch = handsSVG:match('<g class="gotchi%-handsDownClosed">(.-)</g>')
print("Hands Down Closed match:")
print("Length: " .. (downClosedMatch and #downClosedMatch or 0))
if downClosedMatch then
    print("Content: " .. downClosedMatch)
end
print("")

-- Test handsUp
local upMatch = handsSVG:match('<g class="gotchi%-handsUp">(.-)</g>')
print("Hands Up match:")
print("Length: " .. (upMatch and #upMatch or 0))
if upMatch then
    print("Content: " .. upMatch)
end
print("")

-- Test with different pattern (non-greedy)
print("=== Testing Non-Greedy Pattern ===")
local downOpenMatch2 = handsSVG:match('<g class="gotchi%-handsDownOpen">(.-)</g>')
print("Non-greedy Hands Down Open match:")
print("Length: " .. (downOpenMatch2 and #downOpenMatch2 or 0))
if downOpenMatch2 then
    print("Content: " .. downOpenMatch2)
end
