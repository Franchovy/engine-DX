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

ConsumableSprite = Class("ConsumableSprite", gfx.sprite)

function ConsumableSprite:init(entity)
    ConsumableSprite.super.init(self)
end

function ConsumableSprite:postInit()
    -- Setup checkpoint handler with initial state (not consumed)
    self.checkpointHandler = CheckpointHandler.getOrCreate(self.id, self, checkpointStateNotConsumed)
end

function ConsumableSprite:consume()
    -- Update checkpoint state

    self.checkpointHandler:pushState(checkpointStateConsumed)

    -- Update load file state

    self.fields.consumed = true

    -- Remove the sprite

    self:remove()
end

function ConsumableSprite:isConsumed()
    return self.fields.consumed
end

function ConsumableSprite:handleCheckpointRevert(state)
    if state.consumed then
        self:remove()
    elseif self.levelName == Game.getLevelName() then
        self:add()
    end

    -- Update load file state

    self.fields.consumed = state.consumed
end
