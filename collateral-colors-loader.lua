-- Collateral Colors Loader
-- Loads and merges collateral color data from haunt1 and haunt2 JSON files

local CollateralColorsLoader = {}

-- Convert hex color from 0x format to # format
local function convertHexColor(hexStr)
    if not hexStr or hexStr == "" then
        return "#000000"
    end
    
    -- Remove 0x prefix if present
    local hex = hexStr:gsub("^0x", "")
    
    -- Add # prefix
    return "#" .. hex
end

-- Simple JSON parser for our specific structure
local function parseJSON(content)
    local collaterals = {}
    
    -- Find all collateral objects by looking for the pattern
    local i = 1
    while i <= #content do
        -- Look for start of collateral object
        local start = content:find('{%s*"collateralType"', i)
        if not start then break end
        
        -- Find end of this collateral object
        local braceCount = 0
        local j = start
        local endPos = nil
        
        while j <= #content do
            local char = content:sub(j, j)
            if char == '{' then
                braceCount = braceCount + 1
            elseif char == '}' then
                braceCount = braceCount - 1
                if braceCount == 0 then
                    endPos = j
                    break
                end
            end
            j = j + 1
        end
        
        if endPos then
            local collateralBlock = content:sub(start, endPos)
            local collateral = {}
            
            -- Extract name
            local name = collateralBlock:match('"name"%s*:%s*"([^"]*)"')
            if name then
                collateral.name = name
            end
            
            -- Extract primary color
            local primaryColor = collateralBlock:match('"primaryColor"%s*:%s*"([^"]*)"')
            if primaryColor then
                collateral.primaryColor = convertHexColor(primaryColor)
            end
            
            -- Extract secondary color
            local secondaryColor = collateralBlock:match('"secondaryColor"%s*:%s*"([^"]*)"')
            if secondaryColor then
                collateral.secondaryColor = convertHexColor(secondaryColor)
            end
            
            -- Extract cheek color
            local cheekColor = collateralBlock:match('"cheekColor"%s*:%s*"([^"]*)"')
            if cheekColor then
                collateral.cheekColor = convertHexColor(cheekColor)
            end
            
            -- Only add if we have the required fields
            if collateral.name and collateral.primaryColor and collateral.secondaryColor and collateral.cheekColor then
                table.insert(collaterals, collateral)
            end
            
            i = endPos + 1
        else
            break
        end
    end
    
    return collaterals
end

-- Load collaterals from a JSON file
local function loadCollateralsFromFile(filePath)
    local file = io.open(filePath, "r")
    if not file then
        return {}
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content or content == "" then
        return {}
    end
    
    local collaterals = {}
    
    -- Extract names
    local names = {}
    for name in content:gmatch('"name"%s*:%s*"([^"]*)"') do
        table.insert(names, name)
    end
    
    -- Extract primary colors
    local primaryColors = {}
    for color in content:gmatch('"primaryColor"%s*:%s*"([^"]*)"') do
        table.insert(primaryColors, color)
    end
    
    -- Extract secondary colors
    local secondaryColors = {}
    for color in content:gmatch('"secondaryColor"%s*:%s*"([^"]*)"') do
        table.insert(secondaryColors, color)
    end
    
    -- Extract cheek colors
    local cheekColors = {}
    for color in content:gmatch('"cheekColor"%s*:%s*"([^"]*)"') do
        table.insert(cheekColors, color)
    end
    
    -- Combine them into collateral objects
    local count = math.min(#names, #primaryColors, #secondaryColors, #cheekColors)
    for i = 1, count do
        table.insert(collaterals, {
            name = names[i],
            primaryColor = convertHexColor(primaryColors[i]),
            secondaryColor = convertHexColor(secondaryColors[i]),
            cheekColor = convertHexColor(cheekColors[i])
        })
    end
    
    return collaterals
end

-- Main function to load all collateral colors
function CollateralColorsLoader.loadAllCollaterals()
    local allCollaterals = {}
    
    -- Load haunt1 collaterals
    local haunt1Collaterals = loadCollateralsFromFile("aavegotchi_db_collaterals_haunt1.json")
    for _, collateral in ipairs(haunt1Collaterals) do
        table.insert(allCollaterals, collateral)
    end
    
    -- Load haunt2 collaterals
    local haunt2Collaterals = loadCollateralsFromFile("aavegotchi_db_collaterals_haunt2.json")
    for _, collateral in ipairs(haunt2Collaterals) do
        table.insert(allCollaterals, collateral)
    end
    
    return allCollaterals
end

-- Get collateral by name
function CollateralColorsLoader.getCollateralByName(collaterals, name)
    for _, collateral in ipairs(collaterals) do
        if collateral.name == name then
            return collateral
        end
    end
    return nil
end

return CollateralColorsLoader
