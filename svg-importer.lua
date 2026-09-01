-- SVG Importer for Aseprite
-- Pixel-perfect SVG import with pose-group and SMIL animation support

local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")
local SVGAnimation = dofile("svg-animation.lua")

local function drawPixelsToCel(sprite, layer, frameIndex, pixels, canvasWidth, canvasHeight)
    local cel = sprite:newCel(layer, frameIndex)
    local image = cel.image
    image:clear(Color{r = 0, g = 0, b = 0, a = 0})

    for _, pixel in ipairs(pixels) do
        if pixel.x >= 0 and pixel.x < canvasWidth and pixel.y >= 0 and pixel.y < canvasHeight then
            local color = Color{r = pixel.color.r, g = pixel.color.g, b = pixel.color.b, a = 255}
            image:drawPixel(pixel.x, pixel.y, color)
        end
    end
end

local function frameDurationForFps(fps)
    fps = fps or 8
    if fps <= 0 then fps = 8 end
    return math.max(1, math.floor(100 / fps + 0.5))
end

local function setAnimationFrameDurations(sprite, frameCount, animFps, animationType)
    if animationType ~= "smil" or frameCount < 1 then
        return
    end
    local duration = frameDurationForFps(animFps)
    for i = 1, frameCount do
        sprite.frames[i].duration = duration
    end
end

local function cleanJsonSvgCode(svgCode)
    if not svgCode then return svgCode end
    svgCode = svgCode:gsub('\\"', '"')
    svgCode = svgCode:gsub('\\\\', '\\')
    return svgCode
end

local function resolveCanvasSize(canvasSize, customWidth, customHeight, svgContent)
    if canvasSize == "Auto (SVG Size)" then
        if not svgContent or svgContent == "" then
            return nil, nil, "SVG content is empty"
        end
        local success, svgData = pcall(SVGParser.parse, svgContent)
        if not success or not svgData or not svgData.viewBox then
            return nil, nil, "Could not parse SVG viewBox"
        end
        return math.floor(svgData.viewBox.width), math.floor(svgData.viewBox.height)
    end

    if canvasSize == "Custom" then
        return customWidth, customHeight
    end

    local widthText, heightText = canvasSize:match("(%d+)x(%d+)")
    return tonumber(widthText), tonumber(heightText)
end

