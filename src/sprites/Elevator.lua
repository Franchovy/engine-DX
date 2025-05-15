local gfx <const> = playdate.graphics
local gmt <const> = playdate.geometry

local imagetableElevator <const> = gfx.imagetable.new(assets.imageTables.elevator)

local downwardsOffsetMax <const> = 2

---
---
--- Private Static methods
---

---@class Elevator : playdate.graphics.sprite
Elevator = Class("Elevator", gfx.sprite)

-- TODO:
-- Change all instances of displacement to directly refer to position
-- On init, get the elevator track on tile (with matching id <-> trackId if there are multiple)
-- When moving, check the elevator track position to see where to move

function Elevator:init(entity)
  Elevator.super.init(self, imagetableElevator[1])

  self:setTag(TAGS.Elevator)

  self.rigidBody = RigidBody(self)

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
  local tag = other:getTag()
  if tag == TAGS.Dialog or tag == TAGS.SavePoint or tag == TAGS.Ability or tag == TAGS.Powerwall or tag == TAGS.ElevatorTrack then
    return gfx.sprite.kCollisionTypeOverlap
  end

  return gfx.sprite.kCollisionTypeSlide
end

function Elevator:updatePosition(x, y)
  -- Move sprite
  Elevator.super.moveTo(self, x, y)

  -- Update LDtk fields
  self.entity.world_position.x = x
  self.entity.world_position.y = y -- - levelBounds.y + TILE_SIZE / 2

  -- Update checkpoint state
  self.checkpointHandler:pushState({ x = x, y = y, levelName = self.levelName })
end

---
---
--- Public class Methods
---

function Elevator:getDirection()
  return self.track and self.track:getOrientation() or nil
end

function Elevator:update()
  Elevator.super.update(self)

  -- Set track for this elevator
  if self.track == nil then
    self:updateTrack()
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
  local orientationMovement
  if key == KEYNAMES.Right then
    speedX = self.speed
    orientationMovement = ORIENTATION.Horizontal
  elseif key == KEYNAMES.Left then
    speedX = -self.speed
    orientationMovement = ORIENTATION.Horizontal
  elseif key == KEYNAMES.Down then
    -- Vertical orientation, return positive if Down, negative if Up
    speedY = self.speed
    orientationMovement = ORIENTATION.Vertical
  elseif key == KEYNAMES.Up then
    speedY = -self.speed
    orientationMovement = ORIENTATION.Vertical
  end

  -- Get destination point
  local idealX, idealY = math.round(self.x + speedX * _G.delta_time, 2), math.round(self.y + speedY * _G.delta_time, 2)

  -- Clamp point to track bounds
  local destinationX, destinationY = self.track:clampElevatorPoint(idealX, idealY)

  if destinationX == self.x and destinationY == self.y then
    -- [End of track] No movement occurred.
    return
  end

  -- Check collision for own movement

  local isCollisionCheckPassed, actualX, actualY = self:isCollisionCheckPassed(self, destinationX, destinationY,
    spriteChild)

  if isCollisionCheckPassed then
    -- Check collision for any children

    local downwardsOffset = key == KEYNAMES.Down and 2 or 0

    -- Get ideal child position
    local idealChildX = actualX + spriteChild.x - self.x
    local idealChildY = actualY + self.height - spriteChild.height + downwardsOffset

    local isCollisionCheckPassedChild, actualChildX, actualChildY = self:isCollisionCheckPassed(spriteChild, idealChildX,
      idealChildY,
      self)

    local spriteChildPreviousX = spriteChild.x

    if isCollisionCheckPassedChild then
      -- If collision check passed, move the child to the new position
      if downwardsOffset > 0 then
        spriteChild:moveTo(actualChildX, actualChildY)
      else
        spriteChild:moveWithCollisions(actualChildX, actualChildY)
      end

      -- Interpolate own destination coordinates

      local finalX = actualChildX - spriteChildPreviousX + self.x
      local finalY = actualChildY - (self.height - spriteChild.height + downwardsOffset)

      if orientationMovement == ORIENTATION.Horizontal then
        self:updatePosition(finalX, self.y)
      else
        self:updatePosition(self.x, finalY)
      end

      self.didActivate = true
    end
  end

  return self.didActivate
end

--- Checks collision for frame, also checking if child collides. Returns a partial movement for itself
--- if elevator or child collides with another object.
function Elevator:isCollisionCheckPassed(spriteToCheck, idealX, idealY, spriteToIgnore)
  local actualX, actualY, collisions = spriteToCheck:checkCollisions(idealX, idealY)
  local isCollisionCheckPassed = true

  for _, collision in pairs(collisions) do
    local shouldSkipCollision = collision.other == spriteToIgnore or collision.type == gfx.sprite
        .kCollisionTypeOverlap

    if not shouldSkipCollision then
      -- Block collision
      return false, actualX, actualY
    end
  end

  -- [Franch] If collision check passes, we return ideal X & Y to ignore the
  -- effect of potential collisions from elevator into player and vice versa.

  return isCollisionCheckPassed, idealX, idealY
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

  self:updatePosition(x, self.y)
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

  self:updatePosition(state.x, state.y)

  if state.levelName ~= self.levelName then
    self:enterLevel(state.levelName)
  end
end
