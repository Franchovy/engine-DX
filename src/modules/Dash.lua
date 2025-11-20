--------------------------
--- Dash
--------------------------

---@class Dash : _Object
Dash = Class("Dash")

-- Local constants

local framesDashRemainingMax <const> = 2
local framesDashCooldownMax <const> = 25
local msCooldownTime <const> = 500

function Dash:init()
    ---@type string|number
    self.lastKeyPressed = nil
    ---@type integer
    self.timeLastKeyPressed = nil
    ---@type integer
    self.framesDashCooldown = 0
    ---@type integer
    self.framesDashRemaining = framesDashRemainingMax
    ---@type boolean
    self.isActivated = false
end

function Dash:registerKeyPressed(key)
    local currentTime = playdate.getCurrentTimeMilliseconds()

    -- Check if:
    -- key press is same as last
    -- key press is within timeframe
    -- cooldown is finished
    -- dash is not in progress

    if key == self.lastKeyPressed
        and self.timeLastKeyPressed > currentTime - msCooldownTime
        and self.framesDashCooldown == 0
        and self.framesDashRemaining > 0 then
        self.isActivated = true
    end

    -- Log latest key press

    self.lastKeyPressed = key
    self.timeLastKeyPressed = currentTime
end

function Dash:getLastKey()
    return self.lastKeyPressed
end

function Dash:cancel()
    self.lastKeyPressed = nil
    self.timeLastKeyPressed = nil
end

function Dash:getIsActivated()
    return self.isActivated
end

function Dash:getIsCooldownActive()
    return self.framesDashCooldown > 0
end

function Dash:getFramesSinceCooldownStarted()
    return framesDashCooldownMax - self.framesDashCooldown
end

function Dash:recharge()
    -- Reset dash frames remaining

    if self.framesDashRemaining == 0 and self.framesDashCooldown == 0 then
        self.framesDashRemaining = framesDashRemainingMax
    end
end

function Dash:finish()
    self.isActivated = false
    self.framesDashCooldown = framesDashCooldownMax
end

function Dash:updateFrame()
    -- Update variables for in-progress dash or cooldown if activated

    if self.isActivated and self.framesDashRemaining == 0 then
        -- End dash, set cooldown

        self:finish()
    elseif self.isActivated and self.framesDashRemaining > 0 then
        -- If activated, reduce dash frames

        self.framesDashRemaining -= 1
    elseif self.framesDashCooldown > 0 then
        -- If not activated, reduce cooldown if active

        self.framesDashCooldown -= 1
    end
end
