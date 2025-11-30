-- Fixed converter for amAAVE SVGs - more robust color replacement
-- This script fixes: missing eyes, incorrect body colors, and style block issues

-- Load modules
local SVGParser = dofile("svg-parser.lua")
local SVGRenderer = dofile("svg-renderer-professional.lua")

-- amAAVE colors (from aavegotchi_db_collaterals_haunt1.json)
local amAAVEColors = {
    primaryColor = "#b6509e",
    secondaryColor = "#cfeef4",
    cheekColor = "#f696c6"
}

-- More robust color replacement - replaces ALL class attributes with fill attributes
local function applyColors(svgString)
    local processedSVG = svgString
    
    -- CRITICAL: Remove ALL style blocks first using a more robust method
    -- Find the start and end of style blocks manually
    while true do
        local styleStart = processedSVG:find('<style')
        if not styleStart then break end
        
        local styleEnd = processedSVG:find('</style>', styleStart)
        if styleEnd then
            processedSVG = processedSVG:sub(1, styleStart - 1) .. processedSVG:sub(styleEnd + 8)
        else
            -- Malformed style tag, try to find just the opening tag
            local tagEnd = processedSVG:find('>', styleStart)
            if tagEnd then
                processedSVG = processedSVG:sub(1, styleStart - 1) .. processedSVG:sub(tagEnd + 1)
            else
                break
            end
        end
    end
    
    -- Replace ALL class attributes with fill attributes
    -- Handle all variations: class="gotchi-primary", class="gotchi-primary gotchi-secondary", etc.
    
    -- First pass: replace classes on any element (groups, paths, rects, etc.)
    -- Use a pattern that matches the entire class attribute value
    processedSVG = processedSVG:gsub('class="([^"]*gotchi%-primary[^"]*)"', 'fill="' .. amAAVEColors.primaryColor .. '"')
    processedSVG = processedSVG:gsub('class="([^"]*gotchi%-secondary[^"]*)"', 'fill="' .. amAAVEColors.secondaryColor .. '"')
    processedSVG = processedSVG:gsub('class="([^"]*gotchi%-eyeColor[^"]*)"', 'fill="' .. amAAVEColors.primaryColor .. '"')
    processedSVG = processedSVG:gsub('class="([^"]*gotchi%-primary%-mouth[^"]*)"', 'fill="' .. amAAVEColors.primaryColor .. '"')
    processedSVG = processedSVG:gsub('class="([^"]*gotchi%-cheek[^"]*)"', 'fill="' .. amAAVEColors.cheekColor .. '"')
    
    return processedSVG
end

