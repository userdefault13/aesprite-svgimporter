-- Clean SVG Renderer for Aavegotchi SVGs
-- Converts path elements to pixels with proper scaling

local SVGRenderer = {}

-- Bresenham's line algorithm with sub-pixel precision
-- Maintains float coordinates for geometric precision
local function bresenhamLine(x0, y0, x1, y1)
    local pixels = {}
    
    -- Validate inputs
    if not x0 or not y0 or not x1 or not y1 then
        return pixels
    end
    
    -- Check for NaN or Infinity
    if x0 ~= x0 or y0 ~= y0 or x1 ~= x1 or y1 ~= y1 then
        return pixels
    end
    
    if math.abs(x0) == math.huge or math.abs(y0) == math.huge or 
       math.abs(x1) == math.huge or math.abs(y1) == math.huge then
        return pixels
    end
    
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx - dy
    
    local x, y = x0, y0
    
    -- Safety limit: maximum pixels per line
    local maxPixels = 10000
    local pixelCount = 0
    
    while pixelCount < maxPixels do
        pixelCount = pixelCount + 1
        -- Store float coordinates for geometric precision
        table.insert(pixels, {x = x, y = y})
        
        -- Use sub-pixel threshold for termination
        if math.abs(x - x1) < 0.5 and math.abs(y - y1) < 0.5 then break end
        
        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x = x + sx
        end
        if e2 < dx then
            err = err + dx
            y = y + sy
        end
    end
    
    return pixels
end

-- Convert path commands to pixel coordinates with proper viewBox handling
local function pathToPixels(pathCommands, scale, offsetX, offsetY, viewBoxX, viewBoxY)
    local pixels = {}
    local currentX, currentY = 0, 0
    local startX, startY = 0, 0
    
    for _, command in ipairs(pathCommands) do
        if command.type == "M" then
            -- Move to position (absolute or relative)
            if #command.params >= 2 then
                if command.isRelative then
                    currentX = currentX + command.params[1] * scale
                    currentY = currentY + command.params[2] * scale
                else
                    currentX = (command.params[1] - viewBoxX) * scale + offsetX
                    currentY = (command.params[2] - viewBoxY) * scale + offsetY
                end
                startX, startY = currentX, currentY
            end
        elseif command.type == "L" then
            -- Line to position (absolute or relative)
            if #command.params >= 2 then
                local endX, endY
                if command.isRelative then
                    endX = currentX + command.params[1] * scale
                    endY = currentY + command.params[2] * scale
                else
                    endX = (command.params[1] - viewBoxX) * scale + offsetX
                    endY = (command.params[2] - viewBoxY) * scale + offsetY
                end
                
                -- Add line pixels
                local linePixels = bresenhamLine(currentX, currentY, endX, endY)
                for _, pixel in ipairs(linePixels) do
                    table.insert(pixels, pixel)
                end
                
                currentX, currentY = endX, endY
            end
        elseif command.type == "H" then
            -- Horizontal line (absolute or relative)
            if #command.params >= 1 then
                local endX
                if command.isRelative then
                    endX = currentX + command.params[1] * scale
                else
                    endX = (command.params[1] - viewBoxX) * scale + offsetX
                end
                local linePixels = bresenhamLine(currentX, currentY, endX, currentY)
                for _, pixel in ipairs(linePixels) do
                    table.insert(pixels, pixel)
                end
                currentX = endX
            end
        elseif command.type == "V" then
            -- Vertical line (absolute or relative)
            if #command.params >= 1 then
                local endY
                if command.isRelative then
                    endY = currentY + command.params[1] * scale
                else
                    endY = (command.params[1] - viewBoxY) * scale + offsetY
                end
                local linePixels = bresenhamLine(currentX, currentY, currentX, endY)
                for _, pixel in ipairs(linePixels) do
                    table.insert(pixels, pixel)
                end
                currentY = endY
            end
        elseif command.type == "Z" then
            -- Close path
            if currentX ~= startX or currentY ~= startY then
                local linePixels = bresenhamLine(currentX, currentY, startX, startY)
                for _, pixel in ipairs(linePixels) do
                    table.insert(pixels, pixel)
                end
                currentX, currentY = startX, startY
            end
        end
    end
    
    return pixels
end

