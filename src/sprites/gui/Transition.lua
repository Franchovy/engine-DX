local gfx <const> = playdate.graphics
local sound <const> = playdate.sound

local _ = {}

--- @class Transition: _Sprite
Transition = Class("Transition", gfx.sprite)

local sfxSwoosh <const> = assert(sound.sampleplayer.new(assets.sounds.swoosh))

local imagetableParticlesBottom <const> = assert(gfx.imagetable.new(assets.imageTables.transition.bottom))
local imagetableParticlesRight <const> = assert(gfx.imagetable.new(assets.imageTables.transition.right))

local loopParticlesBottom = gfx.animation.loop.new(27, imagetableParticlesBottom, false)
local loopParticlesRight = gfx.animation.loop.new(27, imagetableParticlesRight, false)

local fadeAnimatorIn = gfx.animator.new(160, 1, 0, playdate.easingFunctions.outCubic)
local fadeAnimatorOut = gfx.animator.new(80, 0, 1, playdate.easingFunctions.inExpo)

local fadeAnimatorWorldComplete = gfx.animator.new(1600, 1, 0, playdate.easingFunctions.inOutCubic)

local delayFadeOutWorldComplete <const> = 1500

local _instance

function Transition.getInstance() return assert(_instance) end

function Transition:init()
    Transition.super.init(self)

    self:setSize(400, 240)
    self:setIgnoresDrawOffset(true)
    self:setZIndex(Z_INDEX.HUD.Main)
    self:setCenter(0, 0)

    -- Phase: 1 -> fade in/pre-transition, 2 -> fade out/post-transition. 0 -> inactive.
    self.phase = 0

    -- Direction of flip
    self.flip = gfx.kImageUnflipped

    -- Which animationLoop to use (horizontal or vertical)
    self.loop = nil

    _instance = self
end

function Transition:startTransitionLevelChange(direction, postTransitionCallback)
    self.phase = 1
    _.setDirection(self, direction)

    self:add()

    -- Pre-transition animation

    fadeAnimatorIn:reset()

    self.fader = fadeAnimatorIn

    playdate.timer.performAfterDelay(200, function()
        -- Post-transition animation

        self.phase = 2

        if postTransitionCallback then
            postTransitionCallback()
        end

        sfxSwoosh:play()

        fadeAnimatorOut:reset()

        self.fader = fadeAnimatorOut

        self.loop.frame = 1
    end)
end

function Transition:startTransitionWorldComplete(postTransitionCallback)
    self.phase = 1

    self:add()

    -- Fade-out animation

    fadeAnimatorWorldComplete:reset()

    self.fader = fadeAnimatorWorldComplete

    playdate.timer.performAfterDelay(delayFadeOutWorldComplete, function()
        -- Post-transition animation

        if postTransitionCallback then
            postTransitionCallback()
        end

        self.phase = 0

        self:finish()
    end)
end

function Transition:getDelayFadeOutWorldComplete()
    return delayFadeOutWorldComplete
end

function Transition:finish()
    self.isActive = false
    self.loop = nil
    self.fader = nil

    self:remove()

    self.phase = 0
end

function Transition:draw(x, y, width, height)
    if self.fader then
        local fadeValue = self.fader:currentValue()

        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(fadeValue, gfx.image.kDitherTypeBayer8x8)
        gfx.fillRect(0, 0, width, height)
    elseif self.loop then
        self.loop:draw(0, 0, self.flip)
    end
end

function Transition:update()
    if self.phase ~= 0 then
        self:markDirty()

        if self.phase == 2 and self.loop and not self.loop:isValid() then
            self:finish()
        end
    end
end

--- Sets direction and which "loop" (animation loop) to use.
--- @param self Transition
--- @param direction DIRECTION Which way the player *enters* (Opposite of particle effect)
function _.setDirection(self, direction)
    assert(direction)

    if direction == DIRECTION.TOP then
        self.loop = loopParticlesBottom
        self.flip = gfx.kImageUnflipped
    elseif direction == DIRECTION.BOTTOM then
        self.loop = loopParticlesBottom
        self.flip = gfx.kImageFlippedY
    elseif direction == DIRECTION.RIGHT then
        self.loop = loopParticlesRight
        self.flip = gfx.kImageFlippedX
    elseif direction == DIRECTION.LEFT then
        self.loop = loopParticlesRight
        self.flip = gfx.kImageUnflipped
    end
end
