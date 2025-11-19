local gfx <const> = playdate.graphics

local imagetableElevator <const> = assert(gfx.imagetable.new(assets.imageTables.elevator))

local downwardsOffsetMax <const> = 2

---
---
--- Private Static methods
---

---@class Elevator : Entity, Moveable
---@field tracks ElevatorTrack[]
Elevator = Class("Elevator", Entity)

Elevator:implements(Moveable)

function Elevator:init(entityData, levelName)
  Elevator.super.init(self, entityData, levelName, imagetableElevator[1])

  Moveable.init(self, { movement = 7 })

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

function Elevator:getOrientationForOffset(offsetX, offsetY)
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

  Moveable.update(self)

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

function Elevator:getTargetPositionFromOffset(offset, position)
  local offsetTarget = offset - (offset > 16 and TILE_SIZE or 0)

  local offsetToMove = math.clamp(offsetTarget, -self.speed, self.speed)
      * (
        math.abs(offsetTarget) > 0.1
        and _G.delta_time
        -- Skip delta_time multiplication for small values
        or 1
      )

  return math.round(
    position - offsetToMove,
    2
  )
end

function Elevator:updatePosition()
  if #self.tracks == 0 then
    return
  end

  local offsetX, offsetY = (self.x - 16) % TILE_SIZE, (self.y - 16) % TILE_SIZE

  if offsetX == 0 and offsetY == 0 then
    return
  end

  local orientation = self:getOrientationForOffset(offsetX, offsetY)

  if orientation == ORIENTATION.Horizontal then
    local targetX = self:getTargetPositionFromOffset(offsetX, self.x)

    self:moveToTarget(
      targetX,
      self.y,
      ORIENTATION.Horizontal,
      self.spriteChild,
      0
    )
  else
    local targetY = self:getTargetPositionFromOffset(offsetY, self.y)

    local downwardsOffset = targetY > self.y + 1 and downwardsOffsetMax or 0

    self:moveToTarget(
      self.x,
      targetY,
      ORIENTATION.Vertical,
      self.spriteChild,
      downwardsOffset
    )
  end
end

function Elevator:getTargetPositionFromKey(key, speed)
  local speedX, speedY = 0, 0
  local orientation
  if key == KEYNAMES.Right then
    speedX = speed
    orientation = ORIENTATION.Horizontal
  elseif key == KEYNAMES.Left then
    speedX = -speed
    orientation = ORIENTATION.Horizontal
  elseif key == KEYNAMES.Down then
    -- Vertical orientation, return positive if Down, negative if Up
    speedY = speed
    orientation = ORIENTATION.Vertical
  elseif key == KEYNAMES.Up then
    speedY = -speed
    orientation = ORIENTATION.Vertical
  end

  -- Get destination point
  return math.round(self.x + speedX * _G.delta_time, 2), math.round(self.y + speedY * _G.delta_time, 2), orientation
end

