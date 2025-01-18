local gfx <const> = playdate.graphics

--- @class Transition : playdate.graphics.sprite
Transition = Class("Transition", gfx.sprite)

local sfxSwoosh <const> = assert(playdate.sound.sampleplayer.new(assets.sounds.swoosh))

local imagetableParticlesBottom <const> = assert(gfx.imagetable.new(assets.imageTables.transition.bottom))
local imagetableParticlesRight <const> = assert(gfx.imagetable.new(assets.imageTables.transition.right))

local loopParticlesBottom = gfx.animation.loop.new(27, imagetableParticlesBottom, false)
local loopParticlesRight = gfx.animation.loop.new(27, imagetableParticlesRight, false)

function Transition:init()
    Transition.super.init(self)

    self:setSize(400, 240)
    self:setIgnoresDrawOffset(true)
    self:setZIndex(Z_INDEX.HUD.Main)
    self:setCenter(0, 0)

    self.flip = gfx.kImageUnflipped
    self.isActive = false
    self.index = 1
end

function Transition:start()
    self.isActive = true

    self:add()

    loopParticlesBottom.frame = 1
    loopParticlesRight.frame = 1

    self.flip = gfx.kImageFlippedY

    sfxSwoosh:play()
end

function Transition:finish()
    self.isActive = false

    self:remove()
end

function Transition:draw(x, y, width, height)
    --[[
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer4x4)
    gfx.fillRect(0, 0, width, height)
    --]]

    loopParticlesBottom:draw(0, 0, self.flip)
    loopParticlesRight:draw(0, 0, self.flip)
end

function Transition:update()
    if self.isActive then
        self:markDirty()
        self.index += 1

        if not loopParticlesBottom:isValid() then
            self:finish()
        end
    end
end