-- Process a single SVG
local function processSVG(svgString, outputName)
    print("Processing: " .. outputName)
    
    -- Apply color replacement
    local coloredSVG = applyColors(svgString)
    
    -- Debug: show first 500 chars of processed SVG
    print("  Processed SVG preview (first 500 chars):")
    print("  " .. coloredSVG:sub(1, 500))
    print("")
    
    -- Wrap in proper SVG structure if not already wrapped
    local wrappedSVG = coloredSVG
    if not coloredSVG:match('^<svg') then
        wrappedSVG = string.format([[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">%s</svg>]], coloredSVG)
    end
    
    -- Check if style block was removed
    if wrappedSVG:match('<style') then
        print("  WARNING: Style block still present!")
    else
        print("  Style block removed successfully")
    end
    
    -- Count color replacements
    local primaryCount = 0
    for _ in wrappedSVG:gmatch('fill="' .. amAAVEColors.primaryColor .. '"') do
        primaryCount = primaryCount + 1
    end
    local secondaryCount = 0
    for _ in wrappedSVG:gmatch('fill="' .. amAAVEColors.secondaryColor .. '"') do
        secondaryCount = secondaryCount + 1
    end
    print("  Color replacements: " .. primaryCount .. " primary, " .. secondaryCount .. " secondary")
    print("")
    
    -- Parse SVG
    local svgData = SVGParser.parse(wrappedSVG)
    if not svgData or not svgData.viewBox then
        print("  ERROR: Could not parse SVG")
        return false
    end
    
    print("  Parsed " .. #svgData.elements .. " elements")
    
    -- Check element types
    local pathCount = 0
    local rectCount = 0
    for _, elem in ipairs(svgData.elements) do
        if elem.type == "path" then pathCount = pathCount + 1
        elseif elem.type == "rect" then rectCount = rectCount + 1 end
    end
    print("  Element breakdown: " .. pathCount .. " paths, " .. rectCount .. " rects")
    print("")
    
    -- Render SVG to pixels
    local renderResult = SVGRenderer.render(svgData, 64, 64)
    if not renderResult or not renderResult.pixels or #renderResult.pixels == 0 then
        print("  ERROR: No pixels rendered from SVG")
        return false
    end
    
    print("  Rendered " .. #renderResult.pixels .. " pixels")
    
    -- Create 64x64 sprite
    local sprite = Sprite(64, 64, ColorMode.RGB)
    local layer = sprite.layers[1]
    local cel = sprite:newCel(layer, 1)
    local image = cel.image
    
    -- Clear canvas to transparent
    app.transaction(function()
        for y = 0, 63 do
            for x = 0, 63 do
                image:drawPixel(x, y, Color{r = 0, g = 0, b = 0, a = 0})
            end
        end
    end)
    
    -- Draw SVG pixels
    local pixelsPlaced = 0
    app.transaction(function()
        for _, pixel in ipairs(renderResult.pixels) do
            if pixel.x >= 0 and pixel.x < 64 and pixel.y >= 0 and pixel.y < 64 then
                local color = Color{r = pixel.color.r, g = pixel.color.g, b = pixel.color.b}
                image:drawPixel(pixel.x, pixel.y, color)
                pixelsPlaced = pixelsPlaced + 1
            end
        end
    end)
    
    print("  Placed " .. pixelsPlaced .. " pixels on 64x64 canvas")
    print("")
    
    -- Save as Aseprite file
    local outputPath = "output/" .. outputName .. ".aseprite"
    app.command.SaveFileAs{
        ui = false,
        filename = outputPath
    }
    
    sprite:close()
    
    print("  Saved: " .. outputPath)
    print("")
    
    return true, pixelsPlaced
end

-- Test SVG from user (front view)
local testSVG = [[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><g class="gotchi-bg"><defs fill="#fff"><pattern id="a" patternUnits="userSpaceOnUse" width="4" height="4"><path d="M0 0h1v1H0zm2 2h1v1H2z"/></pattern><pattern id="b" patternUnits="userSpaceOnUse" x="0" y="0" width="2" height="2"><path d="M0 0h1v1H0z"/></pattern><pattern id="c" patternUnits="userSpaceOnUse" x="-2" y="0" width="8" height="1"><path d="M0 0h1v1H0zm2 0h1v1H2zm2 0h1v1H4z"/></pattern><pattern id="d" patternUnits="userSpaceOnUse" x="0" y="0" width="4" height="4"><path d="M0 0h1v1H0zm0 2h1v1H0zm1 0V1h1v1zm1 0h1v1H2zm0-1h1V0H2zm1 2h1v1H3z"/></pattern><pattern id="e" patternUnits="userSpaceOnUse" width="64" height="32"><path d="M4 4h1v1H4zm7 0h1v1h-1zm7 0h1v1h-1zm7 0h1v1h-1zm7 0h1v1h-1zm7 0h1v1h-1zm7 0h1v1h-1zm7 0h1v1h-1zm7 0h1v1h-1z"/><path fill="url(#a)" d="M0 8h64v7H0z"/><path fill="url(#b)" d="M0 16h64v1H0z"/><path fill="url(#c)" d="M0 18h64v1H0z"/><path fill="url(#b)" d="M22 18h15v1H22zM0 20h64v3H0z"/><path fill="url(#d)" d="M0 24h64v8H0z"/></pattern><mask id="f"><path fill="url(#e)" d="M0 0h64v32H0z"/></mask></defs><path fill="#fff" d="M0 0h64v32H0z"/><path fill="#dea8ff" class="gotchi-secondary" mask="url(#f)" d="M0 0h64v32H0z"/><path fill="#dea8ff" class="gotchi-secondary" d="M0 32h64v32H0z"/><path mask="url(#f)" fill="#fff" transform="matrix(1 0 0 -1 0 64)" d="M0 0h64v32H0z"/></g><style>.gotchi-primary{fill:#FF2A7A;}.gotchi-secondary{fill:#FFC3DF;}.gotchi-cheek{fill:#F696C6;}.gotchi-eyeColor{fill:#FF2A7A;}.gotchi-primary-mouth{fill:#FF2A7A;}.gotchi-sleeves-up{display:none;}.gotchi-handsUp{display:none;}.gotchi-handsDownOpen{display:block;}.gotchi-handsDownClosed{display:none;}</style><g class="gotchi-body"><path d="M47 14v-2h-2v-2h-4V8h-4V6H27v2h-4v2h-4v2h-2v2h-2v41h4v-2h5v2h5v-2h6v2h5v-2h5v2h4V14z" class="gotchi-primary"/><path d="M45 14v-2h-4v-2h-4V8H27v2h-4v2h-4v2h-2v39h2v-2h5v2h5v-2h6v2h5v-2h5v2h2V14z" class="gotchi-secondary"/><path d="M18,49h2v-1h2v1h2v2h5v-2h2v-1h2v1h2v2h5v-2h2v-1h2v1h1V14h-4v-2h-4v-2h-5V9h-5v2h-4v2h-4v2h-1V49z" fill="#fff"/></g><path class="gotchi-cheek" d="M21 32v2h2v-2h-1zm21 0h-1v2h2v-2z"/><g class="gotchi-primary-mouth"><path d="M29 32h-2v2h2v-1z"/><path d="M33 34h-4v2h6v-2h-1z"/><path d="M36 32h-1v2h2v-2z"/></g><g class="gotchi-shadow"><path opacity=".25" d="M25 58H19v1h1v1h24V59h1V58h-1z" fill="#000"/></g><g class="gotchi-collateral"><path d="M30 9V8h-1v1h-1v2h1v1h2V9z" fill="#ffc2db"/><path d="M28 7V6h-1v2h2V7z" fill="#ffdeec"/><path d="M26 5h1v1h-1z" fill="#fff"/><path d="M33 13v-2h-1v1h-1v1h-2v1h1v1h4v-2z" fill="#ff88b8"/><g fill="#ff3085"><path d="M27 5V4h-1V3h-1v3h1V5z"/><path d="M27 5h1v1h-1z"/><path d="M28 6h1v1h-1z"/><path d="M29 7h1v1h-1z"/><path d="M30 8h1v1h-1zm-2 1h1V8h-2v3h1z"/><path d="M31 13v-1h-2v-1h-1v3h1v-1z"/><path d="M31 12h1v-1h1v-1h-1V9h-1z"/><path d="M34 12v-1h-1v2h1v2h1v-3z"/><path d="M30 15v-1h-1v2h5v-1zm-4-9h1v2h-1z"/></g></g><g class="gotchi-eyeColor"><rect x="22" y="28" width="6" height="6" transform="rotate(-90 22 28)" /><rect x="36" y="22" width="6" height="6" /></g><g class="gotchi-handsDownClosed"><g class="gotchi-primary"><path d="M19 42h1v1h-1zm1-6h1v1h-1z"/><path d="M21 37h1v1h-1zm5 3v4h1v-4zm-5 3h-1v1h2v-1z"/><path d="M24 44h-2v1h4v-1h-1zm1-5h-1v1h2v-1z"/><path d="M23 38h-1v1h2v-1z"/></g><g class="gotchi-secondary"><path d="M19 43h1v1h-1zm5 2h-2v1h4v-1h-1z"/><path d="M27 41v3h1v-3zm-6 3h-1v1h2v-1z"/><path d="M26 44h1v1h-1zm-7-3h-1v2h1v-1z"/></g><g class="gotchi-primary"><path d="M44 42h1v1h-1zm-1-6h1v1h-1z"/><path d="M42 37h1v1h-1z"/><path d="M42 39v-1h-2v1h1zm0 4v1h2v-1h-1z"/><path d="M40 44h-2v1h4v-1h-1z"/><path d="M38 42v-2h-1v4h1v-1z"/><path d="M40 40v-1h-2v1h1z"/></g><g class="gotchi-secondary"><path d="M42 44v1h2v-1h-1zm-5-2v-1h-1v3h1v-1z"/><path d="M40 45h-2v1h4v-1h-1z"/><path d="M37 44h1v1h-1zm7-1h1v1h-1z"/></g></g><g class="gotchi-handsDownOpen"><g class="gotchi-primary"><path d="M56 38v-1h-2v-1h-2v-1h-1v-1h-1v-1h-1v8h1v1h2v1h4v-1h1v-4z"/></g><g class="gotchi-secondary"><path d="M54 38v-1h-2v-1h-1v-1h-1v-1h-1v6h1v1h2v1h4v-4z" /></g><path d="M54,38v-1h-2v-1h-1v-1h-1v-1h-1v5h1v1h2v1h4v-3H54z" fill="#fff"/><g class="gotchi-primary"><path d="M8 38v-1h2v-1h2v-1h1v-1h1v-1h1v8h-1v1h-2v1H8v-1H7v-4z"/></g><g class="gotchi-secondary"><path d="M10 38v-1h2v-1h1v-1h1v-1h1v6h-1v1h-2v1H8v-4z" /></g><path d="M8,38v3h4v-1h2v-1h1v-5h-1v1h-1v1h-1v1h-2v1H8z" fill="#fff"/></g><g class="gotchi-handsUp"><g class="gotchi-secondary"><path d="M50,38h1v1h-1V38z"/><path d="M49 39h1v1h-1v-1zm2-2h1v1h-1v-1z"/><path d="M52,36h2v1h-2V36z"/><path d="M54,35h2v1h-2V35z"/></g><path d="M52,32v1h-2v1h-1v5h1v-1h1v-1h1v-1h2v-1h2v-3H52z" fill="#fff"/><g class="gotchi-primary"><path d="M49,33h1v1h-1V33z"/><path d="M50 32h2v1h-2v-1zm0 7h1v1h-1v-1z"/><path d="M49 40h1v1h-1v-1zm2-2h1v1h-1v-1z"/><path d="M52 37h2v1h-2v-1zm0-6h4v1h-4v-1z"/><path d="M56,32h1v4h-1V32z"/><path d="M54,36h2v1h-2V36z"/></g><g class="gotchi-secondary"><path d="M13,38h1v1h-1V38z"/><path d="M14 39h1v1h-1v-1zm-2-2h1v1h-1v-1z"/><path d="M10,36h2v1h-2V36z"/><path d="M8,35h2v1H8V35z"/></g><path d="M8,32v3h2v1h2v1h1v1h1v1h1v-5h-1v-1h-2v-1H8z" fill="#fff"/><g class="gotchi-primary"><path d="M14,33h1v1h-1V33z"/><path d="M12 32h2v1h-2v-1zm1 7h1v1h-1v-1z"/><path d="M14 40h1v1h-1v-1zm-2-2h1v1h-1v-1z"/><path d="M10 37h2v1h-2v-1zm-2-6h4v1H8v-1z"/><path d="M7,32h1v4H7V32z"/><path d="M8,36h2v1H8V36z"/></g></g></svg>]]

-- Process test SVG
print("=== Testing amAAVE Front View Conversion (Fixed) ===")
print("")

local success = processSVG(testSVG, "amAAVE_front_fixed")

if success then
    print("SUCCESS: Conversion completed!")
else
    print("ERROR: Conversion failed!")
end

