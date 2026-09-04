-- Clean SVG Parser for Aavegotchi SVGs
-- Handles simple SVG structures with path, rect, circle, ellipse, line, polygon
-- and polyline elements, resolving fill/stroke, transforms, masks and clip-paths
-- into a flat list of "path" elements the renderer can rasterize uniformly.

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

-- Escape Lua pattern magic characters so attribute names like "stroke-width"
-- or "clip-path" (which contain '-', itself a pattern quantifier) match literally.
local function escapePattern(s)
    return (s:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"))
end

local function getAttr(attrStr, name)
    local pat = escapePattern(name)
    return attrStr:match(pat .. '="([^"]*)"') or attrStr:match(pat .. "='([^']*)'")
end

local function trim(value)
    if not value then return nil end
    return value:match("^%s*(.-)%s*$")
end

local function parseStyleProp(attrStr, propName)
    local style = getAttr(attrStr, "style")
    if not style then return nil end
    local value = style:match(escapePattern(propName) .. "%s*:%s*([^;]+)")
    return trim(value)
end

local function parseElementFill(attrStr)
    local fill = getAttr(attrStr, "fill")
    if fill then return fill end
    local styleFill = parseStyleProp(attrStr, "fill")
    if styleFill == "none" then return nil end
    return styleFill
end

-- Returns the raw stroke value: nil (unset), "none" (explicitly off), or a color string.
local function parseElementStroke(attrStr)
    local stroke = getAttr(attrStr, "stroke")
    if stroke then return stroke end
    return parseStyleProp(attrStr, "stroke")
end

local function parseElementStrokeWidth(attrStr)
    local width = getAttr(attrStr, "stroke-width")
    if width then return tonumber(width) end
    local styleWidth = parseStyleProp(attrStr, "stroke-width")
    return styleWidth and tonumber(styleWidth) or nil
end

local function parseElementStrokeOpacity(attrStr)
    local op = getAttr(attrStr, "stroke-opacity")
    if op then return tonumber(op) end
    local styleOp = parseStyleProp(attrStr, "stroke-opacity")
    return styleOp and tonumber(styleOp) or nil
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

local function ellipseToPathCommands(cx, cy, rx, ry)
    local commands = {}
    if not cx or not cy or not rx or not ry or rx <= 0 or ry <= 0 then
        return commands
    end

    local segments = math.max(24, math.min(160, math.floor(math.max(rx, ry) * 0.8)))
    for n = 0, segments - 1 do
        local angle = (n / segments) * math.pi * 2
        local x = cx + math.cos(angle) * rx
        local y = cy + math.sin(angle) * ry
        table.insert(commands, {
            type = (n == 0) and "M" or "L",
            isRelative = false,
            params = {x, y}
        })
    end
    table.insert(commands, {type = "Z", isRelative = false, params = {}})
    return commands
end

-- "x1,y1 x2,y2 ..." (commas and/or whitespace separated) -> {{x=,y=}, ...}
local function parsePointsAttr(pointsStr)
    local nums = {}
    if not pointsStr then return {} end
    for n in pointsStr:gmatch("[%-%d%.]+") do
        local v = tonumber(n)
        if v then table.insert(nums, v) end
    end
    local points = {}
    for i = 1, #nums - 1, 2 do
        table.insert(points, {x = nums[i], y = nums[i + 1]})
    end
    return points
end

local function pointsToPathCommands(points, closed)
    local commands = {}
    if #points == 0 then return commands end
    table.insert(commands, {type = "M", isRelative = false, params = {points[1].x, points[1].y}})
    for i = 2, #points do
        table.insert(commands, {type = "L", isRelative = false, params = {points[i].x, points[i].y}})
    end
    if closed then
        table.insert(commands, {type = "Z", isRelative = false, params = {}})
    end
    return commands
end

local function rectPathCommands(x, y, width, height)
    return {
        {type = "M", isRelative = false, params = {x, y}},
        {type = "L", isRelative = false, params = {x + width, y}},
        {type = "L", isRelative = false, params = {x + width, y + height}},
        {type = "L", isRelative = false, params = {x, y + height}},
        {type = "Z", isRelative = false, params = {}}
    }
end

-- Parse CSS styles from all <style> blocks: fill/stroke/stroke-width per class, plus display.
local function parseCSSStyles(svgContent)
    local styles = {}
    local strokeStyles = {}
    local strokeWidths = {}
    local display = {}

    local function ingestStyleBlock(styleBlock)
        if not styleBlock then return end
        -- .class{fill:#color} or .class{fill:#color; display:none; ...}
        for className, decls in styleBlock:gmatch('%.([%w%-]+)%{([^}]*)%}') do
            local fillValue = decls:match('fill%s*:%s*([^;]+)')
            if fillValue then
                styles[className] = hexToRgb(fillValue)
            end
            local strokeValue = decls:match('stroke%s*:%s*([^;]+)')
            if strokeValue then
                strokeValue = trim(strokeValue)
                if strokeValue and strokeValue ~= "none" then
                    strokeStyles[className] = hexToRgb(strokeValue)
                end
            end
            local strokeWidthValue = decls:match('stroke%-width%s*:%s*([^;]+)')
            if strokeWidthValue then
                strokeWidths[className] = tonumber(trim(strokeWidthValue))
            end
            local displayValue = decls:match('display%s*:%s*([^;]+)')
            if displayValue then
                display[className] = trim(displayValue)
            end
        end
    end

    -- Match every <style ...>...</style> (optional attrs / CDATA)
    for styleBlock in svgContent:gmatch('<style[^>]*>(.-)</style>') do
        local inner = styleBlock:match('<!%[CDATA%[(.-)%]%]>') or styleBlock
        ingestStyleBlock(inner)
    end

    return styles, display, strokeStyles, strokeWidths
end

-- Resolve a color from a class attribute that may contain multiple classes.
-- Generic: works for fill or stroke class maps (className -> {r,g,b}).
local function getColorFromClassAttr(classAttr, classColorMap)
    if not classAttr or classAttr == "" then
        return nil
    end
    for className in classAttr:gmatch("%S+") do
        local color = classColorMap[className]
        if color then
            return color
        end
    end
    return nil
end

-- Resolve a numeric value (e.g. stroke-width) from a class attribute.
local function getNumberFromClassAttr(classAttr, classNumberMap)
    if not classAttr or classAttr == "" then
        return nil
    end
    for className in classAttr:gmatch("%S+") do
        local value = classNumberMap[className]
        if value then
            return value
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
-- Returns solidColor, patternId, gradientId (fields are mutually exclusive)
local function resolveFill(pathFill, pathClass, cssStyles, currentGroupFill)
    local classFill = getColorFromClassAttr(pathClass, cssStyles)
    if classFill then
        return classFill, nil
    end
    if pathFill then
        local patternId = parseUrlRef(pathFill)
        if patternId then
            return nil, patternId
        end
        if pathFill == "none" then
            return nil, nil
        end
        return hexToRgb(pathFill), nil
    end
    if currentGroupFill then
        return currentGroupFill, nil
    end
    return {r = 0, g = 0, b = 0}, nil
end

-- Resolve element stroke color: class wins, then inline, then group inheritance.
-- rawStroke: nil (unset/inherit), "none" (explicitly off), or a color string.
local function resolveStroke(rawStroke, pathClass, cssStrokeStyles, currentGroupStroke)
    local classStroke = getColorFromClassAttr(pathClass, cssStrokeStyles)
    if classStroke then
        return classStroke
    end
    if rawStroke then
        if rawStroke == "none" then
            return nil
        end
        return hexToRgb(rawStroke)
    end
    return currentGroupStroke
end

local function resolveStrokeWidth(rawWidth, pathClass, cssStrokeWidths, currentGroupStrokeWidth)
    local classWidth = getNumberFromClassAttr(pathClass, cssStrokeWidths)
    if classWidth then return classWidth end
    if rawWidth then return rawWidth end
    return currentGroupStrokeWidth or 1
end

-- Gradient coordinates/offsets: "50%" -> 0.5 (fraction), "120" -> 120 (raw
-- user-space number). The renderer interprets the result differently
-- depending on gradientUnits (objectBoundingBox fraction vs userSpaceOnUse
-- absolute coordinate), so both forms just resolve to a plain number here.
local function parseGradCoord(str)
    if not str then return 0 end
    local pct = str:match("^([%-%d%.]+)%%$")
    if pct then return (tonumber(pct) or 0) / 100 end
    return tonumber(str) or 0
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

-- ============================================================================
-- <use> RESOLUTION
-- <use xlink:href="#id"> is common (defs shared between multiple placements,
-- clipPath geometry defined once and reused). The rest of the parser is a
-- single-pass state machine with no id registry, so <use> is resolved as a
-- text-expansion pre-pass: build id -> raw markup, then splice each <use>'s
-- referenced markup in as a <g transform="translate(x,y) ..."> wrapper before
-- the normal parse runs.
-- ============================================================================

-- Byte index one past the end of an element at `start`, handling self-closing
-- tags and same-tag-name nesting (e.g. a referenced <g> containing <g>s).
local function findGenericElementEnd(content, start, tagName)
    local tagEnd = content:find(">", start)
    if not tagEnd then return nil end
    if content:sub(tagEnd - 1, tagEnd) == "/>" then
        return tagEnd + 1
    end
    local closeTag = "</" .. tagName .. ">"
    local depth = 1
    local pos = tagEnd + 1
    while pos <= #content and depth > 0 do
        local nextClose = content:find(closeTag, pos, true)
        if not nextClose then return nil end
        local nextOpen = content:find("<" .. tagName, pos, true)
        if nextOpen and nextOpen < nextClose then
            local afterName = content:sub(nextOpen + 1 + #tagName, nextOpen + 1 + #tagName)
            if afterName:match("[%s>/]") then
                local innerEnd = content:find(">", nextOpen)
                if innerEnd and content:sub(innerEnd - 1, innerEnd) == "/>" then
                    pos = innerEnd + 1
                else
                    depth = depth + 1
                    pos = (innerEnd or nextOpen) + 1
                end
            else
                pos = nextOpen + 1
            end
        else
            depth = depth - 1
            pos = nextClose + #closeTag
        end
    end
    return pos
end

-- Flat scan of the whole document for id="..." on any tag -> that tag's raw markup.
local function buildIdMap(content)
    local map = {}
    local i = 1
    while i <= #content do
        local tagStart = content:find("<", i)
        if not tagStart then break end
        local nextChar = content:sub(tagStart + 1, tagStart + 1)
        if nextChar == "" then
            break
        elseif nextChar == "/" or nextChar == "!" or nextChar == "?" then
            i = tagStart + 1
        else
            local tagNameEnd = content:find("[%s/>]", tagStart + 1)
            if not tagNameEnd then break end
            local tagName = content:sub(tagStart + 1, tagNameEnd - 1)
            local openTagClose = content:find(">", tagStart)
            if not openTagClose then break end
            if tagName == "" then
                i = openTagClose + 1
            else
                local openTagStr = content:sub(tagStart, openTagClose)
                local id = openTagStr:match('id="([^"]*)"') or openTagStr:match("id='([^']*)'")
                if id then
                    local elEnd = findGenericElementEnd(content, tagStart, tagName)
                    if elEnd then
                        map[id] = content:sub(tagStart, elEnd - 1)
                        i = elEnd
                    else
                        i = openTagClose + 1
                    end
                else
                    i = openTagClose + 1
                end
            end
        end
    end
    return map
end

-- Replace every <use href="#id" .../> with the referenced markup wrapped in a
-- <g transform="translate(x,y) ...">. Unresolvable refs are dropped (no-op)
-- rather than left as a literal <use> the rest of the parser doesn't understand.
local function expandUseElements(content, idMap)
    local out = {}
    local i = 1
    local changed = false
    while i <= #content do
        local usePos = content:find("<use", i)
        if not usePos then
            table.insert(out, content:sub(i))
            break
        end
        local afterUse = content:sub(usePos + 4, usePos + 4)
        if not afterUse:match("[%s>/]") then
            table.insert(out, content:sub(i, usePos + 3))
            i = usePos + 4
        else
            table.insert(out, content:sub(i, usePos - 1))
            local tagEnd = content:find(">", usePos)
            if not tagEnd then
                table.insert(out, content:sub(usePos))
                i = #content + 1
            else
                local selfClosing = content:sub(tagEnd - 1, tagEnd) == "/>"
                local useTag = content:sub(usePos, tagEnd)
                local afterElement
                if selfClosing then
                    afterElement = tagEnd + 1
                else
                    local closePos = content:find("</use>", tagEnd + 1, true)
                    afterElement = closePos and (closePos + 6) or (tagEnd + 1)
                end

                local href = getAttr(useTag, "xlink:href") or getAttr(useTag, "href")
                local refId = href and href:match("#(.+)")
                local refMarkup = refId and idMap[refId]

                if refMarkup then
                    local ux = tonumber(getAttr(useTag, "x") or "0") or 0
                    local uy = tonumber(getAttr(useTag, "y") or "0") or 0
                    local useTransform = getAttr(useTag, "transform") or ""
                    table.insert(out, string.format(
                        '<g transform="translate(%s,%s) %s">%s</g>',
                        tostring(ux), tostring(uy), useTransform, refMarkup
                    ))
                    changed = true
                end

                i = afterElement
            end
        end
    end
    return table.concat(out), changed
end

-- ============================================================================
-- AFFINE MATRIX HELPERS: x' = a*x + c*y + e, y' = b*x + d*y + f
-- Module-level so both group transforms and element-level `transform="..."`
-- attributes share one implementation (translate/scale/rotate/skew/matrix).
-- ============================================================================

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

local function matRotate(angleDeg, cx, cy)
    local rad = math.rad(angleDeg or 0)
    local cosA, sinA = math.cos(rad), math.sin(rad)
    local rot = {a = cosA, b = sinA, c = -sinA, d = cosA, e = 0, f = 0}
    if cx and cy then
        local m = matMultiply(matTranslate(cx, cy), rot)
        return matMultiply(m, matTranslate(-cx, -cy))
    end
    return rot
end

local function matSkewX(angleDeg)
    return {a = 1, b = 0, c = math.tan(math.rad(angleDeg or 0)), d = 1, e = 0, f = 0}
end

local function matSkewY(angleDeg)
    return {a = 1, b = math.tan(math.rad(angleDeg or 0)), c = 0, d = 1, e = 0, f = 0}
end

-- Parse a full transform="..." list (translate/scale/rotate/skewX/skewY/matrix),
-- applied right-to-left per the SVG spec.
local function parseTransformMatrix(transformStr)
    if not transformStr then return matIdentity() end
    local ops = {}
    for kind, args in transformStr:gmatch("([%a]+)%(([^)]*)%)") do
        local nums = {}
        for n in args:gmatch("([%-%d%.eE%+]+)") do
            table.insert(nums, tonumber(n))
        end
        table.insert(ops, {kind = kind, nums = nums})
    end
    local m = matIdentity()
    for i = #ops, 1, -1 do
        local op = ops[i]
        if op.kind == "translate" then
            m = matMultiply(matTranslate(op.nums[1] or 0, op.nums[2] or 0), m)
        elseif op.kind == "scale" then
            local sx = op.nums[1] or 1
            local sy = op.nums[2] or sx
            m = matMultiply(matScale(sx, sy), m)
        elseif op.kind == "rotate" then
            m = matMultiply(matRotate(op.nums[1] or 0, op.nums[2], op.nums[3]), m)
        elseif op.kind == "skewX" then
            m = matMultiply(matSkewX(op.nums[1] or 0), m)
        elseif op.kind == "skewY" then
            m = matMultiply(matSkewY(op.nums[1] or 0), m)
        elseif op.kind == "matrix" and #op.nums >= 6 then
            m = matMultiply({
                a = op.nums[1], b = op.nums[2], c = op.nums[3],
                d = op.nums[4], e = op.nums[5], f = op.nums[6]
            }, m)
        end
    end
    return m
end

-- Resolve all shared shape fields (fill, stroke, opacity, mask/clip refs, transform)
-- from an element's attribute string plus inherited group state. Geometry
-- (pathCommands) is attached separately by each shape's parsing block.
local function resolveShapeStyle(attrStr, ctx)
    local class = getAttr(attrStr, "class")
    local fillColor, patternId = resolveFill(parseElementFill(attrStr), class, ctx.cssStyles, ctx.currentGroupFill)

    local rawStroke = parseElementStroke(attrStr)
    local strokeColor = resolveStroke(rawStroke, class, ctx.cssStrokeStyles, ctx.currentGroupStroke)
    local strokeWidth = nil
    local strokeOpacity = nil
    if strokeColor then
        strokeWidth = resolveStrokeWidth(
            parseElementStrokeWidth(attrStr), class, ctx.cssStrokeWidths, ctx.currentGroupStrokeWidth
        )
        strokeOpacity = parseElementStrokeOpacity(attrStr)
    end

    local opacity = tonumber(getAttr(attrStr, "opacity"))
    local maskId = parseUrlRef(getAttr(attrStr, "mask")) or ctx.currentMaskId
    local clipId = parseUrlRef(getAttr(attrStr, "clip-path")) or ctx.currentClipId

    local elementTransform = getAttr(attrStr, "transform")
    local elementMatrix = elementTransform and parseTransformMatrix(elementTransform) or matIdentity()
    local m = matMultiply(ctx.currentTransform or matIdentity(), elementMatrix)

    return {
        type = "path",
        fill = fillColor,
        patternId = patternId,
        opacity = opacity,
        maskId = maskId,
        clipId = clipId,
        stroke = strokeColor,
        strokeWidth = strokeWidth,
        strokeOpacity = strokeOpacity,
        svgOffset = {x = m.e, y = m.f},
        svgMatrix = {a = m.a, b = m.b, c = m.c, d = m.d, e = m.e, f = m.f}
    }
end

-- Main parsing function with group support
function SVGParser.parse(svgContent)
    -- Resolve <use href="#id"> before the single-pass parse runs (bounded to a
    -- few levels so a self/cyclic reference can't loop forever).
    if svgContent:find("<use", 1, true) then
        local idMap = buildIdMap(svgContent)
        for _ = 1, 3 do
            local expanded, changed = expandUseElements(svgContent, idMap)
            svgContent = expanded
            if not changed then break end
        end
    end

    local result = {
        viewBox = {x = 0, y = 0, width = 64, height = 64},
        elements = {},
        patterns = {},
        masks = {},
        clipPaths = {},
        gradients = {}
    }

    -- Parse CSS styles first
    local cssStyles, cssDisplay, cssStrokeStyles, cssStrokeWidths = parseCSSStyles(svgContent)

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

    -- Parse with group awareness
    local i = 1
    local groupFillStack = {}
    local currentGroupFill = nil
    local groupStrokeStack = {}
    local currentGroupStroke = nil
    local groupStrokeWidthStack = {}
    local currentGroupStrokeWidth = nil
    local maskIdStack = {}
    local currentMaskId = nil
    local clipIdStack = {}
    local currentClipId = nil
    local transformStack = {}
    local currentTransform = matIdentity()
    local defsDepth = 0
    local skipDepth = 0 -- Skip subtrees with display:none
    local currentPattern = nil
    local currentMask = nil
    local currentClipPath = nil
    local currentGradient = nil
    local patternStack = {}

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

    -- Build a "path" element from a shape's attribute string + explicit pathCommands,
    -- routing it into the pattern/mask/clipPath/root element list currently in scope.
    local function emitShape(attrStr, pathCommands)
        if skipDepth > 0 then return end
        local ctx = {
            cssStyles = cssStyles,
            cssStrokeStyles = cssStrokeStyles,
            cssStrokeWidths = cssStrokeWidths,
            currentGroupFill = currentGroupFill,
            currentGroupStroke = currentGroupStroke,
            currentGroupStrokeWidth = currentGroupStrokeWidth,
            currentMaskId = currentMaskId,
            currentClipId = currentClipId,
            currentTransform = currentTransform
        }
        local element = resolveShapeStyle(attrStr, ctx)
        element.pathCommands = pathCommands

        if currentPattern then
            table.insert(currentPattern.elements, element)
        elseif currentMask then
            table.insert(currentMask.elements, element)
        elseif currentClipPath then
            table.insert(currentClipPath.elements, element)
        elseif defsDepth == 0 then
            table.insert(result.elements, element)
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
        -- clipPath open/close
        elseif char == '<' and svgContent:sub(i + 1, i + 8) == 'clipPath' and svgContent:sub(i + 9, i + 9):match('[%s>]') then
            local tagEnd = svgContent:find('>', i)
            if tagEnd then
                local tag = svgContent:sub(i, tagEnd)
                local id = tag:match('id="([^"]*)"')
                local clipPath = { id = id, elements = {} }
                if id then
                    result.clipPaths[id] = clipPath
                end
                currentClipPath = clipPath
                i = tagEnd + 1
            else
                i = i + 1
            end
        elseif char == '<' and svgContent:sub(i, i + 10) == '</clipPath>' then
            currentClipPath = nil
            i = i + 11
        -- linearGradient / radialGradient open/close, with <stop> children
        elseif char == '<' and svgContent:sub(i + 1, i + 14) == 'linearGradient' and svgContent:sub(i + 15, i + 15):match('[%s>/]') then
            local tagEnd = svgContent:find('>', i)
            if tagEnd then
                local tag = svgContent:sub(i, tagEnd)
                local id = tag:match('id="([^"]*)"')
                local gradient = {
                    type = "linear",
                    id = id,
                    units = getAttr(tag, "gradientUnits") or "objectBoundingBox",
                    x1 = parseGradCoord(getAttr(tag, "x1") or "0%"),
                    y1 = parseGradCoord(getAttr(tag, "y1") or "0%"),
                    x2 = parseGradCoord(getAttr(tag, "x2") or "100%"),
                    y2 = parseGradCoord(getAttr(tag, "y2") or "0%"),
                    stops = {}
                }
                if id then result.gradients[id] = gradient end
                currentGradient = (svgContent:sub(tagEnd - 1, tagEnd) == '/>') and nil or gradient
                i = tagEnd + 1
            else
                i = i + 1
            end
        elseif char == '<' and svgContent:sub(i, i + 16) == '</linearGradient>' then
            currentGradient = nil
            i = i + 17
        elseif char == '<' and svgContent:sub(i + 1, i + 14) == 'radialGradient' and svgContent:sub(i + 15, i + 15):match('[%s>/]') then
            local tagEnd = svgContent:find('>', i)
            if tagEnd then
                local tag = svgContent:sub(i, tagEnd)
                local id = tag:match('id="([^"]*)"')
                local gradient = {
                    type = "radial",
                    id = id,
                    units = getAttr(tag, "gradientUnits") or "objectBoundingBox",
                    cx = parseGradCoord(getAttr(tag, "cx") or "50%"),
                    cy = parseGradCoord(getAttr(tag, "cy") or "50%"),
                    r = parseGradCoord(getAttr(tag, "r") or "50%"),
                    stops = {}
                }
                if id then result.gradients[id] = gradient end
                currentGradient = (svgContent:sub(tagEnd - 1, tagEnd) == '/>') and nil or gradient
                i = tagEnd + 1
            else
                i = i + 1
            end
        elseif char == '<' and svgContent:sub(i, i + 16) == '</radialGradient>' then
            currentGradient = nil
            i = i + 17
        elseif char == '<' and svgContent:sub(i + 1, i + 4) == 'stop' and svgContent:sub(i + 5, i + 5):match('[%s>/]') then
            local stopStr, after = findElementSpan(svgContent, i, 'stop')
            if stopStr then
                if currentGradient then
                    local colorStr = getAttr(stopStr, "stop-color") or parseStyleProp(stopStr, "stop-color") or "#000000"
                    local opacityStr = getAttr(stopStr, "stop-opacity") or parseStyleProp(stopStr, "stop-opacity") or "1"
                    table.insert(currentGradient.stops, {
                        offset = parseGradCoord(getAttr(stopStr, "offset") or "0"),
                        color = hexToRgb(colorStr),
                        opacity = tonumber(opacityStr) or 1
                    })
                end
                i = after
            else
                i = i + 1
            end
        -- Look for opening <g> tags with fill/stroke attribute, class, mask, clip-path or transform
        elseif char == '<' and svgContent:sub(i + 1, i + 1) == 'g' and svgContent:sub(i + 2, i + 2):match('[%s>]') then
            local gEnd = svgContent:find('>', i)
            if gEnd then
                local gTag = svgContent:sub(i, gEnd)
                local groupFill = parseElementFill(gTag)
                local groupStroke = parseElementStroke(gTag)
                local groupClass = getAttr(gTag, "class")
                local groupTransform = getAttr(gTag, "transform")
                local groupMaskId = parseUrlRef(getAttr(gTag, "mask"))
                local groupClipId = parseUrlRef(getAttr(gTag, "clip-path"))

                -- display:none groups and all descendants are skipped
                local groupHidden = hasDisplayNone(groupClass, cssDisplay)
                if groupHidden or skipDepth > 0 then
                    skipDepth = skipDepth + 1
                end

                -- Handle group fill
                if groupFill and not parseUrlRef(groupFill) and groupFill ~= "none" then
                    local fillColor = hexToRgb(groupFill)
                    table.insert(groupFillStack, fillColor)
                    currentGroupFill = fillColor
                elseif groupClass then
                    local fillColor = getColorFromClassAttr(groupClass, cssStyles)
                    if fillColor then
                        table.insert(groupFillStack, fillColor)
                        currentGroupFill = fillColor
                    else
                        table.insert(groupFillStack, currentGroupFill)
                    end
                else
                    table.insert(groupFillStack, currentGroupFill)
                end

                -- Handle group stroke + stroke-width inheritance
                do
                    local strokeColor = resolveStroke(groupStroke, groupClass, cssStrokeStyles, currentGroupStroke)
                    table.insert(groupStrokeStack, strokeColor)
                    currentGroupStroke = strokeColor
                    local strokeWidth = strokeColor
                        and resolveStrokeWidth(parseElementStrokeWidth(gTag), groupClass, cssStrokeWidths, currentGroupStrokeWidth)
                        or currentGroupStrokeWidth
                    table.insert(groupStrokeWidthStack, strokeWidth)
                    currentGroupStrokeWidth = strokeWidth
                end

                -- Handle group mask / clip-path inheritance (own value wins, else inherit parent's)
                table.insert(maskIdStack, currentMaskId)
                if groupMaskId then currentMaskId = groupMaskId end
                table.insert(clipIdStack, currentClipId)
                if groupClipId then currentClipId = groupClipId end

                -- Handle group transform (translate / scale / rotate / skew / matrix)
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
            if #groupStrokeStack > 0 then
                table.remove(groupStrokeStack)
                currentGroupStroke = groupStrokeStack[#groupStrokeStack]
            end
            if #groupStrokeWidthStack > 0 then
                table.remove(groupStrokeWidthStack)
                currentGroupStrokeWidth = groupStrokeWidthStack[#groupStrokeWidthStack]
            end
            if #maskIdStack > 0 then
                currentMaskId = table.remove(maskIdStack)
            end
            if #clipIdStack > 0 then
                currentClipId = table.remove(clipIdStack)
            end
            popTransform()
            i = i + 4
        -- Look for closing </svg> tags
        elseif char == '<' and svgContent:sub(i, i + 5) == '</svg>' then
            popTransform()
            i = i + 6
        -- <path>
        elseif char == '<' and svgContent:sub(i + 1, i + 4) == 'path' then
            local pathStr, after = findElementSpan(svgContent, i, 'path')
            if pathStr then
                local d = pathStr:match('d="([^"]*)"') or pathStr:match("d='([^']*)'")
                emitShape(pathStr, d and parsePathData(d) or {})
                i = after
            else
                i = i + 1
            end
        -- <rect>
        elseif char == '<' and svgContent:sub(i + 1, i + 4) == 'rect' then
            local rectStr, after = findElementSpan(svgContent, i, 'rect')
            if rectStr then
                local x = tonumber(rectStr:match('x="([^"]*)"') or rectStr:match("x='([^']*)'") or "0") or 0
                local y = tonumber(rectStr:match('y="([^"]*)"') or rectStr:match("y='([^']*)'") or "0") or 0
                local width = tonumber(rectStr:match('width="([^"]*)"') or rectStr:match("width='([^']*)'") or "0") or 0
                local height = tonumber(rectStr:match('height="([^"]*)"') or rectStr:match("height='([^']*)'") or "0") or 0
                if width > 0 and height > 0 then
                    emitShape(rectStr, rectPathCommands(x, y, width, height))
                end
                i = after
            else
                i = i + 1
            end
        -- <circle>
        elseif char == '<' and svgContent:sub(i + 1, i + 6) == 'circle' then
            local circleStr, after = findElementSpan(svgContent, i, 'circle')
            if circleStr then
                local cx = tonumber(getAttr(circleStr, "cx") or "0")
                local cy = tonumber(getAttr(circleStr, "cy") or "0")
                local r = tonumber(getAttr(circleStr, "r") or "0")
                emitShape(circleStr, circleToPathCommands(cx, cy, r))
                i = after
            else
                i = i + 1
            end
        -- <ellipse>
        elseif char == '<' and svgContent:sub(i + 1, i + 7) == 'ellipse' and svgContent:sub(i + 8, i + 8):match('[%s>/]') then
            local ellipseStr, after = findElementSpan(svgContent, i, 'ellipse')
            if ellipseStr then
                local cx = tonumber(getAttr(ellipseStr, "cx") or "0")
                local cy = tonumber(getAttr(ellipseStr, "cy") or "0")
                local rx = tonumber(getAttr(ellipseStr, "rx") or "0")
                local ry = tonumber(getAttr(ellipseStr, "ry") or "0")
                emitShape(ellipseStr, ellipseToPathCommands(cx, cy, rx, ry))
                i = after
            else
                i = i + 1
            end
        -- <line> (stroke-only, no fill area)
        elseif char == '<' and svgContent:sub(i + 1, i + 4) == 'line' and svgContent:sub(i + 5, i + 5):match('[%s>/]') then
            local lineStr, after = findElementSpan(svgContent, i, 'line')
            if lineStr then
                local x1 = tonumber(getAttr(lineStr, "x1") or "0") or 0
                local y1 = tonumber(getAttr(lineStr, "y1") or "0") or 0
                local x2 = tonumber(getAttr(lineStr, "x2") or "0") or 0
                local y2 = tonumber(getAttr(lineStr, "y2") or "0") or 0
                emitShape(lineStr, pointsToPathCommands({{x = x1, y = y1}, {x = x2, y = y2}}, false))
                i = after
            else
                i = i + 1
            end
        -- <polygon> (implicitly closed for both fill and stroke)
        elseif char == '<' and svgContent:sub(i + 1, i + 7) == 'polygon' and svgContent:sub(i + 8, i + 8):match('[%s>/]') then
            local polyStr, after = findElementSpan(svgContent, i, 'polygon')
            if polyStr then
                local pts = parsePointsAttr(getAttr(polyStr, "points"))
                emitShape(polyStr, pointsToPathCommands(pts, true))
                i = after
            else
                i = i + 1
            end
        -- <polyline> (closed for fill per spec, open for stroke)
        elseif char == '<' and svgContent:sub(i + 1, i + 8) == 'polyline' and svgContent:sub(i + 9, i + 9):match('[%s>/]') then
            local polyStr, after = findElementSpan(svgContent, i, 'polyline')
            if polyStr then
                local pts = parsePointsAttr(getAttr(polyStr, "points"))
                emitShape(polyStr, pointsToPathCommands(pts, false))
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
