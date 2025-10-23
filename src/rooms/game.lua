local pd <const> = playdate
local gfx <const> = pd.graphics
local sound <const> = pd.sound

Game = Class("Game", Room)

local sceneManager

-- LDtk current level name

local LEVEL_NAME_INITIAL <const> = "Level_0"
local initialLevelNameSaveProgress
local currentLevelName

local spriteTransition
local spriteGUILightingEffect
local spriteGUILevelComplete
local spriteBackground

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
    -- MEMORY CARD

    MemoryCard.setLastPlayed(filepathLevel)

    local progressDataLevel = MemoryCard.levelProgressToLoad(filepathLevel)

    worldCurrent = LDtkWorld(filepathLevel, progressDataLevel)

    -- Get last progress of level

    local progressData = MemoryCard.getLevelCompletion(filepathLevel)

    SpriteRescueCounter.loadProgressData(progressData)

    --

    -- Set world name

    self.checkpointHandler = CheckpointHandler.getOrCreate("game", self)

    spriteGUILevelComplete = GUILevelComplete()

    SpriteRescueCounter()

    spriteTransition = Transition()

    spriteGUILightingEffect = GUILightingEffect()

    spriteBackground = Background()

    -- Load Ability Panel

    self.abilityPanel = GUIChipSet()

    -- Music

    self:setupMusic()

    -- Menu items

    self:setupSystemMenu()

    -- Cheats

    self:setupCheats()

    -- Set world not complete

    worldCurrent.isCompleted = false
end

---------------------------------
--- SETUP METHODS
---------------------------------

function Game:setupMusic()
    -- Load if music should play:

    local shouldEnableMusic = MemoryCard.getShouldEnableMusic()

    -- Play music if enabled

    if shouldEnableMusic then
        FilePlayer.play(assets.music.game)
    end
end

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
        if shouldEnableMusic then
            FilePlayer.play(assets.music.game)
        else
            FilePlayer.stop()
        end

        MemoryCard.setShouldEnableMusic(shouldEnableMusic)
    end)
end

function Game:setupCheats()
    self.guiCheatUnlock = GUICheatUnlock()

    -- Unlock Crank: LRLR-UDU-BAA
    self.guiCheatUnlock:addCheat(
        { pd.kButtonLeft, pd.kButtonRight, pd.kButtonLeft, pd.kButtonRight, pd
            .kButtonUp, pd.kButtonDown, pd.kButtonUp, pd.kButtonB, pd.kButtonA, pd.kButtonA },
        function() Player.getInstance():unlockAbility(ABILITIES.CrankToWarp) end
    )

    -- Unlock Double Jump: LRRL-UDU-BAA
    self.guiCheatUnlock:addCheat(
        { pd.kButtonLeft, pd.kButtonRight, pd.kButtonRight, pd.kButtonLeft, pd
            .kButtonUp, pd.kButtonDown, pd.kButtonUp, pd.kButtonB, pd.kButtonA, pd.kButtonA },
        function() Player.getInstance():unlockAbility(ABILITIES.DoubleJump) end
    )

    -- Unlock Dash: LLRR-UDU-BAA
    self.guiCheatUnlock:addCheat(
        { pd.kButtonLeft, pd.kButtonLeft, pd.kButtonRight, pd.kButtonRight, pd
            .kButtonUp, pd.kButtonDown, pd.kButtonUp, pd.kButtonB, pd.kButtonA, pd.kButtonA },
        function() Player.getInstance():unlockAbility(ABILITIES.Dash) end
    )
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

    data = data or {}
    local direction = data.direction
    local level = data.level
    local isCheckpointRevert = data.isCheckpointRevert

    -- Get current level

    if currentLevelName then
        -- Already loaded game
        currentLevelName = level and level.name
    else
        currentLevelName = initialLevelNameSaveProgress or LEVEL_NAME_INITIAL
    end

    -- Set Font

    local fontDefault = gfx.font.new(assets.fonts.dialog)
    gfx.setFont(fontDefault)

    -- Load level fields

    local levelData = LDtk.get_custom_data(currentLevelName) or {}

    -- Parse custom level data

    self:parseCustomLevelData(levelData)

    self.guiCheatUnlock:add()

    -- Load level --

    if not isCheckpointRevert then
        self.checkpointHandler:pushState({ levelName = currentLevelName })
    end

    -- Load level layers

    LDtk.loadAllLayersAsSprites(currentLevelName)

    -- Load level sprites

    LDtk.loadAllEntitiesAsSprites(currentLevelName)

    local player = Player.getInstance()

    if player then
        player:add()
        player:enterLevel(currentLevelName, direction)

        Camera.enterLevel(currentLevelName)
    end

    local abilityPanel = GUIChipSet.getInstance()

    if abilityPanel then
        abilityPanel:add()
    end

    local rescueCounter = SpriteRescueCounter.getInstance()

    if rescueCounter then
        rescueCounter:add()
    end

    if getmetatable(previous).class == Game then
        -- Add Transition Sprite to finish transition
        spriteTransition:add()
    end

    if CONFIG.ADD_DARKNESS_EFFECT or CONFIG.ADD_SUPER_DARKNESS_EFFECT then
        spriteGUILightingEffect:add()
    end
