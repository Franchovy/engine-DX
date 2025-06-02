local gfx = playdate.graphics

Powerwall = Class("Powerwall", gfx.sprite)

function Powerwall:init(entity)
    Powerwall.super.init(self)

    -- Collisions

    self:setTag(TAGS.Powerwall)
    self:setGroups(GROUPS.Overlap)

    -- Sprite config

    self:setCenter(0, 0)
    self:setSize(entity.size.width, entity.size.height)
end

function Powerwall:postInit()

end
