-- Clean Aseprite SVG Importer Plugin
-- Simple and focused on Aavegotchi SVG conversion

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")

-- Import SVG from file
local function importFromFile(filePath, canvasWidth, canvasHeight)
    local file = io.open(filePath, "r")
    if not file then
        app.alert("Error: Could not open file " .. filePath)
        return
    end
    
    local svgContent = file:read("*all")
    file:close()
    
    if not svgContent or svgContent == "" then
        app.alert("Error: File is empty or could not be read")
        return
    end
    
    -- Parse SVG
    local svgData = SVGParser.parse(svgContent)

    -- Use SVG's native dimensions
    local viewBoxWidth = math.floor(svgData.viewBox.width)
    local viewBoxHeight = math.floor(svgData.viewBox.height)
    
    -- If user selected a specific size, use it; otherwise use viewBox size
    -- This allows rendering at native size (1:1 pixel mapping)
    if canvasWidth == viewBoxWidth and canvasHeight == viewBoxHeight then
        -- Perfect 1:1 rendering
        app.alert("Rendering at native SVG size: " .. viewBoxWidth .. "×" .. viewBoxHeight .. " (1:1 pixel mapping)")
    end
    
    -- Debug output with color info
    local debugMsg = "ViewBox: " .. viewBoxWidth .. "×" .. viewBoxHeight .. "\n"
    debugMsg = debugMsg .. "Canvas: " .. canvasWidth .. "×" .. canvasHeight .. "\n"
    debugMsg = debugMsg .. "Parsed " .. #svgData.elements .. " elements"
    if #svgData.elements > 0 then
        local firstElem = svgData.elements[1]
        if firstElem.type == "path" and firstElem.pathCommands then
            debugMsg = debugMsg .. "\nFirst element: " .. firstElem.type .. " with " .. #firstElem.pathCommands .. " commands"
        elseif firstElem.type == "rect" then
            debugMsg = debugMsg .. "\nFirst element: " .. firstElem.type .. " (" .. (firstElem.width or 0) .. "×" .. (firstElem.height or 0) .. ")"
        else
            debugMsg = debugMsg .. "\nFirst element: " .. firstElem.type
        end
        debugMsg = debugMsg .. "\nFill: " .. string.format("#%02x%02x%02x", firstElem.fill.r, firstElem.fill.g, firstElem.fill.b)

        -- Show color variety with details
        local colors = {}
        local sampleColors = {}
        for i, elem in ipairs(svgData.elements) do
            if elem.fill then
                local colorKey = string.format("#%02x%02x%02x", elem.fill.r, elem.fill.g, elem.fill.b)
                colors[colorKey] = (colors[colorKey] or 0) + 1
                if #sampleColors < 5 and not colors[colorKey] or colors[colorKey] == 1 then
                    table.insert(sampleColors, string.format("%d:%s", i, colorKey))
                end
            end
        end
        local colorCount = 0
        local colorList = {}
        for colorKey, count in pairs(colors) do
            colorCount = colorCount + 1
            table.insert(colorList, string.format("%s(%d)", colorKey, count))
        end
        debugMsg = debugMsg .. "\nUnique colors: " .. colorCount
        if #colorList > 0 then
            debugMsg = debugMsg .. "\nColors found: " .. table.concat(colorList, ", ")
        end
        if #sampleColors > 0 then
            debugMsg = debugMsg .. "\nSample: " .. table.concat(sampleColors, ", ")
        end

        -- Check for black pixels
        local blackPixels = 0
        for colorKey, count in pairs(colors) do
            if colorKey == "#000000" then
                blackPixels = count
                break
            end
        end
        if blackPixels > 0 then
            debugMsg = debugMsg .. "\nWARNING: " .. blackPixels .. " elements have black fill color!"
        end
    end
    app.alert(debugMsg)
    
    -- Render to pixels (all elements)
    local renderResult = SVGRenderer.render(svgData, canvasWidth, canvasHeight)
    
    -- Debug: Check actual pixel coordinate range
    local maxX, maxY = -1, -1
    local minX, minY = math.huge, math.huge
    for _, pixel in ipairs(renderResult.pixels) do
        maxX = math.max(maxX, pixel.x)
        maxY = math.max(maxY, pixel.y)
        minX = math.min(minX, pixel.x)
        minY = math.min(minY, pixel.y)
    end

    app.alert("Rendered " .. #renderResult.pixels .. " pixels\n" ..
              "Canvas: " .. canvasWidth .. "×" .. canvasHeight .. "\n" ..
              "Pixel bounds: X=[" .. minX .. "," .. maxX .. "], Y=[" .. minY .. "," .. maxY .. "]\n" ..
              "Expected: X=[0," .. (canvasWidth-1) .. "], Y=[0," .. (canvasHeight-1) .. "]")

    -- Check for potential outline artifacts
    local edgePixels = 0
    for _, pixel in ipairs(renderResult.pixels) do
        if pixel.x == 0 or pixel.x == canvasWidth-1 or pixel.y == 0 or pixel.y == canvasHeight-1 then
            edgePixels = edgePixels + 1
        end
    end
    if edgePixels > 0 then
        app.alert("Warning: " .. edgePixels .. " pixels are on the canvas edge - this might create outline artifacts")
    end
    
    -- Create new sprite
    local sprite = Sprite(canvasWidth, canvasHeight, ColorMode.RGB)
    local layer = sprite.layers[1]
    local cel = sprite:newCel(layer, 1)
    local image = cel.image
    
    -- Draw pixels to image
    app.transaction(
        function()
            for _, pixel in ipairs(renderResult.pixels) do
                if pixel.x >= 0 and pixel.x < canvasWidth and pixel.y >= 0 and pixel.y < canvasHeight then
                    local color = Color{r = pixel.color.r, g = pixel.color.g, b = pixel.color.b}
                    image:drawPixel(pixel.x, pixel.y, color)
                end
            end
        end
    )
    
    app.refresh()
    app.alert("SVG imported successfully!")
