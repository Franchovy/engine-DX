local gfx <const> = playdate.graphics

--- @class GUILightingEffect: _Sprite
GUILightingEffect = Class("GUILightingEffect", gfx.sprite)

function GUILightingEffect:init()
    GUILightingEffect.super.init(self)

    local image = gfx.image.new(800, 480)

    gfx.pushContext(image)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, image:getSize())
    gfx.popContext()

    local imageCenterX, imageCenterY = image.width / 2, image.height / 2
    local ditherPattern = gfx.image.kDitherTypeBayer2x2

    if not CONFIG.ADD_SUPER_DARKNESS_EFFECT then
        local maskImage = gfx.image.new(image:getSize())
        gfx.pushContext(maskImage)

        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, maskImage:getSize())

        gfx.setColor(gfx.kColorBlack)

        gfx.setDitherPattern(0.6, ditherPattern)
        gfx.fillCircleAtPoint(imageCenterX, imageCenterY, 95)

        gfx.setDitherPattern(0.3, ditherPattern)
        gfx.fillCircleAtPoint(imageCenterX, imageCenterY, 90)

        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(imageCenterX, imageCenterY, 80)
        gfx.popContext()

        image:setMaskImage(maskImage)
    end

    self:setImage(image)
    self:setZIndex(Z_INDEX.Level.Overlay)
end

function GUILightingEffect:update()
    GUILightingEffect.super.update(self)

    local player = Player:getInstance()
    if player then
        self:moveTo(player.x, player.y)
    end
end
