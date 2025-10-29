-- Debug pattern matching
local file = io.open("aavegotchi_db_collaterals_haunt1.json", "r")
if not file then
    print("Could not open file")
    return
end

local content = file:read("*all")
file:close()

print("File length: " .. #content)

-- Look for name patterns
local nameCount = 0
for name in content:gmatch('"name"%s*:%s*"([^"]*)"') do
    nameCount = nameCount + 1
    print("Found name " .. nameCount .. ": " .. name)
    if nameCount >= 3 then break end
end

print("Total names found: " .. nameCount)

-- Look for primary color patterns
local colorCount = 0
for color in content:gmatch('"primaryColor"%s*:%s*"([^"]*)"') do
    colorCount = colorCount + 1
    print("Found primary color " .. colorCount .. ": " .. color)
    if colorCount >= 3 then break end
end

print("Total primary colors found: " .. colorCount)
