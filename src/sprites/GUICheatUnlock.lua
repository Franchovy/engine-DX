local gfx <const> = playdate.graphics

local spCheatUnlock <const> = playdate.sound.sampleplayer.new(assets.sounds.cheatUnlock)

--- @class GUICheatUnlock : playdate.graphics.sprite
GUICheatUnlock = Class("GUICheatUnlock", gfx.sprite)

local _instance
local _callbacks = {}

local function _callbackInternal(spriteCheat)
    local cheatCallback = _callbacks[spriteCheat]

    _instance:playUnlockSequence()

    cheatCallback()
end

function GUICheatUnlock:init()
    GUICheatUnlock.super.init(self)

    self:setSize(100, 18)
    self:setZIndex(1000)
    self:moveTo(2, 2)
    self:setIgnoresDrawOffset(true)
    self:setCenter(0, 0)

    self:setVisible(false)

    self.cheats = {}

    _instance = self
end

function GUICheatUnlock:add()
    GUICheatUnlock.super.add(self)

    for _, v in pairs(self.cheats) do
        v:add()
    end
end

function GUICheatUnlock:remove()
    GUICheatUnlock.super.remove(self)

    for _, v in pairs(self.cheats) do
        v:remove()
    end
end

function GUICheatUnlock:draw(x, y, width, height)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, self.width, self.height)

    gfx.drawTextAligned("Cheat Enabled", (self.width / 2), 4, kTextAlignment.center)
end

function GUICheatUnlock:addCheat(sequence, callback)
    local cheat = Tanuk_CodeSequence(sequence, _callbackInternal)

    _callbacks[cheat] = callback

    table.insert(self.cheats, cheat)
end

function GUICheatUnlock:clearAll()
    for _, v in pairs(self.cheats) do
        v:remove()
    end

    _callbacks = {}

    self.cheats = {}
end

function GUICheatUnlock:playUnlockSequence()
    self:setVisible(true)

    spCheatUnlock:play()

    playdate.timer.performAfterDelay(5000, function()
        self:setVisible(false)
    end)
end
