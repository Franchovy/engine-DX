local gfx <const> = playdate.graphics

---@class GUIEnergyLevel : _Sprite
GUIEnergyLevel = Class("GUIEnergyLevel", gfx.sprite)

local _instance

function GUIEnergyLevel.getInstance()
    return assert(_instance)
end

function GUIEnergyLevel.destroy()
    _instance = nil
end

function GUIEnergyLevel:init()
    GUIEnergyLevel.super.init(self)

    self:setSize(100, 14)
    self:setCenter(0, 0)
    self:moveTo(400 - self:getSize() - 6, 6)
    self:setZIndex(Z_INDEX.HUD.Main)
    self:setIgnoresDrawOffset(true)

    _instance = self
end

function GUIEnergyLevel:draw()
    local power = PowerLevel.getLevel()

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(self.width - power, 0, power, self.height)
end