end

-- Import SVG from code
local function importFromCode(svgCode, canvasWidth, canvasHeight)
    if not svgCode or svgCode == "" then
        app.alert("Error: No SVG code provided")
        return
    end
    
    -- Parse SVG
    local svgData = SVGParser.parse(svgCode)
    
    -- Debug output with color info
    local debugMsg = "Debug: Parsed " .. #svgData.elements .. " elements"
    if #svgData.elements > 0 then
        local firstElem = svgData.elements[1]
        if firstElem.type == "path" and firstElem.pathCommands then
            debugMsg = debugMsg .. "\nFirst element: " .. firstElem.type .. " with " .. #firstElem.pathCommands .. " commands"
        elseif firstElem.type == "rect" then
            debugMsg = debugMsg .. "\nFirst element: " .. firstElem.type .. " (" .. (firstElem.width or 0) .. "×" .. (firstElem.height or 0) .. ")"
        else
            debugMsg = debugMsg .. "\nFirst element: " .. firstElem.type
        end
        debugMsg = debugMsg .. "\nFill: " .. string.format("#%02x%02x%02x", firstElem.fill.r, firstElem.fill.g, firstElem.fill.b)
        
        -- Show color variety with details
        local colors = {}
        local sampleColors = {}
        for i, elem in ipairs(svgData.elements) do
            if elem.fill then
                local colorKey = string.format("#%02x%02x%02x", elem.fill.r, elem.fill.g, elem.fill.b)
                colors[colorKey] = (colors[colorKey] or 0) + 1
                if #sampleColors < 5 and not colors[colorKey] or colors[colorKey] == 1 then
                    table.insert(sampleColors, string.format("%d:%s", i, colorKey))
                end
            end
        end
        local colorCount = 0
        local colorList = {}
        for colorKey, count in pairs(colors) do
            colorCount = colorCount + 1
            table.insert(colorList, string.format("%s(%d)", colorKey, count))
        end
        debugMsg = debugMsg .. "\nUnique colors: " .. colorCount
        if #colorList > 0 then
            debugMsg = debugMsg .. "\nColors found: " .. table.concat(colorList, ", ")
        end
        if #sampleColors > 0 then
            debugMsg = debugMsg .. "\nSample: " .. table.concat(sampleColors, ", ")
        end

        -- Check for black pixels
        local blackPixels = 0
        for colorKey, count in pairs(colors) do
            if colorKey == "#000000" then
                blackPixels = count
                break
            end
        end
        if blackPixels > 0 then
            debugMsg = debugMsg .. "\nWARNING: " .. blackPixels .. " elements have black fill color!"
        end
    end
    app.alert(debugMsg)
    
    -- Render to pixels (all elements)
    local renderResult = SVGRenderer.render(svgData, canvasWidth, canvasHeight)
    
    -- Debug: Check actual pixel coordinate range
    local maxX, maxY = -1, -1
    local minX, minY = math.huge, math.huge
    for _, pixel in ipairs(renderResult.pixels) do
        maxX = math.max(maxX, pixel.x)
        maxY = math.max(maxY, pixel.y)
        minX = math.min(minX, pixel.x)
        minY = math.min(minY, pixel.y)
    end

    app.alert("Rendered " .. #renderResult.pixels .. " pixels\n" ..
              "Canvas: " .. canvasWidth .. "×" .. canvasHeight .. "\n" ..
              "Pixel bounds: X=[" .. minX .. "," .. maxX .. "], Y=[" .. minY .. "," .. maxY .. "]\n" ..
              "Expected: X=[0," .. (canvasWidth-1) .. "], Y=[0," .. (canvasHeight-1) .. "]")

    -- Check for potential outline artifacts
    local edgePixels = 0
    for _, pixel in ipairs(renderResult.pixels) do
        if pixel.x == 0 or pixel.x == canvasWidth-1 or pixel.y == 0 or pixel.y == canvasHeight-1 then
            edgePixels = edgePixels + 1
        end
    end
    if edgePixels > 0 then
        app.alert("Warning: " .. edgePixels .. " pixels are on the canvas edge - this might create outline artifacts")
    end
    
    -- Create new sprite
    local sprite = Sprite(canvasWidth, canvasHeight, ColorMode.RGB)
    local layer = sprite.layers[1]
    local cel = sprite:newCel(layer, 1)
    local image = cel.image
    
    -- Draw pixels to image
    app.transaction(
        function()
            for _, pixel in ipairs(renderResult.pixels) do
                if pixel.x >= 0 and pixel.x < canvasWidth and pixel.y >= 0 and pixel.y < canvasHeight then
                    local color = Color{r = pixel.color.r, g = pixel.color.g, b = pixel.color.b}
                    image:drawPixel(pixel.x, pixel.y, color)
                end
            end
        end
    )
    
    app.refresh()
    app.alert("SVG imported successfully!")
