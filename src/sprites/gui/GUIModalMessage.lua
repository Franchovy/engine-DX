local gfx <const> = playdate.graphics

---@class GUIModalMessage : _Sprite
GUIModalMessage = Class("GUIModalMessage", gfx.sprite)

local _instance

---@return GUIModalMessage
function GUIModalMessage.getInstance()
    return _instance
end

function GUIModalMessage.destroy()
    _instance = nil
end

function GUIModalMessage.showMessage(message)
    -- Build image
    _instance:buildImage(message)

    -- Show message coming in from bottom right
    local xStart, yStart = 410, 170
    local xEnd = 240

    _instance:moveTo(xStart, yStart)
    _instance:add()

    local timerIn = playdate.frameTimer.new(30, xStart, xEnd, playdate.easingFunctions.inOutExpo)

    local updateCallback = function(timer)
        _instance:moveTo(timer.value, yStart)
    end

    timerIn.updateCallback = updateCallback

    timerIn.timerEndedCallback = function(timer)
        local timerOut = playdate.frameTimer.new(30, xEnd, xStart, playdate.easingFunctions.inOutExpo)

        _instance:moveTo(timer.value, yStart)

        timerOut.delay = 150
        timerOut.updateCallback = updateCallback

        timerOut.timerEndedCallback = function(timer)
            _instance:remove()
        end
    end
end

function GUIModalMessage:init()
    GUIModalMessage.super.init(self)

    self:setIgnoresDrawOffset(true)
    self:setZIndex(Z_INDEX.HUD.MainPlus)
    self:setCenter(0, 0)

    _instance = self
end

function GUIModalMessage:buildImage(text)
    local image = gfx.image.new(150, 50)

    gfx.setFont(Fonts.Dialog)
    gfx.pushContext(image)

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(0, 0, 150, 50, 5)

    gfx.setColor(gfx.kColorBlack)

    gfx.setLineWidth(2)
    gfx.drawRoundRect(2, 2, 146, 46, 3)

    gfx.drawTextInRect(text, 5, 5, 140, 40)

    gfx.popContext()

    self:setImage(image)
end
