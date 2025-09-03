-- ConsumableSprite - interfaces with LDtk loading, saving state, as well as checkpoints.
-- For now handles a simple binary state of consumed true/false. We can potentially extend this further.

local gfx <const> = playdate.graphics

-- Static states for consumed/not consumed
-- Used specifically for the checkpoint interface to avoid creating lots of tables
-- containing basically the same information. This means we have to be careful not to
-- write to these two tables.

local checkpointStateNotConsumed <const> = {
    consumed = false
}

local checkpointStateConsumed <const> = {
    consumed = true
}

--

local function _shouldSpawn(entityData, levelName)
    -- If sprite has been marked "consumed" then we shouldn't add it in. (e.g. DrillableBlock, ButtonPickup)
    return not entityData.fields.consumed
end

local function _consume(self)
    -- Update checkpoint state

    self.checkpointHandler:pushState(checkpointStateConsumed)

    -- Update load file state

    self.fields.consumed = true

    -- Remove the sprite

    self:remove()
end

local function _isConsumed(self)
    return self.fields.consumed
end

local function _handleCheckpointRevert(self, state)
    if state.consumed then
        self:remove()
    elseif self.levelName == Game.getLevelName() then
        self:add()
    end

    -- Update load file state

    self.fields.consumed = state.consumed
end

local function _init(self, data, levelName, ...)
    _G[self.entityClassName].super.init(self, ...)

    -- Setup checkpoint handler with initial state (not consumed)
    self.checkpointHandler = CheckpointHandler.getOrCreate(self.id, self, checkpointStateNotConsumed)
end

local function createEntityClassPrototype(className)
    return {
        entityClassName = className,
        init = _init,
        shouldSpawn = _shouldSpawn,
        handleCheckpointRevert = _handleCheckpointRevert,
        consume = _consume,
        isConsumed = _isConsumed
    }
end

--- @class Consumable : Entity
--- @field consume function Consumes the entity, marking the LDtk entity as consumed.
--- @field isConsumed function Check if the entity has been consumed. Returns boolean
Consumable = Class("Consumable", Entity, createEntityClassPrototype("Consumable"))

--- @class ConsumableAnimated : EntityAnimated
--- @field consume function Consumes the entity, marking the LDtk entity as consumed.
--- @field isConsumed function Check if the entity has been consumed. Returns boolean
ConsumableAnimated = Class("ConsumableAnimated", EntityAnimated, createEntityClassPrototype("ConsumableAnimated"))
