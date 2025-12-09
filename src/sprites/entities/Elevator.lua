local gfx <const> = playdate.graphics

local imagetableElevator <const> = assert(gfx.imagetable.new(assets.imageTables.elevator))

local downwardsOffsetMax <const> = 2
local speedMovement <const> = 7

---@class Elevator : Entity, Moveable
---@field tracks ElevatorTrack[]
Elevator = Class("Elevator", Entity)

Elevator:implements(Moveable)

function Elevator:init(entityData, levelName)
  Elevator.super.init(self, entityData, levelName, imagetableElevator[1])

  Moveable.init(self, { movement = speedMovement })

  -- Collisions

  self:setTag(TAGS.Elevator)
  self:setGroups({ GROUPS.Solid })
  self:setCollidesWithGroups({ GROUPS.Solid })
  self.collisionResponse = gfx.sprite.kCollisionTypeSlide

  -- Elevator-specific fields

  self.deactivatedSpeed = 3.5
  self.speed = 7                    -- Constant, but could be modified on a per-elevator basis in the future.
  self.movement = 0                 -- Update scalar for movement.
  self.didActivationSuccess = false -- Update value for checking if activation was successful
  self.didMoveRemaining = false     -- Update value for checking if remaining/adjustment movement occurred

  self.shouldReturnToStart = self.fields.returnToStart or false

  if self.shouldReturnToStart and not self.fields.startPosition then
    self.fields.startPosition = { x = self.entity.world_position.x, y = self.entity.world_position.y }
  end

  -- Set collideRect to bottom half of sprite
  self:setCollideRect(0, 16, 32, 16)

  -- Offset upwards to occupy upper portion of tile, if needed.
  local tileOffsetY = (self.y - TILE_SIZE / 2) % TILE_SIZE
  self:moveBy(0, -tileOffsetY)

  -- Connected elevator track list
  self.tracks = {}

  -- Checkpoint Handling setup

  self.checkpointHandler = CheckpointHandler.getOrCreate(self.id, self,
    { x = self.x, y = self.y, levelName = self.levelName })

  self.latestCheckpointPosition = { x = 0, y = 0 }
end

---
---
--- Public class Methods
---

function Elevator:getDirectionsAvailable()
  local directions = {}

  for _, track in pairs(self.tracks) do
    directions[track:getOrientation()] = true
  end

  return directions
end

function Elevator:getTrackForDirection(orientation)
  for _, track in pairs(self.tracks) do
    if track:getOrientation() == orientation then
      return track
    end
  end
end

function Elevator:getDirectionForOffset(offsetX, offsetY)
  if offsetX > 0 then
    return KEYNAMES.Right
  elseif offsetX < 0 then
    return KEYNAMES.Left
  elseif offsetY > 0 then
    return KEYNAMES.Up
  elseif offsetY < 0 then
    return KEYNAMES.Down
  end

  return nil
end

function Elevator:getOrientationFromMovement(offsetX, offsetY)
  return offsetX ~= 0 and ORIENTATION.Horizontal or offsetY ~= 0 and ORIENTATION.Vertical or nil
end

function Elevator:savePosition(skipSaveToCheckpoint)
  local x, y = self:getPosition()

  -- Update LDtk fields
  self.entity.world_position.x = x
  self.entity.world_position.y = y -- - levelBounds.y + TILE_SIZE / 2

  if not skipSaveToCheckpoint and (self.x ~= self.latestCheckpointPosition.x or self.y ~= self.latestCheckpointPosition.y) then
    self.latestCheckpointPosition.x = self.x
    self.latestCheckpointPosition.y = self.y

    -- Update checkpoint state
    self.checkpointHandler:pushState({ x = x, y = y, levelName = self.levelName })
  end
end

function Elevator:freeze()
  self.isFrozen = true
end

function Elevator:unfreeze()
  self.isFrozen = false
end

function Elevator:update()
  Elevator.super.update(self)

  if self.isFrozen then
    return
  end

  if not (self.didMoveLeft or self.didMoveRight or self.didMoveDown or self.didMoveUp) then
    -- Move self to closest tile
    self:setVelocityTowardsClosestTile()
  else
    -- Reset speed
    self.speedMovement = speedMovement
  end

  -- Skip if warp is in progress
  if CrankWatch.getDidPassThreshold() then
    return
  end

  Moveable.update(self)

  self:savePosition()

  -- Update connected tracks for this elevator
  self:updateTrack()

  -- Reset collision check if not disabled for this frame

  if not self.isCollisionsDisabledForFrame then
    self:setCollisionsEnabled(true)
  end

  -- Reset update variables

  self.spriteChild = nil
  self.isCollisionsDisabledForFrame = false
  self.didActivate = false
