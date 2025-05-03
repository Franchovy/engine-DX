local gfx <const> = playdate.graphics

-- Local constants

local imageTableElevatorTrack <const> = gfx.imagetable.new(assets.imageTables.elevatorTrack)

local TILE_ID <const> = {
    [ORIENTATION.Vertical] = {
        BODY = 1,
        END = 2,
        START = 3,
    },
    [ORIENTATION.Horizontal] = {
        BODY = 4,
        START = 5,
        END = 6
    }
}

-- Class definition

ElevatorTrack = Class("ElevatorTrack", gfx.sprite)

function ElevatorTrack:init(trackLengthInTiles, orientation)
    ElevatorTrack.super.init(self)

    local numberOfTiles = trackLengthInTiles + 1

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

    if orientation == ORIENTATION.Vertical then
        self:setCenter(0.5, 0)
        self:setSize(TILE_SIZE, TILE_SIZE * numberOfTiles)
    else
        self:setCenter(0, 0.75)
        self:setSize(TILE_SIZE * numberOfTiles, TILE_SIZE)
    end

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
