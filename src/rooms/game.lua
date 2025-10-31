local pd <const> = playdate
local gfx <const> = pd.graphics
local sound <const> = pd.sound

---@class Game : Room
Game = Class("Game", Room)

-- LDtk current level name

local msFadeInLevel <const> = 220
local msFadeOutLevel <const> = 160
local msFadeInWorld <const> = 600
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

    SpriteRescueCounter()

    local progressData = MemoryCard.getLevelCompletion(filepathLevel)

    SpriteRescueCounter:getInstance():loadProgressData(progressData)

    --

    Transition()

    GUILightingEffect()

    Background()

    -- Load Ability Panel

    GUIChipSet()

    -- Checkpoints

    self.checkpointHandler = CheckpointHandler.getOrCreate("game", self)
end

function Game:unload()
    -- Reset load data

    worldCurrent = nil
    currentLevelName = nil

    initialLevelNameSaveProgress = nil

    -- Remove active cheats

    Player.destroy()
    GUICheatUnlock.destroy()
    GUIChipSet.destroy()
    SpriteRescueCounter.destroy()

    Checkpoint.clearAll()

    -- Remove system/PD menu items

    playdate.getSystemMenu():removeAllMenuItems()

    -- Remove currentGame reference from manager
    SCENES.currentGame = nil

    -- Stop the music!

    FilePlayer.stop()
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
        if shouldEnableMusic then
            FilePlayer.play(assets.music.game)
        else
            FilePlayer.stop()
        end

        MemoryCard.setShouldEnableMusic(shouldEnableMusic)
    end)
end

function Game:setupMusic()
    -- Load if music should play:

    local shouldEnableMusic = MemoryCard.getShouldEnableMusic()

    -- Play music if enabled

    if shouldEnableMusic then
        FilePlayer.play(assets.music.game)
    end
end

function Game:setupCheats()
    local guiCheatUnlock = GUICheatUnlock()

    -- Unlock Crank: LRLR-UDU-BAA
    guiCheatUnlock:addCheat(
        { pd.kButtonLeft, pd.kButtonRight, pd.kButtonLeft, pd.kButtonRight, pd
            .kButtonUp, pd.kButtonDown, pd.kButtonUp, pd.kButtonB, pd.kButtonA, pd.kButtonA },
        function() Player.getInstance():unlockAbility(ABILITIES.CrankToWarp) end
    )

    -- Unlock Double Jump: LRRL-UDU-BAA
    guiCheatUnlock:addCheat(
        { pd.kButtonLeft, pd.kButtonRight, pd.kButtonRight, pd.kButtonLeft, pd
            .kButtonUp, pd.kButtonDown, pd.kButtonUp, pd.kButtonB, pd.kButtonA, pd.kButtonA },
        function() Player.getInstance():unlockAbility(ABILITIES.DoubleJump) end
    )

    -- Unlock Dash: LLRR-UDU-BAA
    guiCheatUnlock:addCheat(
        { pd.kButtonLeft, pd.kButtonLeft, pd.kButtonRight, pd.kButtonRight, pd
            .kButtonUp, pd.kButtonDown, pd.kButtonUp, pd.kButtonB, pd.kButtonA, pd.kButtonA },
        function() Player.getInstance():unlockAbility(ABILITIES.Dash) end
    )
end

function Game:setupFonts()
    -- Set Font

    local fontDefault = gfx.font.new(assets.fonts.dialog)
    gfx.setFont(fontDefault)
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

        self:setupMusic()
        self:setupSystemMenu()
        self:setupCheats()
        self:setupFonts()
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

    worldCurrent:loadLevel(currentLevelName, isFirstTimeLoad)

    -- Load level --

    if not isCheckpointRevert then
        self.checkpointHandler:pushState({ levelName = currentLevelName })
    end

    -- Add static classes that should always be present in-game

    local player = Player.getInstance()
    if player then
        player:add()
    end

    if player then
        player:enterLevel(currentLevelName, direction)
    end

    Camera.enterLevel(currentLevelName)

    SpriteRescueCounter.getInstance():add()
    Transition.getInstance():add()
    GUILightingEffect.getInstance():add()
    GUICheatUnlock.getInstance():add()
    GUIChipSet.getInstance():add()
end

function Game:update()
end

function Game:leave(next, ...)
    -- Clear sprites in level

    gfx.sprite.removeAll()

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

    Transition:getInstance():fadeOut(msFadeOutLevel, function()
        -- Load next level

        local nextLevel, nextLevelBounds = LDtk.getNeighborLevelForPos(currentLevelName, direction, coordinates)

        Manager:getInstance():enter(SCENES.currentGame,
            { direction = direction, level = { name = nextLevel, bounds = nextLevelBounds } })

        Player.getInstance():unfreeze()

        Transition:getInstance():fadeIn(msFadeInLevel)
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

    -- Fade out music - after same delay as transition

    FilePlayer:fadeOut(msFadeOutWorld)

    -- Set level complete in data

    Transition:getInstance():fadeOut(msFadeOutWorld, function()
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
