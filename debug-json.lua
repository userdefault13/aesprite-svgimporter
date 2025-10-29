-- Debug JSON loading
local CollateralColorsLoader = dofile("collateral-colors-loader.lua")

print("Testing JSON loading...")

-- Test loading collaterals
local collaterals = CollateralColorsLoader.loadAllCollaterals()
print("Collaterals loaded: " .. (collaterals and #collaterals or 0))

if collaterals and #collaterals > 0 then
    print("First collateral: " .. (collaterals[1].name or "no name"))
    print("Primary color: " .. (collaterals[1].primaryColor or "no color"))
else
    print("No collaterals found")
    
    -- Test individual file loading
    local file = io.open("aavegotchi_db_collaterals_haunt1.json", "r")
    if file then
        local content = file:read("*all")
        file:close()
        print("File content length: " .. #content)
        print("First 200 chars: " .. string.sub(content, 1, 200))
    else
        print("Could not open haunt1 file")
    end
end
