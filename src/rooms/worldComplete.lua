local gfx <const> = playdate.graphics

---@class WorldComplete : Room
WorldComplete = Class("WorldComplete", Room)

local imagetablePlayer = assert(gfx.imagetable.new(assets.imageTables.player))

local sprite = gfx.sprite.new()
local spritePlayer

---@type _Image
local imageTitle
local widthImageTitle, heightImageTitle
local radiusCircleMaxTitle

---@type _Image
local imageLevel
local widthImageLevel, heightImageLevel

---@type _Image
local imageBotsRescued
local widthImageBotsRescued, heightImageBotsRescued

---@type MenuItem
local restartButton
---@type MenuItem
local continueButton

local animatorTitleReveal = gfx.animator.new(1200, 0, 1, playdate.easingFunctions.inCirc)
local animatorTitleMove = gfx.animator.new(800, 0, 1, playdate.easingFunctions.inOutExpo)
local animatorLevelReveal = gfx.animator.new(1200, 0, 1, playdate.easingFunctions.inExpo)
local animatorBotsRescuedReveal = gfx.animator.new(800, 0, 1, playdate.easingFunctions.inExpo)
local countBotsShown = 0

function WorldComplete:init()
    self:setupImageTitle()
    self:setupButtons()
end

function WorldComplete:enter(previous, filepathLevelCurrent, filepathLevelNext)
    local _, levelName, _, indexWorld = ReadFile.getAreaWorld(filepathLevelCurrent)

    --

    gfx.setDrawOffset(0, 0)

    self:setupImageLevel(indexWorld, levelName)

    animatorTitleReveal:reset()

    sprite:setSize(400, 240)
    sprite:moveTo(200, 120)
    sprite:add()

    spritePlayer = AnimatedSprite(imagetablePlayer)
    spritePlayer:addState("default-x", 9, 12, { loop = true, tickStep = 2, flip = 1 }, true)
    spritePlayer:moveTo(300, 120)

    -- Set up bot rescued graphics

    local dataBotsRescued = MemoryCard.getValue(SAVE_FILE.GameData, { "levels", filepathLevelCurrent, "rescuedSprites" },
        {})
    local countBotsRescued, total = 0, 0
    local botsSaved = {}

    for _, data in ipairs(dataBotsRescued) do
        local isRescued, botId = data.value, data.botId
        total += 1

        if isRescued then
            countBotsRescued += 1
            table.insert(botsSaved, botId)
        end
    end

    self:setupImageTextBotsRescued(countBotsRescued, total)
    self:setupBotsRescued(botsSaved)

    --

    playdate.timer.performAfterDelay(2000, function()
        self:animateButtons()
    end)

    if filepathLevelNext then
        -- Debug code (No exit)
        if true then return end

        playdate.timer.performAfterDelay(15000, function()
            Transition:getInstance():fadeOut(1600, function()
                Game.loadAndEnter(filepathLevelNext)
            end)
        end)
    end
end

function WorldComplete:leave()
    Player.destroy()
    spritePlayer = nil

    sprite:remove()
end

function sprite:draw(x, y, width, height)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 400, 240)

    if not animatorTitleReveal:ended() then
        local mask = imageTitle:getMaskImage()

        gfx.pushContext(mask)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(widthImageTitle / 2, heightImageTitle / 2,
            animatorTitleReveal:currentValue() * radiusCircleMaxTitle)
        gfx.popContext()

        if animatorTitleReveal:progress() < 0.8 then
            animatorTitleMove:reset()
        end
    elseif not animatorTitleMove:ended() then
        animatorLevelReveal:reset()
    elseif not animatorLevelReveal:ended() then
        local mask = imageLevel:getMaskImage()

        gfx.pushContext(mask)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillPolygon(
            0, 0,
            widthImageLevel * animatorLevelReveal:currentValue(), 0,
            widthImageLevel * animatorLevelReveal:currentValue() - 20, heightImageLevel,
            0, heightImageLevel
        )
        gfx.popContext()

        animatorBotsRescuedReveal:reset()
    elseif not animatorBotsRescuedReveal:ended() then
        local mask = imageBotsRescued:getMaskImage()

        gfx.pushContext(mask)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillPolygon(
            0, 0,
            widthImageBotsRescued * animatorBotsRescuedReveal:currentValue(), 0,
            widthImageBotsRescued * animatorBotsRescuedReveal:currentValue() - 10, heightImageBotsRescued,
            0, heightImageBotsRescued
        )
        gfx.popContext()
    end

    local yImageTitle = 20 + 100 * (1 - animatorTitleMove:currentValue())

    imageTitle:drawAnchored(200, yImageTitle, 0.5, 0.5)
    imageLevel:draw(20, 60)
    imageBotsRescued:draw(20, 94)