end

-- Create and show the import dialog
local function showImportDialog()
    local dlg = Dialog("SVG Importer")
    
    -- Canvas size options
    dlg:combobox{
        id = "canvas_size",
        label = "Canvas Size",
        option = "Auto (SVG Size)",
        options = {"Auto (SVG Size)", "16x16", "32x32", "64x64", "128x128", "Custom"},
        onchange = function()
            local canvasSize = dlg.data.canvas_size
            if canvasSize == "Custom" then
                dlg:modify{id = "custom_width", visible = true}
                dlg:modify{id = "custom_height", visible = true}
            else
                dlg:modify{id = "custom_width", visible = false}
                dlg:modify{id = "custom_height", visible = false}
            end
        end
    }
    
    dlg:number{
        id = "custom_width",
        label = "Custom Width",
        text = "64",
        visible = false
    }
    
    dlg:number{
        id = "custom_height", 
        label = "Custom Height",
        text = "64",
        visible = false
    }
    
    -- Import method
    dlg:separator{text = "Import Method"}
    
    dlg:file{
        id = "svg_file",
        label = "SVG File",
        open = true,
        filetypes = {"svg"},
        title = "Select SVG File"
    }
    
    dlg:separator{text = "Or paste SVG code:"}
    
    dlg:entry{
        id = "svg_code",
        label = "SVG Code",
        text = "",
        multiline = true,
        focus = false
    }
    
    -- Buttons
    dlg:button{
        id = "import",
        text = "Import",
        onclick = function()
            local canvasSize = dlg.data.canvas_size
            local customWidth = dlg.data.custom_width
            local customHeight = dlg.data.custom_height
            local svgFile = dlg.data.svg_file
            local svgCode = dlg.data.svg_code
            
            -- Determine canvas dimensions
            local canvasWidth, canvasHeight
            if canvasSize == "Auto (SVG Size)" then
                -- Parse SVG to get viewBox dimensions
                local svgContent
                if svgFile and svgFile ~= "" then
                    local file = io.open(svgFile, "r")
                    if file then
                        svgContent = file:read("*all")
                        file:close()
                    else
                        app.alert("Error: Could not open SVG file")
                        return
                    end
                elseif svgCode and svgCode ~= "" then
                    svgContent = svgCode
                else
                    app.alert("Error: No SVG file or code provided")
                    return
                end
                
                if svgContent and svgContent ~= "" then
                    -- Use the already loaded SVGParser module
                    local success, svgData = pcall(SVGParser.parse, svgContent)
                    if success and svgData and svgData.viewBox then
                        -- ViewBox dimensions map directly to canvas size
                        -- Renderer will scale coords to fit within pixel indices
                        canvasWidth = math.floor(svgData.viewBox.width)
                        canvasHeight = math.floor(svgData.viewBox.height)
                        app.alert("Auto Size Detected:\nViewBox: " .. svgData.viewBox.width .. "×" .. svgData.viewBox.height .. "\nCanvas: " .. canvasWidth .. "×" .. canvasHeight .. " pixels")
                    else
                        app.alert("Error: Could not parse SVG viewBox\nReason: " .. (success and "No viewBox found" or "Parse failed"))
                        return
                    end
                else
                    app.alert("Error: SVG content is empty")
                    return
                end
            elseif canvasSize == "Custom" then
                canvasWidth = customWidth
                canvasHeight = customHeight
            else
                local size = canvasSize:match("(%d+)x(%d+)")
                canvasWidth = tonumber(size)
                canvasHeight = tonumber(size)
            end
            
            -- Validate dimensions
            if not canvasWidth or not canvasHeight or canvasWidth <= 0 or canvasHeight <= 0 then
                app.alert("Error: Invalid canvas dimensions")
                return
            end
            
            -- Import from file or code
            if svgFile and svgFile ~= "" then
                importFromFile(svgFile, canvasWidth, canvasHeight)
            elseif svgCode and svgCode ~= "" then
                importFromCode(svgCode, canvasWidth, canvasHeight)
            else
                app.alert("Error: Please select an SVG file or paste SVG code")
                return
            end
            
            dlg:close()
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

-- Register the plugin
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
