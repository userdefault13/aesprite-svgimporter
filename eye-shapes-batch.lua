-- Generalized Eye Shapes Batch Converter
-- Usage examples:
--  - In Aseprite: File → Scripts → Run → select this file (optionally pass --script-param collateral=amDAI via CLI)
--  - CLI: aseprite -b --script eye-shapes-batch.lua --script-param collateral=amDAI

local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")

-- Read param
local params = app and app.params or {}
local collateralName = "amUSDC"
if type(params) == "table" then
    if params.collateral and params.collateral ~= "" then
        collateralName = params.collateral
    else
        -- Some Aseprite builds pass params as a list of strings
        for _, v in pairs(params) do
            if type(v) == "string" then
                local name = v:match("^collateral=(.+)$")
                if name and name ~= "" then
                    collateralName = name
                    break
                end
            end
        end
    end
end

-- Skip existing outputs? default true; accepts aliases: skipExisting / skip
local skipExisting = true
do
    if type(params) == "table" then
        local raw = params.skipExisting or params.skip
        if raw ~= nil then
            local s = tostring(raw):lower()
            if s == "false" or s == "0" or s == "no" then
                skipExisting = false
            end
        end
    end
end

-- Roots
local eyeShapesRoot = "examples/eye_shapes"
local outputRoot = "output/" .. collateralName .. "/eye shape"

-- Rarity colors (hex without '#')
local rarityColors = {
    mythical_low  = "FF00FF",
    rare_low      = "0064FF",
    uncommon_low  = "5D24BF",
    uncommon_high = "36818E",
    rare_high     = "EA8C27",
    mythical_high = "51FFA8",
}

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a"); f:close(); return s
end

local function ensureDir(dir)
    if app and app.fs and app.fs.isDirectory then
        if not app.fs.isDirectory(dir) then
            local parts = {}
            for part in dir:gmatch("[^/]+") do table.insert(parts, part) end
            local acc = ""
            for i, p in ipairs(parts) do
                acc = (i == 1) and p or (acc .. "/" .. p)
                if not app.fs.isDirectory(acc) then pcall(function() app.fs.mkdir(acc) end) end
            end
        end
    else
        os.execute('mkdir -p "' .. dir .. '"')
    end
end

local function fileExists(path)
    if app and app.fs and app.fs.isFile then
        return app.fs.isFile(path)
    end
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

-- Lightweight lookup across both haunt JSONs
local function loadCollateralPrimaryHex(nameWanted)
    local files = {"aavegotchi_db_collaterals_haunt1.json", "aavegotchi_db_collaterals_haunt2.json"}
    for _, jsonPath in ipairs(files) do
        local raw = readFile(jsonPath)
        if raw then
            local pos = 1
            while true do
                local ns, ne, nval = raw:find('"name"%s*:%s*"([^"]+)"', pos)
                if not ns then break end
                pos = ne + 1
                if nval == nameWanted then
                    -- Extract the exact JSON object boundaries around this name field
                    local startIdx = ns
                    local braceDepth = 0
                    -- Walk backwards to find the opening brace for the object
                    for i = ns, 1, -1 do
                        local ch = raw:sub(i, i)
                        if ch == '}' then
                            braceDepth = braceDepth + 1
                        elseif ch == '{' then
                            if braceDepth == 0 then
                                startIdx = i
                                break
                            else
                                braceDepth = braceDepth - 1
                            end
                        end
                    end

                    -- Walk forwards to find the closing brace for the object
                    local endIdx = ne
                    braceDepth = 0
                    for i = startIdx, #raw do
                        local ch = raw:sub(i, i)
                        if ch == '{' then
                            braceDepth = braceDepth + 1
                        elseif ch == '}' then
                            braceDepth = braceDepth - 1
                            if braceDepth == 0 then
                                endIdx = i
                                break
                            end
                        end
                    end

                    local chunk = raw:sub(startIdx, endIdx)
                    local _, _, hex = chunk:find('"primaryColor"%s*:%s*"0x([0-9a-fA-F]+)"')
                    if hex then return hex:lower() end
                end
            end
        end
    end
    -- Known fallbacks
    local known = {
        amAAVE = "b6509e", maAAVE = "b6509e",
        amUSDC = "2664ba", maUSDC = "2664ba",
        amUSDT = "26a17b", maUSDT = "26a17b",
        amDAI  = "ff7d00", maDAI  = "ff7d00",
        amWETH = "000000", maWETH = "000000",
        amWMATIC = "824ee2", maWMATIC = "824ee2",
    }
    if known[nameWanted] then
        print("INFO: Using known fallback for " .. nameWanted .. " (#" .. known[nameWanted] .. ")")
        return known[nameWanted]
    end
    print("WARN: Collateral " .. nameWanted .. " not found; defaulting to #ff7d00")
    return "ff7d00"
