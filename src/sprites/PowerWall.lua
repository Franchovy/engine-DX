local gfx = playdate.graphics

Powerwall = Class("Powerwall", gfx.sprite)

function Powerwall:init(entity)
    Powerwall.super.init(self)

    self:setTag(TAGS.Powerwall)
    self:setCenter(0, 0)
    self:setSize(entity.size.width, entity.size.height)
end

function Powerwall:postInit()
    printTable(self)
end
