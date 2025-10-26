local gfx <const> = playdate.graphics

--- @class GUILightingEffect: _Sprite
GUILightingEffect = Class("GUILightingEffect", gfx.sprite)

local _instance

local maskImage
local imageLargeCircle = gfx.image.new(200, 200)
local imageSmallCircle = gfx.image.new(100, 100)

local xImageCircleLarge, yImageCircleLarge = 0, 0

function GUILightingEffect.getInstance() return assert(_instance) end

function GUILightingEffect:init()
    GUILightingEffect.super.init(self)

    -- Create image and get mask

    local image = gfx.image.new(400, 240, gfx.kColorClear)
    maskImage = image:getMaskImage()
    self:setImage(image)

    -- Images to be used for mask

    self:createCircleImages()

    -- Sprite config

    self:setCenter(0, 0)
    self:setIgnoresDrawOffset(true)
    self:setZIndex(Z_INDEX.Level.Overlay)

    _instance = self
end

function GUILightingEffect:createCircleImages()
    for _, image in pairs({ imageLargeCircle, imageSmallCircle }) do
        local radius = image:getSize() / 2
        local imageCenterX, imageCenterY = image.width / 2, image.height / 2
        local ditherPattern = gfx.image.kDitherTypeBayer2x2

        gfx.pushContext(image)

        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, image:getSize())

        gfx.setColor(gfx.kColorBlack)

        gfx.setDitherPattern(0.6, ditherPattern)
        gfx.fillCircleAtPoint(imageCenterX, imageCenterY, radius)

        gfx.setDitherPattern(0.3, ditherPattern)
        gfx.fillCircleAtPoint(imageCenterX, imageCenterY, radius - 5)

        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(imageCenterX, imageCenterY, radius - 15)

        gfx.popContext()
    end
end

function GUILightingEffect:update()
    GUILightingEffect.super.update(self)

    -- Get locations to draw circles

    local player = Player:getInstance()
    local xOffset, yOffset = gfx.getDrawOffset()
    local xCircleLarge, yCircleLarge = xOffset + player.x, yOffset + player.y

    -- If circles have moved
    if xImageCircleLarge ~= xCircleLarge or yImageCircleLarge ~= yCircleLarge then
        xImageCircleLarge = xCircleLarge
        yImageCircleLarge = yCircleLarge

        -- Clear image mask

        maskImage:clear(gfx.kColorWhite)

        -- Draw circles onto mask image

        local drawModeOriginal = gfx.getImageDrawMode()
        gfx.pushContext(maskImage)

        gfx.setImageDrawMode(gfx.kDrawModeWhiteTransparent)
        imageLargeCircle:drawCentered(xCircleLarge, yCircleLarge)

        gfx.popContext()
        gfx.setImageDrawMode(drawModeOriginal)

        -- Mark sprite as dirty

        self:markDirty()
    end
end
