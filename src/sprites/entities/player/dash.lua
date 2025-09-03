Dash = {}

-- Local constants

local framesDashRemainingMax <const> = 2
local framesDashCooldownMax <const> = 25
local msCooldownTime <const> = 500

-- Local variables

local lastKeyPressed
local timeLastKeyPressed
local framesDashCooldown = 0
local framesDashRemaining = framesDashRemainingMax
local isActivated = false

function Dash:registerKeyPressed(key)
    local currentTime = playdate.getCurrentTimeMilliseconds()

    -- Check if:
    -- key press is same as last
    -- key press is within timeframe
    -- cooldown is finished
    -- dash is not in progress

    if key == lastKeyPressed
        and timeLastKeyPressed > currentTime - msCooldownTime
        and framesDashCooldown == 0
        and framesDashRemaining > 0 then
        isActivated = true
    end

    -- Log latest key press

    lastKeyPressed = key
    timeLastKeyPressed = currentTime
end

function Dash:getLastKey()
    return lastKeyPressed
end

function Dash:getIsActivated()
    return isActivated
end

function Dash:getIsCooldownActive()
    return framesDashCooldown > 0
end

function Dash:getFramesSinceCooldownStarted()
    return framesDashCooldownMax - framesDashCooldown
end

function Dash:recharge()
    -- Reset dash frames remaining

    if framesDashRemaining == 0 and framesDashCooldown == 0 then
        framesDashRemaining = framesDashRemainingMax
    end
end

function Dash:finish()
    isActivated = false
    framesDashCooldown = framesDashCooldownMax
end

function Dash:updateFrame()
    -- Update variables for in-progress dash or cooldown if activated

    if isActivated and framesDashRemaining == 0 then
        -- End dash, set cooldown

        self:finish()
    elseif isActivated and framesDashRemaining > 0 then
        -- If activated, reduce dash frames

        framesDashRemaining -= 1
    elseif framesDashCooldown > 0 then
        -- If not activated, reduce cooldown if active

        framesDashCooldown -= 1
    end
end
