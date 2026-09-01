-- SVG animation detection and frame building for Aseprite import
-- Supports pose/state groups (Aavegotchi-style) and basic SMIL sampling

local SVGAnimation = {}

local function getAttr(tag, name)
    return tag:match(name .. '="([^"]*)"') or tag:match(name .. "='([^']*)'")
end

local function trim(value)
    if not value then return nil end
    return value:match("^%s*(.-)%s*$")
end

local function parseDuration(dur)
    if not dur or dur == "" then return 1 end
    local n, unit = dur:match("^([%-%d%.]+)(%a*)$")
    n = tonumber(n) or 1
    if unit == "ms" then return math.max(0.001, n / 1000) end
    return math.max(0.001, n)
end

local function splitSemicolonValues(valuesStr)
    local values = {}
    if not valuesStr then return values end
    for v in valuesStr:gmatch("[^;]+") do
        local trimmed = trim(v)
        if trimmed and trimmed ~= "" then
            table.insert(values, trimmed)
        end
    end
    return values
end

local function findGroupEnd(content, start)
    if content:sub(start, start + 1) ~= "<g" then
        return nil
    end
    local tagEnd = content:find(">", start)
    if not tagEnd then return nil end

    local depth = 1
    local pos = tagEnd + 1
    while pos <= #content and depth > 0 do
        local nextOpen = content:find("<g", pos, true)
        local nextClose = content:find("</g>", pos, true)
        if not nextClose then return nil end

        if nextOpen and nextOpen < nextClose then
            depth = depth + 1
            local openEnd = content:find(">", nextOpen)
            if not openEnd then return nil end
            pos = openEnd + 1
        else
            depth = depth - 1
            pos = nextClose + 4
        end
    end

    return pos
end

local function skipBlock(content, i, tagName)
    local openStart = content:find("<" .. tagName, i, true)
    if not openStart or openStart ~= i then
        return nil
    end
    local closeTag = "</" .. tagName .. ">"
    local closePos = content:find(closeTag, i, true)
    if not closePos then return nil end
    return closePos + #closeTag
end

local function extractSharedParts(svgContent)
    local styles = {}
    for block in svgContent:gmatch("(<style[^>]*>.-</style>)") do
        table.insert(styles, block)
    end

    local defs = {}
    for block in svgContent:gmatch("(<defs[^>]*>.-</defs>)") do
        table.insert(defs, block)
    end

    return {
        viewBox = svgContent:match('viewBox="([^"]*)"') or svgContent:match("viewBox='([^']*)'") or "0 0 64 64",
        width = svgContent:match('width="([^"]*)"') or svgContent:match("width='([^']*)'"),
        height = svgContent:match('height="([^"]*)"') or svgContent:match("height='([^']*)'"),
        styles = table.concat(styles),
        defs = table.concat(defs)
    }
end

local function getSvgBody(svgContent)
    local rootOpen = svgContent:find("<svg")
    if not rootOpen then
        return svgContent, extractSharedParts('<svg viewBox="0 0 64 64"></svg>')
    end

    local rootEnd = svgContent:find(">", rootOpen)
    local rootClose = svgContent:find("</svg>", rootEnd or rootOpen)
    if not rootEnd or not rootClose then
        return svgContent, extractSharedParts(svgContent)
    end

    return svgContent:sub(rootEnd + 1, rootClose - 1), extractSharedParts(svgContent)
end

local function wrapSvg(parts, body)
    local widthAttr = parts.width and (' width="' .. parts.width .. '"') or ""
    local heightAttr = parts.height and (' height="' .. parts.height .. '"') or ""
    return string.format(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="%s"%s%s>%s%s%s</svg>',
        parts.viewBox,
        widthAttr,
        heightAttr,
        parts.styles or "",
        parts.defs or "",
        body
    )
end

local function frameNameFromTag(gTag, index)
    local className = getAttr(gTag, "class")
    if className and className ~= "" then
        return className:match("%S+") or ("frame" .. index)
    end
    local id = getAttr(gTag, "id")
    if id and id ~= "" then
        return id
    end
    return "frame" .. index
end

local function mergeTransform(existing, addition)
    if not addition or addition == "" then
        return existing
    end
    if not existing or existing == "" then
        return addition
    end
    return existing .. " " .. addition
end

local function smilValueToTransform(animType, value)
    if animType == "translate" then
        local x, y = value:match("^([%-%d%.]+)[,%s]+([%-%d%.]+)$")
        if x then
            return string.format("translate(%s,%s)", x, y or 0)
        end
        x = value:match("^([%-%d%.]+)$")
        if x then
            return string.format("translate(%s,0)", x)
        end
    elseif animType == "scale" then
        local sx, sy = value:match("^([%-%d%.]+)[,%s]+([%-%d%.]+)$")
        if sx then
            return string.format("scale(%s,%s)", sx, sy or sx)
        end
        sx = value:match("^([%-%d%.]+)$")
        if sx then
            return string.format("scale(%s,%s)", sx, sx)
        end
    elseif animType == "rotate" then
        local angle, cx, cy = value:match("^([%-%d%.]+)[,%s]+([%-%d%.]+)[,%s]+([%-%d%.]+)$")
        if angle and cx then
            return string.format("rotate(%s,%s,%s)", angle, cx, cy)
        end
        angle = value:match("^([%-%d%.]+)$")
        if angle then
            return string.format("rotate(%s)", angle)
        end
    end
    return nil
end

