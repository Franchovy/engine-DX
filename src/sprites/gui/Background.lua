local gfx <const> = playdate.graphics
local geo <const> = playdate.geometry

local images <const> = {
    assert(gfx.image.new(assets.images.background)),
    assert(gfx.image.new(assets.images.background2))
}
local backgroundImages <const> = {}

local levelBounds

--- @class Background: _Sprite
Background = Class("Background", gfx.sprite)

function Background:init()
    Background.super.init(self)

    self:setSize(400, 240)
    self:setIgnoresDrawOffset(true)
    self:setZIndex(Z_INDEX.Level.Background)
    self:setCenter(0, 0)
    self:moveTo(0, 0)

    for _, image in ipairs(images) do
        local backgroundImage = gfx.image.new(image.width * 2, image.height)

        gfx.pushContext(backgroundImage)
        image:draw(0, 0)
        image:draw(image.width, 0)
        gfx.popContext()

        table.insert(backgroundImages, backgroundImage)
    end

    self.previousOffset = {}
    self.paralaxOffsets = { 1 }
    self.verticalOffsets = { 1 }
end

function Background:draw(dirtyX, dirtyY, dirtyWidth, dirtyHeight)
    for i = #backgroundImages, 1, -1 do
        local image = backgroundImages[i]

        local imageX, imageY = self.paralaxOffsets[i], self.verticalOffsets[i]

        if not imageX or not imageY then
            goto continue
        end

        local x, y, w, h

        if imageX < 0 then
            x, y, w, h = 0, 0, 400, image.height
        else
            x, y, w, h = imageX, 0, image.width, image.height
        end

        local drawX, drawY, drawWidth, drawHeight = geo.rect.fast_intersection(dirtyX, dirtyY, dirtyWidth, dirtyHeight, x,
            y, w, h)

        image:draw(drawX, drawY, gfx.kImageUnflipped, -imageX + drawX, drawY, drawWidth,
            drawHeight)

        ::continue::
    end
end

function Background.enterLevel(levelNew)
    levelBounds = LDtk.get_rect(levelNew)
end

function Background:update()
    Background.super.update(self)

    local offsetX, offsetY = gfx.getDrawOffset()

    if self.previousOffset.x ~= offsetX or self.previousOffset.y ~= offsetY then
        for i = 1, #images do
            local parallaxOffsetX = offsetX * (0.3 / i) % images[i].width
            self.paralaxOffsets[i] = parallaxOffsetX % 400 - 400

            --local parallaxOffsetY = offsetY + levelBounds.y * (0.1 / i)
            --self.verticalOffsets[i] = math.min(math.max(parallaxOffsetY, 0), 800) -- Clamp to bounds
        end

        self:markDirty()
    end

    self.previousOffset.x, self.previousOffset.y = offsetX, offsetY
end
