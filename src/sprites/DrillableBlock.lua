local gfx <const> = playdate.graphics

local imageSprite = assert(gfx.image.new(assets.images.drillableBlock))
local spListBlockCrush = {
    [1] = playdate.sound.sampleplayer.new(assets.sounds.blockCrush[1]),
    [2] = playdate.sound.sampleplayer.new(assets.sounds.blockCrush[2]),
    [3] = playdate.sound.sampleplayer.new(assets.sounds.blockCrush[3]),
    [4] = playdate.sound.sampleplayer.new(assets.sounds.blockCrush[4])
}

--- @class DrillableBlock : ConsumableSprite
DrillableBlock = Class("DrillableBlock", ConsumableSprite)

local maxTicksToDrill = 15

function DrillableBlock:init(entity)
    DrillableBlock.super.init(self, entity)

    self:setImage(imageSprite)

    -- Collisions

    self:setGroups(GROUPS.Solid)
    self:setTag(TAGS.DrillableBlock)

    -- Sub-state variables

    self.ticksToDrill = 0
    self.isActivating = false
end

function DrillableBlock:activate()
    if self.ticksToDrill >= maxTicksToDrill then
        local index = math.random(1, 4)
        spListBlockCrush[index]:play()

        self:consume()
    else
        self.ticksToDrill += 1

        self.isActivating = true
    end
end

function DrillableBlock:reset()
    self.ticksToDrill = 0
end

function DrillableBlock:update()
    -- If a drilling has ended early, reset
    if not self.isActivating and self.ticksToDrill > 0 then
        self:reset()
    end

    self.isActivating = false
end

function DrillableBlock:handleCheckpointRevert(state)
    DrillableBlock.super.handleCheckpointRevert(self, state)

    self:reset()
end
