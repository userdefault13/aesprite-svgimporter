-- Clean SVG Parser for Aavegotchi SVGs
-- Handles simple SVG structures with path elements

local SVGParser = {}

-- Parse hex color to RGB
local function hexToRgb(hex)
    if not hex or hex == "" then return {r = 0, g = 0, b = 0} end
    
    -- Remove # if present
    hex = hex:gsub("#", "")
    
    -- Handle 3-digit hex
    if #hex == 3 then
        hex = hex:gsub("(.)(.)(.)", "%1%1%2%2%3%3")
    end
    
    -- Handle 6-digit hex
    if #hex == 6 then
        local r = tonumber(hex:sub(1, 2), 16) or 0
        local g = tonumber(hex:sub(3, 4), 16) or 0
        local b = tonumber(hex:sub(5, 6), 16) or 0
        return {r = r, g = g, b = b}
    end
    
    return {r = 0, g = 0, b = 0}
end

-- Parse viewBox attribute
local function parseViewBox(viewBoxStr)
    if not viewBoxStr then return {x = 0, y = 0, width = 64, height = 64} end
    
    local coords = {}
    for coord in viewBoxStr:gmatch("[%d%.%-]+") do
        table.insert(coords, tonumber(coord))
    end
    
    if #coords >= 4 then
        return {
            x = coords[1] or 0,
            y = coords[2] or 0,
            width = coords[3] or 64,
            height = coords[4] or 64
        }
    end
    
    return {x = 0, y = 0, width = 64, height = 64}
end

-- Parse path data string - handles M, L, H, V, Z commands
local function parsePathData(pathData)
    local commands = {}
    local i = 1
    
    while i <= #pathData do
        local char = pathData:sub(i, i)
        
        if char:match("[MmLlHhVvZz]") then
            local command = {type = char:upper(), isRelative = char:match("[a-z]")}
            
            if char:upper() == "Z" then
                -- Close path - no parameters
                table.insert(commands, command)
                i = i + 1
            else
                -- Extract parameters
                local params = {}
                i = i + 1
                
                while i <= #pathData do
                    local nextChar = pathData:sub(i, i)
                    if nextChar:match("[MmLlHhVvZz]") then
                        break
                    end
                    
                    -- Skip whitespace and commas
                    if nextChar:match("%s") or nextChar == "," then
                        i = i + 1
                    else
                        -- Extract number (including negative signs and decimals)
                        local numStr = ""
                        
                        -- Handle negative sign
                        if pathData:sub(i, i) == "-" then
                            numStr = numStr .. "-"
                            i = i + 1
                        end
                        
                        -- Extract digits and decimal point
                        while i <= #pathData do
                            local c = pathData:sub(i, i)
                            if c:match("[%d%.]") then
                                numStr = numStr .. c
                                i = i + 1
                            else
                                break
                            end
                        end
                        
                        if numStr ~= "" and numStr ~= "-" then
                            local num = tonumber(numStr)
                            if num then
                                table.insert(params, num)
                            end
                        end
                    end
                end
                
                command.params = params
                table.insert(commands, command)
            end
        else
            i = i + 1
        end
    end
    
    return commands
end

-- Main parsing function
function SVGParser.parse(svgContent)
    local result = {
        viewBox = {x = 0, y = 0, width = 64, height = 64},
        elements = {}
    }
    
    -- Extract viewBox
    local viewBox = svgContent:match('viewBox="([^"]*)"')
    if viewBox then
        result.viewBox = parseViewBox(viewBox)
    end
    
    -- Find all <path> elements
    for pathStr in svgContent:gmatch('<path[^>]*/>') do
        -- Extract fill attribute
        local fill = pathStr:match('fill="([^"]*)"')
        local fillColor = {r = 0, g = 0, b = 0}
        if fill then
            fillColor = hexToRgb(fill)
        end
        
        -- Extract d attribute
        local d = pathStr:match('d="([^"]*)"')
        local pathCommands = {}
        if d then
            pathCommands = parsePathData(d)
        end
        
        -- Create path element
        local path = {
            type = "path",
            fill = fillColor,
            pathCommands = pathCommands
        }
        
        table.insert(result.elements, path)
    end
    
    return result
end

return SVGParser
