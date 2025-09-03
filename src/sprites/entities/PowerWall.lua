local gfx = playdate.graphics

--- @class Powerwall : Entity
Powerwall = Class("Powerwall", Entity)

function Powerwall:init(entityData, levelName)
    Powerwall.super.init(self, entityData, levelName)

    -- Collisions

    self:setTag(TAGS.Powerwall)
    self:setGroups(GROUPS.Overlap)

    -- Sprite config

    self:setCenter(0, 0)
    self:setSize(entityData.size.width, entityData.size.height)
end

function Powerwall:activate()
    Manager.emitEvent(EVENTS.ChipSetPower, true)
end