-- Returns ok, message
local function importSvgContent(svgContent, canvasWidth, canvasHeight, importMode, animFps)
    if not svgContent or svgContent == "" then
        return false, "No SVG content provided"
    end

    svgContent = cleanJsonSvgCode(svgContent)
    importMode = importMode or "Auto"
    animFps = animFps or 8

    if not canvasWidth or not canvasHeight or canvasWidth <= 0 or canvasHeight <= 0 then
        return false, "Invalid canvas dimensions"
    end

    local animationInfo = SVGAnimation.detect(svgContent, animFps)
    local useAnimation = importMode == "Animation Frames"
        or (importMode == "Auto" and animationInfo.frames and #animationInfo.frames >= 2)

    if importMode == "Animation Frames" and (not animationInfo.frames or #animationInfo.frames < 2) then
        return false, "No animation frames detected. Use sibling <g class=\"...\"> groups or SMIL <animateTransform>."
    end

    local sprite = Sprite(canvasWidth, canvasHeight, ColorMode.RGB)
    local layer = sprite.layers[1]

    if useAnimation then
        local frameNames = {}
        app.transaction(function()
            for frameIndex, frame in ipairs(animationInfo.frames) do
                if frameIndex > 1 then
                    sprite:newFrame()
                end

                local frameSvg = frame.svg or svgContent
                local svgData = SVGParser.parse(frameSvg)
                local renderResult = SVGRenderer.render(svgData, canvasWidth, canvasHeight)
                drawPixelsToCel(sprite, layer, frameIndex, renderResult.pixels, canvasWidth, canvasHeight)
                frameNames[frameIndex] = frame.name or ("frame" .. frameIndex)
            end

            setAnimationFrameDurations(sprite, #animationInfo.frames, animFps, animationInfo.type)

            if #animationInfo.frames >= 2 then
                sprite:newTag(1, #animationInfo.frames, "animation")
            end
        end)

        local typeLabel = animationInfo.type == "smil" and "SMIL" or "poses"
        return true, string.format(
            "Animation imported (%s): %d frames, %dx%d (%s)",
            typeLabel,
            #animationInfo.frames,
            canvasWidth,
            canvasHeight,
            table.concat(frameNames, ", ")
        )
    end

    local svgData = SVGParser.parse(svgContent)
    local renderResult = SVGRenderer.render(svgData, canvasWidth, canvasHeight)

    app.transaction(function()
        drawPixelsToCel(sprite, layer, 1, renderResult.pixels, canvasWidth, canvasHeight)
    end)

    return true, string.format(
        "Imported: %d elements, %d pixels on %dx%d canvas",
        #svgData.elements,
        #renderResult.pixels,
        canvasWidth,
        canvasHeight
    )
end

local function resolveSvgInput(svgFile, svgCode, clipboardCode)
    if clipboardCode and clipboardCode ~= "" then
        return clipboardCode
    end
    if svgCode and svgCode:match("%S") then
        return svgCode
    end
    if svgFile and svgFile ~= "" then
        local file = io.open(svgFile, "r")
        if not file then
            return nil, "Could not open SVG file"
        end
        local content = file:read("*all")
        file:close()
        return content
    end
    return nil, "Select an SVG file or paste SVG code"
end

local function showImportDialog()
    local dlg = Dialog("SVG Importer")
    local clipboardSvgCode = nil

    dlg:combobox{
        id = "canvas_size",
        label = "Canvas Size",
        option = "Auto (SVG Size)",
        options = {"Auto (SVG Size)", "16x16", "32x32", "64x64", "128x128", "Custom"},
        onchange = function()
            local canvasSize = dlg.data.canvas_size
            local isCustom = canvasSize == "Custom"
            dlg:modify{id = "custom_width", visible = isCustom}
            dlg:modify{id = "custom_height", visible = isCustom}
        end
    }

    dlg:label{
        text = "Auto uses the SVG viewBox for 1:1 pixel mapping"
    }

    dlg:number{id = "custom_width", label = "Custom Width", text = "64", visible = false}
    dlg:number{id = "custom_height", label = "Custom Height", text = "64", visible = false}

    dlg:separator{text = "Animation"}

    dlg:combobox{
        id = "import_mode",
        label = "Import Mode",
        option = "Auto",
        options = {"Auto", "Single Frame", "Animation Frames"},
        onchange = function()
            local mode = dlg.data.import_mode
            dlg:modify{
                id = "anim_fps",
                visible = mode == "Auto" or mode == "Animation Frames"
            }
        end
    }

    dlg:label{
        text = "Auto: sibling <g> pose groups or SMIL become frames"
    }

    dlg:number{id = "anim_fps", label = "SMIL FPS", text = "8", decimals = 0}

    dlg:separator{text = "SVG Source"}

    dlg:file{
        id = "svg_file",
        label = "SVG File",
        open = true,
        filetypes = {"svg"},
        title = "Select SVG File"
    }

    dlg:button{
        id = "paste_clipboard",
        text = "Paste SVG from Clipboard",
        onclick = function()
            local text = app.clipboard.text
            if not text or text == "" then
                dlg:modify{id = "import_status", text = "Clipboard is empty"}
                return
            end
            if not text:match("<svg") and not text:match("<g") then
                dlg:modify{id = "import_status", text = "Clipboard does not look like SVG markup"}
                return
            end
            clipboardSvgCode = text
            local pathCount = select(2, text:gsub("<path", ""))
            local frameCount = SVGAnimation.frameCount(text, dlg.data.anim_fps or 8)
            local details = "Ready: " .. #text .. " chars"
            if pathCount > 0 then
                details = details .. ", " .. pathCount .. " paths"
            end
            if frameCount >= 2 then
                details = details .. ", " .. frameCount .. " animation frames"
            end
            dlg:modify{id = "import_status", text = details}
        end
    }

    dlg:label{
        id = "import_status",
        text = "Paste multi-line SVG via clipboard (text field is single-line only)"
    }

    dlg:entry{id = "svg_code", label = "Single-line SVG", text = "", focus = false}

    dlg:separator{text = ""}
    dlg:newrow{always = true}

    dlg:button{
        id = "import",
        text = "Import",
        focus = true,
        onclick = function()
            local svgContent, inputError = resolveSvgInput(
                dlg.data.svg_file,
                dlg.data.svg_code,
                clipboardSvgCode
            )

            if inputError then
                dlg:modify{id = "import_status", text = "Error: " .. inputError}
                return
            end

            local canvasWidth, canvasHeight, sizeError = resolveCanvasSize(
                dlg.data.canvas_size,
                dlg.data.custom_width,
                dlg.data.custom_height,
                svgContent
            )

            if sizeError then
                dlg:modify{id = "import_status", text = "Error: " .. sizeError}
                return
            end

            if not canvasWidth or not canvasHeight or canvasWidth <= 0 or canvasHeight <= 0 then
                dlg:modify{id = "import_status", text = "Error: Invalid canvas dimensions"}
                return
            end

            local ok, message = importSvgContent(
                svgContent,
                canvasWidth,
                canvasHeight,
                dlg.data.import_mode,
                dlg.data.anim_fps or 8
            )

            if not ok then
                dlg:modify{id = "import_status", text = "Error: " .. message}
                return
            end

            app.refresh()
            dlg:close()
            app.alert(message)
        end
    }

    dlg:button{
        id = "cancel",
        text = "Cancel",
        onclick = function()
            dlg:close()
        end
    }

    dlg:show{wait = false}
end

function init(plugin)
    plugin:newCommand{
        id = "svg_import",
        title = "Import SVG",
        group = "file_import",
        onenabled = function() return true end,
        onclick = showImportDialog
    }
end

return plugin