end

function WorldComplete:setupImageTitle()
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)

    imageTitle = gfx.image.new(300, 40, gfx.kColorBlack)
    gfx.pushContext(imageTitle)
    gfx.setFont(Fonts.Menu.Large)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned("World Complete", 150, 20, kTextAlignment.center)
    gfx.popContext()

    gfx.setImageDrawMode(gfx.kDrawModeCopy)

    -- Fill mask with black
    local mask = gfx.image.new(300, 40, gfx.kColorBlack)
    imageTitle:setMaskImage(mask)

    -- Pre-calculated values

    widthImageTitle, heightImageTitle = imageTitle:getSize()
    radiusCircleMaxTitle = math.sqrt(widthImageTitle ^ 2 + heightImageTitle ^ 2)
end

function WorldComplete:setupImageLevel(levelNumber, levelName)
    levelNumber = levelNumber or "X"
    levelName = levelName or "Default Level"

    imageLevel = gfx.image.new(300, 40, gfx.kColorBlack)

    gfx.pushContext(imageLevel)

    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.setFont(Fonts.Menu.Small)
    gfx.drawText("Level " .. levelNumber .. ":", 0, 0)
    gfx.setFont(Fonts.Menu.Medium)
    gfx.drawText(levelName, 0, 15)

    gfx.popContext()

    -- Fill mask with black
    local mask = gfx.image.new(300, 40, gfx.kColorBlack)
    imageLevel:setMaskImage(mask)

    widthImageLevel, heightImageLevel = imageLevel:getSize()
end

function WorldComplete:setupImageTextBotsRescued(rescueCount, total)
    rescueCount = rescueCount or 0
    total = total or 0

    imageBotsRescued = gfx.image.new(200, 20, gfx.kColorBlack)

    gfx.pushContext(imageBotsRescued)

    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.setFont(Fonts.Dialog)
    gfx.drawText("Bots Rescued: " .. rescueCount .. "/" .. total, 0, 0)
    gfx.popContext()

    -- Fill mask with black
    local mask = gfx.image.new(200, 20, gfx.kColorBlack)
    imageBotsRescued:setMaskImage(mask)

    widthImageBotsRescued, heightImageBotsRescued = imageBotsRescued:getSize()
end

local function _onNextLevelPressed()

end

local function _onRestartPressed()

end

function WorldComplete:setupButtons()
    restartButton = MenuItem("Restart", _onRestartPressed)
    continueButton = MenuItem("Next Level", _onNextLevelPressed)

    restartButton:moveTo(100, 300)
    continueButton:moveTo(300, 300)
end

function WorldComplete:animateButtons()
    continueButton:add()
    restartButton:add()

    self:updateButtons()

    local frametimer = playdate.frameTimer.new(26, 0, 1, playdate.easingFunctions.inOutExpo)

    frametimer.updateCallback = function(timer)
        if restartButton and continueButton then
            local value = timer.value

            restartButton:moveTo(100, 300 - value * 100)
            continueButton:moveTo(300, 300 - value * 100)
        end
    end

    frametimer:start()
end

function WorldComplete:setupBotsRescued(listBotIds)
    -- Draw bots rescued

    print("Drawing " .. #listBotIds .. " bots.")
end

local index = 2

function WorldComplete:updateButtons()
    restartButton:setSelected(index == 1)
    continueButton:setSelected(index == 2)
end

function WorldComplete:leftButtonUp()
    if index == 1 then
        return
    end

    index -= 1

    self:updateButtons()
end

function WorldComplete:rightButtonUp()
    if index == 2 then
        return
    end

    index += 1

    self:updateButtons()
end

function WorldComplete:AButtonUp()
    if index == 1 then
        restartButton:performCallback()
    else
        continueButton:performCallback()
    end
end
