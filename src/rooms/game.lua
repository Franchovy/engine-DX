local pd <const> = playdate
local gfx <const> = pd.graphics
local sound <const> = pd.sound

---@class Game : Room
Game = Class("Game", Room)

-- LDtk current level name

local sfxSwoosh <const> = assert(sound.sampleplayer.new(assets.sounds.swoosh))

local msFadeInLevel <const> = 220
local msFadeOutLevel <const> = 160
local msFadeInWorld <const> = 2000
local msFadeOutWorld <const> = 1200

local LEVEL_NAME_INITIAL <const> = "Level_0"
local initialLevelNameSaveProgress
local currentLevelName

local worldCurrent

-- Static methods

function Game.loadAndEnter(filepathLevel)
    -- Create Game Scene

    local game = Game(filepathLevel)

    -- Enter Game Scene

    SCENES.currentGame = game

    Manager.getInstance():enter(game, { isInitialLoad = true })
end

--- @param filepathLevel string level to load
function Game:init(filepathLevel)
    -- Load World / Load + Update progress

    MemoryCard.setLastPlayed(filepathLevel)

    local progressDataLevel = MemoryCard.levelProgressToLoad(filepathLevel)

    worldCurrent = LDtkWorld(filepathLevel, progressDataLevel)
    worldCurrent.isCompleted = false

    -- Get last progress of level

    GUISpriteRescueCounter()

    local progressData = MemoryCard.getLevelCompletion(filepathLevel)

    GUISpriteRescueCounter:getInstance():loadProgressData(progressData)

    --

    Transition()
    GUILightingEffect()
    Background()
    GUILevelName()
    GUIScreenEdges()
    GUIPowerLevel()

    -- Load Ability Panel

    GUIChipSet()

    -- Checkpoints

    self.checkpointHandler = CheckpointHandler.getOrCreate("game", self)

    -- Level change field

    Game.enableLevelChange = true
end

function Game:unload()
    -- Reset load data

    worldCurrent = nil
    currentLevelName = nil

    initialLevelNameSaveProgress = nil


    -- Destroy game-specific singletons (excludes Transition)

    Player.destroy()
    GUILightingEffect:destroy()
    GUIChipSet.destroy()
    GUIScreenEdges.destroy()
    GUISpriteRescueCounter.destroy()
    GUIPowerLevel:destroy()

    Checkpoint.clearAll()

    -- Remove system/PD menu items

    playdate.getSystemMenu():removeAllMenuItems()
    playdate.setMenuImage(nil)

    -- Remove currentGame reference from manager
    SCENES.currentGame = nil

    -- Stop the music!

    FilePlayer.getInstance():stop()
end

---------------------------------
--- SETUP METHODS
---------------------------------

function Game:setupSystemMenu()
    local systemMenu = pd.getSystemMenu()

    systemMenu:removeAllMenuItems()

    -- Main menu return
    systemMenu:addMenuItem("main menu", function()
        Manager.getInstance():enter(SCENES.menu)
    end)

    -- Music enabled/disabled
    local shouldEnableMusic = MemoryCard.getShouldEnableMusic()

    systemMenu:addCheckmarkMenuItem("music", shouldEnableMusic, function(shouldEnableMusic)
        FilePlayer.getInstance():setPaused(not shouldEnableMusic)

        MemoryCard.setShouldEnableMusic(shouldEnableMusic)
    end)
end

---------------------------------
---
---------------------------------

function Game.getLevelName()
    return currentLevelName
end

function Game.getLevelBounds()
    return LDtk.get_rect(currentLevelName)
end

