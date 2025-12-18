-- Clean SVG Parser for Aavegotchi SVGs
-- Handles simple SVG structures with path elements

local SVGParser = {}

-- Parse hex color to RGB
local function hexToRgb(hex)
    if not hex or hex == "" then return {r = 0, g = 0, b = 0} end

    -- Remove # if present and clean up trailing characters
    hex = hex:gsub("#", ""):gsub("[^%w]", "")  -- Remove # and any non-alphanumeric characters

    -- Handle 3-digit hex
    if #hex == 3 then
        hex = hex:gsub("(.)(.)(.)", "%1%1%2%2%3%3")
    end

    -- Handle 6-digit hex
    if #hex >= 6 then
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

-- Parse path data string - handles M, L, H, V, Z commands with safety limits
local function parsePathData(pathData)
    local commands = {}
    local i = 1
    local maxIterations = #pathData * 2 -- Safety limit
    local iterations = 0
    
    while i <= #pathData and iterations < maxIterations do
        iterations = iterations + 1
        local char = pathData:sub(i, i)
        
        if char:match("[MmLlHhVvZz]") then
            local command = {type = char:upper(), isRelative = (char:match("[a-z]") ~= nil)}
            
            if char:upper() == "Z" then
                -- Close path - no parameters
                table.insert(commands, command)
                i = i + 1
            else
                -- Extract parameters
                local params = {}
                i = i + 1
                local lastI = i -- Track position to detect infinite loops
                
                while i <= #pathData and iterations < maxIterations do
                    iterations = iterations + 1
                    local nextChar = pathData:sub(i, i)
                    
                    if nextChar:match("[MmLlHhVvZz]") then
                        break
                    end
                    
                    -- Skip whitespace and commas
                    if nextChar:match("%s") or nextChar == "," then
                        i = i + 1
                    elseif nextChar:match("[%d%.%-]") then
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
                    else
                        -- Unknown character, skip it to prevent infinite loop
                        i = i + 1
                    end
                    
                    -- Safety check: ensure we're making progress
                    if i == lastI then
                        i = i + 1 -- Force progress
                    end
                    lastI = i
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

