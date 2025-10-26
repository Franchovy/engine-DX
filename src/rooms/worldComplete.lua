local gfx <const> = playdate.graphics

---@class WorldComplete : Room
WorldComplete = Class("WorldComplete", Room)

local spriteWorldCompleteText

function WorldComplete:init()
end

function WorldComplete:enter(previous, currentLevelName, nextLevelName)
    gfx.setDrawOffset(0, 0)

    spriteWorldCompleteText = gfx.sprite.spriteWithText("World complete, congratulations!", 200, 60, nil, nil, nil,
        kTextAlignment.center)
    spriteWorldCompleteText:getImage():setInverted(true)
    spriteWorldCompleteText:moveTo(200, 120)
    spriteWorldCompleteText:add()

    playdate.timer.performAfterDelay(5000, function()
        Transition:getInstance():startTransitionWorldComplete(function()
            Game.loadAndEnter(nextLevelName)
        end)
    end)
end

function WorldComplete:leave()
    spriteWorldCompleteText:remove()
    spriteWorldCompleteText = nil
end

function WorldComplete:draw()

end