end

local function listEntries(cmd)
    local p = io.popen(cmd)
    if not p then return {} end
    local out = p:read("*a") or ""; p:close()
    local items = {}; for line in out:gmatch("[^\n]+") do table.insert(items, line) end
    return items
end

local function listSetFolders()
    local sets = {}
    for _, pattern in ipairs({eyeShapesRoot .. "/haunt1_*", eyeShapesRoot .. "/haunt2_*"}) do
        local dirs = listEntries('bash -lc "ls -d ' .. pattern .. ' 2>/dev/null || true"')
        for _, d in ipairs(dirs) do table.insert(sets, d) end
    end
    return sets
end

local function existingViewsForSet(setDir)
    local views = {}
    local files = listEntries('bash -lc "ls -1 \'' .. setDir .. '\'/*.svg 2>/dev/null || true"')
    for _, f in ipairs(files) do
        if f:match("_front%.svg$") or f:match("_left%.svg$") or f:match("_right%.svg$") then
            table.insert(views, f)
        end
    end
    table.sort(views)
    return views
end

local function applyColors(svgContent, eyeHex, primaryHex)
    local stripped = svgContent:gsub("<style>.-</style>", "")
    local style = '<style>.gotchi-eyeColor{fill:#' .. eyeHex .. '}.gotchi-primary{fill:#' .. primaryHex .. '}</style>'
    local injected = stripped:gsub("(<svg[^>]*>)", "%1" .. style, 1)
    if injected == stripped then injected = style .. stripped end
    return injected
end

-- Replace <rect .../> with equivalent <path .../> (supports rotate transforms)
local function rectsToPaths(svg)
    local out = svg
    local function convertOne(rectStr)
        -- Extract fill/class to keep attributes if needed (we rely on style, so omit)
        local x = tonumber(rectStr:match('x="([-%d%.]+)"') or '0') or 0
        local y = tonumber(rectStr:match('y="([-%d%.]+)"') or '0') or 0
        local w = tonumber(rectStr:match('width="([-%d%.]+)"') or '0') or 0
        local h = tonumber(rectStr:match('height="([-%d%.]+)"') or '0') or 0
        -- rotation
        local tStr = rectStr:match('transform="([^"]*)"')
        local angle, cx, cy
        if tStr then
            local a1, c1, c2 = tStr:match('rotate%(([-%d%.]+)%s+([-%d%.]+)%s+([-%d%.]+)%)')
            if a1 and c1 and c2 then
                angle = tonumber(a1) or 0
                cx = tonumber(c1) or (x + w/2)
                cy = tonumber(c2) or (y + h/2)
            else
                local aOnly = tStr:match('rotate%(([-%d%.]+)%)')
                if aOnly then
                    angle = tonumber(aOnly) or 0
                    cx = x + w/2
                    cy = y + h/2
                end
            end
        end
        local function rot(px, py)
            if not angle then return px, py end
            local rad = angle * math.pi / 180
            local cosA, sinA = math.cos(rad), math.sin(rad)
            local dx, dy = px - cx, py - cy
            local rx = cx + dx * cosA - dy * sinA
            local ry = cy + dx * sinA + dy * cosA
            return rx, ry
        end
        local x1, y1 = rot(x, y)
        local x2, y2 = rot(x + w, y)
        local x3, y3 = rot(x + w, y + h)
        local x4, y4 = rot(x, y + h)
        local d = string.format("M %g %g L %g %g L %g %g L %g %g Z", x1, y1, x2, y2, x3, y3, x4, y4)
        return '<path d="' .. d .. '"/>'
    end
    -- Replace all rects
    out = out:gsub("<rect%s-[^>]-/>", convertOne)
    return out
