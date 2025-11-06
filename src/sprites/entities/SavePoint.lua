local gfx <const> = playdate.graphics

local image <const> = gfx.image.new(150, 150)

---@class SavePont: Entity
SavePoint = Class("SavePoint", Entity)

function SavePoint:init(entityData, levelName)
    SavePoint.super.init(self, entityData, levelName, image)

    -- Entity Config

    self.chipSet = entityData.fields.chipSet

    -- Collisions

    self:setTag(TAGS.SavePoint)
    self:setGroups(GROUPS.Overlap)

    -- State properties

    self.isActivated = false -- entityData.fields.isActivated or false
    self.chipSetCurrentError = nil

    self:setZIndex(Z_INDEX.Level.Neutral)

    -- Update collision rect
    self:setCollideRect(0, 0, self:getSize())
end

function SavePoint:activate()
    if self.isActivated then
        return
    end

    Manager.emitEvent(EVENTS.SavePointSet)
end
