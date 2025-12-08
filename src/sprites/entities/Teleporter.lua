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
end

function Teleporter:activate(sprite)
    print("Teleporting sprite: " .. sprite.id)
end
