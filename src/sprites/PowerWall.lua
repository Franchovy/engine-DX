local gfx = playdate.graphics
local sound = playdate.sound

local spPowerUp <const> = assert(sound.sampleplayer.new(assets.sounds.powerUp))
local spPowerDown <const> = assert(sound.sampleplayer.new(assets.sounds.powerDown))

Powerwall = Class("Powerwall", gfx.sprite)

function Powerwall:init(entity)
    Powerwall.super.init(self)

    -- Collisions

    self:setTag(TAGS.Powerwall)
    self:setGroups(GROUPS.Overlap)

    -- Sprite config

    self:setCenter(0, 0)
    self:setSize(entity.size.width, entity.size.height)

    -- Update variables
    self.isActivated = false
    self.isActivatedPrevious = self.isActivated
end

function Powerwall:postInit()

end

function Powerwall:activate()
    self.isActivated = true
end

function Powerwall:update()
    if self.isActivated and not self.isActivatedPrevious then
        -- Enter power area

        spPowerUp:play()
        spPowerDown:stop()
    elseif self.isActivatedPrevious and not self.isActivated then
        -- Exit power area

        spPowerDown:play()
        spPowerUp:stop()
    end

    if self.isActivated ~= self.isActivatedPrevious then
        Manager.emitEvent(EVENTS.UpdateChipSet, { isActive = not self.isActivated })
    end

    -- Reset update variables

    self.isActivatedPrevious = self.isActivated
    self.isActivated = false
end
