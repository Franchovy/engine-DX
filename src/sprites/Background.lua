local gfx <const> = playdate.graphics
local geo <const> = playdate.geometry

local image <const> = assert(gfx.image.new(assets.images.background))
local backgroundImage <const> = gfx.image.new(image.width * 2, image.height)

--- @class Background : playdate.graphics.sprite
Background = Class("Background", gfx.sprite)

function Background:init()
    Background.super.init(self)

    self:setSize(400, 240)
    self:setIgnoresDrawOffset(true)
    self:setZIndex(Z_INDEX.Level.Background)
    self:setCenter(0, 0)
    self:moveTo(0, 0)

    gfx.pushContext(backgroundImage)
    image:draw(0, 0)
    image:draw(image.width, 0)
    gfx.popContext()

    self.paralaxOffsets = { 1 }
end

function Background:draw(dirtyX, dirtyY, dirtyWidth, dirtyHeight)
    local imageX = self.paralaxOffset
    local x, y, w, h
    if imageX < 0 then
        --
        x, y, w, h = geo.rect.fast_intersection(dirtyX, dirtyY, dirtyWidth, dirtyHeight, 0, 0, 400,
            backgroundImage.height)
    else
        --
        x, y, w, h = geo.rect.fast_intersection(dirtyX, dirtyY, dirtyWidth, dirtyHeight, imageX, 0, backgroundImage
            .width,
            backgroundImage.height)
    end

    backgroundImage:draw(x, y, gfx.kImageUnflipped, -self.paralaxOffset + x, y, w, h)
end

function Background:update()
    Background.super.update(self)

    local offset = gfx.getDrawOffset() * 0.3 % image.width

    if offset ~= self.previousOffset then
        self.paralaxOffset = offset % 400 - 400

        self:markDirty()
    end

    self.previousOffset = offset
end
