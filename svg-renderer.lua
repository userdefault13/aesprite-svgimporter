-- Clean SVG Renderer for Aavegotchi SVGs
-- Converts path elements to pixels with proper scaling

local SVGRenderer = {}

-- Bresenham's line algorithm
local function bresenhamLine(x0, y0, x1, y1)
    local pixels = {}
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx - dy
    
    local x, y = x0, y0
    
    while true do
        table.insert(pixels, {x = math.floor(x + 0.5), y = math.floor(y + 0.5)})
        
        if x == x1 and y == y1 then break end
        
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

-- Convert path commands to pixel coordinates
local function pathToPixels(pathCommands, scale, offsetX, offsetY)
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
                    currentX = command.params[1] * scale + offsetX
                    currentY = command.params[2] * scale + offsetY
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
                    endX = command.params[1] * scale + offsetX
                    endY = command.params[2] * scale + offsetY
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
                    endX = command.params[1] * scale + offsetX
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
                    endY = command.params[1] * scale + offsetY
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

-- Simple point-in-polygon test for filling
local function pointInPolygon(x, y, polygon)
    local inside = false
    local j = #polygon
    
    for i = 1, #polygon do
        local xi, yi = polygon[i].x, polygon[i].y
        local xj, yj = polygon[j].x, polygon[j].y
        
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    
    return inside
end

-- Fill closed paths
local function fillPath(pathPoints, width, height, color)
    local filledPixels = {}
    
    if #pathPoints < 3 then
        return filledPixels
    end
    
    -- Find bounding box
    local minX, maxX = pathPoints[1].x, pathPoints[1].x
    local minY, maxY = pathPoints[1].y, pathPoints[1].y
    
    for _, point in ipairs(pathPoints) do
        minX = math.min(minX, point.x)
        maxX = math.max(maxX, point.x)
        minY = math.min(minY, point.y)
        maxY = math.max(maxY, point.y)
    end
    
    -- Fill using point-in-polygon test
    for y = math.floor(minY), math.ceil(maxY) do
        for x = math.floor(minX), math.ceil(maxX) do
            if x >= 0 and x < width and y >= 0 and y < height then
                if pointInPolygon(x, y, pathPoints) then
                    table.insert(filledPixels, {
                        x = x,
                        y = y,
                        color = color
                    })
                end
            end
        end
    end
    
    return filledPixels
end

-- Render a single path element
local function renderPath(path, viewBox, targetWidth, targetHeight)
    local pixels = {}
    
    -- Calculate scaling
    local scaleX = targetWidth / viewBox.width
    local scaleY = targetHeight / viewBox.height
    local scale = math.min(scaleX, scaleY)
    
    -- Calculate offset to center the content
    local scaledWidth = viewBox.width * scale
    local scaledHeight = viewBox.height * scale
    local offsetX = math.floor((targetWidth - scaledWidth) / 2)
    local offsetY = math.floor((targetHeight - scaledHeight) / 2)
    
    -- Convert path to pixels
    local pathPixels = pathToPixels(path.pathCommands, scale, offsetX, offsetY)
    local pathPoints = {}
    
    -- Collect points for filling
    for _, pixel in ipairs(pathPixels) do
        table.insert(pathPoints, {x = pixel.x, y = pixel.y})
    end
    
    -- Add outline pixels
    for _, pixel in ipairs(pathPixels) do
        if pixel.x >= 0 and pixel.x < targetWidth and pixel.y >= 0 and pixel.y < targetHeight then
            table.insert(pixels, {
                x = pixel.x,
                y = pixel.y,
                color = path.fill
            })
        end
    end
    
    -- Add fill pixels if we have enough points for a closed shape
    if #pathPoints >= 3 then
        local filledPixels = fillPath(pathPoints, targetWidth, targetHeight, path.fill)
        for _, pixel in ipairs(filledPixels) do
            table.insert(pixels, {
                x = pixel.x,
                y = pixel.y,
                color = pixel.color
            })
        end
    end
    
    return pixels
end

-- Main rendering function
function SVGRenderer.render(svgData, targetWidth, targetHeight)
    local result = {
        width = targetWidth,
        height = targetHeight,
        pixels = {}
    }
    
    -- Render all path elements
    for _, path in ipairs(svgData.elements) do
        local pathPixels = renderPath(path, svgData.viewBox, targetWidth, targetHeight)
        for _, pixel in ipairs(pathPixels) do
            table.insert(result.pixels, pixel)
        end
    end
    
    return result
end

return SVGRenderer
