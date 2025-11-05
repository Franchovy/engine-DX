local gfx <const> = playdate.graphics
local sound <const> = playdate.sound

local _ = {}

--- @class Transition: _Sprite
Transition = Class("Transition", gfx.sprite)

local _instance

local fadeColor

---@alias FadeConfig {color: number,duration: number, start: number, finish:number}

---@type FadeConfig?
local fadeTriggered

-- Static Methods

---@return Transition
function Transition.getInstance() return assert(_instance) end

function Transition.load(config)
    if config.color then
        fadeColor = config.color
    end

    if config.fadeOut then
        fadeTriggered = {
            color = config.fadeOut.color or fadeColor,
            duration = config.fadeOut.duration or 1000,
            start = 1,
            finish = 0,
            delay = config.fadeOut.delay or 0
        }
    elseif config.fadeIn then
        fadeTriggered = {
            color = config.fadeIn.color or fadeColor,
            duration = config.fadeIn.duration or 1000,
            start = 0,
            finish = 1,
            delay = config.fadeIn.delay or 0
        }
    end
end

-- Instance Methods

function Transition:init()
    Transition.super.init(self)

    self:setSize(400, 240)
    self:setIgnoresDrawOffset(true)
    self:setZIndex(Z_INDEX.HUD.Main)
    self:setCenter(0, 0)

    fadeColor = gfx.kColorBlack

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
        --self:remove()
        --self.fader = nil

        if finishCallback then
            finishCallback()
        end
    end)
end

function Transition:draw(x, y, width, height)
    if self.fader then
        local fadeValue = self.fader:currentValue()

        gfx.setColor(fadeColor)

        ---@cast fadeValue number
        gfx.setDitherPattern(fadeValue, gfx.image.kDitherTypeBayer8x8)

        gfx.fillRect(0, 0, width, height)
    end
end

function Transition:update()
    if self.fader and not self.fader:ended() then
        self:markDirty()
    end

    if fadeTriggered and (not self.fader or self.fader:ended()) then
        -- Trigger fade

        fadeColor = fadeTriggered.color

        local animator = gfx.animator.new(fadeTriggered.duration, fadeTriggered.start, fadeTriggered.finish,
            playdate.easingFunctions.linear, fadeTriggered.delay)

        self:animateFade(fadeTriggered.duration, animator, nil)

        -- Reset value

        fadeTriggered = nil
    end
end
