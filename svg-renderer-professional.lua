-- Professional SVG Renderer
-- Implements browser-grade rendering algorithms in pure Lua
-- Uses scanline rasterization, Active Edge Table, and non-zero winding rule

local SVGRenderer = {}

-- ============================================================================
-- EDGE STRUCTURE AND EDGE TABLE BUILDING
-- ============================================================================

-- Create an edge from two points
local function createEdge(x1, y1, x2, y2)
    -- Ensure edge goes top to bottom
    if y1 > y2 then
        x1, y1, x2, y2 = x2, y2, x1, y1
    end
    
    -- Skip horizontal edges (they don't contribute to fills)
    if y1 == y2 then
        return nil
    end
    
    return {
        yMin = y1,
        yMax = y2,
        x = x1,  -- x coordinate at yMin
        dx = (x2 - x1) / (y2 - y1),  -- slope: change in x per y
        winding = (y2 > y1) and 1 or -1  -- direction for winding rule
    }
end

-- Build edge table from polygon points
local function buildEdgeTable(points)
    local edges = {}
    local n = #points
    
    if n < 2 then
        return edges
    end
    
    for i = 1, n do
        local j = (i % n) + 1
        local x1, y1 = points[i].x, points[i].y
        local x2, y2 = points[j].x, points[j].y
        
        local edge = createEdge(x1, y1, x2, y2)
        if edge then
            table.insert(edges, edge)
        end
    end
    
    return edges
end

-- ============================================================================
-- SCANLINE FILL ALGORITHM (What browsers use!)
-- ============================================================================

-- Scanline fill with even-odd rule
local function scanlineFillEvenOdd(pathPoints, width, height, color)
    local pixels = {}
    
    if #pathPoints < 3 then
        return pixels
    end
    
    -- Build edge table
    local edges = buildEdgeTable(pathPoints)
    if #edges == 0 then
        return pixels
    end
    
    -- Find Y range
    local minY = math.huge
    local maxY = -math.huge
    for _, edge in ipairs(edges) do
        minY = math.min(minY, edge.yMin)
        maxY = math.max(maxY, edge.yMax)
    end
    
    minY = math.max(0, math.floor(minY))
    maxY = math.min(height - 1, math.ceil(maxY))
    
    -- Process each scanline
    for y = minY, maxY do
        local intersections = {}
        
        -- Find all edges that intersect this scanline
        for _, edge in ipairs(edges) do
            if y >= edge.yMin and y < edge.yMax then
                -- Calculate x intersection
                local x = edge.x + (y - edge.yMin) * edge.dx
                table.insert(intersections, x)
            end
        end
        
        -- Sort intersections by x
        table.sort(intersections)
        
        -- Fill between pairs of intersections (even-odd rule)
        -- Use epsilon to handle floating-point precision
        -- Example: intersections at 0.0 and 34.0 → fill pixels 0 to 33 (34 pixels)
        for i = 1, #intersections - 1, 2 do
            local epsilon = 0.0001
            local xStart = math.max(0, math.floor(intersections[i] + epsilon))
            local xEnd = math.min(width - 1, math.floor(intersections[i + 1] - epsilon))
            
            for x = xStart, xEnd do
                table.insert(pixels, {
                    x = x,
                    y = y,
                    color = color
                })
            end
        end
    end
    
    return pixels
end

-- Scanline fill with non-zero winding rule (browser default)
local function scanlineFillNonZero(pathPoints, width, height, color)
    local pixels = {}
    
    if #pathPoints < 3 then
        return pixels
    end
    
    -- Build directed edges
    local edges = {}
    local n = #pathPoints
    
    for i = 1, n do
        local j = (i % n) + 1
        local x1, y1 = pathPoints[i].x, pathPoints[i].y
        local x2, y2 = pathPoints[j].x, pathPoints[j].y
        
        if y1 ~= y2 then  -- Skip horizontal
            local edge
            if y1 < y2 then
                edge = createEdge(x1, y1, x2, y2)
                edge.winding = 1  -- Downward edge
            else
                edge = createEdge(x2, y2, x1, y1)
                edge.winding = -1  -- Upward edge
            end
            table.insert(edges, edge)
        end
    end
    
    if #edges == 0 then
        return pixels
    end
    
    -- Find bounds
    local minY, maxY = math.huge, -math.huge
    for _, edge in ipairs(edges) do
        minY = math.min(minY, edge.yMin)
        maxY = math.max(maxY, edge.yMax)
    end
    
    minY = math.max(0, math.floor(minY))
    maxY = math.min(height - 1, math.ceil(maxY))
    
    -- Process each scanline
    for y = minY, maxY do
        local crossings = {}
        
        -- Find intersections with winding
        for _, edge in ipairs(edges) do
            if y >= edge.yMin and y < edge.yMax then
                local x = edge.x + (y - edge.yMin) * edge.dx
                table.insert(crossings, {x = x, winding = edge.winding})
            end
        end
        
        -- Sort by x
        table.sort(crossings, function(a, b) return a.x < b.x end)
        
        -- Apply non-zero winding rule
        local windingCount = 0
        local fillStart = nil
        
        for i, crossing in ipairs(crossings) do
            local prevWinding = windingCount
            windingCount = windingCount + crossing.winding
            
            -- Start fill when winding becomes non-zero
            if prevWinding == 0 and windingCount ~= 0 then
                fillStart = crossing.x
            end
            
            -- End fill when winding becomes zero
            -- Use epsilon to handle floating-point precision
            if prevWinding ~= 0 and windingCount == 0 and fillStart then
                local epsilon = 0.0001
                local xStart = math.max(0, math.floor(fillStart + epsilon))
                local xEnd = math.min(width - 1, math.floor(crossing.x - epsilon))
                
                for x = xStart, xEnd do
                    table.insert(pixels, {x = x, y = y, color = color})
                end
                
                fillStart = nil
            end
        end
    end
    
    return pixels
end

-- ============================================================================
-- INTEGER-ONLY SCANLINE FILL (for pixel-perfect 1:1 rendering)
-- ============================================================================

-- Integer-only scanline fill for 1:1 pixel-perfect rendering
-- When viewBox dimensions match canvas dimensions exactly
local function scanlineFillInteger(pathPoints, width, height, color)
    local pixels = {}
    
    if #pathPoints < 3 then
        return pixels
    end
    
    -- Build edges with integer coordinates
    local edges = {}
    local n = #pathPoints
    
    for i = 1, n do
        local j = (i % n) + 1
        local x1, y1 = pathPoints[i].x, pathPoints[i].y
        local x2, y2 = pathPoints[j].x, pathPoints[j].y
        
        -- Convert to integer pixel coordinates
        local px1, py1 = math.floor(x1), math.floor(y1)
        local px2, py2 = math.floor(x2), math.floor(y2)
        
        if py1 ~= py2 then  -- Skip horizontal edges
            local edge
            if py1 < py2 then
                edge = {
                    yMin = py1,
                    yMax = py2,
                    x = x1,  -- Keep fractional for accurate intersection
                    dx = (x2 - x1) / (y2 - y1),
                    winding = 1
                }
            else
                edge = {
                    yMin = py2,
                    yMax = py1,
                    x = x2,
                    dx = (x1 - x2) / (y1 - y2),
                    winding = -1
                }
            end
            table.insert(edges, edge)
        end
    end
    
    if #edges == 0 then
        return pixels
    end
    
    -- Find Y bounds
    local minY, maxY = math.huge, -math.huge
    for _, edge in ipairs(edges) do
        minY = math.min(minY, edge.yMin)
        maxY = math.max(maxY, edge.yMax)
    end
    
    -- Clamp to canvas bounds (0-indexed pixels)
    minY = math.max(0, minY)
    maxY = math.min(height - 1, maxY)
    
    -- Process each scanline with integer math
    for y = minY, maxY do
        local crossings = {}
        
        -- Find intersections
        for _, edge in ipairs(edges) do
            if y >= edge.yMin and y < edge.yMax then
                -- Calculate intersection at pixel center (y + 0.5)
                local x = edge.x + (y + 0.5 - edge.yMin) * edge.dx
                table.insert(crossings, {x = x, winding = edge.winding})
            end
        end
        
        -- Sort by x coordinate
        table.sort(crossings, function(a, b) return a.x < b.x end)
        
        -- Apply non-zero winding rule with integer pixel mapping
        local windingCount = 0
        local fillStart = nil
        
        for i, crossing in ipairs(crossings) do
            local prevWinding = windingCount
            windingCount = windingCount + crossing.winding
            
            -- Start fill when winding becomes non-zero
            if prevWinding == 0 and windingCount ~= 0 then
                fillStart = crossing.x
            end
            
            -- End fill when winding becomes zero
            if prevWinding ~= 0 and windingCount == 0 and fillStart then
                -- Direct integer mapping for pixel-perfect rendering
                -- Round to epsilon to handle floating-point precision issues
                local epsilon = 0.0001
                local xStartRaw = fillStart + epsilon
                local xEndRaw = crossing.x - epsilon
                
                -- Start: first pixel at or after intersection
                -- End: last pixel before intersection
                local xStart = math.max(0, math.floor(xStartRaw))
                local xEnd = math.min(width - 1, math.floor(xEndRaw))
                
                for x = xStart, xEnd do
                    table.insert(pixels, {x = x, y = y, color = color})
                end
                
                fillStart = nil
            end
        end
    end
    
    return pixels
end

-- ============================================================================
-- SUB-PATH HANDLING (for compound paths with multiple M commands)
-- ============================================================================

-- Separate path commands into sub-paths
local function separateSubPaths(pathCommands)
    local subPaths = {}
    local currentSubPath = {}
    
    for _, command in ipairs(pathCommands) do
        if command.type == "M" then
            if #currentSubPath > 0 then
                table.insert(subPaths, currentSubPath)
            end
            currentSubPath = {command}
        else
            table.insert(currentSubPath, command)
        end
    end
    
    if #currentSubPath > 0 then
        table.insert(subPaths, currentSubPath)
    end
    
    return subPaths
end

-- Convert sub-path commands to point array
-- IMPORTANT: initialX/initialY passed in to handle relative moves after Z
local function subPathToPoints(subPathCommands, scale, offsetX, offsetY, viewBoxX, viewBoxY, initialX, initialY)
    local points = {}
    local currentX, currentY = initialX or 0, initialY or 0
    local startX, startY = 0, 0
    
    for _, command in ipairs(subPathCommands) do
        if command.type == "M" then
            -- Move to position
            if #command.params >= 2 then
                if command.isRelative then
                    -- Relative move from CURRENT position
                    currentX = currentX + command.params[1] * scale
                    currentY = currentY + command.params[2] * scale
                else
                    -- Absolute move
                    currentX = (command.params[1] - viewBoxX) * scale + offsetX
                    currentY = (command.params[2] - viewBoxY) * scale + offsetY
                end
                startX, startY = currentX, currentY
                table.insert(points, {x = currentX, y = currentY})
            end
        elseif command.type == "L" then
            -- Line to position
            if #command.params >= 2 then
                local endX, endY
                if command.isRelative then
                    endX = currentX + command.params[1] * scale
                    endY = currentY + command.params[2] * scale
                else
                    endX = (command.params[1] - viewBoxX) * scale + offsetX
                    endY = (command.params[2] - viewBoxY) * scale + offsetY
                end
                
                table.insert(points, {x = endX, y = endY})
                currentX, currentY = endX, endY
            end
        elseif command.type == "H" then
            -- Horizontal line
            if #command.params >= 1 then
                local endX
                if command.isRelative then
                    endX = currentX + command.params[1] * scale
                else
                    endX = (command.params[1] - viewBoxX) * scale + offsetX
                end
                
                table.insert(points, {x = endX, y = currentY})
                currentX = endX
            end
        elseif command.type == "V" then
            -- Vertical line
            if #command.params >= 1 then
                local endY
                if command.isRelative then
                    endY = currentY + command.params[1] * scale
                else
                    endY = (command.params[1] - viewBoxY) * scale + offsetY
                end
                
                table.insert(points, {x = currentX, y = endY})
                currentY = endY
            end
        elseif command.type == "Z" then
            -- Close path - ensure it connects back to start
            if currentX ~= startX or currentY ~= startY then
                table.insert(points, {x = startX, y = startY})
            end
            currentX, currentY = startX, startY
        end
    end
    
    -- Return points and final position for next sub-path
    return points, currentX, currentY
end

-- ============================================================================
-- MAIN RENDERING FUNCTIONS
-- ============================================================================

-- Render a single path element with proper sub-path handling
local function renderPath(path, viewBox, targetWidth, targetHeight)
    local pixels = {}
    
    -- Validate inputs
    if not path or not path.pathCommands or #path.pathCommands == 0 then
        return pixels
    end
    
    if not viewBox or not viewBox.width or not viewBox.height then
        return pixels
    end
    
    -- Calculate scaling to map viewBox coordinates to pixel indices
    -- viewBox "0 0 W H" defines W×H coordinate space
    -- For pixel art, use 1:1 mapping when canvas matches viewBox dimensions
    local viewBoxX = viewBox.x or 0
    local viewBoxY = viewBox.y or 0
    
    local scaleX = targetWidth / viewBox.width
    local scaleY = targetHeight / viewBox.height
    local scale = math.min(scaleX, scaleY)
    
    -- Note: scale == 1.0 triggers optimized integer-only rendering
    -- This avoids floating-point rounding ambiguity for pixel-perfect SVGs
    
    if not scale or scale <= 0 or scale ~= scale then
        return pixels
    end
    
    -- Place at (0,0) - top-left corner, no centering
    local offsetX = 0
    local offsetY = 0
    
    -- Debug: Track max coordinates
    local maxCoordX, maxCoordY = -math.huge, -math.huge
    
    -- Separate into sub-paths
    local subPaths = separateSubPaths(path.pathCommands)
    
    -- Track position across sub-paths for relative moves
    local lastX, lastY = 0, 0
    
    -- Convert each sub-path to points and fill using scanline algorithm
    for _, subPath in ipairs(subPaths) do
        local points, endX, endY = subPathToPoints(subPath, scale, offsetX, offsetY, 
                                                    viewBox.x or 0, viewBox.y or 0, lastX, lastY)
        
        if #points >= 3 then
            -- Update last position for next sub-path (for relative m commands)
            lastX = endX or lastX
            lastY = endY or lastY
            
            -- Choose rendering algorithm based on scale
            local filledPixels
            if scale == 1.0 then
                -- Pixel-perfect 1:1 rendering: use integer-only algorithm
                filledPixels = scanlineFillInteger(points, targetWidth, targetHeight, path.fill)
            else
                -- Scaled rendering: use non-zero winding rule (browser default)
                filledPixels = scanlineFillNonZero(points, targetWidth, targetHeight, path.fill)
            end
            
            for _, pixel in ipairs(filledPixels) do
                if pixel and pixel.x and pixel.y and pixel.color then
                    table.insert(pixels, pixel)
                end
            end
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
            for _, pixel in ipairs(pathPixels) do
                if pixel and pixel.x and pixel.y and pixel.color then
                    table.insert(result.pixels, pixel)
                end
            end
        end
    end
    
    return result
end

return SVGRenderer

