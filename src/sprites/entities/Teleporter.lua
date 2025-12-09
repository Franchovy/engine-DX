local gfx = playdate.graphics

---@class Teleporter: _Sprite
Teleporter = Class("Teleporter", Entity)

function Teleporter:init(entityData, levelName)
    Teleporter.super.init(self, entityData, levelName)

    self.targetLevel = entityData.fields.destination_level

    local _, config = pcall(json.decode, entityData.fields.config)
    if config then
        if config.type then
            self.type = config.type
        end

        if config.destination then
            self.destination = config.destination
        end
    end

    self:setGroups({ GROUPS.ActivatePlayer, GROUPS.ActivateBot })

    self.fadeOutTimers = {}
end

function Teleporter:activate(sprite)
    local type = self.type

    if type and sprite.super.className ~= type then
        return
    end

    local destination = self.destination
    local targetLevel = self.targetLevel
    local spriteDestination = LDtk.entitiesById[destination]

    if targetLevel and destination then
        local imagePrevious = sprite:getImage()
        local imageMaskBase = imagePrevious:getMaskImage()

        if self.fadeOutTimers[sprite] then
            -- Timer for this sprite already exists, can remove.
            return
        end

        -- Fade out sprite
        local frametimer = playdate.frameTimer.new(25, 1, 0)

        if sprite.freeze then
            sprite:freeze()
        end

        frametimer.updateCallback = function(timer)
            local imageMaskBase = imageMaskBase:copy()
            gfx.pushContext(imageMaskBase)
            gfx.setColor(gfx.kColorBlack)
            gfx.setDitherPattern(timer.value)
            gfx.fillRect(0, 0, imageMaskBase:getSize())
            gfx.popContext()

            sprite:getImage():setMaskImage(imageMaskBase)
        end

        frametimer.timerEndedCallback = function(timer)
            sprite:remove()
            sprite:setImage(imagePrevious)

            if sprite.unfreeze then
                sprite:unfreeze()
            end

            sprite:enterLevel(targetLevel)
            sprite:moveEntity(spriteDestination.position.x, spriteDestination.position.y)

            self.fadeOutTimers[sprite] = nil
        end

        self.fadeOutTimers[sprite] = frametimer
    end
end
