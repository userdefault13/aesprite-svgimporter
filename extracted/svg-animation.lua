-- SVG animation detection and frame building for Aseprite import
-- Supports pose/state groups (Aavegotchi-style) and SMIL sampling:
-- <animateTransform> (translate/scale/rotate), <animate>/<animateColor>
-- (arbitrary attribute keyframing, e.g. fill/opacity), and <animateMotion>
-- (straight-line M/L paths), with multiple simultaneous animators each
-- targeting their own element (nesting parent, or xlink:href/href by id).

local SVGAnimation = {}

local function getAttr(tag, name)
    local escaped = name:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
    return tag:match(escaped .. '="([^"]*)"') or tag:match(escaped .. "='([^']*)'")
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
    elseif animType == "skewX" or animType == "skewY" then
        local angle = value:match("^([%-%d%.]+)$")
        if angle then
            return string.format("%s(%s)", animType, angle)
        end
    end
    return nil
end

-- Strip every animate-like tag from a snapshot's markup (used by pose-group
-- frames, which take a whole subtree verbatim and shouldn't replay SMIL too).
local function stripSmilTags(markup)
    return markup
        :gsub("<animateTransform[^>]*/%s*>", "")
        :gsub("<animateTransform[^>]*>.-</animateTransform>", "")
        :gsub("<animateMotion[^>]*/%s*>", "")
        :gsub("<animateMotion[^>]*>.-</animateMotion>", "")
        :gsub("<animateColor[^>]*/%s*>", "")
        :gsub("<animateColor[^>]*>.-</animateColor>", "")
        :gsub("<animate[^>]*/%s*>", "")
        :gsub("<animate[^>]*>.-</animate>", "")
        :gsub("<set[^>]*/%s*>", "")
        :gsub("<set[^>]*>.-</set>", "")
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

-- ============================================================================
-- SMIL: multiple simultaneous animators, each targeting its own element.
-- ============================================================================

-- '>' terminator that isn't inside a quoted attribute value.
local function findTagEnd(content, ltStart)
    local i = ltStart + 1
    local inQuote = nil
    while i <= #content do
        local c = content:sub(i, i)
        if inQuote then
            if c == inQuote then inQuote = nil end
        elseif c == '"' or c == "'" then
            inQuote = c
        elseif c == '>' then
            return i
        end
        i = i + 1
    end
    return nil
end

local function setAttrOnTag(tagRaw, name, value)
    local escaped = name:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
    if tagRaw:match(escaped .. '="') then
        return (tagRaw:gsub(escaped .. '="[^"]*"', name .. '="' .. value .. '"', 1))
    elseif tagRaw:match(escaped .. "='") then
        return (tagRaw:gsub(escaped .. "='[^']*'", name .. "='" .. value .. "'", 1))
    elseif tagRaw:sub(-2) == "/>" then
        return tagRaw:sub(1, -3) .. ' ' .. name .. '="' .. value .. '"/>'
    else
        return tagRaw:sub(1, -2) .. ' ' .. name .. '="' .. value .. '">'
    end
end

-- Flatten a motion path's M/L commands into evenly (by arc length) sampled
-- "x,y" points. Curves aren't supported: SMIL motion paths in the wild are
-- overwhelmingly straight-segment nudges, and full arc-length-correct cubic
-- sampling isn't worth the complexity for that case.
local function sampleMotionPath(pathStr, sampleCount)
    local points = {}
    local cx, cy = 0, 0
    for cmd, argStr in pathStr:gmatch("([MLml])([^MLmlZz]*)") do
        local nums = {}
        for n in argStr:gmatch("[%-%d%.]+") do table.insert(nums, tonumber(n)) end
        for k = 1, #nums - 1, 2 do
            if cmd == "m" or cmd == "l" then
                cx, cy = cx + nums[k], cy + nums[k + 1]
            else
                cx, cy = nums[k], nums[k + 1]
            end
            table.insert(points, { x = cx, y = cy })
        end
    end
    if #points < 2 then return {} end

    local segLen, total = {}, 0
    for i = 1, #points - 1 do
        local dx, dy = points[i + 1].x - points[i].x, points[i + 1].y - points[i].y
        local len = math.sqrt(dx * dx + dy * dy)
        segLen[i] = len
        total = total + len
    end
    if total <= 0 then return {} end

    local samples = {}
    for s = 0, sampleCount - 1 do
        local target = total * (s / math.max(1, sampleCount - 1))
        local acc, seg = 0, 1
        while seg < #points and acc + segLen[seg] < target do
            acc = acc + segLen[seg]
            seg = seg + 1
        end
        local segT = segLen[seg] > 0 and ((target - acc) / segLen[seg]) or 0
        local x = points[seg].x + (points[seg + 1].x - points[seg].x) * segT
        local y = points[seg].y + (points[seg + 1].y - points[seg].y) * segT
        table.insert(samples, string.format("%.3f,%.3f", x, y))
    end
    return samples
