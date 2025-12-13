local gfx <const> = playdate.graphics

local imagetable = assert(gfx.imagetable.new(assets.imageTables.drillableBlock))
local spListBlockCrush = {
    [1] = playdate.sound.sampleplayer.new(assets.sounds.blockCrush[1]),
    [2] = playdate.sound.sampleplayer.new(assets.sounds.blockCrush[2]),
    [3] = playdate.sound.sampleplayer.new(assets.sounds.blockCrush[3]),
    [4] = playdate.sound.sampleplayer.new(assets.sounds.blockCrush[4])
}

--- @class DrillableBlock : Consumable
DrillableBlock = Class("DrillableBlock", Consumable)

local maxTicksToDrill = 12

function DrillableBlock:init(entityData, levelName)
    DrillableBlock.super.init(self, entityData, levelName)

    self:setImage(imagetable[1])

    -- Collisions

    self:setGroups(GROUPS.Solid)
    self:setTag(TAGS.DrillableBlock)

    -- Sub-state variables

    self.ticksToDrill = 0
    self.isActivating = false
end

function DrillableBlock:activateDown()
    if self.ticksToDrill >= maxTicksToDrill then

        self:consume()
    else
        self.ticksToDrill += 1

        self:setImage(imagetable[math.ceil(self.ticksToDrill / 2)])

        self.isActivating = true
    end
end

function DrillableBlock:consume()
    DrillableBlock.super.consume(self)

    spListBlockCrush[math.random(1, 4)]:play()

    -- Re-add drillable block for post-consumed animation

    self:add()

    self:setCollisionsEnabled(false)

    self.ticksToDrill = maxTicksToDrill
end

function DrillableBlock:reset()
    self.ticksToDrill = 0

    self:setImage(imagetable[1])

    self:setCollisionsEnabled(true)
end

function DrillableBlock:update()
    if self:isConsumed() and (math.ceil(self.ticksToDrill / 2) <= #imagetable) then
        -- Play end animation frames
        local image = imagetable[math.ceil(self.ticksToDrill / 2)]
        self:setImage(image)

        self.ticksToDrill += 1
    elseif self:isConsumed() and (math.ceil(self.ticksToDrill / 2) > #imagetable) then
        -- Finished
        self:reset()
        self:remove()
    elseif not self.isActivating and self.ticksToDrill > 0 then
        -- If a drilling has ended early, reset
        self:reset()
    end

    self.isActivating = false
end

function DrillableBlock:handleCheckpointRevert(state)
    if self.fields.consumed and not state.consumed then
        local sfx = spListBlockCrush[math.random(1, 4)]
        sfx:setOffset(0.3)
        sfx:play(1, -1)
    end

    DrillableBlock.super.handleCheckpointRevert(self, state)

    self:reset()
end

function DrillableBlock:getTicksToDrillLeft()
    return maxTicksToDrill - self.ticksToDrill
end
