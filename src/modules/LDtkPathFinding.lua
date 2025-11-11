local gfx <const> = playdate.graphics

LDTkPathFinding = {}

local levels = {}
local locations = {}

local function _hasOverlappingWallSprite(x, y, levelBounds)
    local obstacleSprites = gfx.sprite.querySpritesAtPoint(levelBounds.x + x * 32 + 16,
        levelBounds.y + y * 32 - 16)
    for _, spriteOverlapping in pairs(obstacleSprites) do
        -- If sprite overlapping is wall, then return false
        if spriteOverlapping:getTag() == TAGS.Wall then
            return true
        end
    end

    return false
end

---comment
---@param graph playdate.pathfinder.graph
---@param widthGraph number
---@param callbackShouldAddConnection fun(xNode1: number, yNode1: number, xNode2: number, yNode2: number, xPositionThrough:number, yPositionThrough:number) : boolean
local function _addMissingDiagonalConnections(graph, widthGraph, heightGraph, callbackShouldAddConnection)
    for _, node in pairs(graph:allNodes()) do
        if node.x > 1 and node.y > 1 and callbackShouldAddConnection(node.x, node.y, node.x - 1, node.y - 1, node.x, node.y - 1) then
            node:addConnectionToNodeWithXY(node.x - 1, node.y - 1, 14, true)
        end

        if node.x < widthGraph and node.y > 1 and callbackShouldAddConnection(node.x, node.y, node.x + 1, node.y - 1, node.x, node.y - 1) then
            node:addConnectionToNodeWithXY(node.x + 1, node.y - 1, 14, true)
        end

        if node.x > 1 and node.y < heightGraph and callbackShouldAddConnection(node.x, node.y, node.x - 1, node.y + 1, node.x - 1, node.y) then
            node:addConnectionToNodeWithXY(node.x - 1, node.y + 1, 14, true)
        end

        if node.x < widthGraph and node.y < heightGraph and callbackShouldAddConnection(node.x, node.y, node.x + 1, node.y + 1, node.x + 1, node.y) then
            node:addConnectionToNodeWithXY(node.x + 1, node.y + 1, 14, true)
        end
    end
end

function LDTkPathFinding.load(levelName)
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
        nodes = nodes
    }

    local allSprites = gfx.sprite.getAllSprites()
    for _, sprite in pairs(allSprites) do
        if sprite:getTag() == TAGS.Wall then
            local xStart, xEnd = sprite:left(), sprite:right()
            local y = sprite:top()

            -- Check for overlapping sprites above every x/y tile

            for x = xStart, xEnd, 32 do
                if x == xEnd then
                    goto continue
                end

                local xNode, yNode = x + 16, y - 16

                if _hasOverlappingWallSprite(xNode, yNode, bounds) then
                    goto continue
                end

                -- Add node to grid

                table.insert(locations, { x = xNode, y = yNode })

                local index = (xNode - 16 - bounds.x) / 32 + ((yNode + 16 - bounds.y) / 32) * widthGraph
                nodes[index] = 1

                ::continue::
            end
        end
    end

    level.graph = playdate.pathfinder.graph.new2DGrid(widthGraph, heightGraph, true, nodes)

    -- SDK-bug not adding diagonal connections? - Manually add the diagonal connections in for now.

    _addMissingDiagonalConnections(level.graph, widthGraph, heightGraph,
        function(xNode1, yNode1, xNode2, yNode2, xPositionThrough, yPositionThrough)
            -- Check if through position is free
            if _hasOverlappingWallSprite(xPositionThrough, yPositionThrough, bounds) then
                return false
            end

            -- Check if nodes 1 and 2 position are free
            if _hasOverlappingWallSprite(xNode1, yNode1, bounds) or _hasOverlappingWallSprite(xNode2, yNode2, bounds) then
                return false
            end

            -- Check if nodes 1 and 2 have ground underneath
            if not _hasOverlappingWallSprite(xNode1, yNode1 + 1, bounds) or not _hasOverlappingWallSprite(xNode2, yNode2 + 1, bounds) then
                return false
            end

            return true
        end)

    _addMissingDiagonalConnections(level.graph, widthGraph, heightGraph, function(xPositionToCheck, yPositionToCheck)
        return not _hasOverlappingWallSprite(xPositionToCheck, yPositionToCheck, bounds)
    end)

    --

    levels[levelName] = level

    DebugDrawer.addDebugDrawCall(function()
        ----[[
        for _, node in pairs(level.graph:allNodes()) do
            if #node:connectedNodes() > 1 then
                gfx.drawCircleAtPoint(bounds.x + (node.x * 32 + 16), bounds.y + (node.y * 32 - 16), 5)
            end
        end
        --]]

        ----[[
        for _, location in pairs(locations) do
            gfx.drawCircleAtPoint(location.x, location.y, 2)
        end
        ----]]
    end)
end
