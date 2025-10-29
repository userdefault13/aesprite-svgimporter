-- Test color replacement properly
local handsSVG = '<g class="gotchi-handsDownClosed"><g class="gotchi-primary"><path d="M19 42h1v1h-1zm1-6h1v1h-1z"/><path d="M21 37h1v1h-1zm5 3v4h1v-4zm-5 3h-1v1h2v-1z"/><path d="M24 44h-2v1h4v-1h-1zm1-5h-1v1h2v-1z"/><path d="M23 38h-1v1h2v-1z"/></g><g class="gotchi-secondary"><path d="M19 43h1v1h-1zm5 2h-2v1h4v-1h-1z"/><path d="M27 41v3h1v-3zm-6 3h-1v1h2v-1z"/><path d="M26 44h1v1h-1zm-7-3h-1v2h1v-1z"/></g><g class="gotchi-primary"><path d="M44 42h1v1h-1zm-1-6h1v1h-1z"/><path d="M42 37h1v1h-1z"/><path d="M42 39v-1h-2v1h1zm0 4v1h2v-1h-1z"/><path d="M40 44h-2v1h4v-1h-1z"/><path d="M38 42v-2h-1v4h1v-1z"/><path d="M40 40v-1h-2v1h1z"/></g><g class="gotchi-secondary"><path d="M42 44v1h2v-1h-1zm-5-2v-1h-1v3h1v-1z"/><path d="M40 45h-2v1h4v-1h-1z"/><path d="M37 44h1v1h-1zm7-1h1v1h-1z"/></g></g>'

print("Original SVG:")
print(handsSVG)
print("")

-- Apply color replacement step by step
local processedSVG = handsSVG

print("Step 1 - Replace gotchi-primary:")
processedSVG = processedSVG:gsub('class="gotchi-primary"', 'fill="#2664ba"')
print("After gotchi-primary replacement:")
print(processedSVG)
print("")

print("Step 2 - Replace gotchi-secondary:")
processedSVG = processedSVG:gsub('class="gotchi-secondary"', 'fill="#d4e0f1"')
print("After gotchi-secondary replacement:")
print(processedSVG)
print("")

print("Step 3 - Replace gotchi-cheek:")
processedSVG = processedSVG:gsub('class="gotchi-cheek"', 'fill="#f696c6"')
print("After gotchi-cheek replacement:")
print(processedSVG)
print("")

-- Count replacements
local primaryCount = 0
for _ in processedSVG:gmatch('fill="#2664ba"') do
    primaryCount = primaryCount + 1
end

local secondaryCount = 0
for _ in processedSVG:gmatch('fill="#d4e0f1"') do
    secondaryCount = secondaryCount + 1
end

print("Final counts:")
print("Primary color replacements: " .. primaryCount)
print("Secondary color replacements: " .. secondaryCount)
print("Remaining class attributes: " .. #processedSVG:gmatch('class="'))