function Game:enter(previous, data)
    assert(worldCurrent, "No world has been loaded!")

    local isFirstTimeLoad = getmetatable(previous).class ~= Game

    if isFirstTimeLoad then
        -- First-time load setup

        self:setupSystemMenu()
    else
        sfxSwoosh:play(1)
    end

    data = data or {}
    local direction = data.direction
    local level = data.level
    local isCheckpointRevert = data.isCheckpointRevert

    -- Get current level

    if isFirstTimeLoad then
        -- Newly loaded world
        currentLevelName = initialLevelNameSaveProgress or LEVEL_NAME_INITIAL
    else
        -- Already loaded game
        currentLevelName = level and level.name
    end

    Camera.reset()

    worldCurrent:loadLevel(currentLevelName, isFirstTimeLoad)

    -- Load level --

    if not isCheckpointRevert then
        self.checkpointHandler:pushState({ levelName = currentLevelName })
    end

    -- Add static classes that should always be present in-game

    local player = Player.getInstance()
    if player then
        player:add()

        Player.getInstance():unfreeze()

        player:enterLevel(currentLevelName, direction)
    end

    Camera.enterLevel(currentLevelName)

    GUISpriteRescueCounter.getInstance():add()
    Transition:getInstance():add()
    GUILightingEffect:getInstance():add()
    GUIChipSet.getInstance():add()
    GUIScreenEdges.getInstance():add()

    Transition:getInstance():fadeIn(isFirstTimeLoad and msFadeInWorld or msFadeInLevel)

    -- Present Level Name if first time load

    if isFirstTimeLoad then
        GUILevelName.getInstance():present()
    elseif GUILevelName.getInstance().isPresenting then
        GUILevelName.getInstance():add()
    end

    if isFirstTimeLoad then
        -- Set initial checkpoint to spawn point

        Checkpoint.incrementNamed("savepoint")
    end
end

function Game:update()
    -- System updates

    Camera.update()

    -- Input handling (for player)

    local player = Player.getInstance()

    if player and not playdate.buttonIsPressed(playdate.kButtonB) then
        local elevator = player:getElevatorActivating()

        if playdate.buttonJustPressed(playdate.kButtonA) then
            player:jump()
        end

        if playdate.buttonIsPressed(playdate.kButtonLeft) then
            player:moveLeft()
        elseif playdate.buttonIsPressed(playdate.kButtonRight) then
            player:moveRight()
        end

        if playdate.buttonIsPressed(playdate.kButtonUp) then
            player:moveUp()
        elseif playdate.buttonIsPressed(playdate.kButtonDown) then
            player:moveDown()
        end
    end

    if player and playdate.buttonIsPressed(playdate.kButtonB) then
        if player.activeBot then
            if playdate.buttonJustPressed(playdate.kButtonB) then
                player.activeBot:onBButtonPress()
            end
        else
            GUIScreenEdges:getInstance():animateIn()

            -- Update camera if pressing a direction + B button

            local directionX, directionY =
                playdate.buttonIsPressed(KEYNAMES.Left) and 1 or playdate.buttonIsPressed(KEYNAMES.Right) and -1 or 0,
                playdate.buttonIsPressed(KEYNAMES.Up) and 1 or playdate.buttonIsPressed(KEYNAMES.Down) and -1 or 0

            local panOffsetX, panOffsetY = 150, 100

            Camera.setOffset(directionX * panOffsetX, directionY * panOffsetY)
        end
    else
        GUIScreenEdges:getInstance():animateOut()
        Camera.setOffset(0, 0)
    end
end

function Game:leave(next, ...)
    -- Remove all particles

    Particles:clearAll()
    --Particles:removeAll()

    -- Clear sprites in level
    -- We do this because "gfx.sprite.removeAll" doesn't call the subclass ":remove()".

    gfx.sprite.performOnAllSprites(function(sprite)
        sprite:remove()
    end)

    --

    if next.super.class ~= Game then
        self:unload()
    end
end

-- Checkpoint interface

function Game:handleCheckpointRevert(state)
    if currentLevelName ~= state.levelName then
        Manager.getInstance():enter(SCENES.currentGame,
            { level = { name = state.levelName }, isCheckpointRevert = true })
    end
end

