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

    local config = json.decode(data.fields.config)

    for key, args in pairs(config) do
        local scripts = CollisionZoneScripts[key]

        for name, func in pairs(scripts) do
            -- Set args for this script
            self.args[name] = args

            -- Set script as named function
            self[name] = func
        end
    end

    -- Collisions

    self:setGroups(GROUPS.Overlap)

    -- Sprite config

    self:setCenter(0, 0)
    self:setSize(data.size.width, data.size.height)
end
