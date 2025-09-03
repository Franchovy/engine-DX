local gfx <const> = playdate.graphics

--- @class LevelEnd : Entity
LevelEnd = Class("LevelEnd", Entity)

function LevelEnd:init(entityData, levelName)
    LevelEnd.super.init(self, entityData, levelName)

    -- Collisions

    self:setGroups(GROUPS.Overlap)
end

function LevelEnd:activate()
    -- Trigger level end
    Manager.emitEvent(EVENTS.WorldComplete)
end
