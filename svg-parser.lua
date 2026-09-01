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

-- Parse path data string - handles line, cubic, and arc commands with safety limits
local function parsePathData(pathData)
    local commands = {}
    local i = 1
    local maxIterations = #pathData * 2 -- Safety limit
    local iterations = 0
    
    while i <= #pathData and iterations < maxIterations do
        iterations = iterations + 1
        local char = pathData:sub(i, i)
        
        if char:match("[MmLlHhVvZzCcSsAa]") then
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
                    
                    if nextChar:match("[MmLlHhVvZzCcSsAa]") then
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

local function getAttr(attrStr, name)
    return attrStr:match(name .. '="([^"]*)"') or attrStr:match(name .. "='([^']*)'")
end

local function trim(value)
    if not value then return nil end
    return value:match("^%s*(.-)%s*$")
end

local function parseStyleFill(attrStr)
    local style = getAttr(attrStr, "style")
    if not style then return nil end
    local fill = style:match("fill%s*:%s*([^;]+)")
    fill = trim(fill)
    if fill == "none" then return nil end
    return fill
end

local function parseElementFill(attrStr)
    return getAttr(attrStr, "fill") or parseStyleFill(attrStr)
end

local function circleToPathCommands(cx, cy, r)
    local commands = {}
    if not cx or not cy or not r or r <= 0 then
        return commands
    end

    local segments = math.max(24, math.min(160, math.floor(r * 0.8)))
    for n = 0, segments - 1 do
        local angle = (n / segments) * math.pi * 2
        local x = cx + math.cos(angle) * r
        local y = cy + math.sin(angle) * r
        table.insert(commands, {
            type = (n == 0) and "M" or "L",
            isRelative = false,
            params = {x, y}
        })
    end
    table.insert(commands, {type = "Z", isRelative = false, params = {}})
    return commands
end

