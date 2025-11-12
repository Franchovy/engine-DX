local gfx <const> = playdate.graphics

local SOLID_COLLISION_GROUPS <const> = 2 ^ (GROUPS.Solid - 1) | 2 ^ (GROUPS.SolidExceptElevator - 1)

LDTkPathFinding = {}

---@enum
PATHFINDING_ADDITIONAL_CONFIGURATIONS = {
    UpperRight = 1,
    UpperDoubleRight = 2,
    DoubleRight = 3,
    LowerRight = 4,
    LowerDoubleRight = 5
}

---@alias Level { bounds: playdate.geometry.rect, graph: playdate.pathfinder.graph, nodes: playdate.pathfinder.node, widthGraph: number, heightGraph: number }

---@type {string: Level}
local levels = {}

local function _hasOverlappingWallSprite(x, y)
    local obstacleSprites = gfx.sprite.querySpritesAtPoint(x, y)

    for _, spriteOverlapping in pairs(obstacleSprites) do
        -- If sprite overlapping is wall, then return
        if spriteOverlapping:getGroupMask() & SOLID_COLLISION_GROUPS ~= 0 then
            return true
        end
    end

    return false
end

local PIXELS_PER_BLOCK = 32

local function _convertLevelToGrid(xLevel, yLevel, bounds)
    return (xLevel + 16 - bounds.x) / PIXELS_PER_BLOCK, (yLevel + 16 - bounds.y) / PIXELS_PER_BLOCK
end

local function _convertGridToLevel(xGrid, yGrid, bounds)
    return bounds.x + xGrid * PIXELS_PER_BLOCK - 16, bounds.y + yGrid * PIXELS_PER_BLOCK - 16
end

local function _convertIndexToGrid(index, widthGraph)
    return (index - 1) % widthGraph + 1, index // widthGraph + 1
end

local function _convertGridToIndex(x, y, widthGraph)
    return x + (y - 1) * widthGraph
end

