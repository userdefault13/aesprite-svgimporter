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
-- MULTI-PATH FILL (for paths with holes)
-- ============================================================================

-- Build edges from multiple sub-paths (handles holes correctly)
local function buildEdgesFromMultiPath(allPoints)
    local edges = {}
    local currentSubPath = {}
    
    for i, point in ipairs(allPoints) do
        if point.isSubPathEnd then
            -- End of current sub-path, build its edges
            if #currentSubPath >= 3 then
                local subEdges = buildEdgeTable(currentSubPath)
                for _, edge in ipairs(subEdges) do
                    table.insert(edges, edge)
                end
            end
            currentSubPath = {}
        else
            table.insert(currentSubPath, point)
        end
    end
    
    -- Handle last sub-path
    if #currentSubPath >= 3 then
        local subEdges = buildEdgeTable(currentSubPath)
        for _, edge in ipairs(subEdges) do
            table.insert(edges, edge)
        end
    end
    
    return edges
end

-- Scanline fill for multiple sub-paths with non-zero winding rule
local function scanlineFillNonZeroMultiPath(allPoints, width, height, color)
    local pixels = {}
    
    if #allPoints < 3 then
        return pixels
    end
    
    -- Build edges from all sub-paths
    local edges = buildEdgesFromMultiPath(allPoints)
    
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