-- Parse CSS styles from <style> block
local function parseCSSStyles(svgContent)
    local styles = {}
    
    -- Extract style block
    local styleBlock = svgContent:match('<style><!%[CDATA%[(.-)%]%]></style>')
    if not styleBlock then
        styleBlock = svgContent:match('<style>(.-)</style>')
    end
    
    if styleBlock then
        -- Parse CSS rules: .class{fill:#color} (no spaces between rules)
        for className, colorValue in styleBlock:gmatch('%.([^%{]+)%{fill:([^}]+)%}') do
            if className and colorValue then
                styles[className] = hexToRgb(colorValue)
            end
        end
    end
    
    return styles
end

-- Helper function to find color from class string (handles multiple classes)
local function getColorFromClass(classString, cssStyles)
    if not classString or not cssStyles then return nil end
    
    -- Split class string by spaces and check each class
    for className in classString:gmatch("([^%s]+)") do
        if cssStyles[className] then
            return cssStyles[className]
        end
    end
    
    return nil
end

-- Main parsing function with group support
function SVGParser.parse(svgContent)
    local result = {
        viewBox = {x = 0, y = 0, width = 64, height = 64},
        elements = {}
    }
    
    -- Parse CSS styles first
    local cssStyles = parseCSSStyles(svgContent)
    
    -- Extract viewBox
    local viewBox = svgContent:match('viewBox="([^"]*)"')
    if viewBox then
        result.viewBox = parseViewBox(viewBox)
    end
    
    -- Parse with group awareness
    local i = 1
    local groupFillStack = {} -- Stack to track nested group fills
    local currentGroupFill = nil
    local svgOffsetStack = {} -- Stack to track nested SVG positioning
    local currentSvgOffset = {x = 0, y = 0}
    
    while i <= #svgContent do
        local char = svgContent:sub(i, i)
        
        -- Look for opening <g> tags with fill attribute or class
        if char == '<' and svgContent:sub(i + 1, i + 1) == 'g' and svgContent:sub(i + 2, i + 2):match('[%s>]') then
            local gEnd = svgContent:find('>', i)
            if gEnd then
                local gTag = svgContent:sub(i, gEnd)
                local groupFill = gTag:match('fill="([^"]*)"')
                local groupClass = gTag:match('class="([^"]*)"')

                if groupFill then
                    local fillColor = hexToRgb(groupFill)
                    table.insert(groupFillStack, fillColor)
                    currentGroupFill = fillColor
                elseif groupClass then
                    local fillColor = getColorFromClass(groupClass, cssStyles)
                    if fillColor then
                        table.insert(groupFillStack, fillColor)
                        currentGroupFill = fillColor
                    else
                        table.insert(groupFillStack, currentGroupFill) -- Inherit parent group fill
                    end
                else
                    table.insert(groupFillStack, currentGroupFill) -- Inherit parent group fill
                end

                i = gEnd + 1
            else
                i = i + 1
            end
        -- Look for opening <svg> tags with x,y positioning
        elseif char == '<' and svgContent:sub(i + 1, i + 3) == 'svg' and svgContent:sub(i + 4, i + 4):match('[%s>]') then
            local svgEnd = svgContent:find('>', i)
            if svgEnd then
                local svgTag = svgContent:sub(i, svgEnd)
                local svgX = svgTag:match('x="([^"]*)"') or svgTag:match("x='([^']*)'")
                local svgY = svgTag:match('y="([^"]*)"') or svgTag:match("y='([^']*)'")

                local newOffset = {
                    x = currentSvgOffset.x + (tonumber(svgX) or 0),
                    y = currentSvgOffset.y + (tonumber(svgY) or 0)
                }
                table.insert(svgOffsetStack, newOffset)
                currentSvgOffset = newOffset

                i = svgEnd + 1
            else
                i = i + 1
            end
        -- Look for closing </g> tags
        elseif char == '<' and svgContent:sub(i, i + 3) == '</g>' then
            if #groupFillStack > 0 then
                table.remove(groupFillStack)
                currentGroupFill = groupFillStack[#groupFillStack]
            end
            i = i + 4
        -- Look for closing </svg> tags
        elseif char == '<' and svgContent:sub(i, i + 5) == '</svg>' then
            if #svgOffsetStack > 0 then
                table.remove(svgOffsetStack)
                currentSvgOffset = svgOffsetStack[#svgOffsetStack] or {x = 0, y = 0}
            end
            i = i + 6
        -- Look for <path> elements
        elseif char == '<' and svgContent:sub(i + 1, i + 4) == 'path' then
            local pathEnd = svgContent:find('/>', i)
            if pathEnd then
                local pathStr = svgContent:sub(i, pathEnd + 1)
                
                -- Extract fill attribute from path
                local pathFill = pathStr:match('fill="([^"]*)"')
                local pathClass = pathStr:match('class="([^"]*)"')
                local fillColor
                
                if pathFill then
                    -- Path has explicit fill - use it
                    fillColor = hexToRgb(pathFill)
                elseif pathClass then
                    -- Path uses CSS class - look up color (handles multiple classes)
                    fillColor = getColorFromClass(pathClass, cssStyles)
                    if not fillColor and currentGroupFill then
                        -- No matching class - inherit from group
                        fillColor = currentGroupFill
                    elseif not fillColor then
                        -- No fill anywhere - default to black
                        fillColor = {r = 0, g = 0, b = 0}
                    end
                elseif currentGroupFill then
                    -- No explicit fill - inherit from group
                    fillColor = currentGroupFill
                else
                    -- No fill anywhere - default to black
                    fillColor = {r = 0, g = 0, b = 0}
                end
                
                -- Extract d attribute
                local d = pathStr:match('d="([^"]*)"')
                local pathCommands = {}
                if d then
                    pathCommands = parsePathData(d)
                end

                -- Create path element with SVG offset stored
                local path = {
                    type = "path",
                    fill = fillColor,
                    pathCommands = pathCommands,
                    svgOffset = {x = currentSvgOffset.x, y = currentSvgOffset.y}  -- Store offset for rendering
                }
                
                table.insert(result.elements, path)
                i = pathEnd + 2
            else
                i = i + 1
            end
        -- Look for <rect> elements
        elseif char == '<' and svgContent:sub(i + 1, i + 4) == 'rect' then
            local rectEnd = svgContent:find('/>', i)
            if rectEnd then
                local rectStr = svgContent:sub(i, rectEnd + 1)
                
                -- Extract fill attribute from rect
                local rectFill = rectStr:match('fill="([^"]*)"')
                local rectClass = rectStr:match('class="([^"]*)"')
                local fillColor
                
                if rectFill then
                    -- Rect has explicit fill - use it
                    fillColor = hexToRgb(rectFill)
                elseif rectClass then
                    -- Rect uses CSS class - look up color (handles multiple classes)
                    fillColor = getColorFromClass(rectClass, cssStyles)
                    if not fillColor and currentGroupFill then
                        -- No matching class - inherit from group
                        fillColor = currentGroupFill
                    elseif not fillColor then
                        -- No fill anywhere - default to black
                        fillColor = {r = 0, g = 0, b = 0}
                    end
                elseif currentGroupFill then
                    -- No explicit fill - inherit from group
                    fillColor = currentGroupFill
                else
                    -- No fill anywhere - default to black
                    fillColor = {r = 0, g = 0, b = 0}
                end
                
                -- Extract rect attributes (x, y, width, height, transform)
                local x = tonumber(rectStr:match('x="([^"]*)"') or rectStr:match("x='([^']*)'") or "0")
                local y = tonumber(rectStr:match('y="([^"]*)"') or rectStr:match("y='([^']*)'") or "0")
                local width = tonumber(rectStr:match('width="([^"]*)"') or rectStr:match("width='([^']*)'") or "0")
                local height = tonumber(rectStr:match('height="([^"]*)"') or rectStr:match("height='([^']*)'") or "0")
                local transform = rectStr:match('transform="([^"]*)"') or rectStr:match("transform='([^']*)'")

                -- Create rect element (will be converted to path commands in renderer)
                -- SVG offset will be applied during rendering
                local rect = {
                    type = "rect",
                    fill = fillColor,
                    x = x or 0,
                    y = y or 0,
                    width = width or 0,
                    height = height or 0,
                    transform = transform,
                    svgOffset = {x = currentSvgOffset.x, y = currentSvgOffset.y}  -- Store offset for rendering
                }
                
                table.insert(result.elements, rect)
                i = rectEnd + 2
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
    
    return result
end

return SVGParser