function LDTkPathFinding.load(levelName)
    if levels[levelName] then
        -- Level has already been loaded.
        return
    end

    local bounds = LDtk.get_rect(levelName)

    local widthGraph = bounds.width / 32
    local heightGraph = bounds.height / 32
    local countNodes = widthGraph * heightGraph

    local nodes = table.create(countNodes)
    for i = 1, countNodes do
        nodes[i] = 0
    end

    local level = {
        bounds = bounds,
        graph = nil,
        nodes = nodes,
        widthGraph = widthGraph,
        heightGraph = heightGraph
    }

    local allSprites = gfx.sprite.getAllSprites()
    for _, sprite in pairs(allSprites) do
        if sprite:getTag() == TAGS.Wall then
            local xStart, xEnd = sprite:left(), sprite:right()
            local y = sprite:top()

            -- Check for overlapping sprites above every x/y tile

            for x = xStart, xEnd, 32 do
                -- X and Y-Node represent the point where the node is going to go, i.e. above the "Wall" block.
                local xNode, yNode = x + 16, y - 16

                if xNode > xEnd or yNode < bounds.y then
                    goto continue
                end

                if _hasOverlappingWallSprite(xNode, yNode) then
                    goto continue
                end

                local xGraph, yGraph = _convertLevelToGrid(xNode, yNode, bounds)

                -- Add node to grid

                local index = _convertGridToIndex(xGraph, yGraph, widthGraph)
                assert(index > 0 and index <= widthGraph * heightGraph)
                nodes[index] = 1

                ::continue::
            end
        end
    end

    -- FRANCH: Actually disable the diagonal linking just to be safe, until the SDK updates diagonals and we can remove some of the below config checks.
    level.graph = playdate.pathfinder.graph.new2DGrid(widthGraph, heightGraph, false, nodes)

    -- Set reference to level
    levels[levelName] = level

    -- Add diagonal and non-direct neighbour connections

    LDTkPathFinding.addAdditionalConnections(levelName)

    if playdate.isSimulator then
        DebugDrawer.addDebugDrawCall(function()
            ----[[
            for i, node in pairs(nodes) do
                if node == 1 then
                    local xGrid, yGrid = _convertIndexToGrid(i, widthGraph)
                    local x, y = _convertGridToLevel(xGrid, yGrid, bounds)
                    gfx.drawCircleAtPoint(x, y, 2)
                end
            end
            --]]

            ----[[
            for _, node in pairs(level.graph:allNodes()) do
                if #node:connectedNodes() > 0 then
                    local x, y = _convertGridToLevel(node.x, node.y, bounds)
                    gfx.drawCircleAtPoint(x, y, 4)

                    ----[[
                    for _, connectedNode in pairs(node:connectedNodes()) do
                        local x2, y2 = _convertGridToLevel(connectedNode.x, connectedNode.y, bounds)
                        gfx.drawLine(
                            x,
                            y,
                            x2,
                            y2
                        )
                    end
                end
            end
            --]]
        end)
    end
end

function LDTkPathFinding.addAdditionalConnections(levelName)
    local level = levels[levelName]
    local nodes = level.nodes
    local widthGraph, heightGraph = level.widthGraph, level.heightGraph
    local bounds = LDtk.get_rect(levelName)

    for i, isActive in pairs(nodes) do
        if isActive == 0 then
            goto continue
        end

        local configurations = {}
        local xGraph, yGraph = _convertIndexToGrid(i, widthGraph)
        local x, y = _convertGridToLevel(xGraph, yGraph, bounds)

        local node = assert(level.graph:nodeWithXY(xGraph, yGraph))

        -- If direct right neighbor exists, ignore
        if nodes[_convertGridToIndex(xGraph + 1, yGraph, widthGraph)] == 1 then
            goto continue
        end

        -- Check for upper-right neighbor

        if
            xGraph < widthGraph and
            yGraph > 0 and
            -- Air with ground (Connection point)
            nodes[_convertGridToIndex(xGraph + 1, yGraph - 1, widthGraph)] == 1 and
            -- Space between is clear
            not _hasOverlappingWallSprite(x, y - 32) then
            node:addConnectionToNodeWithXY(xGraph + 1,
                yGraph - 1, 14, true)

            -- No other configurations can work with this.
            goto continue
        end

        -- Check for 2x-right neighbor

        if
            xGraph + 1 < widthGraph and
            -- Air with ground (Connection point)
            nodes[_convertGridToIndex(xGraph + 2, yGraph, widthGraph)] == 1 and
            -- Space between
            not _hasOverlappingWallSprite(x + 32, y) then
            node:addConnectionToNodeWithXY(xGraph + 2,
                yGraph, 20, true)

            configurations[PATHFINDING_ADDITIONAL_CONFIGURATIONS.DoubleRight] = true
        end

        -- Check for lower-right neighbor

        if
            xGraph < widthGraph and
            yGraph < heightGraph and
            -- Air with ground (Connection point)
            nodes[_convertGridToIndex(xGraph + 1, yGraph + 1, widthGraph)] == 1 and
            -- Space between
            not _hasOverlappingWallSprite(x + 32, y) then
            node:addConnectionToNodeWithXY(xGraph + 1,
                yGraph + 1, 14, true)

            configurations[PATHFINDING_ADDITIONAL_CONFIGURATIONS.LowerRight] = true
        end

        -- Check for upper-2x-right neighbor

        if
            xGraph + 1 < widthGraph and
            yGraph > 0 and
            not configurations[PATHFINDING_ADDITIONAL_CONFIGURATIONS.UpperRight] and
            -- Air with ground (Connection point)
            nodes[_convertGridToIndex(xGraph + 2, yGraph - 1, widthGraph)] == 1 and
            -- Space between
            not _hasOverlappingWallSprite(x + 32, y) and
            not _hasOverlappingWallSprite(x + 32, y - 32) then
            node:addConnectionToNodeWithXY(xGraph + 2,
                yGraph - 1, 24, true)

            configurations[PATHFINDING_ADDITIONAL_CONFIGURATIONS.UpperDoubleRight] = true
        end

        -- Check for lower-2x-right neighbor

        if
            xGraph + 1 < widthGraph and
            yGraph < heightGraph and
            not configurations[PATHFINDING_ADDITIONAL_CONFIGURATIONS.LowerRight] and
            not configurations[PATHFINDING_ADDITIONAL_CONFIGURATIONS.UpperRight] and
            -- Air with ground (Connection point)
            nodes[_convertGridToIndex(xGraph + 2, yGraph + 1, widthGraph)] == 1 and
            -- Space between
            not _hasOverlappingWallSprite(x + 32, y) and
            not _hasOverlappingWallSprite(x + 32, y + 32) then
            node:addConnectionToNodeWithXY(xGraph + 2,
                yGraph + 1, 24, true)

            configurations[PATHFINDING_ADDITIONAL_CONFIGURATIONS.LowerDoubleRight] = true
        end

        ::continue::
    end
end

---comment
---@param levelName string
---@param startX number
---@param startY number
---@param endX number
---@param endY number
---@return {x: number, y: number}[]?
function LDTkPathFinding.getPath(levelName, startX, startY, endX, endY)
    if not levels[levelName] then
        return
    end

    local bounds = LDtk.get_rect(levelName)
    local xStartGraph, yStartGraph = _convertLevelToGrid(startX, startY, bounds)
    local xEndGraph, yEndGraph = _convertLevelToGrid(endX, endY, bounds)

    local graph = levels[levelName].graph

    local nodeStart = graph:nodeWithXY(math.round(xStartGraph), math.round(yStartGraph))
    local nodeEnd = graph:nodeWithXY(math.round(xEndGraph), math.round(yEndGraph))

    if not nodeStart or not nodeEnd then
        return
    end

    local nodesPath = graph:findPath(nodeStart, nodeEnd)

    if not nodesPath then
        return
    end

    local pointsPath = {}

    for _, point in ipairs(nodesPath) do
        local x, y = _convertGridToLevel(point.x, point.y, bounds)
        table.insert(pointsPath, { x = x, y = y })
    end

    return pointsPath
end
