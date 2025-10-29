-- Debug pattern matching for color replacement
local handsSVG = '<g class="gotchi-handsDownClosed"><g class="gotchi-primary"><path d="M19 42h1v1h-1zm1-6h1v1h-1z"/><path d="M21 37h1v1h-1zm5 3v4h1v-4zm-5 3h-1v1h2v-1z"/><path d="M24 44h-2v1h4v-1h-1zm1-5h-1v1h2v-1z"/><path d="M23 38h-1v1h2v-1z"/></g><g class="gotchi-secondary"><path d="M19 43h1v1h-1zm5 2h-2v1h4v-1h-1z"/><path d="M27 41v3h1v-3zm-6 3h-1v1h2v-1z"/><path d="M26 44h1v1h-1zm-7-3h-1v2h1v-1z"/></g><g class="gotchi-primary"><path d="M44 42h1v1h-1zm-1-6h1v1h-1z"/><path d="M42 37h1v1h-1z"/><path d="M42 39v-1h-2v1h1zm0 4v1h2v-1h-1z"/><path d="M40 44h-2v1h4v-1h-1z"/><path d="M38 42v-2h-1v4h1v-1z"/><path d="M40 40v-1h-2v1h1z"/></g><g class="gotchi-secondary"><path d="M42 44v1h2v-1h-1zm-5-2v-1h-1v3h1v-1z"/><path d="M40 45h-2v1h4v-1h-1z"/><path d="M37 44h1v1h-1zm7-1h1v1h-1z"/></g></g>'

print("Original SVG:")
print(handsSVG)
print("")

-- Test different patterns
print("Testing pattern matching:")

-- Pattern 1: Exact match
local test1 = handsSVG:gsub('class="gotchi-primary"', 'fill="#2664ba"')
print("Pattern 1 - Exact match:")
print("Found gotchi-primary: " .. tostring(handsSVG:find('class="gotchi-primary"')))
print("After replacement: " .. tostring(test1:find('class="gotchi-primary"')))
print("")

-- Pattern 2: More flexible
local test2 = handsSVG:gsub('class="gotchi%-primary"', 'fill="#2664ba"')
print("Pattern 2 - Escaped:")
print("After replacement: " .. tostring(test2:find('class="gotchi-primary"')))
print("")

-- Pattern 3: Check what's actually in the string
print("Character analysis:")
for i = 1, math.min(200, #handsSVG) do
    local char = handsSVG:sub(i, i)
    if char == '"' or char == 'c' or char == 'l' or char == 'a' or char == 's' then
        print("Position " .. i .. ": '" .. char .. "'")
    end
end

-- Find all class attributes
print("\nAll class attributes found:")
for class in handsSVG:gmatch('class="([^"]*)"') do
    print("Found class: '" .. class .. "'")
end
