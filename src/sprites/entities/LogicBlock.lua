local gfx <const> = playdate.graphics

local imagetable = assert(gfx.imagetable.new(assets.imageTables.logicBlock))

---@class LogicBlock : Entity
---@field fields {chipSet:string[], reverse:boolean}
LogicBlock = Class("LogicBlock", Entity)

function LogicBlock:init(data, levelName)
    LogicBlock.super.init(self, data, levelName, imagetable[1])

    self:setTag(TAGS.DrillableBlock)

    self:setZIndex(Z_INDEX.Level.Active)
    self.chipSet = self.fields.chipSet

    local chipSetToCheck = GUIChipSet.getInstance().chipSet

    self:updateActivationState(chipSetToCheck)
    self.chipSetToCheckPrevious = chipSetToCheck
end

function LogicBlock:setActive(shouldActivate)
    if self.fields.reverse then
        shouldActivate = not shouldActivate
    end

    self:setImage(imagetable[shouldActivate and 2 or 1])
    self:setGroups(shouldActivate and { GROUPS.Solid } or {})
    self.isActive = shouldActivate
end

function LogicBlock:updateActivationState(chipSetToCheck)
    local shouldActivate = true
    for i, chip in ipairs(chipSetToCheck) do
        if chip ~= self.chipSet[i] then
            shouldActivate = false
            break
        end
    end

    self:setActive(shouldActivate)
end

function LogicBlock:update()
    local chipSetToCheckNew = GUIChipSet.getInstance().chipSet

    if self.chipSetToCheckPrevious ~= chipSetToCheckNew then
        self.chipSetToCheckPrevious = chipSetToCheckNew

        self:updateActivationState(chipSetToCheckNew)
    end
end
