-- Debug color replacement to see what's happening
local SVGParser = dofile("svg-parser.lua")

-- Test with hands SVG
local handsSVG = '<g class="gotchi-handsDownClosed"><g class="gotchi-primary"><path d="M19 42h1v1h-1zm1-6h1v1h-1z"/><path d="M21 37h1v1h-1zm5 3v4h1v-4zm-5 3h-1v1h2v-1z"/><path d="M24 44h-2v1h4v-1h-1zm1-5h-1v1h2v-1z"/><path d="M23 38h-1v1h2v-1z"/></g><g class="gotchi-secondary"><path d="M19 43h1v1h-1zm5 2h-2v1h4v-1h-1z"/><path d="M27 41v3h1v-3zm-6 3h-1v1h2v-1z"/><path d="M26 44h1v1h-1zm-7-3h-1v2h1v-1z"/></g><g class="gotchi-primary"><path d="M44 42h1v1h-1zm-1-6h1v1h-1z"/><path d="M42 37h1v1h-1z"/><path d="M42 39v-1h-2v1h1zm0 4v1h2v-1h-1z"/><path d="M40 44h-2v1h4v-1h-1z"/><path d="M38 42v-2h-1v4h1v-1z"/><path d="M40 40v-1h-2v1h1z"/></g><g class="gotchi-secondary"><path d="M42 44v1h2v-1h-1zm-5-2v-1h-1v3h1v-1z"/><path d="M40 45h-2v1h4v-1h-1z"/><path d="M37 44h1v1h-1zm7-1h1v1h-1z"/></g></g>'

print("Original hands SVG:")
print(handsSVG)
print("")

-- Apply color replacement
local processedSVG = handsSVG
processedSVG = processedSVG:gsub('class="gotchi-primary"', 'fill="#2664ba"')
processedSVG = processedSVG:gsub('class="gotchi-secondary"', 'fill="#d4e0f1"')
processedSVG = processedSVG:gsub('class="gotchi-cheek"', 'fill="#f696c6"')

print("After color replacement:")
print(processedSVG)
print("")

-- Wrap in SVG
local wrappedSVG = string.format([[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">%s</svg>]], processedSVG)

print("Final wrapped SVG:")
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
