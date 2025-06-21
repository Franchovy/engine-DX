local gfx <const> = playdate.graphics

local imagetable = assert(gfx.imagetable.new(assets.imageTables.drillableBlock))
local spListBlockCrush = {
    [1] = playdate.sound.sampleplayer.new(assets.sounds.blockCrush[1]),
    [2] = playdate.sound.sampleplayer.new(assets.sounds.blockCrush[2]),
    [3] = playdate.sound.sampleplayer.new(assets.sounds.blockCrush[3]),
    [4] = playdate.sound.sampleplayer.new(assets.sounds.blockCrush[4])
}

--- @class DrillableBlock : ConsumableSprite
DrillableBlock = Class("DrillableBlock", ConsumableSprite)

local maxTicksToDrill = 12

function DrillableBlock:init(entity)
    DrillableBlock.super.init(self, entity)

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
        local index = math.random(1, 4)
        spListBlockCrush[index]:play()

        self:consume()
    else
        self.ticksToDrill += 1

        self:setImage(imagetable[math.ceil(self.ticksToDrill / 2)])

        self.isActivating = true
    end
end

function DrillableBlock:consume()
    DrillableBlock.super.consume(self)

    -- Re-add drillable block for post-consumed animation

    self:add()

    self:setCollisionsEnabled(false)

    self.frameTimerPostConsumed = playdate.frameTimer.new(6, function(timer)
        self:remove()

        self:reset()

        self.frameTimerPostConsumed = nil

        timer:remove()
    end)

    self.frameTimerPostConsumed.updateCallback = function(timer)
        local frame = math.ceil(timer.frame)

        self:setImage(imagetable[6 + frame])
    end
end

function DrillableBlock:reset()
    self.ticksToDrill = 0

    self:setImage(imagetable[1])

    self:setCollisionsEnabled(true)
end

function DrillableBlock:update()
    -- If a drilling has ended early, reset
    if not self.isActivating and self.ticksToDrill > 0 then
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