function Game:returnToCheckpointNamed(name, finishedCallback)
    local player = Player.getInstance()
    if not player then return end

    Game.enableLevelChange = false

    Transition:getInstance():fadeOut(1000, function()
        player:freeze()

        playdate.timer.performAfterDelay(2000, function()
            Checkpoint.goToNamed(name)

            Camera.setOffsetInstantaneous()

            Transition:getInstance():fadeIn(500, function()
                Game.enableLevelChange = true

                player:unfreeze()

                if finishedCallback then
                    finishedCallback()
                end
            end)
        end
        )
    end)
end

---------------------------------
--- Event-based methods
---------------------------------

function Game:levelComplete(data)
    if worldCurrent.isCompleted or Game.enableLevelChange == false then
        return
    end

    Player.getInstance():freeze()

    local direction = data.direction
    local coordinates = data.coordinates

    Transition:getInstance():fadeOut(msFadeOutLevel, function()
        -- Load next level

        local nextLevel, nextLevelBounds = LDtk.getNeighborLevelForPos(currentLevelName, direction, coordinates)

        Manager:getInstance():enter(SCENES.currentGame,
            { direction = direction, level = { name = nextLevel, bounds = nextLevelBounds } })
    end)
end

function Game:botRescued(bot, botNumber)
    local spriteRescueCounter = GUISpriteRescueCounter.getInstance()
    spriteRescueCounter:setSpriteRescued(botNumber, bot.fields.spriteNumber)

    -- Save the rescued sprite list
    local rescuedSprites = spriteRescueCounter:getRescuedSprites()
    MemoryCard.setLevelCompletion(worldCurrent.filepath, { rescuedSprites = rescuedSprites })
end

function Game:worldComplete(args)
    if worldCurrent.isCompleted then
        return
    end

    worldCurrent.isCompleted = true

    -- Freeze Player

    Player.getInstance():freeze()

    -- Clear out checkpoint handling

    Checkpoint.clearAll()

    -- Fade out music - after same delay as transition

    FilePlayer.getInstance():fadeOut(msFadeOutWorld)

    local shouldSkipTransition = args and args.skipTransition or false

    -- Set level complete in data

    Transition:getInstance():fadeOut(not shouldSkipTransition and msFadeOutWorld or 0, function()
        -- Update level progress

        local saveData = { complete = true, currentLevel = LEVEL_NAME_INITIAL }
        MemoryCard.setLevelCompletion(worldCurrent.filepath, saveData)

        -- Remove progress file
        MemoryCard.clearLevelCheckpoint(worldCurrent.filepath)

        -- Get next level to play

        local filepathLevelNext = ReadFile.getNextWorld(worldCurrent.filepath)

        if filepathLevelNext then
            -- Clear Player Instance
            Player.destroy()

            Manager.getInstance():enter(SCENES.worldComplete, worldCurrent.filepath, filepathLevelNext)

            Transition:getInstance():fadeIn(msFadeInWorld)
        end
    end)
end

function Game:chipSetNew(chipSet)
    local abilityPanel = GUIChipSet.getInstance()

    abilityPanel:setChipSet(chipSet, true)
end

function Game:chipSetAdd(button, sprite)
    local chipSet = GUIChipSet.getInstance()

    chipSet:performPickUp(button, sprite)
end

function Game:chipSetPower(power)
    local abilityPanel = GUIChipSet.getInstance()

    abilityPanel:setIsPowered(power)
end

function Game:checkpointIncrement()
    Checkpoint.increment()
end

function Game:savePointSet()
    local levelData = LDtk.getAllLevels()

    --[[MemoryCard.saveLevelCheckpoint(worldCurrent.filepath, levelData)]]

    local spriteRescueCounter = GUISpriteRescueCounter.getInstance()
    local rescuedSprites = spriteRescueCounter:getRescuedSprites()
    --[[MemoryCard.setLevelCompletion(worldCurrent.filepath,
        { currentLevel = currentLevelName, rescuedSprites = rescuedSprites })]]

    Checkpoint.incrementNamed("savepoint")
end

