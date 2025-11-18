---@class PowerLevel
PowerLevel = {}

local powerLevelMax <const> = 100
local decrementPower <const> = 0.01
local power = powerLevelMax

function PowerLevel.reset()
    power = powerLevelMax
end

function PowerLevel.update()
    power -= decrementPower
end

function PowerLevel.getLevel()
    return power
end
