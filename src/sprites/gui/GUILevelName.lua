local gfx <const> = playdate.graphics

local FADE_IN_TIME_MS <const> = 4000
local FADE_OUT_TIME_MS <const> = 3000
local DISPLAY_DURATION_MS <const> = 7000

local animatorFadeIn = gfx.animator.new(FADE_IN_TIME_MS, 0, 1, playdate.easingFunctions.inOutCirc)
local animatorFadeOut = gfx.animator.new(FADE_OUT_TIME_MS, 1, 0, playdate.easingFunctions.inOutCirc)
local animatorFade = gfx.animator.new(0, 0, 0)

--- @class GUILevelName : _Sprite
GUILevelName = Class("GUILevelName", gfx.sprite)

local _instance

function GUILevelName.getInstance()
    return assert(_instance)
end

function GUILevelName.load(config)
    if not _instance then return end

    if config.subtitle then
        _instance.subHeader = config.subtitle
    end

    if config.title then
        _instance.name = config.title
    end

    _instance:rebuildImage()
end

-- Instance Methods

function GUILevelName:init()
    GUILevelName.super.init(self)

    self:setIgnoresDrawOffset(true)
    self:setZIndex(Z_INDEX.HUD.Main)
    self:setCenter(0, 0)
    self:moveTo(20, 180)

    self.subHeader = nil
    self.name = nil

    self.isPresenting = false

    _instance = self
end

function GUILevelName:rebuildImage()
    if self.name == nil and self.subHeader == nil then
        return
    end

    local textSubHeader = self.subHeader or ""
    local textName = self.name or ""

    -- Get current font context
    local fontPrevious = gfx.getFont()
    local drawModePrevious = gfx.getImageDrawMode()

    -- Create text images

    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.setFont(Fonts.Menu.Small)
    local imageTextSubHeader = gfx.imageWithText(textSubHeader, 200, 70)

    gfx.setFont(Fonts.Menu.Large)
    local imageTextTitle = gfx.imageWithText(textName, 300, 70)

    -- Create image to draw on
    local image = gfx.image.new(300, 70)

    -- Draw text images onto main image
    gfx.pushContext(image)

    -- Draw a "shadow" of the text for better white-on-white readability

    local imageTextSubHeaderInverted = imageTextSubHeader:invertedImage()
    local imageTextTitleInverted = imageTextTitle:invertedImage()

    gfx.setImageDrawMode(gfx.kDrawModeWhiteTransparent)

    -- "Top" shadow - dense, 2-px larger than text

    imageTextSubHeaderInverted:draw(-2, 8)
    imageTextTitleInverted:draw(-2, 23)

    imageTextSubHeaderInverted:draw(2, 12)
    imageTextTitleInverted:draw(2, 27)

    -- "Bottom" shadow, looser, blurred image

    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    imageTextSubHeaderInverted:drawBlurred(0, 10, 2, 2, gfx.image.kDitherTypeBayer4x4)
    imageTextTitleInverted:drawBlurred(0, 25, 2, 2, gfx.image.kDitherTypeBayer4x4)

    -- Reset draw mode, draw text

    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)

    imageTextSubHeader:draw(0, 10)
    imageTextTitle:draw(0, 25)

    gfx.popContext()

    -- Restore current draw context
    gfx.setFont(fontPrevious)
    gfx.setImageDrawMode(drawModePrevious)

    -- Set main image
    self.image = image

    self:setSize(image:getSize())
end

function GUILevelName:present()
    if self.name == nil and self.subHeader == nil then
        return
    end

    if not self.image then
        self:rebuildImage()
    end

    self:add()
    self:moveTo(20, 190)

    self.isPresenting = true

    animatorFade = animatorFadeIn
    animatorFadeIn:reset()

    playdate.timer.performAfterDelay(FADE_IN_TIME_MS + DISPLAY_DURATION_MS, function()
        animatorFade = animatorFadeOut
        animatorFadeOut:reset()

        playdate.timer.performAfterDelay(FADE_OUT_TIME_MS, function()
            self.isPresenting = false

            self:remove()
        end)
    end)
end

function GUILevelName:draw(x, y, width, height)
    local image = self.image
    local fadeValue = animatorFade:currentValue()

    ---@cast fadeValue number
    image:drawFaded(0, 0, fadeValue, gfx.image.kDitherTypeBayer8x8)
end

function GUILevelName:update()
    if not animatorFadeIn:ended() or animatorFadeOut:ended() then
        self:markDirty()
    end
end
