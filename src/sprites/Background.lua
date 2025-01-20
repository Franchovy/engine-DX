local gfx <const> = playdate.graphics

local image <const> = assert(gfx.image.new(assets.images.background))

--- @class Background : playdate.graphics.sprite
Background = Class("Background", gfx.sprite)

function Background:init()
    Background.super.init(self)

    self:setSize(400, 240)
    self:setIgnoresDrawOffset(true)
    self:setZIndex(Z_INDEX.Level.Background)
    self:setCenter(0, 0)
    self:moveTo(0, 0)
end

function Background:draw(x, y, width, height)
    image:draw(0, 0)
end

function Background:update()
    Background.super.update(self)

    self:markDirty()
end
