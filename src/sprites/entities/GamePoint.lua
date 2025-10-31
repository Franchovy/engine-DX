---@class GamePoint : Entity
GamePoint = Class("GamePoint", Entity)

function GamePoint:init(...)
    GamePoint.super.init(self, ...)
end

function GamePoint:load()
    local config = json.decode(self.fields.config)
    ConfigHandler.loadConfig(config)
end
