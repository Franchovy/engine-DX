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
