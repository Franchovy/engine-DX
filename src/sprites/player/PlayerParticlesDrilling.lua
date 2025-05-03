local gfx <const> = playdate.graphics

local imagetableParticles <const> = assert(gfx.imagetable.new(assets.imageTables.particlesDrilling))

local indexAnimationPre = 8
local indexAnimationEnd = 26

---@class PlayerParticlesDrilling: playdate.graphics.sprite
PlayerParticlesDrilling = Class("PlayerParticlesDrilling", gfx.sprite)

function PlayerParticlesDrilling:init(player)
    PlayerParticlesDrilling.super.init(self)

    self:setSize(imagetableParticles[1]:getSize())
    self:setCenter(0.5, 0.5)
    self:setZIndex(Z_INDEX.Level.Overlay)

    self.player = player
    self.index = 1
    self.isPlaying = false
end

function PlayerParticlesDrilling:startAnimation()
    self.index = 1

    self.isPlaying = true

    self:add()
end

function PlayerParticlesDrilling:endAnimation()
    if self.index > indexAnimationPre and self.index < indexAnimationEnd then
        self.index = indexAnimationEnd
    else
        self:stop()
    end
end

function PlayerParticlesDrilling:stop()
    self.isPlaying = false
    self.index = 1
    self:remove()
end

function PlayerParticlesDrilling:update()
    if self.isPlaying then
        if self.index <= #imagetableParticles then
            self.index += 1
        else
            self:stop()
        end

        self:setImage(imagetableParticles[self.index])
    end
end