end

local function ensureWrappedSVG(svgContent)
    if not svgContent then return nil end
    if svgContent:find("<svg") and svgContent:find('viewBox="') then return svgContent end
    local cleaned = svgContent:gsub("<%?xml.-%?>", "")
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">' .. cleaned .. '</svg>'
end

local function convertVariant(inputPath, variantKey, eyeHex, primaryHex, outputDir)
    -- Compute output path early to short-circuit if skipping
    local base = inputPath:gsub("\\", "/"):match("([^/]+)%.svg$") or "eye_shape"
    local out = outputDir .. "/" .. base .. "_" .. variantKey .. ".aseprite"
    if skipExisting and fileExists(out) then
        print("Skip existing: " .. out)
        return true
    end
    local raw = readFile(inputPath); if not raw then print("ERROR: read " .. inputPath); return false end
    local wrapped = ensureWrappedSVG(raw)
    -- Normalize rectangles into paths so the parser can handle them
    wrapped = rectsToPaths(wrapped)
    wrapped = applyColors(wrapped, eyeHex, primaryHex)

    local svgData = SVGParser.parse(wrapped)
    if not svgData or not svgData.viewBox then print("ERROR: parse " .. inputPath .. " (" .. variantKey .. ")"); return false end
    local render = SVGRenderer.render(svgData, 64, 64)
    if not render or not render.pixels or #render.pixels == 0 then print("ERROR: 0 pixels " .. inputPath .. " (" .. variantKey .. ")"); return false end

    local sprite = Sprite(64, 64, ColorMode.RGB)
    local layer = sprite.layers[1]
    local cel = sprite:newCel(layer, 1)
    local image = cel.image

    app.transaction(function()
        for y = 0, 63 do for x = 0, 63 do image:drawPixel(x, y, Color{r=0,g=0,b=0,a=0}) end end
    end)
    app.transaction(function()
        for _, p in ipairs(render.pixels) do
            if p.x >= 0 and p.x < 64 and p.y >= 0 and p.y < 64 then
                image:drawPixel(p.x, p.y, Color{r=p.color.r, g=p.color.g, b=p.color.b})
            end
        end
    end)

    ensureDir(outputDir)
    app.command.SaveFileAs{ ui=false, filename=out }
    sprite:close()
    print("Saved: " .. out)
    return true
end

-- Main
do
    local commonHex = loadCollateralPrimaryHex(collateralName)
    print("Collateral for 'common': " .. collateralName .. " (#" .. commonHex .. ")")
    local setDirs = listSetFolders()
    if #setDirs == 0 then setDirs = {eyeShapesRoot .. "/haunt1_id00_range0-1"} end

    local variants = {
        { key="mythical_low",  eye=rarityColors.mythical_low },
        { key="rare_low",      eye=rarityColors.rare_low },
        { key="uncommon_low",  eye=rarityColors.uncommon_low },
        { key="common",        eye=commonHex },
        { key="uncommon_high", eye=rarityColors.uncommon_high },
        { key="rare_high",     eye=rarityColors.rare_high },
        { key="mythical_high", eye=rarityColors.mythical_high },
    }

    for _, setDir in ipairs(setDirs) do
        local outputDir = outputRoot .. "/" .. (setDir:gsub("^" .. eyeShapesRoot .. "/", ""))
        ensureDir(outputDir)
        local views = existingViewsForSet(setDir)
        for _, inputPath in ipairs(views) do
            print("Processing: " .. inputPath)
            for _, v in ipairs(variants) do
                if v.key == "common" then
                    convertVariant(inputPath, v.key, commonHex, commonHex, outputDir)
                else
                    convertVariant(inputPath, v.key, v.eye, commonHex, outputDir)
                end
            end
        end
    end
    print("Done generating eye shape variants for " .. collateralName .. ".")
end


