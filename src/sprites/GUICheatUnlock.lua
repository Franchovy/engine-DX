local gfx <const> = playdate.graphics

local spCheatUnlock <const> = playdate.sound.sampleplayer.new(assets.sounds.cheatUnlock)

--- @class GUICheatUnlock : playdate.graphics.sprite
GUICheatUnlock = Class("GUICheatUnlock", gfx.sprite)

function GUICheatUnlock:init()
    GUICheatUnlock.super.init(self)

    self:setSize(100, 18)
    self:setZIndex(1000)
    self:moveTo(2, 2)
    self:setIgnoresDrawOffset(true)
    self:setCenter(0, 0)
end

function GUICheatUnlock:add()
    GUICheatUnlock.super.add(self)
    spCheatUnlock:play()
end

function GUICheatUnlock:draw(x, y, width, height)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, self.width, self.height)

    gfx.drawTextAligned("Cheat Enabled", (self.width / 2), 4, kTextAlignment.center)
end
