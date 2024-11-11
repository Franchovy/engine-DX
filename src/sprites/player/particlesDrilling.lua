local gfx <const> = playdate.graphics

local imagetableParticles <const> = assert(gfx.imagetable.new(assets.imageTables.particlesDrilling))

local indexAnimationPre = 12
local indexAnimationEnd = 65

---@class PlayerParticlesDrilling: playdate.graphics.sprite
PlayerParticlesDrilling = Class("PlayerParticlesDrilling", gfx.sprite)

function PlayerParticlesDrilling:init(player)
    PlayerParticlesDrilling.super.init(self)

    self:setSize(imagetableParticles[1]:getSize())
    self:setZIndex(1)

    self.player = player
    self.index = 1
    self.isPlaying = false
end

function PlayerParticlesDrilling:moveToPlayer()
    self:moveTo(self.blockX, self.blockY - 12)
end

function PlayerParticlesDrilling:play(blockX, blockY)
    if self.isPlaying then
        self:stop()
    end

    self.blockX, self.blockY = blockX, blockY

    self.isPlaying = true

    self:add()

    self:moveToPlayer()
end

function PlayerParticlesDrilling:endAnimation()
    if self.index < indexAnimationEnd and self.index > indexAnimationPre then
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

        self:moveToPlayer()
        self:setImage(imagetableParticles[self.index])
    end
end
