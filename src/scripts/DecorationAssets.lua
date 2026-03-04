---comment
---@param self Decoration
---@param config table
local function setupAnimationBotRescueSign(self, config)
    self:addState("needsRescue", 1, 4, { tickStep = 4 })
        .asDefault()
    self:addState("isRescued", 5, 8, { tickStep = 4 })

    self:playAnimation()

    local botNumber = config.botNumber

    if not botNumber then
        return
    end

    -- Get saved state for bot number.

    local isRescued = GUISpriteRescueCounter:getInstance():getIsBotRescued(botNumber)

    -- Set animation state to whichever corresponds

    if isRescued then
        self:changeState("isRescued", true)
    end
end

DECORATION_ASSETS = {
    ["light-1"] = {
        path = "assets/images/light-1",
        startFrame = 1,
        endFrame = 3,
        animationParams = { tickStep = 5 },
        lightSource = true
    },
    ["hanging-lightbulb"] = {
        path = "assets/images/hanging-lightbulb",
        lightSource = true,
        startFrame = 1,
        endFrame = 4,
        animationParams = { tickStep = 12 },
    },
    ["standing-lightbulb"] = {
        path = "assets/images/standing-lightbulb",
        lightSource = true,
        startFrame = 1,
        endFrame = 4,
        animationParams = { tickStep = 6 },
    },
    ["wheel-of-time"] = {
        path = "assets/images/wheel-1"
    },
    ["flower-1"] = {
        path = "assets/images/flower-1",
        startFrame = 1,
        endFrame = 8,
        animationParams = { tickStep = 2 }
    },
    ["flower-2"] = {
        path = "assets/images/flower-2",
        startFrame = 1,
        endFrame = 8,
        animationParams = { tickStep = 2 }
    },
    ["flower-3"] = {
        path = "assets/images/flower-3",
        startFrame = 1,
        endFrame = 8,
        animationParams = { tickStep = 2 }
    },
    ["bot-rescue-sign"] = {
        path = "assets/images/bot-rescue-sign",
        setupAnimation = setupAnimationBotRescueSign
    }
}
