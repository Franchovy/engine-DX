---@diagnostic disable: duplicate-set-field

-- Swizzle enter method – adds reference from scene to the manager.
local enterSwizzled = Manager.enter
function Manager.enter(self, next, ...)
    local args = { ... }
    next.manager = self

    --- [FRANCH] A delay is necessary here, at least for now, since pushing the
    --- new scene directly from the pause menu causes the new scene to be stuck in
    --- the pause menu's draw context (?). Anyways, until that's fixed, this needs to stay.

    playdate.frameTimer.performAfterDelay(1, function()
        enterSwizzled(self, next, table.unpack(args))
    end)
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

function Manager.gameWillPause()
    Manager.emitEvent('gameWillPause')
end

function Manager.gameWillResume()
    Manager.emitEvent('gameWillResume')
end
