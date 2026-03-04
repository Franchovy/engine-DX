local gfx <const> = playdate.graphics

---@class WorldComplete : Room
WorldComplete = Class("WorldComplete", Room)

local imagetablePlayer = assert(gfx.imagetable.new(assets.imageTables.player))

local sprite = gfx.sprite.new()
local spritePlayer
---@type _Sprite[]
local spritesBots = {}

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

local filepathLevelCurrent, filepathLevelNext

function WorldComplete:init()
    self:setupImageTitle()
    self:setupButtons()
end

function WorldComplete:enter(previous, filepathLevelCurrentNew, filepathLevelNextNew)
    filepathLevelCurrent = filepathLevelCurrentNew
    filepathLevelNext = filepathLevelNextNew

    local _, levelName, _, indexWorld = ReadFile.getAreaWorld(filepathLevelCurrentNew)

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

    playdate.timer.performAfterDelay(3000, function()
        self:animateBotsRescued()
    end)

    playdate.timer.performAfterDelay(4000, function()
        self:animateButtons()
    end)
end

function WorldComplete:leave()
    -- Remove sprites
    Player.destroy()
    spritePlayer = nil
    sprite:remove()
    for _, sprite in pairs(spritesBots) do
        sprite:remove()
    end
    spritesBots = {}

    -- Clear animated image
    imageTitle:setMaskImage(gfx.image.new(300, 40, gfx.kColorBlack))
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
    if not filepathLevelNext then
        return
    end

    Transition:getInstance():fadeOut(1600, function()
        Game.loadAndEnter(filepathLevelNext)
    end)
end

local function _onRestartPressed()
    if not filepathLevelCurrent then
        return
    end

    Transition:getInstance():fadeOut(1600, function()
        Game.loadAndEnter(filepathLevelCurrent)
    end)
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
    self:enableButtons()

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

    local startX, startY = 32, 140
    local spacingX = 32 + 12

    for i, botId in ipairs(listBotIds) do
        local configAnimation = BotConfig[botId].animations
        local animationFrames

        if configAnimation[BOT_ANIMATION_STATES.Happy] then
            animationFrames = configAnimation[BOT_ANIMATION_STATES.Happy]
        elseif configAnimation[BOT_ANIMATION_STATES.Idle] then
            animationFrames = configAnimation[BOT_ANIMATION_STATES.Idle]
        end

        local animationSpeed = BotConfig[botId].animationSpeed or 2

        local sprite = AnimatedSprite.new(FILE_PATHS.ASSETS.BOT_IMAGES .. botId)
        sprite:addState("d", animationFrames[1], animationFrames[2], { tickStep = animationSpeed })
        sprite:playAnimation()
        sprite:moveTo(startX + (i - 1) * spacingX, startY)

        table.insert(spritesBots, sprite)
    end
end

function WorldComplete:animateBotsRescued()
    local total = #spritesBots

    if total == 0 then
        return
    end

    local frametimer = playdate.frameTimer.new(30 * total, 0, total)

    frametimer.updateCallback = function(timer)
        local index = math.floor(timer.value)

        -- Show bot at index
        local sprite = spritesBots[index]

        if sprite then
            sprite:add()
        end
    end
end

--- INPUT BUTTONS HANDLING

local index = 2
local isButtonsEnabled = false

function WorldComplete:enableButtons()
    isButtonsEnabled = true
end

function WorldComplete:updateButtons()
    restartButton:setSelected(index == 1)
    continueButton:setSelected(index == 2)
end

function WorldComplete:leftButtonUp()
    if (not isButtonsEnabled) or index == 1 then
        return
    end

    index -= 1

    self:updateButtons()
end

function WorldComplete:rightButtonUp()
    if (not isButtonsEnabled) or index == 2 then
        return
    end

    index += 1

    self:updateButtons()
end

function WorldComplete:AButtonUp()
    if not isButtonsEnabled then
        return
    end

    if index == 1 then
        restartButton:performCallback()
    else
        continueButton:performCallback()
    end
end