function Elevator:moveToTarget(targetX, targetY, orientation, spriteChild, downwardsOffset)
  if targetX == self.x and targetY == self.y then
    -- No movement occurred.
    return false
  end

  local track = self:getTrackForDirection(orientation)
  if not track then
    return
  end

  -- Clamp point to track bounds
  local destinationX, destinationY = track:clampElevatorPoint(targetX, targetY)

  if destinationX == self.x and destinationY == self.y then
    -- [End of track] No movement occurred.
    return false
  end

  -- Check collision for own movement

  local isCollisionCheckPassed, actualX, actualY = self:isCollisionCheckPassed(self, destinationX, destinationY,
    spriteChild)

  if not isCollisionCheckPassed or (actualX == self.x and actualY == self.y) then
    -- No movement occurred.
    return false
  end

  if not spriteChild then
    -- If no sprite child is given, then consider movement successful.

    if orientation == ORIENTATION.Horizontal then
      self:moveTo(actualX, self.y)
    else
      self:moveTo(self.x, actualY)
    end

    self:savePosition()

    return true
  end

  -- Keep or remove downwardsOffset based on movement direction

  downwardsOffset = (orientation == ORIENTATION.Vertical and destinationY > self.y) and downwardsOffset or 0

  -- Check collision for any children

  local childOffset = self.y - spriteChild.y

  -- Get ideal child position
  local idealChildX = actualX + spriteChild.x - self.x
  local idealChildY = actualY - childOffset + downwardsOffset

  local isCollisionCheckPassedChild, actualChildX, actualChildY = self:isCollisionCheckPassed(spriteChild, idealChildX,
    idealChildY,
    self)

  -- Track previous X position for horizontal movement
  local spriteChildPreviousX = spriteChild.x

  -- Only add downwardsOffset if no collision happened
  local downwardsOffsetAdjusted = isCollisionCheckPassedChild and downwardsOffset or 0

  -- Interpolate own destination coordinates

  local finalX = actualChildX - spriteChildPreviousX + self.x
  local finalY = actualChildY + childOffset - downwardsOffsetAdjusted

  -- Move child sprite

  spriteChild:moveTo(actualChildX, actualChildY)

  -- Move elevator (self)

  if orientation == ORIENTATION.Horizontal then
    -- We move with collisions as a safeguard against moving into other sprites,
    -- which can happen due to the previous-child-offset

    self:moveWithCollisions(finalX, self.y)
  else
    self:moveTo(self.x, finalY)
  end

  self:savePosition()

  -- Return movement success
  return true
end

--- Sets movement to be executed in the next update() call using vector.
--- *param* key - the player input key direction (KEYNAMES)
--- *returns* the distance covered in the activation.
function Elevator:activateDown(spriteChild, key)
  -- Set child sprite

  self.spriteChild = spriteChild

  -- Return if no key is passed in

  if not key then return end

  -- Return if no track (cannot move elevator)

  if #self.tracks == 0 then return end

  -- Get destination point
  local idealX, idealY, orientation = self:getTargetPositionFromKey(key, self.speed)

  self.didActivate = self:moveToTarget(idealX, idealY, orientation, spriteChild, downwardsOffsetMax)

  return self.didActivate
end

--- Checks collision for frame, also checking if child collides. Returns a partial movement for itself
--- if elevator or child collides with another object.
function Elevator:isCollisionCheckPassed(spriteToCheck, idealX, idealY, spriteToIgnore)
  if spriteToCheck ~= self then
    -- Disable collisions with self
    self:setCollisionsEnabled(false)
  end

  local actualX, actualY, collisions = spriteToCheck:checkCollisions(idealX, idealY)

  if spriteToCheck ~= self then
    -- Re-enable collisions with self
    self:setCollisionsEnabled(true)
  end

  local isCollisionCheckPassed = true

  for _, collision in pairs(collisions) do
    local shouldSkipCollision = collision.other == spriteToIgnore or collision.type == gfx.sprite
        .kCollisionTypeOverlap

    if not shouldSkipCollision then
      -- Block collision
      return false, actualX, actualY
    end
  end

  return isCollisionCheckPassed, actualX, actualY
end

function Elevator:hasMovedRemaining()
  return self.didMoveRemaining
end

function Elevator:enterLevel(levelName, direction)
  local levelNamePrevious = self.levelName

  self:add()

  -- Reset tracks

  self.tracks = {}

  -- Update levelName

  self.levelName = levelName

  -- Remove elevator from previous level

  local layersPreviousLevel = LDtk.get_layers(levelNamePrevious)
  local entitiesPreviousLevel = layersPreviousLevel["Entities"].entities

  local index = table.indexWhere(
    entitiesPreviousLevel,
    function(value)
      return self.id == value.iid
    end
  )

  table.remove(entitiesPreviousLevel, index)

  -- Add elevator to new level

  local layersNewLevel = LDtk.get_layers(levelName)
  local entitiesNewLevel = layersNewLevel["Entities"].entities
  table.insert(entitiesNewLevel, self.entity)

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

function Elevator:wasActivationSuccessful()
  return self.didActivate
end

function Elevator:handleCheckpointRevert(state)
  self.movement = 0

  self:moveTo(state.x, state.y)
  self:savePosition(true)

  if state.levelName ~= self.levelName then
    self:enterLevel(state.levelName)
  end
end
