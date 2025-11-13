-- JSON Metadata Loader for Aavegotchi Wearables
-- Parses the wearables database and provides offset lookup by ID and view

local JsonMetadataLoader = {}

-- Cache for loaded metadata to avoid re-parsing
local metadataCache = nil

-- Simple JSON parser using string patterns for this specific structure
local function parseJson(jsonStr)
    local metadata = {wearables = {}}

    local wearablesKeyPos = jsonStr:find('"wearables"%s*:%s*%[')
    if not wearablesKeyPos then
        return metadata
    end

    local arrayStart = jsonStr:find("%[", wearablesKeyPos)
    if not arrayStart then
        return metadata
    end

    local depth = 0
    local pos = arrayStart
    repeat
        local char = jsonStr:sub(pos, pos)
        if char == "[" then
            depth = depth + 1
        elseif char == "]" then
            depth = depth - 1
        end
        pos = pos + 1
    until depth == 0 or pos > #jsonStr

    if depth ~= 0 then
        return metadata
    end

    local wearablesSection = jsonStr:sub(arrayStart + 1, pos - 2)
    local index = 1
    local length = #wearablesSection

    while index <= length do
        local startPos = wearablesSection:find("{", index, true)
        if not startPos then break end

        local depth = 0
        local pos = startPos
        repeat
            local char = wearablesSection:sub(pos, pos)
            if char == "{" then
                depth = depth + 1
            elseif char == "}" then
                depth = depth - 1
            end
            pos = pos + 1
        until depth == 0 or pos > length

        local objectStr = wearablesSection:sub(startPos, pos - 1)
        index = pos

        if objectStr:find('"id"%s*:') then
            local id = tonumber(objectStr:match('"id"%s*:%s*(%d+)'))
            if id then
                local wearableData = {
                    id = id,
                    name = objectStr:match('"name"%s*:%s*"([^"]*)"') or "Unknown",
                    previewoffsets = {}
                }

                local previewSection = objectStr:match('"previewoffsets"%s*:%s*%[([%s%S]-)%]')
                if previewSection then
                    for x, y in previewSection:gmatch('"x"%s*:%s*"([^"]*)"%s*,%s*"y"%s*:%s*"([^"]*)"') do
                        table.insert(wearableData.previewoffsets, {
                            x = tonumber(x) or 0,
                            y = tonumber(y) or 0
                        })
                    end
                end

                metadata.wearables[id] = wearableData
            end
        end
    end

    return metadata
end

-- Load and parse the wearables metadata
local function loadMetadata()
    if metadataCache then
        return metadataCache
    end
    
    local config = dofile("batch-config.lua")
    local metadataFile = config.metadata_file
    
    local file = io.open(metadataFile, "r")
    if not file then
        print("Error: Could not open metadata file: " .. metadataFile)
        return nil
    end
    
    local jsonContent = file:read("*all")
    file:close()
    
    if not jsonContent or jsonContent == "" then
        print("Error: Metadata file is empty")
        return nil
    end
    
    local success, metadata = pcall(parseJson, jsonContent)
    if not success then
        print("Error: Failed to parse metadata JSON")
        return nil
    end
    
    -- The parser already indexes wearables by id, just reuse it directly.
    local indexedMetadata = (metadata and metadata.wearables) or {}
    metadataCache = indexedMetadata
    return indexedMetadata
end

-- Get offset for a specific wearable and view
function JsonMetadataLoader.getOffsetForWearable(id, viewIndex)
    local metadata = loadMetadata()
    if not metadata then
        return {x = 0, y = 0}
    end
    
    local wearable = metadata[id]
    if not wearable then
        print("Warning: No metadata found for wearable ID: " .. tostring(id))
        return {x = 0, y = 0}
    end
    
    local previewoffsets = wearable.previewoffsets
    if not previewoffsets or not previewoffsets[viewIndex + 1] then
        print("Warning: No preview offset found for wearable ID: " .. tostring(id) .. ", view: " .. tostring(viewIndex))
        return {x = 0, y = 0}
    end
    
    local offset = previewoffsets[viewIndex + 1]
    return {
        x = tonumber(offset.x) or 0,
        y = tonumber(offset.y) or 0
    }
end

-- Get wearable name by ID
function JsonMetadataLoader.getWearableName(id)
    local metadata = loadMetadata()
    if not metadata then
        return "Unknown"
    end
    
    local wearable = metadata[id]
    if not wearable then
        return "Unknown"
    end
    
    return wearable.name or "Unknown"
end

-- Get all available wearable IDs
function JsonMetadataLoader.getAllWearableIds()
    local metadata = loadMetadata()
    if not metadata then
        return {}
    end
    
    local ids = {}
    for id, _ in pairs(metadata) do
        table.insert(ids, id)
    end
    
    table.sort(ids)
    return ids
end

-- Clear cache (useful for testing or if metadata file changes)
function JsonMetadataLoader.clearCache()
    metadataCache = nil
end

return JsonMetadataLoader
