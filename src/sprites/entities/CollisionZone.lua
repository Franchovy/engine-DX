--- @class CollisionZone : Entity
CollisionZone = Class("CollisionZone", Entity)

---@param data ldtkData
---@param levelName string
---@param ... unknown
function CollisionZone:init(data, levelName, ...)
    Entity.init(self, data, levelName, ...)

    -- Load scripts as functions for each config

    -- Args for named functions (a.k.a. scripts) are passed through this table
    self.args = {}

    local config = assert(json.decode(data.fields.config), "Error decoding CollisionZone json!")

    self:loadConfig(config)

    -- Collisions

    self:setGroups(GROUPS.ActivatePlayer)

    -- Sprite config

    self:setCenter(0, 0)
    self:setSize(data.size.width, data.size.height)
end

function CollisionZone:loadConfig(config)
    for key, args in pairs(config) do
        local scripts = CollisionZoneScripts[key]

        for name, func in pairs(scripts) do
            -- Set args for this script
            self.args[name] = args

            -- Set script as named function
            self[name] = func
        end
    end
end

function CollisionZone:activate()
    self.isActivated = self.latestTime
end

function CollisionZone:update()
    if self.isActivated and self.isActivated < self.latestTime then
        -- On activation last tick

        self.isActivatedPrevious = self.isActivated
        self.isActivated = false
    elseif not self.isActivated and self.isActivatedPrevious then
        -- On ended activation last tick

        self.isActivatedPrevious = false

        -- Call onExit callback if exists
        if self.onExit then
            self:onExit()
        end
    end

    self.latestTime = _G.activation_time
end