end

-- Single left-to-right pass: track the open-element stack so every
-- <animate*> tag can be paired with its nesting-parent element, plus an
-- id -> opening-tag map for xlink:href/href-targeted animators.
local function collectAnimators(content)
    local animators = {}
    local stripSpans = {}
    local idTagMap = {}
    local stack = {}

    local i, n = 1, #content
    while i <= n do
        local lt = content:find("<", i)
        if not lt then break end
        local c2 = content:sub(lt + 1, lt + 1)

        if c2 == "!" then
            if content:sub(lt, lt + 3) == "<!--" then
                local e = content:find("-->", lt, true)
                i = e and (e + 3) or (n + 1)
            else
                local e = content:find(">", lt)
                i = e and (e + 1) or (n + 1)
            end
        elseif c2 == "?" then
            local e = content:find("?>", lt, true)
            i = e and (e + 2) or (n + 1)
        elseif c2 == "/" then
            local e = content:find(">", lt)
            if not e then break end
            if #stack > 0 then table.remove(stack) end
            i = e + 1
        else
            local nameEnd = content:find("[%s/>]", lt + 1)
            if not nameEnd then break end
            local tagName = content:sub(lt + 1, nameEnd - 1)
            local tagEnd = findTagEnd(content, lt)
            if not tagEnd then break end
            local selfClosing = content:sub(tagEnd - 1, tagEnd) == "/>"
            local rawTag = content:sub(lt, tagEnd)
            local id = rawTag:match('id="([^"]*)"') or rawTag:match("id='([^']*)'")

            if tagName == "animate" or tagName == "animateTransform"
                or tagName == "animateMotion" or tagName == "animateColor" then
                local entry = {
                    kind = tagName,
                    raw = rawTag,
                    parent = stack[#stack]
                }
                table.insert(animators, entry)

                local span = { start = lt, stop = tagEnd + 1 }
                if not selfClosing then
                    local closeTag = "</" .. tagName .. ">"
                    local closePos = content:find(closeTag, tagEnd + 1, true)
                    if closePos then
                        span.stop = closePos + #closeTag
                    end
                end
                table.insert(stripSpans, span)
                i = span.stop
            else
                if id and id ~= "" then
                    idTagMap[id] = { start = lt, stop = tagEnd }
                end
                if selfClosing then
                    i = tagEnd + 1
                else
                    table.insert(stack, { start = lt, stop = tagEnd, name = tagName })
                    i = tagEnd + 1
                end
            end
        end
    end

    return animators, stripSpans, idTagMap
end

local function lerp(a, b, t) return a + (b - a) * t end

-- "10,0" / "10 0" / "10" -> {10, 0} / {10}. Positional, not semantic: works
-- for translate/scale/rotate/skew args and "x,y" motion points alike since
-- they're all just interpolated component-wise.
local function parseNumericList(str)
    local nums = {}
    if not str then return nil end
    for n in str:gmatch("[%-%d%.]+") do
        local v = tonumber(n)
        if not v then return nil end
        table.insert(nums, v)
    end
    if #nums == 0 then return nil end
    return nums
end

local function lerpValueString(v1, v2, t)
    local n1, n2 = parseNumericList(v1), parseNumericList(v2)
    if n1 and n2 and #n1 == #n2 and #n1 > 0 then
        local parts = {}
        for i = 1, #n1 do parts[i] = tostring(lerp(n1[i], n2[i], t)) end
        return table.concat(parts, ",")
    end
    -- Shapes don't match (or non-numeric): step at the segment midpoint
    -- rather than interpolate, matching SMIL's calcMode="discrete" fallback.
    return t < 0.5 and v1 or v2
end

local function parseColor(str)
    if not str then return nil end
    local hex = str:match("^#(%x%x%x%x%x%x)$")
    if hex then
        return { tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16) }
    end
    local hex3 = str:match("^#(%x)(%x)(%x)$")
    if hex3 then
        local r, g, b = str:match("^#(%x)(%x)(%x)$")
        return {
            tonumber(r .. r, 16), tonumber(g .. g, 16), tonumber(b .. b, 16)
        }
    end
    return nil
