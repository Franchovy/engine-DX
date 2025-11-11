local gfx <const> = playdate.graphics

LDTkPathFinding = {}

local locations = {}

function LDTkPathFinding.load(levelName)
    local allSprites = gfx.sprite.getAllSprites()
    for _, sprite in pairs(allSprites) do
        if sprite:getTag() == TAGS.Wall then
            local xStart, xEnd = sprite:left(), sprite:right()
            local y = sprite:top()

            -- Check for overlapping sprites above every x/y tile

            for x = xStart, xEnd, 32 do
                local spritesOverlapping = gfx.sprite.querySpritesAtPoint(x + 16, y - 16)

                for _, spriteOverlapping in pairs(spritesOverlapping) do
                    -- If sprite overlapping is wall, then skip
                    if spriteOverlapping:getTag() == TAGS.Wall then
                        goto continue
                    end
                end

                -- Add node to grid
                print("Adding node to grid: " .. x .. " " .. y)
                table.insert(locations, { x = x, y = y })

                ::continue::
            end
        end
    end

    DebugDrawer.addDebugDrawCall(function()
        for _, location in pairs(locations) do
            gfx.drawCircleAtPoint(location.x, location.y, 5)
        end
    end)
end
