-- Debug eyes SVG parsing
local SVGParser = dofile("svg-parser.lua")

-- Test eyes mad SVG
local eyesMadSVG = '<g class="gotchi-primary"><path d="M29 27V26H28H27V27V28H28H29V27Z"></path><path d="M27 24H26H25V25V26H26H27V25V24Z"></path><path d="M25 22H24H23V23V24H24H25V23V22Z"></path><path d="M37 27V26H36H35V27V28H36H37V27Z"></path><path d="M39 26V25V24H38H37V25V26H38H39Z"></path><path d="M41 24V23V22H40H39V23V24H40H41Z"></path></g>'

print("Original eyes mad SVG:")
print(eyesMadSVG)
print("")

-- Wrap with full SVG structure
local wrappedSVG = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><style>.gotchi-primary { fill: #2664ba; }</style>' .. eyesMadSVG .. '</svg>'

print("Wrapped SVG:")
print(wrappedSVG)
print("")

-- Parse SVG
local svgData = SVGParser.parse(wrappedSVG)
if svgData then
    print("SVG parsed successfully")
    print("ViewBox: " .. svgData.viewBox.width .. "x" .. svgData.viewBox.height)
    print("Elements: " .. #svgData.elements)
    
    for i, element in ipairs(svgData.elements) do
        print("Element " .. i .. ": " .. element.type)
        if element.attributes then
            for key, value in pairs(element.attributes) do
                print("  " .. key .. " = " .. tostring(value))
            end
        end
    end
else
    print("ERROR: Could not parse SVG")
end