end

local function lerpColor(a, b, t)
    return string.format(
        "#%02x%02x%02x",
        math.floor(lerp(a[1], b[1], t) + 0.5),
        math.floor(lerp(a[2], b[2], t) + 0.5),
        math.floor(lerp(a[3], b[3], t) + 0.5)
    )
end

local function parseKeyTimes(str, expectedCount)
    if not str then return nil end
    local times = {}
    for v in str:gmatch("[^;]+") do
        table.insert(times, tonumber(trim(v)))
    end
    if #times ~= expectedCount then return nil end
    return times
end

-- Maps a 0..1 fraction of an animator's own duration to the pair of
-- keyframe values straddling it, plus how far between them (0..1).
local function sampleSegment(values, keyTimes, frac)
    local n = #values
    if n == 1 then return values[1], values[1], 0 end
    local times = keyTimes
    if not times then
        times = {}
        for i = 1, n do times[i] = (i - 1) / (n - 1) end
    end
    if frac <= times[1] then return values[1], values[1], 0 end
    if frac >= times[n] then return values[n], values[n], 0 end
    for i = 1, n - 1 do
        if frac >= times[i] and frac <= times[i + 1] then
            local span = times[i + 1] - times[i]
            local localFrac = span > 0 and ((frac - times[i]) / span) or 0
            return values[i], values[i + 1], localFrac
        end
    end
    return values[n], values[n], 0
end

