local gfx <const> = playdate.graphics

-- Local constants

local imageTableElevatorTrack <const> = gfx.imagetable.new(assets.imageTables.elevatorTrack)

local TILE_ID <const> = {
    [ORIENTATION.Vertical] = {
        START = 4,
        BODY = 7,
        END = 10,
    },
    [ORIENTATION.Horizontal] = {
        START = 1,
        BODY = 2,
        END = 3
    }
}

-- Class definition

---@class ElevatorTrack : Entity
ElevatorTrack = Class("ElevatorTrack", Entity)

-- Fake Constructors for LDtk name reference

local _shouldSpawn = Entity.shouldSpawn

ElevatorTrackH = { shouldSpawn = _shouldSpawn }

function ElevatorTrackH.init(_, entityData, levelName)
    return ElevatorTrack(entityData, levelName, ORIENTATION.Horizontal)
end

setmetatable(ElevatorTrackH, { __call = ElevatorTrackH.init })

ElevatorTrackV = { shouldSpawn = _shouldSpawn }

function ElevatorTrackV.init(_, entityData, levelName)
    return ElevatorTrack(entityData, levelName, ORIENTATION.Vertical)
end

setmetatable(ElevatorTrackV, { __call = ElevatorTrackV.init })

---

function ElevatorTrack:init(entityData, levelName, orientation)
    ElevatorTrack.super.init(self, entityData, levelName)

    -- Set tag

    self:setTag(TAGS.ElevatorTrack)

    -- Create Tilemap

    local numberOfTiles = (orientation == ORIENTATION.Horizontal and entityData.size.width or
        entityData.size.height) / TILE_SIZE * 2 - 1

    -- Create tilemap data using length
    local dataTilemap = table.create(numberOfTiles, 0)

    for i = 1, numberOfTiles do
        local tileID = i == 1 and TILE_ID[orientation].START or i == numberOfTiles and TILE_ID[orientation].END or
            TILE_ID[orientation].BODY

        table.insert(dataTilemap, tileID)
    end

    -- Create tilemap for elevator track
    local tilemap = gfx.tilemap.new()
    tilemap:setImageTable(imageTableElevatorTrack)
    tilemap:setTiles(dataTilemap, orientation == ORIENTATION.Vertical and 1 or numberOfTiles)

    self.tilemap = tilemap
    self.orientation = orientation

    -- Sprite config

    if self.orientation == ORIENTATION.Vertical then
        self:setSize(self.entity.size.width, self.entity.size.height - TILE_SIZE / 2)
    else
        -- Offset horizontal tracks to center of tile
        self:setSize(self.entity.size.width - TILE_SIZE / 2, self.entity.size.height)
        self:moveBy(TILE_SIZE / 4, 0)
    end

    self:setCollideRect(0, 0, self:getSize())

    self:setZIndex(Z_INDEX.Level.Neutral)
end

function ElevatorTrack:setInitialPosition(initialPosition)
    if self.orientation == ORIENTATION.Vertical then
        self:moveTo(initialPosition.x, initialPosition.y + TILE_SIZE / 2)
    else
        self:moveTo(initialPosition.x - TILE_SIZE / 2, initialPosition.y + TILE_SIZE)
    end
end

function ElevatorTrack:draw(x, y, width, height)
    self.tilemap:draw(0, 0)
end

function ElevatorTrack:getOrientation()
    return self.orientation
end

function ElevatorTrack:clampElevatorPoint(x, y)
    return math.min(math.max(self:left() + TILE_SIZE / 4, x), self:right() - TILE_SIZE / 4),
        math.min(math.max(self:top() - TILE_SIZE / 2, y), self:bottom() - TILE_SIZE)
end
