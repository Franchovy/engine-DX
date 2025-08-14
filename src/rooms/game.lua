local pd <const> = playdate
local gfx <const> = pd.graphics
local sound <const> = pd.sound

Game = Class("Game", Room)

local sceneManager
local systemMenu <const> = pd.getSystemMenu()

local worldName
local areaName

-- LDtk current level name

local LEVEL_NAME_INITIAL <const> = "Level_0"
local initialLevelNameSaveProgress
local currentLevelName

local spriteTransition
local spriteGUILightingEffect
local spriteGUILevelComplete
local spriteBackground

-- Sprites

local botsToRescueCountDefault <const> = 3

-- Static methods

--- @param area string
--- @param world string
function Game.loadWorld(area, world)
    -- Load LDtk file

    local filepathLevel = ReadFile.getWorldFilepath(area, world)

    LDtk.load(filepathLevel)

    -- Check if save data exists

    local fileLevelProgress = MemoryCard.levelProgressToLoad(area, world)

    if fileLevelProgress then
        -- Replace entities data in LDtk loaded levels with save progress

        LDtk.loadLevelEntitiesData(fileLevelProgress)
    end

    -- Get last progress of level

    local dataProgress = MemoryCard.getLevelCompletion(area, world)

    if dataProgress then
        if dataProgress.currentLevel then
            initialLevelNameSaveProgress = dataProgress.currentLevel
        end

        if dataProgress.rescuedSprites then
            local spriteRescueCounter = SpriteRescueCounter.getInstance()

            spriteRescueCounter:loadRescuedSprites(dataProgress.rescuedSprites)

            spriteRescueCounter:setPositionsSpriteCounter()
        end
    end

    --

    MemoryCard.setLastPlayed(area, world)

    -- Set world name

    worldName = world
    areaName = area
end

function Game.getLevelName()
    return currentLevelName
end

function Game.getLevelBounds()
    return LDtk.get_rect(currentLevelName)
end

-- Private Methods

local function goToStart()
    sceneManager:enter(sceneManager.scenes.menu)
end

-- Instance methods

function Game:init()
    self.checkpointHandler = CheckpointHandler.getOrCreate("game", self)

    spriteGUILevelComplete = GUILevelComplete()

    SpriteRescueCounter()

    spriteTransition = Transition()

    spriteGUILightingEffect = GUILightingEffect()

    spriteBackground = Background()
end

function Game:enter(previous, data)
    assert(worldName, "No world has been loaded!")

    data = data or {}
    local direction = data.direction
    local level = data.level
    local isCheckpointRevert = data.isCheckpointRevert

    -- Set Font

    local fontDefault = gfx.font.new(assets.fonts.dialog)
    gfx.setFont(fontDefault)

    -- Load rescuable bot array

    -- Get current level

    currentLevelName = level and level.name or initialLevelNameSaveProgress or LEVEL_NAME_INITIAL

    -- Load level bounds

    local levelBounds = level and level.bounds or LDtk.get_rect(currentLevelName)

    -- Load level fields

    local levelData = LDtk.get_custom_data(currentLevelName) or {}

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

    -- This should run only once to initialize the game instance.

    if not self.isInitialized then
        self.isInitialized = true

        -- Set local reference to sceneManager

        sceneManager = self.manager
        sceneManager.scenes.currentGame = self

        -- Load Ability Panel

        self.abilityPanel = GUIChipSet()

        -- Load if music should play:

        local shouldEnableMusic = MemoryCard.getShouldEnableMusic()

        -- Play music if enabled

        if shouldEnableMusic then
            FilePlayer.play(assets.music.game)
        end

        -- Menu items

        systemMenu:removeAllMenuItems()

        systemMenu:addMenuItem("main menu", goToStart)
        systemMenu:addCheckmarkMenuItem("music", shouldEnableMusic, function(shouldEnableMusic)
            if shouldEnableMusic then
                FilePlayer.play(assets.music.game)
            else
                FilePlayer.stop()
            end

            MemoryCard.setShouldEnableMusic(shouldEnableMusic)
        end)

        -- Cheats

        self.guiCheatUnlock = GUICheatUnlock()

        -- Crank unlock cheat

        self.guiCheatUnlock:addCheat(
            { pd.kButtonDown, pd.kButtonDown, pd.kButtonUp, pd.kButtonLeft, pd.kButtonRight, pd.kButtonLeft, pd
                .kButtonRight, pd.kButtonB, pd.kButtonB, pd.kButtonA, pd.kButtonA },
            function() Player.getInstance():unlockCrank() end
        )
        self.guiCheatUnlock:addCheat(
            { pd.kButtonLeft, pd.kButtonRight, pd.kButtonRight, pd.kButtonLeft, pd
                .kButtonUp, pd.kButtonDown, pd.kButtonUp, pd.kButtonA, pd.kButtonA },
            function() print("Alt cheat") end
        )

        -- Set world not complete

        self.isWorldComplete = false

        -- Perma-power enabled/disabled

        GUIChipSet.getInstance():setPowerPermanent(levelData.power)
    end

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

        if checkpoint then
            player:setBlueprints(checkpoint.blueprints)
            player:moveTo(checkpoint.x, checkpoint.y)
        end

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
        worldName = nil

        -- Remove end timer

        if timerEndSceneTransition then
            self.timerEndSceneTransition:remove()
            self.timerEndSceneTransition = nil
        end

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
        sceneManager.scenes.currentGame = nil

        -- Stop the music!

        FilePlayer.stop()
    end