-- Resolve one animator into a sampler: { target = {start,stop}, dur = number,
-- apply = function(tagRaw, t01) -> tagRaw }, where t01 is 0..1 progress
-- through this animator's own duration (the caller derives it from global
-- time, looping shorter animators via modulo).
local function resolveAnimator(entry, idTagMap)
    local raw = entry.raw
    local href = getAttr(raw, "xlink:href") or getAttr(raw, "href")
    local target = entry.parent
    if href then
        local refId = href:match("#(.+)")
        target = (refId and idTagMap[refId]) or target
    end
    if not target then return nil end

    local dur = parseDuration(getAttr(raw, "dur") or "1s")

    local function valuesFromAttrs()
        local values = splitSemicolonValues(getAttr(raw, "values"))
        if #values == 0 then
            local fromV, toV = getAttr(raw, "from"), getAttr(raw, "to")
            if fromV then table.insert(values, fromV) end
            if toV then table.insert(values, toV) end
        end
        return values
    end

    if entry.kind == "animateTransform" then
        local animType = getAttr(raw, "type") or "translate"
        local values = valuesFromAttrs()
        if #values < 2 then return nil end
        local keyTimes = parseKeyTimes(getAttr(raw, "keyTimes"), #values)
        return {
            target = target,
            dur = dur,
            apply = function(tagRaw, t01)
                local v1, v2, f = sampleSegment(values, keyTimes, t01)
                local addition = smilValueToTransform(animType, lerpValueString(v1, v2, f))
                if not addition then return tagRaw end
                local existing = getAttr(tagRaw, "transform")
                return setAttrOnTag(tagRaw, "transform", mergeTransform(existing, addition))
            end
        }
    elseif entry.kind == "animateMotion" then
        local values = valuesFromAttrs()
        if #values == 0 then
            local pathAttr = getAttr(raw, "path")
            if pathAttr then
                -- Resolution of the path's own shape, independent of output
                -- frame count: interpolation below fills in between samples.
                values = sampleMotionPath(pathAttr, 60)
            end
        end
        if #values < 2 then return nil end
        local keyTimes = parseKeyTimes(getAttr(raw, "keyTimes"), #values)
        return {
            target = target,
            dur = dur,
            apply = function(tagRaw, t01)
                local v1, v2, f = sampleSegment(values, keyTimes, t01)
                local addition = smilValueToTransform("translate", lerpValueString(v1, v2, f))
                if not addition then return tagRaw end
                local existing = getAttr(tagRaw, "transform")
                return setAttrOnTag(tagRaw, "transform", mergeTransform(existing, addition))
            end
        }
    else -- "animate" or "animateColor": arbitrary attribute keyframing
        local attributeName = getAttr(raw, "attributeName")
        if not attributeName or attributeName == "" then return nil end
        local values = valuesFromAttrs()
        if #values < 2 then return nil end
        local keyTimes = parseKeyTimes(getAttr(raw, "keyTimes"), #values)
        return {
            target = target,
            dur = dur,
            apply = function(tagRaw, t01)
                local v1, v2, f = sampleSegment(values, keyTimes, t01)
                local c1, c2 = parseColor(v1), parseColor(v2)
                local outValue
                if c1 and c2 then
                    outValue = lerpColor(c1, c2, f)
                else
                    outValue = lerpValueString(v1, v2, f)
                end
                return setAttrOnTag(tagRaw, attributeName, outValue)
            end
        }
    end
end

local function applyEdits(content, edits)
    table.sort(edits, function(a, b) return a.start < b.start end)
    local out = {}
    local pos = 1
    for _, e in ipairs(edits) do
        if e.start >= pos then
            table.insert(out, content:sub(pos, e.start - 1))
            table.insert(out, e.replacement)
            pos = e.stop
        end
    end
    table.insert(out, content:sub(pos))
    return table.concat(out)
end

function SVGAnimation.detectSmil(svgContent, fps)
    fps = fps or 8
    if not svgContent:find("<animate", 1, true) then
        return { type = "none", frames = {} }
    end

    local rawAnimators, stripSpans, idTagMap = collectAnimators(svgContent)
    local samplers = {}
    for _, entry in ipairs(rawAnimators) do
        local sampler = resolveAnimator(entry, idTagMap)
        if sampler then table.insert(samplers, sampler) end
    end
    if #samplers == 0 then
        return { type = "none", frames = {} }
    end

    -- One shared timeline spans the longest animator's duration; shorter
    -- animators loop within it (t01 wraps via modulo), so e.g. a fast eye
    -- blink and a slow body bob can run at their own natural cadence.
    local maxDur = 0
    for _, s in ipairs(samplers) do
        maxDur = math.max(maxDur, s.dur)
    end
    local frameCount = math.min(math.max(math.ceil(maxDur * fps), 2), 120)

    local frames = {}
    for frameIndex = 1, frameCount do
        local globalTime = (frameCount > 1) and ((frameIndex - 1) / (frameCount - 1)) * maxDur or 0

        -- Accumulate every sampler's edit for this frame per target tag, so
        -- multiple animators on the same element (e.g. transform + opacity)
        -- compose into one modified tag instead of clobbering each other.
        local tagEdits = {}
        for _, s in ipairs(samplers) do
            local t01 = 0
            if s.dur > 0 then
                -- Wrap shorter animators via modulo, but an exact multiple of
                -- their duration (notably the final frame, when this is the
                -- longest animator) must land on 1 (end value), not wrap to 0.
                local raw = globalTime / s.dur
                t01 = raw % 1
                if t01 == 0 and raw > 0 then t01 = 1 end
            end
            local key = s.target.start
            local current = tagEdits[key] or {
                start = s.target.start,
                stop = s.target.stop,
                raw = svgContent:sub(s.target.start, s.target.stop)
            }
            current.raw = s.apply(current.raw, t01)
            tagEdits[key] = current
        end

        local edits = {}
        for _, e in pairs(tagEdits) do
            table.insert(edits, { start = e.start, stop = e.stop, replacement = e.raw })
        end
        for _, span in ipairs(stripSpans) do
            table.insert(edits, { start = span.start, stop = span.stop, replacement = "" })
        end

        table.insert(frames, {
            name = string.format("t%d", frameIndex),
            svg = applyEdits(svgContent, edits)
        })
    end

    return {
        type = "smil",
        frames = frames,
        fps = fps,
        duration = maxDur
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
