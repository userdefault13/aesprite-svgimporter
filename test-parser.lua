#!/usr/bin/env lua

-- Test script to run SVG parser from CLI
local SVGParser = dofile("extracted/svg-parser.lua")

-- Test SVG from line 4 (left side view with gotchi-wearable classes)
local testSVG = [[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><style>.gotchi-primary{fill:#0074f9;}
      .gotchi-secondary{fill:#c8e1fd;}
      .gotchi-cheek{fill:#f696c6;}</style><g class="gotchi-body"><path d="M43 14v-2h-2v-2h-2V8h-4V6h-6v2h-4v2h-2v2h-2v2h-1v41h3v-2h3v2h4v-2h4v2h4v-2h3v2h3V14z" class="gotchi-wearable gotchi-primary"/><path d="M41 14v-2h-2v-2h-4V8h-6v2h-4v2h-2v2h-2v39h2v-2h3v2h4v-2h4v2h4v-2h3v2h2V14z" class="gotchi-wearable gotchi-secondary"/><path d="M42,51h-1v-2h-3v2h-4v-2h-4v2h-4v-2h-3v2h-2V14h2v-1h2v-2h4V9h6v2h4v2h2v2h1V51z" fill="#ffffff" class="gotchi-wearable"/></g><path class="gotchi-cheek" d="M22 32h2v2h-2z" fill="#f696c6"/></svg>]]

print("=== Testing SVG Parser ===")
print("")

local svgData = SVGParser.parse(testSVG)

print("")
print("=== Parsing Results ===")
print("ViewBox: " .. svgData.viewBox.width .. "x" .. svgData.viewBox.height)
print("Elements parsed: " .. #svgData.elements)
print("")

for i, elem in ipairs(svgData.elements) do
    local colorStr = string.format("#%02x%02x%02x", elem.fill.r, elem.fill.g, elem.fill.b)
    local isBlack = (elem.fill.r == 0 and elem.fill.g == 0 and elem.fill.b == 0)
    local status = isBlack and "⚠️  BLACK" or "✓"
    print(string.format("%s Element %d: %s, Fill: %s, Commands: %d", 
        status, i, elem.type, colorStr, #elem.pathCommands))
end

print("")
print("=== Summary ===")
local blackCount = 0
for _, elem in ipairs(svgData.elements) do
    if elem.fill.r == 0 and elem.fill.g == 0 and elem.fill.b == 0 then
        blackCount = blackCount + 1
    end
end
print("Black elements: " .. blackCount)

