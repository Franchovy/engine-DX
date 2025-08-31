Dash = {}

-- Local constants

local msCooldownTime <const> = 500

-- Local variables

local lastKeyPressed
local timeLastKeyPressed
local isActivated = false

function Dash:registerKeyPressed(key)
    local currentTime = playdate.getCurrentTimeMilliseconds()

    if key == lastKeyPressed and timeLastKeyPressed > currentTime - msCooldownTime then
        isActivated = true
    end

    lastKeyPressed = key
    timeLastKeyPressed = currentTime
end

function Dash:getIsActivated()
    return isActivated
end

function Dash:update()
    -- Reset activation

    isActivated = false
end
