local gfx <const> = playdate.graphics
local geo <const> = playdate.geometry

local images <const> = {
    assert(gfx.image.new(assets.images.background)),
    assert(gfx.image.new(assets.images.background2))
}
local backgroundImages <const> = {}

--- @class Background: _Sprite
Background = Class("Background", gfx.sprite)

local levelBounds
local _instance

-- Static Methods

function Background.getInstance() return assert(_instance) end

function Background.load(config)
    if not _instance then return end

    if config then
        _instance:enterLevel(Game.getLevelName())

        _instance:add()
    else
        _instance:remove()
    end
end

-- Instance Methods

function Background:init()
    Background.super.init(self)

    self:setSize(400, 240)
    self:setIgnoresDrawOffset(true)
    self:setZIndex(Z_INDEX.Level.Background)
    self:setCenter(0, 0)
    self:moveTo(0, 0)

    for _, image in ipairs(images) do
        local backgroundImage = gfx.image.new(800, image.height)

        gfx.pushContext(backgroundImage)

        local xDraw = 0
        repeat
            image:draw(xDraw, 0)
            xDraw += image.width
        until xDraw > 800

        gfx.popContext()

        table.insert(backgroundImages, backgroundImage)
    end

    self.previousOffset = {}
    self.paralaxOffsets = { 1 }
    self.verticalOffsets = { 1 }

    _instance = self
end

function Background:draw(dirtyX, dirtyY, dirtyWidth, dirtyHeight)
    local xDrawOffset, yDrawOffset = Camera.getDrawOffset()

    local xCrop, yCrop = 0, 0
    local rightCrop, bottomCrop = 400, 240

    if levelBounds then
        xCrop, yCrop =
            math.max(0, xDrawOffset + levelBounds.x),
            math.max(0, yDrawOffset + levelBounds.y)
        rightCrop, bottomCrop =
            math.min(400, xDrawOffset + levelBounds.right - xCrop),
            math.min(240, yDrawOffset + levelBounds.bottom - yCrop)
    end

    for i = #backgroundImages, 1, -1 do
        local image = backgroundImages[i]

        local imageX, imageY = self.paralaxOffsets[i], self.verticalOffsets[i]

        if not imageX or not imageY then
            goto continue
        end

        local x, y, w, h

        x, y, w, h = xCrop, yCrop, rightCrop, math.min(bottomCrop, image.height)

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

    if Settings.get(SETTINGS.PerformanceMode) then
        return
    end

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
