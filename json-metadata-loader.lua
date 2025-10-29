-- JSON Metadata Loader for Aavegotchi Wearables
-- Parses the wearables database and provides offset lookup by ID and view

local JsonMetadataLoader = {}

-- Cache for loaded metadata to avoid re-parsing
local metadataCache = nil

-- Simple JSON parser using string patterns for this specific structure
local function parseJson(jsonStr)
    local metadata = {wearables = {}}
    
    -- Extract wearables array using pattern matching
    for wearable in jsonStr:gmatch('{"id":(%d+),.-?"previewoffsets":%[([^%]]+)%]') do
        local id = tonumber(wearable)
        if id then
            local wearableData = {
                id = id,
                name = "Unknown",
                previewoffsets = {}
            }
            
            -- Extract name
            local nameMatch = jsonStr:match('"id":' .. id .. ',.-?"name":"([^"]*)"')
            if nameMatch then
                wearableData.name = nameMatch
            end
            
            -- Extract previewoffsets
            local offsetsMatch = jsonStr:match('"id":' .. id .. ',.-?"previewoffsets":%[([^%]]+)%]')
            if offsetsMatch then
                local offsetIndex = 1
                for x, y in offsetsMatch:gmatch('{"x":"([^"]*)","y":"([^"]*)"}') do
                    wearableData.previewoffsets[offsetIndex] = {
                        x = tonumber(x) or 0,
                        y = tonumber(y) or 0
                    }
                    offsetIndex = offsetIndex + 1
                end
            end
            
            metadata.wearables[id] = wearableData
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
    
    -- Index wearables by ID for quick lookup
    local indexedMetadata = {}
    if metadata and metadata.wearables then
        for _, wearable in ipairs(metadata.wearables) do
            if wearable.id then
                indexedMetadata[wearable.id] = wearable
            end
        end
    end
    
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
