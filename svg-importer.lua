-- Clean Aseprite SVG Importer Plugin
-- Simple and focused on Aavegotchi SVG conversion

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer.lua")

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
    
    -- Debug output
    local debugMsg = "Debug: Parsed " .. #svgData.elements .. " elements"
    if #svgData.elements > 0 then
        debugMsg = debugMsg .. "\nFirst element: " .. svgData.elements[1].type .. " with " .. #svgData.elements[1].pathCommands .. " commands"
        debugMsg = debugMsg .. "\nFill color: " .. string.format("#%02x%02x%02x", svgData.elements[1].fill.r, svgData.elements[1].fill.g, svgData.elements[1].fill.b)
    end
    app.alert(debugMsg)
    
    -- Render to pixels
    local renderResult = SVGRenderer.render(svgData, canvasWidth, canvasHeight)
    app.alert("Debug: Rendered " .. #renderResult.pixels .. " pixels")
    
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
    
    -- Debug output
    local debugMsg = "Debug: Parsed " .. #svgData.elements .. " elements"
    if #svgData.elements > 0 then
        debugMsg = debugMsg .. "\nFirst element: " .. svgData.elements[1].type .. " with " .. #svgData.elements[1].pathCommands .. " commands"
        debugMsg = debugMsg .. "\nFill color: " .. string.format("#%02x%02x%02x", svgData.elements[1].fill.r, svgData.elements[1].fill.g, svgData.elements[1].fill.b)
    end
    app.alert(debugMsg)
    
    -- Render to pixels
    local renderResult = SVGRenderer.render(svgData, canvasWidth, canvasHeight)
    app.alert("Debug: Rendered " .. #renderResult.pixels .. " pixels")
    
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
        option = "64x64",
        options = {"16x16", "32x32", "64x64", "128x128", "Custom"},
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
            if canvasSize == "Custom" then
                canvasWidth = customWidth
                canvasHeight = customHeight
            else
                local size = canvasSize:match("(%d+)x(%d+)")
                canvasWidth = tonumber(size)
                canvasHeight = tonumber(size)
            end
            
            -- Validate dimensions
            if canvasWidth <= 0 or canvasHeight <= 0 then
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
