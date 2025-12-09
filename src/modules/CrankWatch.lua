---@class CrankWatch: _Object
CrankWatch = Class("CrankWatch")

local crankChange = 0
local _crankChangeDebug = nil

CrankWatch.watchers = {}

function CrankWatch:init(id, threshold)
    self.crankMaxThreshold = threshold
    self.id = id

    CrankWatch.watchers[id] = self
end

function CrankWatch:get(id)
    return CrankWatch.watchers[id]
end

function CrankWatch:remove()
    CrankWatch.watchers[self.id] = nil
end

function CrankWatch:getDidPassThreshold()
    return math.abs(crankChange) > self.crankMaxThreshold
end

function CrankWatch:getThresholdProportion()
    return math.max(0, 1 - (math.abs(crankChange) / self.crankMaxThreshold))
end

function CrankWatch.update()
    crankChange = _crankChangeDebug or playdate.getCrankChange()
    _crankChangeDebug = nil
end

function CrankWatch.__setCrankChange(value)
    _crankChangeDebug = value
end
