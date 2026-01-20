local gfx <const> = playdate.graphics

local imagePowerBar <const> = assert(gfx.image.new(assets.images.powerbar))

---@class GUIPowerLevel: GuiSprite
---@field instance GUIPowerLevel
---@field getInstance fun(): GUIPowerLevel
GUIPowerLevel = Class("GUIPowerLevel", GuiSprite)

local thresholdMainBarMax = 0.90
local thresholdMainBarMin = 0.20

local crankValueDecreaseCoefficient <const> = 50
local thresholdCrankInput <const> = 3000

function GUIPowerLevel.load(config)
    local instance = GUIPowerLevel:getInstance()

    instance:startEnergyBar(config)
end

function GUIPowerLevel:init()
    GUIPowerLevel.super.init(self)

    self:setSize(imagePowerBar:getSize())
    self:setCenter(0, 0)
    self:moveTo(400 - self.width, 240 - self.height)
    self:setZIndex(Z_INDEX.HUD.Main)
    self:setIgnoresDrawOffset(true)

    self.isActive = false
    self.time = 0
    self.maxTime = 1
    self.objective = nil
    self.checkpointName = nil

    self.isDisplayedChargePoints = true
    self.finalChargeCount = 3

    self.checkpointHandler = CheckpointHandler.getOrCreate(self, self, {
        isActive = self.isActive
    })

    self.crankLevel = 0
end

local widthMainBar, heightMainBar <const> = 82, 9

function GUIPowerLevel:draw()
    if not self.isActive or not self.time or not self.maxTime or not self.finalChargeCount then
        return
    end

    local power = self.time / self.maxTime
    local powerMainBar = (power - thresholdMainBarMin) / (thresholdMainBarMax - thresholdMainBarMin)
    local widthPowerMainBar = math.max(0, powerMainBar * widthMainBar)

    gfx.setColor(gfx.kColorWhite)

    -- Charge points (for full charge)

    if self.isDisplayedChargePoints then
        gfx.fillRect(5, 4, 1, 2)
        gfx.fillRect(5, 13, 1, 2)
    end

    if self.finalChargeCount >= 3 then
        gfx.fillRect(88, 6, 2, 7)
    end

    if self.finalChargeCount >= 2 then
        gfx.fillRect(91, 6, 2, 7)
    end

    if self.finalChargeCount >= 1 then
        gfx.fillRect(94, 6, 2, 7)
    end

    gfx.setDitherPattern(0.2, gfx.image.kDitherTypeBayer2x2)

    -- Main power bar
    gfx.fillRoundRect(5 + (widthMainBar - widthPowerMainBar), 5, widthPowerMainBar,
        heightMainBar, 2)

    imagePowerBar:draw(0, 0)
end

function GUIPowerLevel:update()
    if not self.isActive then
        return
    end

    local power = math.max(0, self.time / self.maxTime)

    -- If Power runs out
    if power <= 0 then
        -- End energy bar
        self:onEnergyDepleted(2000)
        return
    end

    self.isDisplayedChargePoints = power > thresholdMainBarMax

    if power < thresholdMainBarMin then
        self.finalChargeCount = math.min(math.floor(power / thresholdMainBarMin * 4), 3)
    end

    -- Update state

    local deltaTime = _G.delta_time / 10
    self.time -= deltaTime

    self.checkpointHandler:pushState({
        deltaTime = deltaTime
    })

    self.crankLevel = math.max(self.crankLevel - deltaTime * crankValueDecreaseCoefficient, 0)
end

function GUIPowerLevel:getIsActive()
    return self.isActive or false
end

function GUIPowerLevel:handleCrankInput()
    if not self.isActive then
        return
    end

    local crankChange = math.abs(playdate.getCrankChange())

    self.crankLevel += crankChange

    if self.crankLevel > thresholdCrankInput then
        self:onEnergyDepleted(500)
    end
end

function GUIPowerLevel:startEnergyBar(config)
    self.isActive = true
    self.maxTime = config.time
    self.time = config.time
    self.objective = config.objective
    self.checkpointName = config.checkpoint

    self.checkpointHandler:pushState({
        isActive = true,
        time = config.time,
        maxTime = config.time,
        objective = config.objective,
        checkpointName = config.checkpoint
    })

    self.isDisplayedChargePoints = true
    self.finalChargeCount = 3

    self:add()
end

function GUIPowerLevel:onEnergyDepleted(delayTime)
    if not self.isActive or not self.checkpointName then
        return
    end

    self.isActive = false

    -- Revert to checkpoint

    Manager.emitEvent(EVENTS.ReturnToCheckpointNamed, self.checkpointName, delayTime, function()
        self:remove()
    end)
end

function GUIPowerLevel:handleCheckpointRevert(state)
    if state.deltaTime then
        local timeNew = math.min(self.time + state.deltaTime, self.maxTime)
        self.time = timeNew
    end

    self.objective = state.objective or self.objective
    self.checkpointName = state.checkpointName or self.checkpointName
    self.isActive = state.isActive or self.isActive
end
