local gfx <const> = playdate.graphics

local imagetableElevator <const> = gfx.imagetable.new(assets.imageTables.elevator)

local downwardsOffsetMax <const> = 2

---
---
--- Private Static methods
---

---@class Elevator : playdate.graphics.sprite
Elevator = Class("Elevator", gfx.sprite)

function Elevator:init(entity)
  Elevator.super.init(self, imagetableElevator[1])

  -- Collisions

  self:setTag(TAGS.Elevator)
  self:setGroups({ GROUPS.Solid, GROUPS.Ground })
  self:setCollidesWithGroups(GROUPS.Solid)

  -- Elevator-specific fields

  self.deactivatedSpeed = 3.5
  self.speed = 7                    -- Constant, but could be modified on a per-elevator basis in the future.
  self.movement = 0                 -- Update scalar for movement.
  self.didActivationSuccess = false -- Update value for checking if activation was successful
  self.didMoveRemaining = false     -- Update value for checking if remaining/adjustment movement occurred
end

function Elevator:postInit()
  -- Set collideRect to bottom half of sprite
  self:setCollideRect(0, 16, 32, 16)

  -- Offset upwards to occupy upper portion of tile, if needed.
  local tileOffsetY = (self.y - TILE_SIZE / 2) % TILE_SIZE
  self:moveBy(0, -tileOffsetY)

  -- Checkpoint Handling setup

  self.checkpointHandler = CheckpointHandler.getOrCreate(self.id, self,
    { x = self.x, y = self.y, levelName = self.levelName })
end

function Elevator:collisionResponse(other)
  if other:getGroupMask() & GROUPS.Solid ~= 0 then
    return gfx.sprite.kCollisionTypeSlide
  end

  return gfx.sprite.kCollisionTypeOverlap
end

---
---
--- Public class Methods
---

function Elevator:getDirection()
  return self.track and self.track:getOrientation() or nil
end

function Elevator:savePosition()
  local x, y = self:getPosition()

  -- Update LDtk fields
  self.entity.world_position.x = x
  self.entity.world_position.y = y -- - levelBounds.y + TILE_SIZE / 2

  -- Update checkpoint state
  self.checkpointHandler:pushState({ x = x, y = y, levelName = self.levelName })
end

function Elevator:update()
  Elevator.super.update(self)

  -- Set track for this elevator
  if self.track == nil then
    self:updateTrack()
  end

  -- Move elevator to nearest tile if applicable

  if not self.didActivate then
    self:updatePosition()
  end

  -- Reset collision check if not disabled for this frame

  if not self.isCollisionsDisabledForFrame then
    self:setCollisionsEnabled(true)
  end

  -- Reset update variables

  self.movement = 0
  self.spriteChild = nil
  self.isCollisionsDisabledForFrame = false
  self.didActivate = false
end

function Elevator:updateTrack()
  local spritesOverlapping = self.querySpritesAtPoint(self:centerX(), self:centerY() + self.height / 4)

  local ownTrackId = self.fields.trackId
  local track

  for _, sprite in pairs(spritesOverlapping) do
    if (sprite:getTag() == TAGS.ElevatorTrack) then
      if ownTrackId and ownTrackId == sprite.fields.uid then
        -- If matching UID, then set to other track.
        track = sprite
      elseif not ownTrackId then
        -- If no specified trackId exists, set to any track.
        track = sprite
      end
    end
  end

  self.track = track
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
  if not self.track then
    return
  end

  local offsetX, offsetY = (self.x - 16) % TILE_SIZE, (self.y - 16) % TILE_SIZE

  if offsetX == 0 and offsetY == 0 then
    return
  end

  local orientation = offsetX ~= 0 and ORIENTATION.Horizontal or ORIENTATION.Vertical

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

function Elevator:moveToTarget(targetX, targetY, orientation, spriteChild, downwardsOffset)
  -- Clamp point to track bounds
  local destinationX, destinationY = self.track:clampElevatorPoint(targetX, targetY)

  if destinationX == self.x and destinationY == self.y then
    -- [End of track] No movement occurred.
    return false
  end

  -- Check collision for own movement

  local isCollisionCheckPassed, actualX, actualY = self:isCollisionCheckPassed(self, destinationX, destinationY,
    spriteChild)

  if not isCollisionCheckPassed then
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
function Elevator:activate(spriteChild, key)
  -- Set child sprite

  self.spriteChild = spriteChild

  -- Return if no key is passed in

  if not key then return end

  -- Return if no track (cannot move elevator)

  if not self.track then return end

  local speedX, speedY = 0, 0
  local orientation
  if key == KEYNAMES.Right then
    speedX = self.speed
    orientation = ORIENTATION.Horizontal
  elseif key == KEYNAMES.Left then
    speedX = -self.speed
    orientation = ORIENTATION.Horizontal
  elseif key == KEYNAMES.Down then
    -- Vertical orientation, return positive if Down, negative if Up
    speedY = self.speed
    orientation = ORIENTATION.Vertical
  elseif key == KEYNAMES.Up then
    speedY = -self.speed
    orientation = ORIENTATION.Vertical
  end

  -- Get destination point
  local idealX, idealY = math.round(self.x + speedX * _G.delta_time, 2), math.round(self.y + speedY * _G.delta_time, 2)

  local downwardsOffset = key == KEYNAMES.Down and downwardsOffsetMax or 0

  self.didActivate = self:moveToTarget(idealX, idealY, orientation, spriteChild, downwardsOffset)

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

  -- Reset track

  self.track = nil

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

  -- Offset elevator to be centered underneath player (horizontal only)

  local x
  if direction and (direction == DIRECTION.LEFT or direction == DIRECTION.RIGHT) and self.fields.orientation == ORIENTATION.Horizontal then
    local player = Player.getInstance()
    x = player:centerX()
  else
    x = self.x
  end

  self:moveTo(x, self.y)

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

  self:moveToAndSave(state.x, state.y)

  if state.levelName ~= self.levelName then
    self:enterLevel(state.levelName)
  end
end
