local gfx <const> = playdate.graphics

---@class WorldComplete : Room
WorldComplete = Class("WorldComplete", Room)


function WorldComplete:init()
end

function WorldComplete:enter(previous, currentLevelName, nextLevelName)
    gfx.setDrawOffset(0, 0)

    playdate.timer.performAfterDelay(5000, function()
        Game.loadAndEnter(nextLevelName)
    end)
end

function WorldComplete:leave()

end

function WorldComplete:draw()
    local drawModePrev = gfx.getImageDrawMode()
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned("Level Complete, bro!", 200, 110, kTextAlignment.center)

    gfx.setImageDrawMode(drawModePrev)
end
