local gfx <const> = playdate.graphics

---@class WorldComplete : Room
WorldComplete = Class("WorldComplete", Room)

local sprite = gfx.sprite.new()

function WorldComplete:init()
end

function WorldComplete:enter(previous, currentLevelName, nextLevelName)
    gfx.setDrawOffset(0, 0)

    sprite:setSize(400, 240)
    sprite:moveTo(200, 120)
    sprite:add()

    if nextLevelName then
        playdate.timer.performAfterDelay(5000, function()
            Transition:getInstance():fadeOut(1600, function()
                Game.loadAndEnter(nextLevelName)
            end)
        end)
    end
end

function WorldComplete:leave()
    sprite:remove()
end

function sprite:draw(x, y, width, height)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 400, 240)

    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned("World Complete!", 200, 120, kTextAlignment.center)
end
