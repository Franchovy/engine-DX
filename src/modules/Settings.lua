---@class Settings
Settings = {}

local values <const> = {}

function Settings.create(defaults)
    for key, value in pairs(defaults) do
        values[key] = value
    end
end

function Settings.set(key, value)
    values[key] = value
end

function Settings.get(key)
    return values[key]
end
