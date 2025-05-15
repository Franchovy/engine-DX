local _floor <const> = math.floor
local _max <const> = math.max
local _min <const> = math.min

function math.round(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return _floor(num * mult + 0.5) / mult
end

function math.clamp(num, min, max)
    return _max(_min(num, max), min)
end
