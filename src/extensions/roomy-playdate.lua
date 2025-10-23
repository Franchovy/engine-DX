---@diagnostic disable: duplicate-set-field

-- Swizzle enter method – adds reference from scene to the manager.
local enterSwizzled = Manager.enter
function Manager.enter(self, next, ...)
    next.manager = self
    enterSwizzled(self, next, ...)
end

--- @class sceneManager : Manager
--- @field scenes Room[]
local sceneManager = {}

-- Swizzle init method - keep a reference of sceneManager

local managerInitSwizzled = Manager.init
Manager.init = function(self, ...)
    managerInitSwizzled(self, ...)

    sceneManager = self
end

-- Static emit function using latest-created sceneManager

function Manager.emitEvent(eventName, ...)
    assert(sceneManager)
    Manager.emit(sceneManager, eventName, ...)
end

function Manager.getInstance()
    return sceneManager
end