-- Improved point-in-polygon test using winding number algorithm
-- More robust for complex shapes than simple ray casting
local function pointInPolygon(x, y, polygon)
    if #polygon < 3 then return false end
    
    local winding = 0
    local n = #polygon
    
    for i = 1, n do
        local j = (i % n) + 1
        local xi, yi = polygon[i].x, polygon[i].y
        local xj, yj = polygon[j].x, polygon[j].y
        
        if yi <= y then
            if yj > y then
                -- Upward crossing
                local cross = (xj - xi) * (y - yi) - (x - xi) * (yj - yi)
                if cross > 0 then
                    winding = winding + 1
                end
            end
        else
            if yj <= y then
                -- Downward crossing
                local cross = (xj - xi) * (y - yi) - (x - xi) * (yj - yi)
                if cross < 0 then
                    winding = winding - 1
                end
            end
        end
    end
    
    return winding ~= 0
end

-- Fill closed paths with sub-pixel precision
-- Tests at pixel centers (0.5, 0.5) for better accuracy on small shapes
local function fillPath(pathPoints, width, height, color)
    local filledPixels = {}
    
    if #pathPoints < 3 then
        return filledPixels
    end
    
    -- Find bounding box (maintain float precision)
    local minX, maxX = pathPoints[1].x, pathPoints[1].x
    local minY, maxY = pathPoints[1].y, pathPoints[1].y
    
    for _, point in ipairs(pathPoints) do
        if point and point.x and point.y then
            minX = math.min(minX, point.x)
            maxX = math.max(maxX, point.x)
            minY = math.min(minY, point.y)
            maxY = math.max(maxY, point.y)
        end
    end
    
    -- Debug: Check if test pixel (2,40) is in bounds
    local isBlackPath = (color.r == 0 and color.g == 0 and color.b == 0)
    if isBlackPath then
        print(string.format("BLACK PATH - BBox: X[%.1f to %.1f], Y[%.1f to %.1f], Points: %d", 
            minX, maxX, minY, maxY, #pathPoints))
        if 2 >= minX and 2 <= maxX and 40 >= minY and 40 <= maxY then
            print("  → Pixel (2,40) IS in bounding box!")
        else
            print("  → Pixel (2,40) NOT in bounding box")
        end
    end
    
    -- Safety check: limit fill area to prevent hanging
    local fillArea = (maxX - minX) * (maxY - minY)
    local MAX_FILL_AREA = 50000 -- Increased limit for complex shapes
    
    if fillArea > MAX_FILL_AREA then
        -- Skip fill for very large areas
        if isBlackPath then
            print(string.format("  → SKIPPED: Area %.0f > %d", fillArea, MAX_FILL_AREA))
        end
        return filledPixels
    end
    
    -- Fill using point-in-polygon test at pixel centers
    for y = math.floor(minY), math.ceil(maxY) do
        for x = math.floor(minX), math.ceil(maxX) do
            if x >= 0 and x < width and y >= 0 and y < height then
                -- Test at pixel center (0.5, 0.5) for geometric precision
                local inside = pointInPolygon(x + 0.5, y + 0.5, pathPoints)
                
                -- Debug specific pixel
                if isBlackPath and x == 2 and y == 40 then
                    print(string.format("  Testing pixel (2,40) at center (2.5,40.5): %s", 
                        inside and "INSIDE" or "OUTSIDE"))
                end
                
                if inside then
                    table.insert(filledPixels, {
                        x = x,
                        y = y,
                        color = color
                    })
                    
                    -- Debug pixel addition
                    if isBlackPath and x == 2 and y == 40 then
                        print("  → Pixel (2,40) ADDED to filledPixels!")
                    end
                end
            end
        end
    end
    
    return filledPixels
end

-- Render a single path element with error handling
local function renderPath(path, viewBox, targetWidth, targetHeight)
    local pixels = {}
    
    -- Validate inputs
    if not path or not path.pathCommands or #path.pathCommands == 0 then
        return pixels
    end
    
    if not viewBox or not viewBox.width or not viewBox.height then
        return pixels
    end
    
    -- Calculate scaling with safety checks
    local scaleX = targetWidth / viewBox.width
    local scaleY = targetHeight / viewBox.height
    local scale = math.min(scaleX, scaleY)
    
    if not scale or scale <= 0 or scale ~= scale then -- Check for NaN
        return pixels
    end
    
    -- Calculate offset to center the content
    local scaledWidth = viewBox.width * scale
    local scaledHeight = viewBox.height * scale
    local offsetX = math.floor((targetWidth - scaledWidth) / 2)
    local offsetY = math.floor((targetHeight - scaledHeight) / 2)
    
    -- Convert path to pixels with error handling
    local success, pathPixels = pcall(pathToPixels, path.pathCommands, scale, offsetX, offsetY, viewBox.x or 0, viewBox.y or 0)
    if not success then
        return pixels
    end
    
    local pathPoints = {}
    
    -- Collect points for filling, removing consecutive duplicates
    -- Duplicates break the winding number algorithm
    local lastX, lastY = nil, nil
    for _, pixel in ipairs(pathPixels) do
        if pixel and pixel.x and pixel.y then
            -- Only add if different from last point (epsilon for float comparison)
            if not lastX or math.abs(pixel.x - lastX) > 0.01 or math.abs(pixel.y - lastY) > 0.01 then
                table.insert(pathPoints, {x = pixel.x, y = pixel.y})
                lastX, lastY = pixel.x, pixel.y
            end
        end
    end
    
    -- Add outline pixels (round to integers at final stage)
    for _, pixel in ipairs(pathPixels) do
        if pixel and pixel.x and pixel.y then
            local px = math.floor(pixel.x + 0.5)
            local py = math.floor(pixel.y + 0.5)
            if px >= 0 and px < targetWidth and py >= 0 and py < targetHeight then
                table.insert(pixels, {
                    x = px,
                    y = py,
                    color = path.fill
                })
            end
        end
    end
    
    -- Add fill pixels if we have enough points for a closed shape
    if #pathPoints >= 3 then
        local success2, filledPixels = pcall(fillPath, pathPoints, targetWidth, targetHeight, path.fill)
        if success2 and filledPixels then
            local isBlackPath = (path.fill.r == 0 and path.fill.g == 0 and path.fill.b == 0)
            local foundTestPixel = false
            
            for _, pixel in ipairs(filledPixels) do
                if pixel and pixel.x and pixel.y and pixel.color then
                    table.insert(pixels, {
                        x = pixel.x,
                        y = pixel.y,
                        color = pixel.color
                    })
                    
                    -- Debug: Check if we're adding (2,40)
                    if isBlackPath and pixel.x == 2 and pixel.y == 40 then
                        foundTestPixel = true
                    end
                end
            end
            
            if isBlackPath then
                print(string.format("BLACK PATH - Added %d fill pixels to render queue", #filledPixels))
                if foundTestPixel then
                    print("  → Pixel (2,40) WAS added to final render queue!")
                else
                    print("  → Pixel (2,40) NOT found in final render queue")
                end
            end
        else
            if path.fill.r == 0 and path.fill.g == 0 and path.fill.b == 0 then
                print("BLACK PATH - Fill call FAILED: " .. tostring(filledPixels))
            end
        end
    end
    
    return pixels
end

-- Main rendering function with error handling
function SVGRenderer.render(svgData, targetWidth, targetHeight)
    local result = {
        width = targetWidth,
        height = targetHeight,
        pixels = {}
    }
    
    -- Validate inputs
    if not svgData or not svgData.elements then
        return result
    end
    
    if not targetWidth or not targetHeight or targetWidth <= 0 or targetHeight <= 0 then
        return result
    end
    
    -- Render all path elements with error handling
    for i, path in ipairs(svgData.elements) do
        local success, pathPixels = pcall(renderPath, path, svgData.viewBox, targetWidth, targetHeight)
        if success and pathPixels then
            local colorHex = string.format("#%02x%02x%02x", path.fill.r, path.fill.g, path.fill.b)
            
            for _, pixel in ipairs(pathPixels) do
                if pixel and pixel.x and pixel.y and pixel.color then
                    -- Debug: Track what paints at (2,40)
                    if pixel.x == 2 and pixel.y == 40 then
                        print(string.format("Element #%d (%s) painting at (2,40)", i, colorHex))
                    end
                    
                    table.insert(result.pixels, pixel)
                end
            end
        end
    end
    
    return result
end

return SVGRenderer
