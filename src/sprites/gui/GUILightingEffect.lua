local gfx <const> = playdate.graphics

--- @class GUILightingEffect: _Sprite
GUILightingEffect = Class("GUILightingEffect", gfx.sprite)

local _instance

local maskImage
local imageLargeCircle = gfx.image.new(200, 200)
local imageSmallCircle = gfx.image.new(100, 100)

---@type {_Sprite : {image: _Image, xPrevious: number, yPrevious: number}}
local effects <const> = {}

---@return GUILightingEffect
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

---@param sprite _Sprite Sprite to track effect
---@param size 1|2 area size, small or large respectively
function GUILightingEffect:addEffect(sprite, size)
    local image = size == 1 and imageSmallCircle or imageLargeCircle

    effects[sprite] = {
        image = image,
        xPrevious = nil,
        yPrevious = nil
    }
end

---@param sprite _Sprite Sprite to track effect
function GUILightingEffect:removeEffect(sprite)
    effects[sprite] = nil
end

function GUILightingEffect:update()
    GUILightingEffect.super.update(self)

    self:makeEffect()
end

function GUILightingEffect:makeEffect()
    local xOffset, yOffset = gfx.getDrawOffset()

    local hasImageMaskClear = false

    -- Draw each sprite's effect

    local drawModeOriginal = gfx.getImageDrawMode()
    gfx.setImageDrawMode(gfx.kDrawModeWhiteTransparent)
    gfx.pushContext(maskImage)

    for sprite, config in pairs(effects) do
        -- FRANCH: This is a work-around to the light not showing up on the first frame.
        sprite:add()

        if sprite.x ~= config.xPrevious or sprite.y ~= config.yPrevious then
            if not hasImageMaskClear then
                -- Clear image mask

                maskImage:clear(gfx.kColorWhite)
                hasImageMaskClear = true
            end

            -- Update position
            config.xPrevious, config.yPrevious = sprite.x, sprite.y

            -- Draw effect image onto mask image
            local xTarget, yTarget = xOffset + sprite.x, yOffset + sprite.y
            config.image:drawCentered(xTarget, yTarget)

            -- Mark sprite as dirty

            self:markDirty()
        end
    end

    gfx.popContext()
    gfx.setImageDrawMode(drawModeOriginal)
end