function Game:checkpointRevert()
    -- Revert checkpoint
    Checkpoint.goToPrevious()
end

function Game:hideOrShowGui(shouldHide)
    local abilityPanel = GUIChipSet.getInstance()

    if shouldHide then
        abilityPanel:hide()
    else
        abilityPanel:show()
    end
end

function Game:collectiblePickup(collectibleIndex, collectibleHash)
    MemoryCard.setCollectiblePickup(collectibleIndex, collectibleHash)

    local levelCompletion = MemoryCard.getLevelCompletion(worldCurrent.filepath)

    local collectibles = levelCompletion and levelCompletion.collectibles or {}

    collectibles[collectibleIndex] = collectibleHash

    MemoryCard.setLevelCompletion(worldCurrent.filepath, { collectibles = collectibles })
end

function Game:gameWillPause()
    local pauseImage, offset = self:createPauseMenuImage()

    playdate.setMenuImage(pauseImage, offset)
end

function Game:createPauseMenuImage()
    local image = gfx.image.new(400, 240, gfx.kColorClear)
    gfx.pushContext(image)

    local offset = 100
    local x, y, width, height, margin, border = 40, 50, 120, 140, 4, 2

    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer4x4)
    gfx.fillRect(0, 0, 400, 240)

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(offset + x, y, width, height, margin)

    gfx.setColor(gfx.kColorBlack)

    gfx.setLineWidth(border)
    gfx.drawRoundRect(offset + x + border, y + border, width - border * 2, height - border * 2, border)

    -- Draw level name

    gfx.setFont(Fonts.Dialog)
    local area, world = ReadFile.getAreaWorld(worldCurrent.filepath)
    local w, heightText, wasTruncated = gfx.drawTextInRect(world, offset + x + margin, y + 16,
        width - margin * 2,
        height - margin * 2, nil, nil, kTextAlignment.center)

    -- Get collectibles

    local completionData = MemoryCard.getLevelCompletion(worldCurrent.filepath)
    local collectibles = completionData and completionData.collectibles or {}

    -- Get rescues

    local rescueCountTotal = GUISpriteRescueCounter.getInstance():getTotalSpritesToRescue() + #collectibles
    local rescues = GUISpriteRescueCounter.getInstance():getRescuedSprites()

    -- Draw rescues & collectibles

    local lineCount = 4
    local widthIndicatorRescue, heightIndicatorRescue, spacing = 20, 20, 8
    local lineCountMax = math.min(4, rescueCountTotal)
    local xStart =
        offset + x + width / 2 - (lineCountMax * widthIndicatorRescue +
            math.max(lineCountMax - 1, 0) * spacing) / 2
    local yStart = y + 16 + heightText + 8

    local function getDrawPosFromIndex(index)
        local index = index - 1
        local indexOnLine = (index % lineCount)
        local x = xStart + indexOnLine * (widthIndicatorRescue + spacing)
        local y = yStart + math.floor(index / lineCount) * (heightIndicatorRescue + spacing)
        return x, y
    end

    for i = 1, rescueCountTotal - #collectibles do
        local isRescued = rescues[i] and rescues[i].value == true

        local xDraw, yDraw = getDrawPosFromIndex(i)

        -- Draw Rescue

        gfx.setColor(gfx.kColorBlack)

        gfx.drawRoundRect(
            xDraw,
            yDraw,
            widthIndicatorRescue,
            heightIndicatorRescue,
            4
        )

        if isRescued then
            gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer4x4)

            gfx.fillRoundRect(
                xDraw,
                yStart,
                widthIndicatorRescue,
                heightIndicatorRescue,
                4
            )
        end
    end

    local i = 1
    for index, _ in ipairs(collectibles) do
        local xDraw, yDraw = getDrawPosFromIndex(#rescues + i)

        -- Draw Collectible

        local image = Collectible.getImageForIndex(index)
        image:draw(xDraw, yDraw)

        i += 1
    end

    return image, offset
end
