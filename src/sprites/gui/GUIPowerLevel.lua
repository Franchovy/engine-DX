local gfx <const> = playdate.graphics

local imagePowerBar <const> = assert(gfx.image.new(assets.images.powerbar))

---@class GUIPowerLevel: GuiSprite
---@field instance GUIPowerLevel
---@field getInstance fun(): GUIPowerLevel
GUIPowerLevel = Class("GUIPowerLevel", GuiSprite)

local thresholdMainBarMax = 0.90
local thresholdMainBarMin = 0.20

function GUIPowerLevel.load(config)
    local instance = GUIPowerLevel:getInstance()

    instance.isActive = true
    instance.maxTime = config.time
    instance.time = config.time
    instance.objective = config.objective
    instance.checkpointName = config.checkpointName

    instance:add()
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

    self.displayChargePoints = true
    self.finalChargeCount = 3
end

local widthMainBar, heightMainBar <const> = 82, 9

function GUIPowerLevel:draw()
    local power = self.time / self.maxTime
    local powerMainBar = (power - thresholdMainBarMin) / (thresholdMainBarMax - thresholdMainBarMin)
    local widthPowerMainBar = math.max(0, powerMainBar * widthMainBar)

    gfx.setColor(gfx.kColorWhite)

    -- Charge points (for full charge)

    if self.displayChargePoints then
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
    local power = math.max(0, self.time / self.maxTime)

    self.displayChargePoints = power > thresholdMainBarMax

    if power < thresholdMainBarMin then
        self.finalChargeCount = math.ceil(power / thresholdMainBarMin * 3)
    end

    self.time -= _G.delta_time / 10
end