-- Integer-only scanline fill for multiple sub-paths
local function scanlineFillIntegerMultiPath(allPoints, width, height, color)
    local pixels = {}
    
    if #allPoints < 3 then
        return pixels
    end
    
    -- Build edges from all sub-paths
    local edges = {}
    local currentSubPath = {}
    
    for i, point in ipairs(allPoints) do
        if point.isSubPathEnd then
            -- Process completed sub-path
            if #currentSubPath >= 3 then
                local n = #currentSubPath
                for j = 1, n do
                    local k = (j % n) + 1
                    local x1, y1 = currentSubPath[j].x, currentSubPath[j].y
                    local x2, y2 = currentSubPath[k].x, currentSubPath[k].y
                    
                    if math.floor(y1) ~= math.floor(y2) then
                        local py1, py2 = math.floor(y1), math.floor(y2)
                        local edge
                        if py1 < py2 then
                            edge = {
                                yMin = py1,
                                yMax = py2,
                                x = x1,
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
            end
            currentSubPath = {}
        else
            table.insert(currentSubPath, point)
        end
    end
    
    -- Handle last sub-path
    if #currentSubPath >= 3 then
        local n = #currentSubPath
        for j = 1, n do
            local k = (j % n) + 1
            local x1, y1 = currentSubPath[j].x, currentSubPath[j].y
            local x2, y2 = currentSubPath[k].x, currentSubPath[k].y
            
            if math.floor(y1) ~= math.floor(y2) then
                local py1, py2 = math.floor(y1), math.floor(y2)
                local edge
                if py1 < py2 then
                    edge = {
                        yMin = py1,
                        yMax = py2,
                        x = x1,
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
    
    minY = math.max(0, minY)
    maxY = math.min(height - 1, maxY)
    
    -- Process each scanline
    for y = minY, maxY do
        local crossings = {}
        
        for _, edge in ipairs(edges) do
            if y >= edge.yMin and y < edge.yMax then
                local x = edge.x + (y + 0.5 - edge.yMin) * edge.dx
                table.insert(crossings, {x = x, winding = edge.winding})
            end
        end
        
        table.sort(crossings, function(a, b) return a.x < b.x end)
        
        local windingCount = 0
        local fillStart = nil
        
        for i, crossing in ipairs(crossings) do
            local prevWinding = windingCount
            windingCount = windingCount + crossing.winding
            
            if prevWinding == 0 and windingCount ~= 0 then
                fillStart = crossing.x
            end
            
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
-- initialSX/initialSY are SVG user-space coords for relative M across sub-paths
-- transformFn(x,y) optional: maps SVG user coords before scale/offset
local function subPathToPoints(subPathCommands, scale, offsetX, offsetY, viewBoxX, viewBoxY, initialSX, initialSY, transformFn)
    local points = {}
    local curSX, curSY = initialSX or 0, initialSY or 0
    local startSX, startSY = curSX, curSY
    local currentX, currentY = 0, 0
    local startX, startY = 0, 0
    local hasStart = false
    local lastCubicControlSX, lastCubicControlSY = nil, nil

    local function mapPoint(sx, sy)
        local tx, ty = sx, sy
        if transformFn then
            tx, ty = transformFn(sx, sy)
        end
        local px = (tx - viewBoxX) * scale + offsetX
        local py = (ty - viewBoxY) * scale + offsetY
        return px, py
    end

    local function addCubicPoints(x0, y0, x1, y1, x2, y2, x3, y3)
        local steps = 16
        for step = 1, steps do
            local t = step / steps
            local mt = 1 - t
            local x = mt * mt * mt * x0
                + 3 * mt * mt * t * x1
                + 3 * mt * t * t * x2
                + t * t * t * x3
            local y = mt * mt * mt * y0
                + 3 * mt * mt * t * y1
                + 3 * mt * t * t * y2
                + t * t * t * y3
            local px, py = mapPoint(x, y)
            table.insert(points, {x = px, y = py})
        end
    end

    local function vectorAngle(ux, uy, vx, vy)
        local dot = ux * vx + uy * vy
        local len = math.sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
        if len == 0 then return 0 end
        local value = math.max(-1, math.min(1, dot / len))
        local angle = math.acos(value)
        if ux * vy - uy * vx < 0 then
            angle = -angle
        end
        return angle
    end

    local function addArcPoints(x0, y0, rx, ry, xAxisRotation, largeArcFlag, sweepFlag, x1, y1)
        rx = math.abs(rx or 0)
        ry = math.abs(ry or 0)
        if rx == 0 or ry == 0 or (x0 == x1 and y0 == y1) then
            local px, py = mapPoint(x1, y1)
            table.insert(points, {x = px, y = py})
            return
        end

        local phi = math.rad(xAxisRotation or 0)
        local cosPhi = math.cos(phi)
        local sinPhi = math.sin(phi)
        local dx = (x0 - x1) / 2
        local dy = (y0 - y1) / 2
        local x1p = cosPhi * dx + sinPhi * dy
        local y1p = -sinPhi * dx + cosPhi * dy

        local rxSq = rx * rx
        local rySq = ry * ry
        local x1pSq = x1p * x1p
        local y1pSq = y1p * y1p
        local radiiScale = x1pSq / rxSq + y1pSq / rySq
        if radiiScale > 1 then
            local s = math.sqrt(radiiScale)
            rx = rx * s
            ry = ry * s
            rxSq = rx * rx
            rySq = ry * ry
        end

        local sign = (largeArcFlag == sweepFlag) and -1 or 1
        local numerator = rxSq * rySq - rxSq * y1pSq - rySq * x1pSq
        local denominator = rxSq * y1pSq + rySq * x1pSq
        local coef = 0
        if denominator ~= 0 then
            coef = sign * math.sqrt(math.max(0, numerator / denominator))
        end
        local cxp = coef * ((rx * y1p) / ry)
        local cyp = coef * (-(ry * x1p) / rx)

        local cx = cosPhi * cxp - sinPhi * cyp + (x0 + x1) / 2
        local cy = sinPhi * cxp + cosPhi * cyp + (y0 + y1) / 2
        local ux = (x1p - cxp) / rx
        local uy = (y1p - cyp) / ry
        local vx = (-x1p - cxp) / rx
        local vy = (-y1p - cyp) / ry
        local theta1 = vectorAngle(1, 0, ux, uy)
        local deltaTheta = vectorAngle(ux, uy, vx, vy)

        if sweepFlag == 0 and deltaTheta > 0 then
            deltaTheta = deltaTheta - math.pi * 2
        elseif sweepFlag == 1 and deltaTheta < 0 then
            deltaTheta = deltaTheta + math.pi * 2
        end

        local steps = math.max(4, math.ceil(math.abs(deltaTheta) / (math.pi / 16)))
        for step = 1, steps do
            local theta = theta1 + deltaTheta * (step / steps)
            local x = cosPhi * rx * math.cos(theta) - sinPhi * ry * math.sin(theta) + cx
            local y = sinPhi * rx * math.cos(theta) + cosPhi * ry * math.sin(theta) + cy
            local px, py = mapPoint(x, y)
            table.insert(points, {x = px, y = py})
        end
    end
    
    for _, command in ipairs(subPathCommands) do
        if command.type == "M" then
            for p = 1, #command.params - 1, 2 do
                if command.isRelative then
                    -- Relative moveto continues from previous SVG point (possibly prior sub-path)
                    curSX = curSX + command.params[p]
                    curSY = curSY + command.params[p + 1]
                else
                    curSX = command.params[p]
                    curSY = command.params[p + 1]
                end
                currentX, currentY = mapPoint(curSX, curSY)
                if p == 1 then
                    startX, startY = currentX, currentY
                    startSX, startSY = curSX, curSY
                    hasStart = true
                end
                table.insert(points, {x = currentX, y = currentY})
            end
            lastCubicControlSX, lastCubicControlSY = nil, nil
        elseif command.type == "L" then
            for p = 1, #command.params - 1, 2 do
                if command.isRelative then
                    curSX = curSX + command.params[p]
                    curSY = curSY + command.params[p + 1]
                else
                    curSX = command.params[p]
                    curSY = command.params[p + 1]
                end
                currentX, currentY = mapPoint(curSX, curSY)
                table.insert(points, {x = currentX, y = currentY})
            end
            lastCubicControlSX, lastCubicControlSY = nil, nil
        elseif command.type == "H" then
            for p = 1, #command.params do
                if command.isRelative then
                    curSX = curSX + command.params[p]
                else
                    curSX = command.params[p]
                end
                currentX, currentY = mapPoint(curSX, curSY)
                table.insert(points, {x = currentX, y = currentY})
            end
            lastCubicControlSX, lastCubicControlSY = nil, nil
        elseif command.type == "V" then
            for p = 1, #command.params do
                if command.isRelative then
                    curSY = curSY + command.params[p]
                else
                    curSY = command.params[p]
                end
                currentX, currentY = mapPoint(curSX, curSY)
                table.insert(points, {x = currentX, y = currentY})
            end
            lastCubicControlSX, lastCubicControlSY = nil, nil
        elseif command.type == "C" then
            for p = 1, #command.params - 5, 6 do
                local x1, y1 = command.params[p], command.params[p + 1]
                local x2, y2 = command.params[p + 2], command.params[p + 3]
                local x3, y3 = command.params[p + 4], command.params[p + 5]
                if command.isRelative then
                    x1, y1 = curSX + x1, curSY + y1
                    x2, y2 = curSX + x2, curSY + y2
                    x3, y3 = curSX + x3, curSY + y3
                end
                addCubicPoints(curSX, curSY, x1, y1, x2, y2, x3, y3)
                curSX, curSY = x3, y3
                currentX, currentY = mapPoint(curSX, curSY)
                lastCubicControlSX, lastCubicControlSY = x2, y2
            end
        elseif command.type == "S" then
            for p = 1, #command.params - 3, 4 do
                local x1, y1
                if lastCubicControlSX and lastCubicControlSY then
                    x1 = curSX * 2 - lastCubicControlSX
                    y1 = curSY * 2 - lastCubicControlSY
                else
                    x1, y1 = curSX, curSY
                end
                local x2, y2 = command.params[p], command.params[p + 1]
                local x3, y3 = command.params[p + 2], command.params[p + 3]
                if command.isRelative then
                    x2, y2 = curSX + x2, curSY + y2
                    x3, y3 = curSX + x3, curSY + y3
                end
                addCubicPoints(curSX, curSY, x1, y1, x2, y2, x3, y3)
                curSX, curSY = x3, y3
                currentX, currentY = mapPoint(curSX, curSY)
                lastCubicControlSX, lastCubicControlSY = x2, y2
            end
        elseif command.type == "A" then
            for p = 1, #command.params - 6, 7 do
                local rx = command.params[p]
                local ry = command.params[p + 1]
                local xAxisRotation = command.params[p + 2]
                local largeArcFlag = command.params[p + 3] ~= 0 and 1 or 0
                local sweepFlag = command.params[p + 4] ~= 0 and 1 or 0
                local x = command.params[p + 5]
                local y = command.params[p + 6]
                if command.isRelative then
                    x = curSX + x
                    y = curSY + y
                end
                addArcPoints(curSX, curSY, rx, ry, xAxisRotation, largeArcFlag, sweepFlag, x, y)
                curSX, curSY = x, y
                currentX, currentY = mapPoint(curSX, curSY)
                lastCubicControlSX, lastCubicControlSY = nil, nil
            end
        elseif command.type == "Z" then
            if hasStart and (currentX ~= startX or currentY ~= startY) then
                table.insert(points, {x = startX, y = startY})
            end
            currentX, currentY = startX, startY
            curSX, curSY = startSX, startSY
            lastCubicControlSX, lastCubicControlSY = nil, nil
        end
    end
    
    -- Return screen points plus SVG cursor for the next relative moveto
    return points, currentX, currentY, curSX, curSY
end

-- Parse matrix(a b c d e f) → function(x,y) and optional inverse
local function parseMatrixTransform(transformStr)
    if not transformStr then return nil, nil end
    local a, b, c, d, e, f = transformStr:match(
        "matrix%(%s*([^%s,]+)%s*[,%s]+([^%s,]+)%s*[,%s]+([^%s,]+)%s*[,%s]+([^%s,]+)%s*[,%s]+([^%s,]+)%s*[,%s]+([^%s%)]+)%s*%)"
    )
    if not a then return nil, nil end
    a, b, c, d, e, f = tonumber(a), tonumber(b), tonumber(c), tonumber(d), tonumber(e), tonumber(f)
    if not (a and b and c and d and e and f) then return nil, nil end
    local forward = function(x, y)
        return a * x + c * y + e, b * x + d * y + f
    end
    local det = a * d - b * c
    local inverse = nil
    if det ~= 0 then
        local ia, ib, ic, id = d / det, -b / det, -c / det, a / det
        local ie = -(ia * e + ic * f)
        local iff = -(ib * e + id * f)
        inverse = function(x, y)
            return ia * x + ic * y + ie, ib * x + id * y + iff
        end
    end
    return forward, inverse
end

-- Combine parent svgMatrix with optional path-level matrix(...) transform.
-- When svgMatrix is present, translation lives in the matrix — do not also use svgOffset.
local function resolveElementTransform(element)
    local pathFn, pathInv = parseMatrixTransform(element and element.transform)
    local m = element and element.svgMatrix
    if m then
        local parentFn = function(x, y)
            return m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f
        end
        local det = m.a * m.d - m.b * m.c
        local parentInv = nil
        if det ~= 0 then
            local ia, ib, ic, id = m.d / det, -m.b / det, -m.c / det, m.a / det
            local ie = -(ia * m.e + ic * m.f)
            local iff = -(ib * m.e + id * m.f)
            parentInv = function(x, y)
                return ia * x + ic * y + ie, ib * x + id * y + iff
            end
        end
        if pathFn then
            return function(x, y)
                local px, py = pathFn(x, y)
                return parentFn(px, py)
            end, (parentInv and pathInv) and function(x, y)
                local px, py = parentInv(x, y)
                return pathInv(px, py)
            end or nil
        end
        return parentFn, parentInv
    end
    return pathFn, pathInv
end

-- Convert <rect> geometry to a path element with baked transforms (no svgMatrix).
-- Used by renderRect and by pathCoverage so rects never hit empty coverage.
local function rectToPathElement(rect)
    if not rect or not rect.width or not rect.height then
        return nil
    end
    if rect.width <= 0 or rect.height <= 0 then
        return nil
    end

    local x = rect.x or 0
    local y = rect.y or 0
    local width = rect.width
    local height = rect.height
    local m = rect.svgMatrix
    if m then
        -- Transform rect origin; axis-aligned scale from matrix diagonal
        local x2, y2 = m.a * (x + width) + m.c * y + m.e, m.b * (x + width) + m.d * y + m.f
        local x3, y3 = m.a * x + m.c * (y + height) + m.e, m.b * x + m.d * (y + height) + m.f
        local x0, y0 = m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f
        local minX = math.min(x0, x2, x3)
        local minY = math.min(y0, y2, y3)
        local maxX = math.max(x0, x2, x3)
        local maxY = math.max(y0, y2, y3)
        -- Also include opposite corner
        local x4, y4 = m.a * (x + width) + m.c * (y + height) + m.e, m.b * (x + width) + m.d * (y + height) + m.f
        minX = math.min(minX, x4)
        minY = math.min(minY, y4)
        maxX = math.max(maxX, x4)
        maxY = math.max(maxY, y4)
        x, y = minX, minY
        width, height = maxX - minX, maxY - minY
    else
        local svgOffsetX = (rect.svgOffset and rect.svgOffset.x) or 0
        local svgOffsetY = (rect.svgOffset and rect.svgOffset.y) or 0
        x = x + svgOffsetX
        y = y + svgOffsetY
    end

    if rect.transform then
        local angle, cx, cy = rect.transform:match("rotate%(([^%s,]+)%s*([^%s,]+)%s*([^%)]+)%)")
        if not angle then
            angle = rect.transform:match("rotate%(([^%)]+)%)")
        end
        if angle then
            angle = tonumber(angle) or 0
            if math.abs(math.abs(angle) - 90) < 0.1 then
                width, height = height, width
                if cx and cy then
                    cx, cy = tonumber(cx), tonumber(cy)
                    local oldCenterX = x + width / 2
                    local oldCenterY = y + height / 2
                    if angle < 0 then
                        x = cx - (oldCenterY - cy) - width / 2
                        y = cy + (oldCenterX - cx) - height / 2
                    else
                        x = cx + (oldCenterY - cy) - width / 2
                        y = cy - (oldCenterX - cx) - height / 2
                    end
                end
            end
        end
    end

    return {
        type = "path",
        fill = rect.fill,
        patternId = rect.patternId,
        maskId = rect.maskId,
        opacity = rect.opacity,
        pathCommands = {
            {type = "M", isRelative = false, params = {x, y}},
            {type = "L", isRelative = false, params = {x + width, y}},
            {type = "L", isRelative = false, params = {x + width, y + height}},
            {type = "L", isRelative = false, params = {x, y + height}},
            {type = "Z", isRelative = false, params = {}}
        }
    }
end

-- Normalize geometry for pathCoverage: rects lack pathCommands until converted.
local function coverageGeometry(element)
    if element and element.type == "rect" then
        return rectToPathElement(element)
    end
    return element
end

local function pathCanvasOffsets(path, scale)
    -- svgMatrix already includes translation; only use svgOffset as legacy fallback
    if path and path.svgMatrix then
        return 0, 0
    end
    local offsetX = (path.svgOffset and path.svgOffset.x) or 0
    local offsetY = (path.svgOffset and path.svgOffset.y) or 0
    if scale ~= 1.0 then
        offsetX = offsetX * scale
        offsetY = offsetY * scale
    end
    return offsetX, offsetY
end

-- Build coverage set from path geometry (keys = x + y * width → true)
local function pathCoverage(path, viewBox, targetWidth, targetHeight, transformFn)
    local coverage = {}
    -- Rects have no pathCommands; bake transforms into a path first
    local fromRect = path and path.type == "rect"
    if fromRect then
        path = rectToPathElement(path)
    end
    if not path or not path.pathCommands or #path.pathCommands == 0 then
        return coverage
    end
    local viewBoxX = viewBox.x or 0
    local viewBoxY = viewBox.y or 0
    local scaleX = targetWidth / viewBox.width
    local scaleY = targetHeight / viewBox.height
    local scale = math.min(scaleX, scaleY)
    -- Prefer element svgMatrix; caller transformFn overrides only when explicitly passed.
    -- Baked rect geometry must not re-apply svgMatrix via resolveElementTransform.
    local tf = transformFn
    if fromRect then
        tf = nil
    elseif tf == nil then
        tf = resolveElementTransform(path)
    end
    local offsetX, offsetY = pathCanvasOffsets(path, scale)

    local subPaths = separateSubPaths(path.pathCommands)
    local lastSX, lastSY = 0, 0
    local allPoints = {}
    for _, subPath in ipairs(subPaths) do
        local points, endX, endY, endSX, endSY = subPathToPoints(
            subPath, scale, offsetX, offsetY, viewBoxX, viewBoxY, lastSX, lastSY, tf
        )
        -- Always advance SVG cursor so relative movetos chain correctly
        if endSX then lastSX = endSX end
        if endSY then lastSY = endSY end
        if #points >= 3 then
            if #allPoints > 0 then
                table.insert(allPoints, {isSubPathEnd = true})
            end
            for _, point in ipairs(points) do
                table.insert(allPoints, point)
            end
        end
    end

    if #allPoints < 3 then
        return coverage
    end

    local filled
    if scale == 1.0 then
        filled = scanlineFillIntegerMultiPath(allPoints, targetWidth, targetHeight, {r = 255, g = 255, b = 255})
    else
        filled = scanlineFillNonZeroMultiPath(allPoints, targetWidth, targetHeight, {r = 255, g = 255, b = 255})
    end
    for _, pixel in ipairs(filled) do
        if pixel.x and pixel.y then
            local x = math.floor(pixel.x + 0.5)
            local y = math.floor(pixel.y + 0.5)
            if x >= 0 and x < targetWidth and y >= 0 and y < targetHeight then
                coverage[x + y * targetWidth] = true
            end
        end
    end
    return coverage
end

-- Pre-render a pattern tile into an alpha map (1 = opaque paint)
local function renderPatternTile(pattern, patterns, width, height)
    local tile = { width = width, height = height, cells = {} }
    if not pattern or width <= 0 or height <= 0 then
        return tile
    end

    local viewBox = { x = 0, y = 0, width = width, height = height }

    for _, elem in ipairs(pattern.elements or {}) do
        if elem.patternId and patterns and patterns[elem.patternId] then
            local child = patterns[elem.patternId]
            local cw = math.max(1, math.floor(child.width or 1))
            local ch = math.max(1, math.floor(child.height or 1))
            local childTile = renderPatternTile(child, patterns, cw, ch)
            local shape = pathCoverage(elem, viewBox, width, height, nil)
            local ox = child.x or 0
            local oy = child.y or 0
            for key, _ in pairs(shape) do
                local x = key % width
                local y = math.floor(key / width)
                local lx = math.floor((x - ox) % cw)
                local ly = math.floor((y - oy) % ch)
                if lx < 0 then lx = lx + cw end
                if ly < 0 then ly = ly + ch end
                local childAlpha = childTile.cells[lx + ly * cw]
                if childAlpha and childAlpha > 0 then
                    tile.cells[key] = 1
                end
            end
        else
            local shape = pathCoverage(elem, viewBox, width, height, nil)
            for key, _ in pairs(shape) do
                tile.cells[key] = 1
            end
        end
    end

    return tile
end

local function samplePattern(tile, pattern, x, y)
    if not tile or not pattern then return 0 end
    local w = tile.width
    local h = tile.height
    if w <= 0 or h <= 0 then return 0 end
    local ox = pattern.x or 0
    local oy = pattern.y or 0
    local lx = math.floor((x - ox) % w)
    local ly = math.floor((y - oy) % h)
    if lx < 0 then lx = lx + w end
    if ly < 0 then ly = ly + h end
    return tile.cells[lx + ly * w] or 0
end

local function blendColor(dst, src, opacity)
    opacity = opacity or 1
    if not dst then
        return {
            r = math.floor((src.r or 0) * opacity + 0.5),
            g = math.floor((src.g or 0) * opacity + 0.5),
            b = math.floor((src.b or 0) * opacity + 0.5)
        }
    end
    local inv = 1 - opacity
    return {
        r = math.floor((dst.r or 0) * inv + (src.r or 0) * opacity + 0.5),
        g = math.floor((dst.g or 0) * inv + (src.g or 0) * opacity + 0.5),
        b = math.floor((dst.b or 0) * inv + (src.b or 0) * opacity + 0.5)
    }
end

-- ============================================================================
-- MAIN RENDERING FUNCTIONS
-- ============================================================================

local function renderPath(path, viewBox, targetWidth, targetHeight)
    local pixels = {}
    
    if not path or not path.pathCommands or #path.pathCommands == 0 then
        return pixels
    end
    
    if not viewBox or not viewBox.width or not viewBox.height then
        return pixels
    end
    
    local scaleX = targetWidth / viewBox.width
    local scaleY = targetHeight / viewBox.height
    local scale = math.min(scaleX, scaleY)
    
    if not scale or scale <= 0 or scale ~= scale then
        return pixels
    end
    
    local offsetX, offsetY = pathCanvasOffsets(path, scale)
    local transformFn = resolveElementTransform(path)
    local subPaths = separateSubPaths(path.pathCommands)
    local lastSX, lastSY = 0, 0
    local allPoints = {}
    
    for _, subPath in ipairs(subPaths) do
        local points, endX, endY, endSX, endSY = subPathToPoints(
            subPath, scale, offsetX, offsetY,
            viewBox.x or 0, viewBox.y or 0, lastSX, lastSY, transformFn
        )
        if endSX then lastSX = endSX end
        if endSY then lastSY = endSY end
        
        if #points >= 3 then
            if #allPoints > 0 then
                table.insert(allPoints, {isSubPathEnd = true})
            end
            for _, point in ipairs(points) do
                table.insert(allPoints, point)
            end
        end
    end
    
    if #allPoints >= 3 and path.fill then
        local filledPixels
        if scale == 1.0 then
            filledPixels = scanlineFillIntegerMultiPath(allPoints, targetWidth, targetHeight, path.fill)
        else
            filledPixels = scanlineFillNonZeroMultiPath(allPoints, targetWidth, targetHeight, path.fill)
        end
        
        for _, pixel in ipairs(filledPixels) do
            if pixel and pixel.x and pixel.y and pixel.color then
                table.insert(pixels, pixel)
            end
        end
    end
    
    return pixels
end

local function renderRect(rect, viewBox, targetWidth, targetHeight)
    local path = rectToPathElement(rect)
    if not path then
        return {}
    end
    return renderPath(path, viewBox, targetWidth, targetHeight)
end

function SVGRenderer.render(svgData, targetWidth, targetHeight)
    local result = {
        width = targetWidth,
        height = targetHeight,
        pixels = {}
    }
    
    if not svgData or not svgData.elements then
        return result
    end
    
    if not targetWidth or not targetHeight or targetWidth <= 0 or targetHeight <= 0 then
        return result
    end
    
    local pixelMap = {}
    local patterns = svgData.patterns or {}
    local masks = svgData.masks or {}

    local patternTiles = {}
    for id, pattern in pairs(patterns) do
        local w = math.max(1, math.floor(pattern.width or 1))
        local h = math.max(1, math.floor(pattern.height or 1))
        patternTiles[id] = renderPatternTile(pattern, patterns, w, h)
    end

    local maskMaps = {}
    for id, mask in pairs(masks) do
        local map = {}
        for _, elem in ipairs(mask.elements or {}) do
            local geom = coverageGeometry(elem)
            if not geom then
                -- skip invalid rect / empty geometry
            elseif elem.patternId and patternTiles[elem.patternId] then
                local shape = pathCoverage(geom, svgData.viewBox, targetWidth, targetHeight, nil)
                local tile = patternTiles[elem.patternId]
                local pat = patterns[elem.patternId]
                for key, _ in pairs(shape) do
                    local x = key % targetWidth
                    local y = math.floor(key / targetWidth)
                    if samplePattern(tile, pat, x, y) > 0 then
                        map[key] = 1
                    end
                end
            else
                local shape = pathCoverage(geom, svgData.viewBox, targetWidth, targetHeight, nil)
                for key, _ in pairs(shape) do
                    map[key] = 1
                end
            end
        end
        maskMaps[id] = map
    end

    local function putPixel(x, y, color, opacity)
        if not color then return end
        if x < 0 or x >= targetWidth or y < 0 or y >= targetHeight then return end
        local key = x + y * targetWidth
        local op = opacity or 1
        if op >= 0.999 then
            pixelMap[key] = { x = x, y = y, color = { r = color.r, g = color.g, b = color.b } }
        else
            local existing = pixelMap[key]
            local blended = blendColor(existing and existing.color or nil, color, op)
            pixelMap[key] = { x = x, y = y, color = blended }
        end
    end

    local function paintElement(element)
        local opacity = element.opacity or 1
        local maskMap = element.maskId and maskMaps[element.maskId] or nil
        -- Bake rect transforms into pathCommands; avoid double-applying svgMatrix via transformFn
        local geom = coverageGeometry(element)
        if not geom then
            return
        end
        local transformFn, transformInv
        if element.type == "rect" then
            transformFn, transformInv = nil, nil
        else
            transformFn, transformInv = resolveElementTransform(element)
        end

        local function maskAllows(x, y)
            if not maskMap then return true end
            local mx, my = x, y
            if transformInv then
                mx, my = transformInv(x, y)
                mx = math.floor(mx + 0.5)
                my = math.floor(my + 0.5)
            end
            if mx < 0 or my < 0 or mx >= targetWidth or my >= targetHeight then
                return false
            end
            return maskMap[mx + my * targetWidth] ~= nil
        end

        if element.patternId and patternTiles[element.patternId] then
            local shape = pathCoverage(geom, svgData.viewBox, targetWidth, targetHeight, transformFn)
            local tile = patternTiles[element.patternId]
            local pat = patterns[element.patternId]
            local paint = element.fill or { r = 255, g = 255, b = 255 }
            for key, _ in pairs(shape) do
                local x = key % targetWidth
                local y = math.floor(key / targetWidth)
                if maskAllows(x, y) and samplePattern(tile, pat, x, y) > 0 then
                    putPixel(x, y, paint, opacity)
                end
            end
            return
        end

        if element.fill then
            if maskMap or transformFn then
                local shape = pathCoverage(geom, svgData.viewBox, targetWidth, targetHeight, transformFn)
                for key, _ in pairs(shape) do
                    local x = key % targetWidth
                    local y = math.floor(key / targetWidth)
                    if maskAllows(x, y) then
                        putPixel(x, y, element.fill, opacity)
                    end
                end
            else
                local success, pathPixels
                if element.type == "rect" then
                    success, pathPixels = pcall(renderRect, element, svgData.viewBox, targetWidth, targetHeight)
                else
                    success, pathPixels = pcall(renderPath, element, svgData.viewBox, targetWidth, targetHeight)
                end
                if success and pathPixels then
                    for _, pixel in ipairs(pathPixels) do
                        if pixel and pixel.x and pixel.y and pixel.color then
                            local x = math.floor(pixel.x + 0.5)
                            local y = math.floor(pixel.y + 0.5)
                            putPixel(x, y, pixel.color, opacity)
                        end
                    end
                end
            end
        end
    end
    
    for _, element in ipairs(svgData.elements) do
        if element.type == "path" or element.type == "rect" then
            pcall(paintElement, element)
        end
    end
    
    for _, pixel in pairs(pixelMap) do
        table.insert(result.pixels, pixel)
    end
    
    return result
end

return SVGRenderer
