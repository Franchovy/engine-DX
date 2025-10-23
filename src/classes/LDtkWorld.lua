---@class LDtkWorld
LDtkWorld = Class("LDtkWorld")

function LDtkWorld:init(filepathLevel, progressEntitiesData)
    LDtk.load(filepathLevel)

    if progressEntitiesData then
        LDtk.loadLevelEntitiesData(progressEntitiesData)
    end
end
