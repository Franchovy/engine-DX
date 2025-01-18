local gfx <const> = playdate.graphics
local sound <const> = playdate.sound

local _ = {}

--- @class Transition : playdate.graphics.sprite
Transition = Class("Transition", gfx.sprite)

local sfxSwoosh <const> = assert(sound.sampleplayer.new(assets.sounds.swoosh))

local imagetableParticlesBottom <const> = assert(gfx.imagetable.new(assets.imageTables.transition.bottom))
local imagetableParticlesRight <const> = assert(gfx.imagetable.new(assets.imageTables.transition.right))

local loopParticlesBottom = gfx.animation.loop.new(27, imagetableParticlesBottom, false)
local loopParticlesRight = gfx.animation.loop.new(27, imagetableParticlesRight, false)

local fadeAnimatorIn = gfx.animator.new(160, 1, 0, playdate.easingFunctions.outCubic)
local fadeAnimatorOut = gfx.animator.new(80, 0, 1, playdate.easingFunctions.inExpo)

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
end

function Transition:startTransition(direction, postTransitionCallback)
    self.phase = 1
    _.setDirection(self, direction)

    self:add()

    -- Pre-transition animation

    fadeAnimatorIn:reset()

    playdate.timer.performAfterDelay(200, function()
        -- Post-transition animation

        self.phase = 2

        postTransitionCallback()
        sfxSwoosh:play()

        fadeAnimatorOut:reset()

        self.loop.frame = 1
    end)
end

function Transition:finish()
    self.isActive = false

    self:remove()

    self.phase = 0
end

function Transition:draw(x, y, width, height)
    local fadeValue = self.phase == 1 and fadeAnimatorIn:currentValue() or fadeAnimatorOut:currentValue()

    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(fadeValue, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, 0, width, height)

    self.loop:draw(0, 0, self.flip)
end

function Transition:update()
    if self.phase ~= 0 then
        self:markDirty()

        if self.phase == 2 and not self.loop:isValid() then
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
