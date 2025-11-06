---@class GamePoint : Entity
GamePoint = Class("GamePoint", Entity)

function GamePoint:init(...)
    GamePoint.super.init(self, ...)
end

function GamePoint:load()
    local config = assert(json.decode(self.fields.config), "GamePoint has invalid JSON!")
    ConfigHandler.loadConfig(config)
end
