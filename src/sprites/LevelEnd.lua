local gfx <const> = playdate.graphics

--- @class LevelEnd : playdate.graphics.sprite
LevelEnd = Class("LevelEnd", gfx.sprite)

function LevelEnd:init(entity)
    LevelEnd.super.init(self)
end

function LevelEnd:activate()
    -- Trigger level end
end