end

function Game:update()

end

function Game:leave(next, ...)
    -- Clear sprites in level

    gfx.sprite.removeAll()

    --

    if next.super.class == Menu or next.super.class == LevelSelect then
        -- Reset load data

        initialLevelNameSaveProgress = nil

        -- Remove active cheats

        self.guiCheatUnlock:clearAll()

        -- Clear ability panel

        GUIChipSet.getInstance():remove()
        GUIChipSet.destroy()

        -- Clear player data

        Player.getInstance():remove()
        Player.destroy()

        -- Clear checkpoints

        Checkpoint.clearAll()

        -- Clear rescued sprites

        SpriteRescueCounter.getInstance():reset()

        -- Remove system/PD menu items

        systemMenu:removeAllMenuItems()

        -- Remove currentGame reference from manager
        SCENES.currentGame = nil

        -- Stop the music!

        FilePlayer.stop()
    end
end

-- Level data setup

function Game:parseCustomLevelData(levelData)
    -- Set Save count & GUI

    local spriteRescueCounter = SpriteRescueCounter.getInstance()
    if #spriteRescueCounter:getRescuedSprites() == 0 and levelData.saveCount then
        spriteRescueCounter:setRescueSpriteCount(levelData.saveCount)

        spriteRescueCounter:setPositionsSpriteCounter()
    end

    -- Add Parallax if required

    if levelData.parallax or CONFIG.PARALLAX_BG then
        spriteBackground.enterLevel(currentLevelName)

        spriteBackground:add()
    end

    -- Perma-power enabled/disabled

    if not self.isInitialized then
        local isPoweredPermanent = levelData.power or false -- for backwards compatibility
        GUIChipSet.getInstance():setPowerPermanent(isPoweredPermanent)
    end
end

-- Checkpoint interface

function Game:handleCheckpointRevert(state)
    if currentLevelName ~= state.levelName then
        sceneManager:enter(SCENES.currentGame,
            { level = { name = state.levelName }, isCheckpointRevert = true })
    end
end

---------------------------------
--- Event-based methods
---------------------------------

function Game:levelComplete(data)
    if worldCurrent.isCompleted then
        Player.getInstance():freeze()

        return
    end

    local direction = data.direction
    local coordinates = data.coordinates

    Player.getInstance():freeze()

    spriteTransition:startTransitionLevelChange(direction, function()
        -- Load next level

        local nextLevel, nextLevelBounds = LDtk.getNeighborLevelForPos(currentLevelName, direction, coordinates)

        Manager:getInstance():enter(SCENES.currentGame,
            { direction = direction, level = { name = nextLevel, bounds = nextLevelBounds } })

        Player.getInstance():unfreeze()
    end)
end

function Game:botRescued(bot, botNumber)
    local spriteRescueCounter = SpriteRescueCounter.getInstance()
    spriteRescueCounter:setSpriteRescued(botNumber, bot.fields.spriteNumber)

    -- Save the rescued sprite list
    local rescuedSprites = spriteRescueCounter:getRescuedSprites()
    MemoryCard.setLevelCompletion(worldCurrent.filepath, { rescuedSprites = rescuedSprites })

    if spriteRescueCounter:isAllSpritesRescued() then
        self:worldComplete()
    end
end

function Game:worldComplete()
    if worldCurrent.isCompleted then
        return
    end

    worldCurrent.isCompleted = true

    -- Freeze Player

    Player.getInstance():freeze()

    -- Clear out checkpoint handling

    Checkpoint.clearAll()

    -- Fade out music

    FilePlayer:fadeOut(spriteTransition:getDelayFadeOutWorldComplete())

    -- Set level complete in data

    spriteTransition:startTransitionWorldComplete(function()
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

            Game.loadAndEnter(filepathLevelNext)
        end
    end)
end

function Game:chipSetNew(chipSet)
    local abilityPanel = GUIChipSet.getInstance()

    abilityPanel:setChipSet(chipSet)
end

function Game:chipSetAdd(chip)
    local abilityPanel = GUIChipSet.getInstance()

    abilityPanel:addChip(chip)
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

    MemoryCard.saveLevelCheckpoint(worldCurrent.filepath, levelData)

    local spriteRescueCounter = SpriteRescueCounter.getInstance()
    local rescuedSprites = spriteRescueCounter:getRescuedSprites()
    MemoryCard.setLevelCompletion(worldCurrent.filepath,
        { currentLevel = currentLevelName, rescuedSprites = rescuedSprites })

    Checkpoint.clearAllPrevious()
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
end
