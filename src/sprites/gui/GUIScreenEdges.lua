local gfx <const> = playdate.graphics

---@class GUIScreenEdges : _Sprite
GUIScreenEdges = Class("GUIScreenEdges", gfx.sprite)

local startValue <const> = 0
local endValue <const> = 8
local duration <const> = 200

---@type GUIScreenEdges?
local _instance

function GUIScreenEdges.getInstance()
    return assert(_instance, "Instance needs to be created!")
end

function GUIScreenEdges.destroy()
    _instance = nil
end

function GUIScreenEdges:init()
    GUIScreenEdges.super.init(self)

    self:setSize(400, 240)
    self:setIgnoresDrawOffset(true)
    self:setZIndex(Z_INDEX.HUD.Background)
    self:setCenter(0, 0)
    self:moveTo(0, 0)

    self.isActive = false
    self.isActivePrevious = false
    ---@type _Animator?
    self.animator = nil

    _instance = self
end

function GUIScreenEdges:animateIn()
    if self.animator and self.animator.endValue == endValue then
        return
    end

    local startValue = self.animator and self.animator:currentValue() or startValue

    self.animator = gfx.animator.new(duration, startValue, endValue)
end

function GUIScreenEdges:animateOut()
    if self.animator and self.animator.endValue == startValue then
        return
    end

    local endValue = self.animator and self.animator:currentValue() or endValue

    self.animator = gfx.animator.new(duration, endValue, startValue)
end

function GUIScreenEdges:draw()
    if not self.animator then
        return
    end
    local value = self.animator:currentValue()

    if value == 0 then
        return
    end

    ---@cast value number
    gfx.setLineWidth(value)
    gfx.setColor(gfx.kColorWhite)

    gfx.drawRect(0, 0, 400, 240)
end

function GUIScreenEdges:update()
    if self.animator and not self.animator:ended() then

    end
end
