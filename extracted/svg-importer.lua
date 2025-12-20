-- Unified SVG Importer Plugin
-- Supports: SVG files, inline SVG code, and JSON files with SVG arrays

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")

-- Simple JSON parser for SVG arrays
local function parseJSON(jsonContent)
    local data = {}
    
    -- Extract body array
    local bodyStart = jsonContent:find('"body"%s*:%s*%[')
    if bodyStart then
        data.body = {}
        local arrayStart = jsonContent:find('%[', bodyStart)
        local inString = false
        local escapeNext = false
        local currentString = ""
        
        for i = arrayStart + 1, #jsonContent do
            local char = jsonContent:sub(i, i)
            
            if escapeNext then
                if inString then
                    if char == '"' then
                        currentString = currentString .. '"'
                    elseif char == '\\' then
                        currentString = currentString .. '\\'
                    elseif char == 'n' then
                        currentString = currentString .. '\n'
                    elseif char == 't' then
                        currentString = currentString .. '\t'
                    else
                        currentString = currentString .. char
                    end
                end
                escapeNext = false
            elseif char == '\\' then
                escapeNext = true
            elseif char == '"' then
                if inString then
                    table.insert(data.body, currentString)
                    currentString = ""
                    inString = false
                else
                    inString = true
                end
            elseif inString then
                currentString = currentString .. char
            elseif char == ']' and not inString then
                break
            end
        end
    end
    
    -- Extract other arrays
    local function extractArray(key)
        local keyStart = jsonContent:find('"' .. key .. '"%s*:%s*%[')
        if keyStart then
            data[key] = {}
            local arrayStart = jsonContent:find('%[', keyStart)
            local inString = false
            local escapeNext = false
            local currentString = ""
            
            for i = arrayStart + 1, #jsonContent do
                local char = jsonContent:sub(i, i)
                
                if escapeNext then
                    if inString then
                        if char == '"' then
                            currentString = currentString .. '"'
                        elseif char == '\\' then
                            currentString = currentString .. '\\'
                        elseif char == 'n' then
                            currentString = currentString .. '\n'
                        elseif char == 't' then
                            currentString = currentString .. '\t'
                        else
                            currentString = currentString .. char
                        end
                    end
                    escapeNext = false
                elseif char == '\\' then
                    escapeNext = true
                elseif char == '"' then
                    if inString then
                        table.insert(data[key], currentString)
                        currentString = ""
                        inString = false
                    else
                        inString = true
                    end
                elseif inString then
                    currentString = currentString .. char
                elseif char == ']' and not inString then
                    break
                end
            end
        end
    end
    
    extractArray("hands")
    extractArray("mouth_neutral")
    extractArray("mouth_happy")
    extractArray("eyes_mad")
    extractArray("eyes_happy")
    extractArray("eyes_sleepy")
    extractArray("shadow")
    
    return data
end

-- Render SVG to sprite
local function renderSVGToSprite(svgCode, canvasWidth, canvasHeight)
    local svgData = SVGParser.parse(svgCode)
    
    if not svgData or not svgData.viewBox then
        app.alert("Error: Failed to parse SVG")
        return nil
    end
    
    -- Use SVG's native dimensions if not specified
    if not canvasWidth or not canvasHeight then
        canvasWidth = math.floor(svgData.viewBox.width)
        canvasHeight = math.floor(svgData.viewBox.height)
    end
    
    -- Render to pixels
    local renderResult = SVGRenderer.render(svgData, canvasWidth, canvasHeight)
    
    if not renderResult or #renderResult.pixels == 0 then
        app.alert("Error: No pixels rendered")
        return nil
    end
    
    -- Create new sprite
    local sprite = Sprite(canvasWidth, canvasHeight, ColorMode.RGB)
    local layer = sprite.layers[1]
    local cel = sprite:newCel(layer, 1)
    local image = cel.image
    
    -- Draw pixels
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
    
    return sprite
end

