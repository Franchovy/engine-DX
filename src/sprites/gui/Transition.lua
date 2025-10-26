local gfx <const> = playdate.graphics
local sound <const> = playdate.sound

local _ = {}

--- @class Transition: _Sprite
Transition = Class("Transition", gfx.sprite)

local sfxSwoosh <const> = assert(sound.sampleplayer.new(assets.sounds.swoosh))

local fadeAnimatorIn = gfx.animator.new(160, 1, 0, playdate.easingFunctions.outCubic)
local fadeAnimatorOut = gfx.animator.new(80, 0, 1, playdate.easingFunctions.inExpo)

local fadeAnimatorWorldComplete = gfx.animator.new(1600, 1, 0, playdate.easingFunctions.inOutCubic)
local fadeAnimatorWorldCompleteOut = gfx.animator.new(600, 0, 1, playdate.easingFunctions.inCubic)

local delayFadeOutWorldComplete <const> = 1500

local _instance

---@return Transition
function Transition.getInstance() return assert(_instance) end

function Transition:init()
    Transition.super.init(self)

    self:setSize(400, 240)
    self:setIgnoresDrawOffset(true)
    self:setZIndex(Z_INDEX.HUD.Main)
    self:setCenter(0, 0)

    -- Phase: 1 -> fade in/pre-transition, 2 -> fade out/post-transition. 0 -> inactive.
    self.phase = 0

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

        gfx.setColor(gfx.kColorBlack)
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
