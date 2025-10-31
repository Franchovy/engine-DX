---@class LDtkWorld
---@property isCompleted boolean
LDtkWorld = Class("LDtkWorld")

function LDtkWorld:init(filepathLevel, progressEntitiesData)
    LDtk.load(filepathLevel)

    if progressEntitiesData then
        LDtk.loadLevelEntitiesData(progressEntitiesData)
    end

    self.filepath = filepathLevel
    self.isCompleted = false
end

function LDtkWorld:loadLevel(levelName, isFirstTimeLoad)
    -- Load level layers

    LDtk.loadAllLayersAsSprites(levelName)

    -- Load level sprites

    LDtk.loadAllEntitiesAsSprites(levelName)

    -- Get custom data if exists

    local dataRaw = LDtk.get_custom_data(levelName)
    if not dataRaw then
        return
    end

    if isFirstTimeLoad then
        -- Load GamePoints on Load (first-time only)

        for _, idGamepoint in pairs(dataRaw["gamepointsOnLoad"] or {}) do
            LDtk.entitiesById[idGamepoint].sprite:load()
        end
    end

    -- Load GamePoints on Enter

    for _, idGamepoint in pairs(dataRaw["gamepointsOnEnter"] or {}) do
        LDtk.entitiesById[idGamepoint].sprite:load()
    end
end
