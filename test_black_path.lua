-- Test parsing of the black outline path
dofile('svg-parser.lua')

local svgContent = [[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 34 20"><path d="M32 5V3h-2V2h-2V0H6v2H4v1H2v2H0v9h1v1h1v1h1v1h1v1h1v1h3v1h18v-1h3v-1h1v-1h1v-1h1v-1h1v-1h1V5z"/></svg>]]

print("=== TESTING BLACK PATH PARSING ===\n")

local result = SVGParser.parse(svgContent)

print("ViewBox:", result.viewBox.x, result.viewBox.y, result.viewBox.width, result.viewBox.height)
print("Elements parsed:", #result.elements)

if #result.elements > 0 then
    local path = result.elements[1]
    print("\nElement 1:")
    print("  Type:", path.type)
    print("  Fill:", string.format("#%02x%02x%02x", path.fill.r, path.fill.g, path.fill.b))
    print("  Commands:", #path.pathCommands)
    
    print("\nFirst 10 commands:")
    for i = 1, math.min(10, #path.pathCommands) do
        local cmd = path.pathCommands[i]
        local paramStr = ""
        if cmd.params then
            for _, p in ipairs(cmd.params) do
                paramStr = paramStr .. " " .. p
            end
        end
        local relStr = cmd.isRelative and " (relative)" or " (absolute)"
        print(string.format("  %d. %s%s%s", i, cmd.type, paramStr, relStr))
    end
    
    print("\n... (" .. (#path.pathCommands - 10) .. " more commands)")
    
    print("\nLast 3 commands:")
    for i = math.max(1, #path.pathCommands - 2), #path.pathCommands do
        local cmd = path.pathCommands[i]
        local paramStr = ""
        if cmd.params then
            for _, p in ipairs(cmd.params) do
                paramStr = paramStr .. " " .. p
            end
        end
        local relStr = cmd.isRelative and " (relative)" or " (absolute)"
        print(string.format("  %d. %s%s%s", i, cmd.type, paramStr, relStr))
    end
    
    -- Check for specific patterns
    print("\n=== CHECKING FOR ISSUES ===")
    
    local hasV0 = false
    local hasH0 = false
    for _, cmd in ipairs(path.pathCommands) do
        if cmd.type == "V" and cmd.params[1] == 0 then
            hasV0 = true
        end
        if cmd.type == "H" and cmd.params[1] == 0 then
            hasH0 = true
        end
    end
    
    if hasV0 then print("✓ Found V0 command (vertical to y=0)") end
    if hasH0 then print("✓ Found H0 command (horizontal to x=0)") end
    
    -- Check if path closes
    local lastCmd = path.pathCommands[#path.pathCommands]
    if lastCmd.type == "Z" then
        print("✓ Path closes with Z command")
    else
        print("⚠️  Path doesn't close!")
    end
else
    print("ERROR: No elements parsed!")
end
