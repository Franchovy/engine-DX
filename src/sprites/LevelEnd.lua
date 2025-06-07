local gfx <const> = playdate.graphics

--- @class LevelEnd : playdate.graphics.sprite
LevelEnd = Class("LevelEnd", gfx.sprite)

function LevelEnd:init(entity)
    LevelEnd.super.init(self)

    print("Added level end")

    -- Collisions

    self:setGroups(GROUPS.Overlap)
end

function LevelEnd:activate()
    -- Trigger level end
    Manager.emitEvent(EVENTS.WorldComplete)
end
