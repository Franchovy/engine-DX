local gfx <const> = playdate.graphics

--- @class GUILightingEffect: _Sprite
GUILightingEffect = Class("GUILightingEffect", gfx.sprite)

local _instance

local maskImage
local imageBackground

-- Template effects

local imageLargeCircle
local imageSmallCircle
local imageFadeMedium
local imageFadeLight

---@type {any : {image: _Image, xPrevious: number, yPrevious: number}}
local effects <const> = {}

-- Static methods

---@return GUILightingEffect
function GUILightingEffect.getInstance() return assert(_instance) end

function GUILightingEffect.load(config)
    if not _instance then return end

    if config.background == "light" then
        _instance:addEffect(Game.getLevelName(), GUILightingEffect.imageFadeLight)
    elseif config.background == "medium" then
        _instance:addEffect(Game.getLevelName(), GUILightingEffect.imageFadeMedium)
    else
        _instance:removeEffect(Game.getLevelName())
    end
end

-- Instance methods

function GUILightingEffect:init()
    GUILightingEffect.super.init(self)

    -- Create image and get mask

    self:createBackgroundImages()

    self:setImage(imageBackground)

    -- Images to be used for mask

    self:createFadeImages()
    self:createCircleImages()

    -- Sprite config

    self:setCenter(0, 0)
    self:setIgnoresDrawOffset(true)
    self:setZIndex(Z_INDEX.Level.Overlay)

    _instance = self
end

function GUILightingEffect:createBackgroundImages()
    imageBackground = gfx.image.new(400, 240, gfx.kColorClear)
    maskImage = imageBackground:getMaskImage()
end

function GUILightingEffect:createFadeImages()
    -- Medium-dark background
    imageFadeMedium = gfx.image.new(400, 240, gfx.kColorBlack)

    gfx.pushContext(imageFadeMedium)
    gfx.setColor(gfx.kColorWhite)
    gfx.setDitherPattern(0.3, gfx.image.kDitherTypeDiagonalLine)
    gfx.fillRect(0, 0, 400, 240)
    gfx.popContext()

    -- Light background
    imageFadeLight = gfx.image.new(400, 240, gfx.kColorBlack)

    gfx.pushContext(imageFadeLight)
    gfx.setColor(gfx.kColorWhite)
    gfx.setDitherPattern(0.7, gfx.image.kDitherTypeDiagonalLine)
    gfx.fillRect(0, 0, 400, 240)
    gfx.popContext()

    GUILightingEffect.imageFadeMedium = imageFadeMedium
    GUILightingEffect.imageFadeLight = imageFadeLight
end

function GUILightingEffect:createCircleImages()
    imageLargeCircle = gfx.image.new(200, 200)
    imageSmallCircle = gfx.image.new(100, 100)

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

    -- Set static references to effects
    GUILightingEffect.imageLargeCircle = imageLargeCircle
    GUILightingEffect.imageSmallCircle = imageSmallCircle
end

---@param sprite _Sprite|any Sprite or (table/object with and x and y) to track effect, or simply a reference for the effect. Needs x and y or the effect will be placed at 0, 0.
---@param image _Image image for effect (should be black & white, applicable as a mask)
function GUILightingEffect:addEffect(sprite, image)
    effects[sprite] = {
        image = image,
        xPrevious = nil,
        yPrevious = nil
    }
end

---@param sprite _Sprite|any Sprite or reference for which to remove effect
function GUILightingEffect:removeEffect(sprite)
    effects[sprite] = nil
end

function GUILightingEffect:update()
    GUILightingEffect.super.update(self)

    self:makeEffect()
end

function GUILightingEffect:makeEffect() -- First loop to check for changes in lighting
    -- First loop to check for changes in lighting

    local applychanges = false

    for sprite, config in pairs(effects) do
        if sprite.x and sprite.y
            and (sprite.x ~= config.xPrevious
                or sprite.y ~= config.yPrevious) then
            applychanges = true
            break
        end
    end

    if not applychanges then
        return
    end

    -- Get draw offset
    local xOffset, yOffset = gfx.getDrawOffset()

    -- Clear image mask

    maskImage:clear(gfx.kColorWhite)

    -- Draw each sprite's effect

    local drawModeOriginal = gfx.getImageDrawMode()
    gfx.setImageDrawMode(gfx.kDrawModeWhiteTransparent)
    gfx.pushContext(maskImage)

    -- Second loop to apply changes if needed

    for sprite, config in pairs(effects) do
        local x, y = 200, 120
        if sprite.x and sprite.y then
            -- Update last drawn position
            config.xPrevious, config.yPrevious = x, y

            -- Set draw x and y subtracting offset
            x = sprite.x + xOffset
            y = sprite.y + yOffset
        end

        -- FRANCH: This is a work-around to the light not showing up on the first frame.
        if sprite.add then
            sprite:add()
        end

        -- Draw effect image onto mask image
        config.image:drawCentered(x, y)
    end

    -- Reset draw context

    gfx.popContext()
    gfx.setImageDrawMode(drawModeOriginal)

    -- Mark sprite as dirty

    self:markDirty()
end