end

-- Checkpoint interface

function Game:handleCheckpointRevert(state)
    if currentLevelName ~= state.levelName then
        sceneManager:enter(sceneManager.scenes.currentGame,
            { level = { name = state.levelName }, isCheckpointRevert = true })
    end
end

-- Event-based methods

function Game:levelComplete(data)
    if self.isWorldComplete then
        Player.getInstance():freeze()

        return
    end

    local direction = data.direction
    local coordinates = data.coordinates

    Player.getInstance():freeze()

    spriteTransition:startTransitionLevelChange(direction, function()
        -- Load next level

        local nextLevel, nextLevelBounds = LDtk.getNeighborLevelForPos(currentLevelName, direction, coordinates)

        sceneManager:enter(sceneManager.scenes.currentGame,
            { direction = direction, level = { name = nextLevel, bounds = nextLevelBounds } })

        Player.getInstance():unfreeze()
    end)
end

function Game:botRescued(bot, botNumber)
    local spriteRescueCounter = SpriteRescueCounter.getInstance()
    spriteRescueCounter:setSpriteRescued(botNumber, bot.fields.spriteNumber)

    -- Save the rescued sprite list
    local rescuedSprites = spriteRescueCounter:getRescuedSprites()
    MemoryCard.setLevelCompletion(areaName, worldName, { rescuedSprites = rescuedSprites })

    if spriteRescueCounter:isAllSpritesRescued() then
        self:worldComplete()
    end
end

function Game:worldComplete()
    if self.isWorldComplete then
        return
    end

    self.isWorldComplete = true

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
        MemoryCard.setLevelCompletion(areaName, worldName, saveData)

        -- Remove progress file
        MemoryCard.clearLevelCheckpoint(areaName, worldName)

        -- Get next level to play

        local nextArea, nextWorld = ReadFile.getNextWorld(worldName, areaName)

        if nextArea and nextWorld then
            -- Clear Player Instance

            Player.destroy()

            -- Load next level

            sceneManager.scenes.currentGame = Game()

            Game.loadWorld(nextArea, nextWorld)

            sceneManager:enter(sceneManager.scenes.currentGame, { isInitialLoad = true })
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

    MemoryCard.saveLevelCheckpoint(areaName, worldName, levelData)

    local spriteRescueCounter = SpriteRescueCounter.getInstance()
    local rescuedSprites = spriteRescueCounter:getRescuedSprites()
    MemoryCard.setLevelCompletion(areaName, worldName,
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