-- Parse CSS styles from all <style> blocks
local function parseCSSStyles(svgContent)
    local styles = {}
    local display = {}

    local function ingestStyleBlock(styleBlock)
        if not styleBlock then return end
        -- .class{fill:#color} or .class{fill:#color; display:none; ...}
        for className, decls in styleBlock:gmatch('%.([%w%-]+)%{([^}]*)%}') do
            local fillValue = decls:match('fill%s*:%s*([^;]+)')
            if fillValue then
                styles[className] = hexToRgb(fillValue)
            end
            local displayValue = decls:match('display%s*:%s*([^;]+)')
            if displayValue then
                display[className] = displayValue:match('^%s*(.-)%s*$')
            end
        end
    end

    -- Match every <style ...>...</style> (optional attrs / CDATA)
    for styleBlock in svgContent:gmatch('<style[^>]*>(.-)</style>') do
        local inner = styleBlock:match('<!%[CDATA%[(.-)%]%]>') or styleBlock
        ingestStyleBlock(inner)
    end

    return styles, display
end

-- Resolve a fill color from a class attribute that may contain multiple classes
local function getFillFromClassAttr(classAttr, cssStyles)
    if not classAttr or classAttr == "" then
        return nil
    end
    
    -- Class attributes can contain multiple classes separated by spaces.
    -- Try each class name in order and return the first one that has a fill.
    for className in classAttr:gmatch("%S+") do
        local styleColor = cssStyles[className]
        if styleColor then
            return styleColor
        end
    end
    
    return nil
end

-- True if any class on the element has display:none
local function hasDisplayNone(classAttr, cssDisplay)
    if not classAttr or classAttr == "" or not cssDisplay then
        return false
    end
    for className in classAttr:gmatch("%S+") do
        if cssDisplay[className] == "none" then
            return true
        end
    end
    return false
end

-- Extract url(#id) reference
local function parseUrlRef(value)
    if not value then return nil end
    return value:match('url%(%s*#([^%)]+)%s*%)')
end

-- Resolve element fill: CSS class wins over inline fill (Aavegotchi color system)
-- Returns solidColor, patternId (one may be nil)
local function resolveFill(pathFill, pathClass, cssStyles, currentGroupFill)
    local classFill = getFillFromClassAttr(pathClass, cssStyles)
    if classFill then
        return classFill, nil
    end
    if pathFill then
        local patternId = parseUrlRef(pathFill)
        if patternId then
            return nil, patternId
        end
        return hexToRgb(pathFill), nil
    end
    if currentGroupFill then
        return currentGroupFill, nil
    end
    return {r = 0, g = 0, b = 0}, nil
end

-- Find end of an SVG element that may be self-closing (<tag .../>) or
-- explicitly closed (<tag ...></tag>). Returns attribute string and index
-- after the full element, or nil if not found.
local function findElementSpan(svgContent, start, tagName)
    local openEnd = svgContent:find('>', start)
    if not openEnd then
        return nil, nil
    end

    local attrStr = svgContent:sub(start, openEnd)
    local after

    -- Self-closing: .../>
    if svgContent:sub(openEnd - 1, openEnd) == '/>' then
        after = openEnd + 1
    else
        -- Explicit close: ...></tagName>
        local closeTag = '</' .. tagName .. '>'
        local closePos = svgContent:find(closeTag, openEnd + 1, true)
        if not closePos then
            return nil, nil
        end
        after = closePos + #closeTag
    end

    return attrStr, after
end

-- Build a path element table from a path attribute string
local function buildPathElement(pathStr, cssStyles, currentGroupFill, transformMatrix)
    local pathFill = parseElementFill(pathStr)
    local pathClass = getAttr(pathStr, "class")
    local fillColor, patternId = resolveFill(pathFill, pathClass, cssStyles, currentGroupFill)
    local d = pathStr:match('d="([^"]*)"')
    local pathCommands = {}
    if d then
        pathCommands = parsePathData(d)
    end

    local opacity = tonumber(getAttr(pathStr, "opacity"))
    local maskId = parseUrlRef(getAttr(pathStr, "mask"))
    local transform = getAttr(pathStr, "transform")

    local m = transformMatrix or {a = 1, b = 0, c = 0, d = 1, e = 0, f = 0}

    return {
        type = "path",
        fill = fillColor,
        patternId = patternId,
        pathCommands = pathCommands,
        -- Keep svgOffset for simple translate cases / backwards compatibility
        svgOffset = {x = m.e, y = m.f},
        svgMatrix = {a = m.a, b = m.b, c = m.c, d = m.d, e = m.e, f = m.f},
        opacity = opacity,
        maskId = maskId,
        transform = transform
    }
end

-- Main parsing function with group support
function SVGParser.parse(svgContent)
    local result = {
        viewBox = {x = 0, y = 0, width = 64, height = 64},
        elements = {},
        patterns = {},
        masks = {}
    }
    
    -- Parse CSS styles first
    local cssStyles, cssDisplay = parseCSSStyles(svgContent)
    
    -- Extract viewBox (fall back to width/height attributes for wearable fragments)
    local viewBox = svgContent:match('viewBox="([^"]*)"')
    if viewBox then
        result.viewBox = parseViewBox(viewBox)
    else
        -- Root <svg width="8" height="28"> style wearable pieces
        local rootTag = svgContent:match('<svg[^>]*>')
        if rootTag then
            local w = tonumber(rootTag:match('%swidth="([^"]*)"') or rootTag:match("%swidth='([^']*)'"))
            local h = tonumber(rootTag:match('%sheight="([^"]*)"') or rootTag:match("%sheight='([^']*)'"))
            if w and h and w > 0 and h > 0 then
                result.viewBox = {x = 0, y = 0, width = w, height = h}
            end
        end
    end

    -- Affine matrix helpers: x' = a*x + c*y + e, y' = b*x + d*y + f
    local function matIdentity()
        return {a = 1, b = 0, c = 0, d = 1, e = 0, f = 0}
    end
    local function matMultiply(m1, m2)
        return {
            a = m1.a * m2.a + m1.c * m2.b,
            b = m1.b * m2.a + m1.d * m2.b,
            c = m1.a * m2.c + m1.c * m2.d,
            d = m1.b * m2.c + m1.d * m2.d,
            e = m1.a * m2.e + m1.c * m2.f + m1.e,
            f = m1.b * m2.e + m1.d * m2.f + m1.f
        }
    end
    local function matTranslate(tx, ty)
        return {a = 1, b = 0, c = 0, d = 1, e = tx, f = ty}
    end
    local function matScale(sx, sy)
        return {a = sx, b = 0, c = 0, d = sy, e = 0, f = 0}
    end
    -- Parse transform="translate(...) scale(...)" lists (SVG: apply right-to-left)
    local function parseTransformMatrix(transformStr)
        if not transformStr then return matIdentity() end
        local ops = {}
        for kind, args in transformStr:gmatch("([%a]+)%(([^)]*)%)") do
            local nums = {}
            for n in args:gmatch("([%-%d%.]+)") do
                table.insert(nums, tonumber(n))
            end
            table.insert(ops, {kind = kind, nums = nums})
        end
        local m = matIdentity()
        -- Build combined matrix applying rightmost transform first
        for i = #ops, 1, -1 do
            local op = ops[i]
            if op.kind == "translate" then
                m = matMultiply(matTranslate(op.nums[1] or 0, op.nums[2] or 0), m)
            elseif op.kind == "scale" then
                local sx = op.nums[1] or 1
                local sy = op.nums[2] or sx
                m = matMultiply(matScale(sx, sy), m)
            end
        end
        return m
    end
    local function matApply(m, x, y)
        return m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f
    end
    local function matCopy(m)
        return {a = m.a, b = m.b, c = m.c, d = m.d, e = m.e, f = m.f}
    end
    
    -- Parse with group awareness
    local i = 1
    local groupFillStack = {} -- Stack to track nested group fills
    local currentGroupFill = nil
    local transformStack = {} -- Stack of affine matrices
    local currentTransform = matIdentity()
    local defsDepth = 0
    local skipDepth = 0 -- Skip subtrees with display:none
    local currentPattern = nil
    local currentMask = nil
    local patternStack = {}
    
    local function currentOffset()
        -- Expose translation component for backwards-compatible svgOffset
        return {x = currentTransform.e, y = currentTransform.f}
    end
    local function pushTransform(m)
        table.insert(transformStack, currentTransform)
        currentTransform = matMultiply(currentTransform, m)
    end
    local function popTransform()
        if #transformStack > 0 then
            currentTransform = table.remove(transformStack)
        else
            currentTransform = matIdentity()
        end
    end
    while i <= #svgContent do
        local char = svgContent:sub(i, i)
        
        -- Track <defs> ... </defs>
        if char == '<' and svgContent:sub(i + 1, i + 4) == 'defs' and svgContent:sub(i + 5, i + 5):match('[%s>]') then
            local defsEnd = svgContent:find('>', i)
            if defsEnd then
                defsDepth = defsDepth + 1
                local defsTag = svgContent:sub(i, defsEnd)
                local defsFill = defsTag:match('fill="([^"]*)"')
                if defsFill and not parseUrlRef(defsFill) then
                    -- defs fill becomes default for nested pattern paths
                    table.insert(groupFillStack, hexToRgb(defsFill))
                    currentGroupFill = hexToRgb(defsFill)
                else
                    table.insert(groupFillStack, currentGroupFill)
                end
                i = defsEnd + 1
            else
                i = i + 1
            end
        elseif char == '<' and svgContent:sub(i, i + 6) == '</defs>' then
            if defsDepth > 0 then
                defsDepth = defsDepth - 1
            end
            if #groupFillStack > 0 then
                table.remove(groupFillStack)
                currentGroupFill = groupFillStack[#groupFillStack]
            end
            i = i + 7
        -- Pattern open/close (inside defs)
        elseif char == '<' and svgContent:sub(i + 1, i + 7) == 'pattern' and svgContent:sub(i + 8, i + 8):match('[%s>]') then
            local tagEnd = svgContent:find('>', i)
            if tagEnd then
                local tag = svgContent:sub(i, tagEnd)
                local id = tag:match('id="([^"]*)"')
                local pattern = {
                    id = id,
                    x = tonumber(tag:match('%sx="([^"]*)"') or "0") or 0,
                    y = tonumber(tag:match('%sy="([^"]*)"') or "0") or 0,
                    width = tonumber(tag:match('width="([^"]*)"') or "0") or 0,
                    height = tonumber(tag:match('height="([^"]*)"') or "0") or 0,
                    elements = {}
                }
                if id then
                    result.patterns[id] = pattern
                end
                table.insert(patternStack, currentPattern)
                currentPattern = pattern
                i = tagEnd + 1
            else
                i = i + 1
            end
        elseif char == '<' and svgContent:sub(i, i + 9) == '</pattern>' then
            currentPattern = table.remove(patternStack)
            i = i + 10
        -- Mask open/close
        elseif char == '<' and svgContent:sub(i + 1, i + 4) == 'mask' and svgContent:sub(i + 5, i + 5):match('[%s>]') then
            local tagEnd = svgContent:find('>', i)
            if tagEnd then
                local tag = svgContent:sub(i, tagEnd)
                local id = tag:match('id="([^"]*)"')
                local mask = { id = id, elements = {} }
                if id then
                    result.masks[id] = mask
                end
                currentMask = mask
                i = tagEnd + 1
            else
                i = i + 1
            end
        elseif char == '<' and svgContent:sub(i, i + 6) == '</mask>' then
            currentMask = nil
            i = i + 7
        -- Look for opening <g> tags with fill attribute, class, or transform
        elseif char == '<' and svgContent:sub(i + 1, i + 1) == 'g' and svgContent:sub(i + 2, i + 2):match('[%s>]') then
            local gEnd = svgContent:find('>', i)
            if gEnd then
                local gTag = svgContent:sub(i, gEnd)
                local groupFill = parseElementFill(gTag)
                local groupClass = getAttr(gTag, "class")
                local groupTransform = getAttr(gTag, "transform")

                -- display:none groups and all descendants are skipped
                local groupHidden = hasDisplayNone(groupClass, cssDisplay)
                if groupHidden or skipDepth > 0 then
                    skipDepth = skipDepth + 1
                end

                -- Handle group fill
                if groupFill and not parseUrlRef(groupFill) then
                    local fillColor = hexToRgb(groupFill)
                    table.insert(groupFillStack, fillColor)
                    currentGroupFill = fillColor
                elseif groupClass then
                    local fillColor = getFillFromClassAttr(groupClass, cssStyles)
                    if fillColor then
                        table.insert(groupFillStack, fillColor)
                        currentGroupFill = fillColor
                    else
                        table.insert(groupFillStack, currentGroupFill)
                    end
                else
                    table.insert(groupFillStack, currentGroupFill)
                end
                
                -- Handle group transform (translate / scale / compound)
                if groupTransform then
                    pushTransform(parseTransformMatrix(groupTransform))
                else
                    pushTransform(matIdentity())
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
                -- Require whitespace before x=/y= so xmlns= is not matched
                local svgX = svgTag:match('%sx="([^"]*)"') or svgTag:match("%sx='([^']*)'")
                local svgY = svgTag:match('%sy="([^"]*)"') or svgTag:match("%sy='([^']*)'")
                local svgTransform = getAttr(svgTag, "transform")

                local m = matTranslate(tonumber(svgX) or 0, tonumber(svgY) or 0)
                if svgTransform then
                    m = matMultiply(m, parseTransformMatrix(svgTransform))
                end
                pushTransform(m)

                i = svgEnd + 1
            else
                i = i + 1
            end
        -- Look for closing </g> tags
        elseif char == '<' and svgContent:sub(i, i + 3) == '</g>' then
            if skipDepth > 0 then
                skipDepth = skipDepth - 1
            end
            if #groupFillStack > 0 then
                table.remove(groupFillStack)
                currentGroupFill = groupFillStack[#groupFillStack]
            end
            popTransform()
            i = i + 4
        -- Look for closing </svg> tags
        elseif char == '<' and svgContent:sub(i, i + 5) == '</svg>' then
            popTransform()
            i = i + 6
        -- Look for <path> elements (self-closing or </path>)
        elseif char == '<' and svgContent:sub(i + 1, i + 4) == 'path' then
            local pathStr, after = findElementSpan(svgContent, i, 'path')
            if pathStr then
                if skipDepth == 0 then
                    local path = buildPathElement(pathStr, cssStyles, currentGroupFill, currentTransform)
                    if currentPattern then
                        table.insert(currentPattern.elements, path)
                    elseif currentMask then
                        table.insert(currentMask.elements, path)
                    elseif defsDepth == 0 then
                        table.insert(result.elements, path)
                    end
                end
                i = after
            else
                i = i + 1
            end
        -- Look for <rect> elements (self-closing or </rect>)
        elseif char == '<' and svgContent:sub(i + 1, i + 4) == 'rect' then
            local rectStr, after = findElementSpan(svgContent, i, 'rect')
            if rectStr then
                if skipDepth == 0 and defsDepth == 0 and not currentPattern and not currentMask then
                    local rectFill = parseElementFill(rectStr)
                    local rectClass = getAttr(rectStr, "class")
                    local fillColor, patternId = resolveFill(rectFill, rectClass, cssStyles, currentGroupFill)

                    local x = tonumber(rectStr:match('x="([^"]*)"') or rectStr:match("x='([^']*)'") or "0")
                    local y = tonumber(rectStr:match('y="([^"]*)"') or rectStr:match("y='([^']*)'") or "0")
                    local width = tonumber(rectStr:match('width="([^"]*)"') or rectStr:match("width='([^']*)'") or "0")
                    local height = tonumber(rectStr:match('height="([^"]*)"') or rectStr:match("height='([^']*)'") or "0")
                    local transform = getAttr(rectStr, "transform")
                    local opacity = tonumber(getAttr(rectStr, "opacity"))
                    local maskId = parseUrlRef(getAttr(rectStr, "mask"))
                    local m = currentTransform

                    local rect = {
                        type = "rect",
                        fill = fillColor,
                        patternId = patternId,
                        x = x or 0,
                        y = y or 0,
                        width = width or 0,
                        height = height or 0,
                        transform = transform,
                        opacity = opacity,
                        maskId = maskId,
                        svgOffset = {x = m.e, y = m.f},
                        svgMatrix = {a = m.a, b = m.b, c = m.c, d = m.d, e = m.e, f = m.f}
                    }

                    table.insert(result.elements, rect)
                end
                i = after
            else
                i = i + 1
            end
        -- Look for <circle> elements (self-closing or </circle>)
        elseif char == '<' and svgContent:sub(i + 1, i + 6) == 'circle' then
            local circleStr, after = findElementSpan(svgContent, i, 'circle')
            if circleStr then
                if skipDepth == 0 and defsDepth == 0 and not currentPattern and not currentMask then
                    local circleFill = parseElementFill(circleStr)
                    local circleClass = getAttr(circleStr, "class")
                    local fillColor, patternId = resolveFill(circleFill, circleClass, cssStyles, currentGroupFill)
                    local transform = getAttr(circleStr, "transform")
                    local opacity = tonumber(getAttr(circleStr, "opacity"))
                    local maskId = parseUrlRef(getAttr(circleStr, "mask"))
                    local cx = tonumber(getAttr(circleStr, "cx") or "0")
                    local cy = tonumber(getAttr(circleStr, "cy") or "0")
                    local r = tonumber(getAttr(circleStr, "r") or "0")
                    local m = currentTransform

                    table.insert(result.elements, {
                        type = "path",
                        fill = fillColor,
                        patternId = patternId,
                        pathCommands = circleToPathCommands(cx, cy, r),
                        svgOffset = {x = m.e, y = m.f},
                        svgMatrix = {a = m.a, b = m.b, c = m.c, d = m.d, e = m.e, f = m.f},
                        opacity = opacity,
                        maskId = maskId,
                        transform = transform
                    })
                end
                i = after
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