end

---comment
---@param xTarget number
---@param yTarget number
---@return integer
---@return integer
function Elevator:constrainMovement(xTarget, yTarget)
  local orientation = self:getOrientationFromMovement(xTarget - self.x, yTarget - self.y)

  local track = self:getTrackForDirection(orientation)
  if not track then
    -- No track for direction, so no movement possible.
    return self.x, self.y
  end

  -- Clamp point to track bounds

  return track:clampElevatorPoint(xTarget, yTarget)
end

function Elevator:updateTrack()
  local ownTrackId = self.fields.trackId
  local hasTrack = #self.tracks > 0

  if hasTrack and ownTrackId then
    -- If elevator already has a track specified, then skip.
    return
  end

  local spritesOverlapping = self.querySpritesAtPoint(self:centerX(), self:centerY() + self.height / 4)

  local tracksNew = {}

  for _, sprite in pairs(spritesOverlapping) do
    ---@cast sprite ElevatorTrack
    if (sprite:getTag() == TAGS.ElevatorTrack) then
      if ownTrackId and ownTrackId == sprite.fields.uid then
        -- If matching UID, then set to other track and break loop.
        table.insert(tracksNew, sprite)
        break
      elseif not ownTrackId then
        -- If no specified trackId exists, set to any track.
        table.insert(tracksNew, sprite)
      end
    end
  end

  self.tracks = tracksNew
end

function Elevator:setVelocityTowardsClosestTile()
  if #self.tracks == 0 then
    return
  end

  local offsetX, offsetY = (self.x - 16) % TILE_SIZE, (self.y - 16) % TILE_SIZE

  if offsetX == 0 and offsetY == 0 then
    return
  end

  local orientation = self:getOrientationFromMovement(offsetX, offsetY)

  local offsetToMove = self:getOffsetToMove(
    orientation == ORIENTATION.Horizontal and offsetX or offsetY
  )

  if math.abs(offsetToMove) > 0.01 then
    self.speedMovement = offsetToMove
    self.forceMoveWithoutChild = orientation == ORIENTATION.Horizontal

    if orientation == ORIENTATION.Horizontal then
      self:moveRight()
    else
      self:moveDown()
    end
  else
    local targetPosition = playdate.geometry.point.new(
      self.x + (orientation == ORIENTATION.Horizontal and offsetToMove or 0),
      self.y + (orientation == ORIENTATION.Vertical and offsetToMove or 0)
    )

    if self.spriteChild then
      self:moveWithChild(targetPosition)
    else
      self:moveWithCollisions(targetPosition)
    end
  end
end

function Elevator:getOffsetToMove(offset)
  local offsetTarget = offset - (offset > 16 and TILE_SIZE or 0)

  return -math.clamp(offsetTarget, -self.speed, self.speed)
      * (
        math.abs(offsetTarget) > 1
        and _G.delta_time
        -- Skip delta_time multiplication for small values
        or 1
      )
end

function Elevator:activateDown()

end

function Elevator:enterLevel(levelName, direction)
  Elevator.super.enterLevel(self, levelName, direction)

  self:add()

  -- Reset tracks

  self.tracks = {}

  -- Offset elevator to be centered underneath player

  local player = Player.getInstance()

  if direction and (direction == DIRECTION.LEFT or direction == DIRECTION.RIGHT) then
    -- Horizontal correction

    self:moveTo(player:centerX(), self.y)
  elseif direction and (direction == DIRECTION.TOP or direction == DIRECTION.BOTTOM) then
    self:moveTo(self.x, player:centerY() + player:centerOffsetY() / 2)
  end

  -- Save new position

  self:savePosition()
end

--- Used specifically for when jumping while moving up with elevator.
function Elevator:disableCollisionsForFrame()
  self:setCollisionsEnabled(false)

  self.isCollisionsDisabledForFrame = true
end

function Elevator:handleCheckpointRevert(state)
  self.movement = 0

  self:moveTo(state.x, state.y)
  self:savePosition(true)

  if state.levelName ~= self.levelName then
    self:enterLevel(state.levelName)
  end
end
