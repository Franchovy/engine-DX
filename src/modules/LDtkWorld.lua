---@class LDtkWorld
---@property isCompleted boolean
LDtkWorld = Class("LDtkWorld")

function LDtkWorld.load(config)
    if config.activate then
        -- Call activate on sprites
        if type(config.activate) == "string" then
            local entity = LDtk.entitiesById[config.activate]

            if entity and entity.sprite and entity.sprite.activate then
                entity.sprite:activate()
            end
        end
    end
end

function LDtkWorld:init(filepathLevel, progressEntitiesData)
    LDtk.load(filepathLevel)

    if progressEntitiesData then
        LDtk.loadLevelEntitiesData(progressEntitiesData)
    end

    self.filepath = filepathLevel
    self.isCompleted = false
end

function LDtkWorld:loadLevel(levelName)
    -- Load level layers

    LDtk.loadAllLayersAsSprites(levelName)

    -- Load level sprites

    LDtk.loadAllEntitiesAsSprites(levelName)

    -- Load Pathfinding for world

    LDTkPathFinding.load(levelName)

    -- Get custom data if exists

    local dataRaw = LDtk.get_custom_data(levelName)
    if not dataRaw then
        return
    end

    if not dataRaw.isFirstTimeLoaded then
        -- Load GamePoints on Load (first-time only)

        for _, idGamepoint in pairs(dataRaw["gamepointsOnLoad"] or {}) do
            local gamepoint = LDtk.entitiesById[idGamepoint]
            if gamepoint and gamepoint.sprite then
                gamepoint.sprite:load()
            end
        end

        -- Set loaded on LDtk data

        dataRaw.isFirstTimeLoaded = true
    end

    -- Load GamePoints on Enter

    for _, idGamepoint in pairs(dataRaw["gamepointsOnEnter"] or {}) do
        local gamepoint = LDtk.entitiesById[idGamepoint]
        if gamepoint and gamepoint.sprite then
            gamepoint.sprite:load()
        end
    end
end