local function stripSmilTags(markup)
    return markup
        :gsub("<animateTransform[^>]*/%s*>", "")
        :gsub("<animateTransform[^>]*>.-</animateTransform>", "")
        :gsub("<animate[^>]*/%s*>", "")
        :gsub("<animate[^>]*>.-</animate>", "")
end

local function applyTransformToGroup(groupMarkup, transformAddition)
    if not transformAddition then
        return stripSmilTags(groupMarkup)
    end

    local gTagEnd = groupMarkup:find(">")
    if not gTagEnd then
        return stripSmilTags(groupMarkup)
    end

    local gTag = groupMarkup:sub(1, gTagEnd)
    local rest = groupMarkup:sub(gTagEnd + 1)
    local existing = getAttr(gTag, "transform")
    local merged = mergeTransform(existing, transformAddition)

    local newTag
    if gTag:match('transform="') then
        newTag = gTag:gsub('transform="[^"]*"', 'transform="' .. merged .. '"', 1)
    elseif gTag:match("transform='") then
        newTag = gTag:gsub("transform='[^']*'", "transform='" .. merged .. "'", 1)
    else
        newTag = gTag:sub(1, -2) .. ' transform="' .. merged .. '">'
    end

    return stripSmilTags(newTag .. rest)
end

function SVGAnimation.detectPoseGroups(svgContent)
    local body, parts = getSvgBody(svgContent)
    local frames = {}
    local i = 1

    while i <= #body do
        local ws = body:find("[^%s]", i)
        if not ws then break end
        i = ws

        if body:sub(i, i + 3) == "<!--" then
            local commentEnd = body:find("-->", i, true)
            if not commentEnd then break end
            i = commentEnd + 3
        elseif body:sub(i, i + 5) == "<style" then
            local after = skipBlock(body, i, "style")
            if not after then return { type = "none", frames = {} } end
            i = after
        elseif body:sub(i, i + 4) == "<defs" then
            local after = skipBlock(body, i, "defs")
            if not after then return { type = "none", frames = {} } end
            i = after
        elseif body:sub(i, i + 1) == "<g" and body:sub(i + 2, i + 2):match("[%s>/]") then
            local groupEnd = findGroupEnd(body, i)
            if not groupEnd then return { type = "none", frames = {} } end

            local groupMarkup = body:sub(i, groupEnd - 1)
            local gTagEnd = groupMarkup:find(">")
            local gTag = groupMarkup:sub(1, gTagEnd)
            table.insert(frames, {
                name = frameNameFromTag(gTag, #frames + 1),
                svg = wrapSvg(parts, stripSmilTags(groupMarkup))
            })
            i = groupEnd
        else
            return { type = "none", frames = {} }
        end
    end

    if #frames < 2 then
        return { type = "none", frames = {} }
    end

    return {
        type = "poses",
        frames = frames,
        fps = nil
    }
end

function SVGAnimation.detectSmil(svgContent, fps)
    fps = fps or 8
    local animTag = svgContent:match("(<animateTransform%s[^>]+>)")
        or svgContent:match("(<animateTransform%s.-</animateTransform>)")
    if not animTag then
        return { type = "none", frames = {} }
    end

    local values = splitSemicolonValues(getAttr(animTag, "values") or getAttr(animTag, "from"))
    if #values == 0 then
        local fromValue = getAttr(animTag, "from")
        local toValue = getAttr(animTag, "to")
        if fromValue then table.insert(values, fromValue) end
        if toValue then table.insert(values, toValue) end
    end
    if #values < 2 then
        return { type = "none", frames = {} }
    end

    local dur = parseDuration(getAttr(animTag, "dur") or "1s")
    local animType = getAttr(animTag, "type") or "translate"
    local frameCount = math.max(#values, math.ceil(dur * fps))
    frameCount = math.min(frameCount, 120)

    local animPos = svgContent:find("<animateTransform", 1, true)
    if not animPos then
        return { type = "none", frames = {} }
    end

    local groupStart = 1
    local searchPos = 1
    while searchPos < animPos do
        local found = svgContent:find("<g", searchPos, true)
        if not found or found >= animPos then
            break
        end
        groupStart = found
        searchPos = found + 2
    end

    local groupEnd = findGroupEnd(svgContent, groupStart)
    if not groupEnd then
        return { type = "none", frames = {} }
    end

    local _, parts = getSvgBody(svgContent)

    local groupMarkup = svgContent:sub(groupStart, groupEnd - 1)
    local frames = {}
    for frameIndex = 1, frameCount do
        local valueIndex = ((frameIndex - 1) % #values) + 1
        local transformAddition = smilValueToTransform(animType, values[valueIndex])
        local frameBody = applyTransformToGroup(groupMarkup, transformAddition)
        table.insert(frames, {
            name = string.format("t%d", frameIndex),
            svg = wrapSvg(parts, frameBody)
        })
    end

    return {
        type = "smil",
        frames = frames,
        fps = fps,
        duration = dur
    }
end

function SVGAnimation.detect(svgContent, fps)
    local smil = SVGAnimation.detectSmil(svgContent, fps)
    if smil.frames and #smil.frames >= 2 then
        return smil
    end

    local poses = SVGAnimation.detectPoseGroups(svgContent)
    if poses.frames and #poses.frames >= 2 then
        return poses
    end

    return { type = "none", frames = {} }
end

function SVGAnimation.frameCount(svgContent, fps)
    local info = SVGAnimation.detect(svgContent, fps)
    return #info.frames
end

return SVGAnimation
