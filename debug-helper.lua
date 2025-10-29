-- Debug helper function
local file = io.open("aavegotchi_db_main.json", "r")
local content = file:read("*all")
file:close()

-- Helper function to extract SVG strings from JSON array
local function extractSVGStrings(arrayContent)
    local svgs = {}
    if not arrayContent then return svgs end
    
    print("Array content length: " .. #arrayContent)
    print("First 200 chars: " .. string.sub(arrayContent, 1, 200))
    
    -- Split by quotes and process each SVG
    local i = 1
    local svgCount = 0
    while i <= #arrayContent do
        local start = arrayContent:find('"', i)
        if not start then break end
        
        local j = start + 1
        local svg = ""
        while j <= #arrayContent do
            local char = arrayContent:sub(j, j)
            if char == '"' then
                -- Check if it's escaped
                if j > 1 and arrayContent:sub(j-1, j-1) == '\\' then
                    svg = svg .. char
                else
                    -- End of SVG string
                    break
                end
            else
                svg = svg .. char
            end
            j = j + 1
        end
        
        if #svg > 0 then
            svgCount = svgCount + 1
            print("SVG " .. svgCount .. " length: " .. #svg)
            print("First 100 chars: " .. string.sub(svg, 1, 100))
            
            -- Unescape the SVG string
            local unescapedSVG = svg:gsub('\\"', '"'):gsub('\\\\', '\\')
            print("Unescaped length: " .. #unescapedSVG)
            print("First 100 chars unescaped: " .. string.sub(unescapedSVG, 1, 100))
            
            table.insert(svgs, unescapedSVG)
        end
        
        i = j + 1
    end
    
    print("Total SVGs extracted: " .. #svgs)
    return svgs
end

-- Test with body array
local bodyArray = content:match('"body"%s*:%s*%[(.-)%]')
local svgs = extractSVGStrings(bodyArray)
