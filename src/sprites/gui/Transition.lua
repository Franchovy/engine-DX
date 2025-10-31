local gfx <const> = playdate.graphics
local sound <const> = playdate.sound

local _ = {}

--- @class Transition: _Sprite
Transition = Class("Transition", gfx.sprite)

local _instance

-- Static Methods

---@return Transition
function Transition.getInstance() return assert(_instance) end

function Transition.load(config)
    if not _instance then return end

    if config.color then
        _instance.fadeColor = config.color
    end
end

-- Instance Methods

function Transition:init()
    Transition.super.init(self)

    self:setSize(400, 240)
    self:setIgnoresDrawOffset(true)
    self:setZIndex(Z_INDEX.HUD.Main)
    self:setCenter(0, 0)

    self.fadeColor = gfx.kColorBlack

    _instance = self
end

function Transition:fadeOut(fadeInTimeMs, finishCallback)
    self:animateFade(fadeInTimeMs, gfx.animator.new(fadeInTimeMs, 1, 0, playdate.easingFunctions.linear),
        finishCallback)
end

function Transition:fadeIn(fadeInTimeMs, finishCallback)
    self:animateFade(fadeInTimeMs, gfx.animator.new(fadeInTimeMs, 0, 1, playdate.easingFunctions.linear), finishCallback)
end

function Transition:animateFade(fadeInTimeMs, animator, finishCallback)
    self:add()

    self.fader = animator

    playdate.timer.performAfterDelay(fadeInTimeMs, function()
        self:remove()
        self.fader = nil

        if finishCallback then
            finishCallback()
        end
    end)
end

function Transition:draw(x, y, width, height)
    if self.fader then
        local fadeValue = self.fader:currentValue()

        gfx.setColor(self.fadeColor)
        ---@cast fadeValue number
        gfx.setDitherPattern(fadeValue, gfx.image.kDitherTypeBayer8x8)

        gfx.fillRect(0, 0, width, height)
    end
end

function Transition:update()
    if self.fader then
        self:markDirty()
    end
end