-- Import single SVG
local function importSingleSVG(svgCode, canvasWidth, canvasHeight)
    local sprite = renderSVGToSprite(svgCode, canvasWidth, canvasHeight)
    if sprite then
        app.refresh()
        app.alert("SVG imported successfully!")
    end
end

-- Unified Import Dialog
local persistentPanel = nil

local function showImportDialog()
    -- Close existing panel if open
    if persistentPanel then
        persistentPanel:close()
        persistentPanel = nil
    end
    
    -- Create unified dialog with fixed width
    persistentPanel = Dialog("SVG Import")
    persistentPanel.bounds = Rectangle(0, 0, 480, 330)
    
    -- Import source type
    persistentPanel:combobox{
        id = "import_type",
        label = "Import From",
        option = "SVG Code",
        options = {"SVG Code", "SVG File", "JSON File"},
        onchange = function()
            local importType = persistentPanel.data.import_type
            persistentPanel:modify{id = "svg_code", visible = (importType == "SVG Code")}
            persistentPanel:modify{id = "svg_file", visible = (importType == "SVG File")}
            persistentPanel:modify{id = "json_file", visible = (importType == "JSON File")}
            persistentPanel:modify{id = "json_category", visible = (importType == "JSON File")}
            persistentPanel:modify{id = "json_index", visible = (importType == "JSON File")}
        end
    }
    
    -- Canvas size options
    persistentPanel:combobox{
        id = "canvas_size",
        label = "Canvas Size",
        option = "Auto (SVG Size)",
        options = {"Auto (SVG Size)", "16x16", "32x32", "64x64", "128x128", "Custom"},
        onchange = function()
            local canvasSize = persistentPanel.data.canvas_size
            if canvasSize == "Custom" then
                persistentPanel:modify{id = "custom_width", visible = true}
                persistentPanel:modify{id = "custom_height", visible = true}
            else
                persistentPanel:modify{id = "custom_width", visible = false}
                persistentPanel:modify{id = "custom_height", visible = false}
            end
        end
    }
    
    persistentPanel:number{
        id = "custom_width",
        label = "Custom Width",
        text = "64",
        visible = false
    }
    
    persistentPanel:number{
        id = "custom_height", 
        label = "Custom Height",
        text = "64",
        visible = false
    }
    
    persistentPanel:separator{text = "SVG Code Input"}
    
    -- SVG code input (visible when "SVG Code" selected)
    persistentPanel:entry{
        id = "svg_code",
        label = "Paste SVG Code",
        text = "",
        multiline = true,
        focus = true
    }
    
    persistentPanel:separator{text = "SVG File"}
    
    -- SVG file input (visible when "SVG File" selected)
    persistentPanel:file{
        id = "svg_file",
        label = "SVG File",
        open = true,
        filetypes = {"svg"},
        title = "Select SVG File",
        visible = false
    }
    
    persistentPanel:separator{text = "JSON File"}
    
    -- JSON file input (visible when "JSON File" selected)
    persistentPanel:file{
        id = "json_file",
        label = "JSON File",
        open = true,
        filetypes = {"json"},
        title = "Select JSON File",
        visible = false,
        onchange = function()
            -- Parse JSON and populate category/index dropdowns
            local jsonFile = persistentPanel.data.json_file
            if jsonFile and jsonFile ~= "" then
                local file = io.open(jsonFile, "r")
                if file then
                    local jsonContent = file:read("*all")
                    file:close()
                    
                    local jsonData = parseJSON(jsonContent)
                    if jsonData then
                        -- Build category options
                        local categories = {}
                        local categoryLabels = {
                            body = "Body",
                            hands = "Hands",
                            mouth_neutral = "Mouth (Neutral)",
                            mouth_happy = "Mouth (Happy)",
                            eyes_mad = "Eyes (Mad)",
                            eyes_happy = "Eyes (Happy)",
                            eyes_sleepy = "Eyes (Sleepy)",
                            shadow = "Shadow"
                        }
                        
                        for key, _ in pairs(jsonData) do
                            if categoryLabels[key] then
                                table.insert(categories, key)
                            end
                        end
                        
                        if #categories > 0 then
                            persistentPanel:modify{
                                id = "json_category",
                                options = categories,
                                option = categories[1]
                            }
                            
                            -- Set default index to "0" when category is loaded
                            persistentPanel:modify{
                                id = "json_index",
                                text = "0"
                            }
                        end
                    end
                end
            end
        end
    }
    
    persistentPanel:combobox{
        id = "json_category",
        label = "Category",
        option = "body",
        options = {"body"},
        visible = false,
        onchange = function()
            -- Update index range when category changes
            local jsonFile = persistentPanel.data.json_file
            if jsonFile and jsonFile ~= "" then
                local file = io.open(jsonFile, "r")
                if file then
                    local jsonContent = file:read("*all")
                    file:close()
                    local jsonData = parseJSON(jsonContent)
                    if jsonData then
                        local category = persistentPanel.data.json_category
                        if category and jsonData[category] then
                            -- Reset index to default when category changes
                            persistentPanel:modify{
                                id = "json_index",
                                text = "0"
                            }
                        end
                    end
                end
            end
        end
    }
    
    -- Parse array string like "[0,1,2,3]" or "0,1,2,3" into Lua array (1-based)
    local function parseIndexArray(indexString)
        if not indexString or indexString == "" then
            return nil
        end
        
        -- Remove brackets if present
        indexString = indexString:gsub("^%s*%[%s*", ""):gsub("%s*%]%s*$", "")
        
        -- Split by comma and convert to numbers
        local indices = {}
        for numStr in indexString:gmatch("([^,]+)") do
            local num = tonumber(numStr:match("^%s*(.-)%s*$"))
            if num then
                -- Convert 0-based to 1-based for Lua arrays
                table.insert(indices, num + 1)
            end
        end
        
        return #indices > 0 and indices or nil
    end

    persistentPanel:entry{
        id = "json_index",
        label = "Index (single number or array like [0,1,2,3])",
        text = "0",
        visible = false
    }
    
    -- Action buttons
    persistentPanel:newrow()
    
    persistentPanel:button{
        id = "import",
        text = "Import SVG",
        onclick = function()
            local importType = persistentPanel.data.import_type
            local canvasSize = persistentPanel.data.canvas_size
            local customWidth = persistentPanel.data.custom_width
            local customHeight = persistentPanel.data.custom_height
            
            -- Determine canvas dimensions
            local canvasWidth, canvasHeight
            local svgContent = nil
            
            -- Get SVG content based on import type
            if importType == "SVG Code" then
                svgContent = persistentPanel.data.svg_code
                if not svgContent or svgContent == "" then
                    app.alert("Error: Please paste SVG code")
                    return
                end
            elseif importType == "SVG File" then
                local svgFile = persistentPanel.data.svg_file
                if not svgFile or svgFile == "" then
                    app.alert("Error: Please select an SVG file")
                    return
                end
                local file = io.open(svgFile, "r")
                if file then
                    svgContent = file:read("*all")
                    file:close()
                else
                    app.alert("Error: Could not open SVG file")
                    return
                end
            elseif importType == "JSON File" then
                local jsonFile = persistentPanel.data.json_file
                local category = persistentPanel.data.json_category
                local indexInput = persistentPanel.data.json_index
                
                if not jsonFile or jsonFile == "" then
                    app.alert("Error: Please select a JSON file")
                    return
                end
                
                local file = io.open(jsonFile, "r")
                if file then
                    local jsonContent = file:read("*all")
                    file:close()
                    local jsonData = parseJSON(jsonContent)
                    
                    if not jsonData or not jsonData[category] then
                        app.alert("Error: Invalid JSON structure or category")
                        return
                    end
                    
                    -- Parse index input (could be single number or array)
                    local indices = parseIndexArray(indexInput)
                    if not indices then
                        -- Try as single number
                        local singleIndex = tonumber(indexInput)
                        if singleIndex then
                            indices = {singleIndex + 1} -- Convert 0-based to 1-based
                        else
                            app.alert("Error: Invalid index format. Use a number or array like [0,1,2,3]")
                            return
                        end
                    end
                    
                    -- Import each SVG in the array
                    local successCount = 0
                    local failCount = 0
                    
                    for i, index in ipairs(indices) do
                        if jsonData[category][index] then
                            svgContent = jsonData[category][index]
                            
                            -- Determine canvas size for this SVG
                            local currentCanvasWidth, currentCanvasHeight
                            if canvasSize == "Auto (SVG Size)" then
                                local success, svgData = pcall(SVGParser.parse, svgContent)
                                if success and svgData and svgData.viewBox then
                                    currentCanvasWidth = math.floor(svgData.viewBox.width)
                                    currentCanvasHeight = math.floor(svgData.viewBox.height)
                                else
                                    app.alert("Error: Could not parse SVG viewBox for index " .. (index - 1))
                                    failCount = failCount + 1
                                    goto continue
                                end
                            elseif canvasSize == "Custom" then
                                currentCanvasWidth = customWidth
                                currentCanvasHeight = customHeight
                            else
                                local size = canvasSize:match("(%d+)x(%d+)")
                                currentCanvasWidth = tonumber(size)
                                currentCanvasHeight = tonumber(size)
                            end
                            
                            -- Validate dimensions
                            if not currentCanvasWidth or not currentCanvasHeight or currentCanvasWidth <= 0 or currentCanvasHeight <= 0 then
                                app.alert("Error: Invalid canvas dimensions for index " .. (index - 1))
                                failCount = failCount + 1
                                goto continue
                            end
                            
                            -- Import this SVG
                            local sprite = renderSVGToSprite(svgContent, currentCanvasWidth, currentCanvasHeight)
                            if sprite then
                                successCount = successCount + 1
                            else
                                failCount = failCount + 1
                            end
                            
                            ::continue::
                        else
                            app.alert("Warning: Index " .. (index - 1) .. " not found in category")
                            failCount = failCount + 1
                        end
                    end
                    
                    app.refresh()
                    
                    -- Show summary
                    if successCount > 0 then
                        local msg = "Imported " .. successCount .. " SVG(s) successfully"
                        if failCount > 0 then
                            msg = msg .. "\n" .. failCount .. " failed"
                        end
                        app.alert(msg)
                    else
                        app.alert("Error: Failed to import any SVGs")
                    end
                    
                    return -- Don't continue with single import logic
                else
                    app.alert("Error: Could not open JSON file")
                    return
                end
            end
            
            -- Determine canvas size (for SVG Code and SVG File)
            if canvasSize == "Auto (SVG Size)" then
                local success, svgData = pcall(SVGParser.parse, svgContent)
                if success and svgData and svgData.viewBox then
                    canvasWidth = math.floor(svgData.viewBox.width)
                    canvasHeight = math.floor(svgData.viewBox.height)
                else
                    app.alert("Error: Could not parse SVG viewBox")
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
            
            -- Import the SVG
            importSingleSVG(svgContent, canvasWidth, canvasHeight)
        end
    }
    
    persistentPanel:newrow()
    
    persistentPanel:button{
        id = "clear",
        text = "Clear",
        onclick = function()
            persistentPanel:modify{id = "svg_code", text = ""}
        end
    }
    
    persistentPanel:button{
        id = "close",
        text = "Close",
        onclick = function()
            persistentPanel:close()
            persistentPanel = nil
        end
    }
    
    -- Show as non-modal (stays open)
    persistentPanel:show{wait = false}
end

-- Register the plugin
function init(plugin)
    plugin:newCommand{
        id = "svg_import",
        title = "SVG Import",
        group = "file_import",
        onenabled = function() return true end,
        onclick = showImportDialog
    }
end

return plugin
