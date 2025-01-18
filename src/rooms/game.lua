local pd <const> = playdate
local gfx <const> = pd.graphics
local sound <const> = pd.sound

Game = Class("Game", Room)

local sceneManager
local systemMenu <const> = pd.getSystemMenu()

local spCheckpointRevert <const> = sound.sampleplayer.new("assets/sfx/checkpoint-revert")
local spWarpAction <const> = playdate.sound.sampleplayer.new(assets.sounds.warpAction)

local worldName
local areaName

-- LDtk current level name

local LEVEL_NAME_INITIAL <const> = "Level_0"
local initialLevelNameSaveProgress
local currentLevelName

local spriteTransition
local spriteGUILightingEffect
local spriteGUILevelComplete

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
    local levelBounds = level and level.bounds or LDtk.get_rect(currentLevelName)

    -- Initial Load - only run once per world

    if data.isInitialLoad then
        -- Load level fields (used only on the initial level)

        local levelData = LDtk.get_custom_data(LEVEL_NAME_INITIAL) or {}

        -- Set up GUI

        local spriteRescueCounter = SpriteRescueCounter.getInstance()

        -- Set Save count

        spriteRescueCounter:setRescueSpriteCount(levelData.saveCount or botsToRescueCountDefault)
    end

    -- This should run only once to initialize the game instance.

    if not self.isInitialized then
        self.isInitialized = true

        -- Set local reference to sceneManager

        sceneManager = self.manager
        sceneManager.scenes.currentGame = self

        -- Load Ability Panel

        self.abilityPanel = AbilityPanel()

        -- Load if music should play:

        local shouldEnableMusic = MemoryCard.getShouldEnableMusic()

        -- Play music if enabled

        if shouldEnableMusic then
            FilePlayer.play(assets.music.game)
        end

        -- Menu items

        systemMenu:addMenuItem("main menu", goToStart)
        systemMenu:addCheckmarkMenuItem("music", shouldEnableMusic, function(shouldEnableMusic)
            if shouldEnableMusic then
                FilePlayer.play(assets.music.game)
            else
                FilePlayer.stop()
            end

            MemoryCard.setShouldEnableMusic(shouldEnableMusic)
        end)
    end

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

        player:enterLevel(direction, levelBounds)
    end

    local abilityPanel = AbilityPanel.getInstance()

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

        -- Clear ability panel

        AbilityPanel.getInstance():remove()
        AbilityPanel.destroy()

        -- Clear player data

        Player.getInstance():remove()
        Player.destroy()

        -- Clear checkpoints

        Checkpoint.clearAll()

        -- Clear rescued sprites

        SpriteRescueCounter.destroy()

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
    local direction = data.direction
    local coordinates = data.coordinates

    Player.getInstance():freeze()

    spriteTransition:startTransition(direction, function()
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
        -- Add on-screen text

        spriteGUILevelComplete:add()

        -- Set player state to game end

        Player.getInstance():setLevelEndReady()

        -- Set level complete in data

        local saveData = { complete = true, currentLevel = LEVEL_NAME_INITIAL }
        MemoryCard.setLevelCompletion(areaName, worldName, saveData)

        -- Remove progress file
        MemoryCard.clearLevelCheckpoint(areaName, worldName)
    end
end

function Game:updateBlueprints()
    local abilityPanel = AbilityPanel.getInstance()
    abilityPanel:updateBlueprints()
end

function Game:checkpointIncrement()
    Checkpoint.increment()
end

function Game:savePointSet()
    local levelData = LDtk.getAllLevels()

    MemoryCard.saveLevelCheckpoint(areaName, worldName, levelData)

    MemoryCard.setLevelCompletion(areaName, worldName, { currentLevel = currentLevelName })

    Checkpoint.clearAllPrevious()
end

function Game:checkpointRevert()
    if not SpriteRescueCounter.getInstance():isAllSpritesRescued() then
        -- SFX

        spWarpAction:play(1)
        spCheckpointRevert:play(1)

        -- Revert checkpoint
        Checkpoint.goToPrevious()
    elseif not self.timerEndSceneTransition then
        -- If all bots have been rescued, then finish the level.

        self.timerEndSceneTransition = playdate.timer.performAfterDelay(3000, function()
            sceneManager:enter(sceneManager.scenes.levelSelect)
        end)
    end
end

function Game:hideOrShowGui(shouldHide)
    local abilityPanel = AbilityPanel.getInstance()

    if shouldHide then
        abilityPanel:hide()
    else
        abilityPanel:show()
    end
end
