local gfx <const> = playdate.graphics

local SPRITE_WIDTH <const> = 200
local SPRITE_HEIGHT <const> = 120

-- Local functions
local _ = {}

--- @class GUILevelComplete : playdate.graphics.sprite
GUILevelComplete = Class("GUILevelComplete", gfx.sprite)

function GUILevelComplete:init()
    GUILevelComplete.super.init(self)

    self:setIgnoresDrawOffset(true)
    self:moveTo((400 - SPRITE_WIDTH) / 2, (240 - SPRITE_HEIGHT) / 2)

    -- Build & Set image with text

    self:setImage(_.createTextImage())

    -- Create Blinker

    self.blinker = gfx.animation.blinker.new(700, 300, true)
end

function GUILevelComplete:add()
    GUILevelComplete.super.add(self)

    self.blinker:startLoop()
end

function GUILevelComplete:remove()
    GUILevelComplete.super.remove(self)

    self.blinker:stop()
end

function GUILevelComplete:update()
    self:setVisible(self.blinker.on)
end

-- Local Functions

function _.createTextImage()
    local image = gfx.image.new(SPRITE_WIDTH, SPRITE_HEIGHT)

    gfx.pushContext(image)

    gfx.setFont(Fonts.Menu.Large)
    local fontHeightTitle = Fonts.Menu.Large:getHeight()

    -- Title
    gfx.drawTextAligned("Level Complete", SPRITE_WIDTH / 2, 0, kTextAlignment.center)

    -- Subtitle
    gfx.setFont(Fonts.Menu.Medium)
    gfx.drawTextAligned("Crank To Finish", SPRITE_WIDTH / 2, fontHeightTitle + 20, kTextAlignment.center)

    gfx.popContext()

    return image
end
