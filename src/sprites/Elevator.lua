import "elevator/elevatorTrack"

local gfx <const> = playdate.graphics
local gmt <const> = playdate.geometry

local imageElevator <const> = gfx.image.new(assets.images.elevator)

local tileAdjustmentPx <const> = 4

---
---
--- Private class methods
---

local function getActivationMovement(self, key)
  if self.fields.orientation == ORIENTATION.Horizontal then
    -- Horizontal orientation, return positive if Right, negative if Left

    if key == KEYNAMES.Right then
      return self.speed
    elseif key == KEYNAMES.Left then
      return -self.speed
    end
  else
    -- Vertical orientation, return positive if Down, negative if Up

    if key == KEYNAMES.Down then
      return self.speed
    elseif key == KEYNAMES.Up then
      return -self.speed
    end
  end
end

--- Get remaining movement based on direction and displacement
local function getMovementRemaining(self, movement)
  if movement < 0 then
    return math.max(-self.displacement, movement)
  elseif movement > 0 then
    return math.min(self.displacementEnd - self.displacement, movement)
  else
    return 0
  end
end

--- Checks collision for frame, also checking if child collides. Returns a partial movement for itself
--- if elevator or child collides with another object.
local function checkIfCollides(spriteToCheck, idealX, idealY, spritesToIgnore)
  spritesToIgnore = spritesToIgnore or {}

  local actualX, actualY, collisions = spriteToCheck:checkCollisions(idealX, idealY)
  local isCollisionCheckPassed = true

  for _, collision in pairs(collisions) do
    local shouldSkipCollision = spritesToIgnore[collision.other] or collision.type == gfx.sprite.kCollisionTypeOverlap

    if not shouldSkipCollision then
      -- Block collision
      isCollisionCheckPassed = false

      break
    end
  end

  -- Return if collision check result
  if not isCollisionCheckPassed then
    return false, actualX, actualY
  end

  -- [Franch] If collision check passes, we return ideal X & Y to ignore the
  -- effect of potential collisions from elevator into player and vice versa.

  return isCollisionCheckPassed, idealX, idealY
end

local function getPositionChildIdeal(self, x, y, isMovingDown)
  x = x or self.x
  y = y or self.y

  -- We push the player into the elevator if moving down for better collision handling.
  local offsetY = isMovingDown and 2 or 0

  -- Center the child on the elevator
  local idealX = x + self.width / 2 - self.spriteChild.width / 2
  local idealY = y - self.spriteChild.height + offsetY

  return idealX, idealY
end

local function getDistanceToNearestTile(self)
  local adjustmentDown = self.displacement % TILE_SIZE
  local adjustmentUp = TILE_SIZE - (self.displacement % TILE_SIZE)

  if adjustmentDown == 0 then
    return 0
  elseif adjustmentDown < adjustmentUp then
    -- Move downwards
    return -adjustmentDown
  else
    -- Move upwards
    return adjustmentUp
  end
end

--- If elevator is within `tileAdjustmentPx` of tile, then returns
--- the adjustment to be exactly on that tile.
local function getAdjustmentToTile(self)
  -- Get adjustment from tiles both above and below.

  local adjustmentDown = self.displacement % TILE_SIZE
  local adjustmentUp = TILE_SIZE - (self.displacement % TILE_SIZE)

  if adjustmentDown > 0 and adjustmentDown < tileAdjustmentPx then
    -- Adjust downwards
    return -adjustmentDown
  elseif adjustmentUp > 0 and adjustmentUp < tileAdjustmentPx then
    -- Adjust upwards
    return adjustmentUp
  else
    -- No adjustment made
    return 0
  end
end

function math.round(num, numDecimalPlaces)
  local mult = 10 ^ (numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

--- Convenience method to get the X & Y position based on a displacement.
local function getPositionFromDisplacement(self, displacement)
  if self.fields.orientation == ORIENTATION.Horizontal then
    return self.initialPosition.x + displacement, self.initialPosition.y
  else
    return self.initialPosition.x, self.initialPosition.y + displacement
  end
end

local function setDisplacement(self, displacement)
  displacement = math.round(displacement, 2)

  self.displacement = displacement
  self.fields.displacement = displacement

  local x, y = getPositionFromDisplacement(self, displacement)
  self:moveTo(x, y)
end

--- Update method for movement
local function updateMovement(self, movement)
  -- Get new position using displacement

  local x, y = getPositionFromDisplacement(self, self.displacement + movement)

  -- Round x and y values to avoid tiny floating point errors

  x, y = math.round(x, 2), math.round(y, 2)

  -- Check collisions for self

  local spritesToIgnore = self.spriteChild and { [self.spriteChild] = true } or {}
  local isCollisionCheckPassed
  isCollisionCheckPassed, x, y = checkIfCollides(self, x, y, spritesToIgnore)

  -- Skip movement if collision happened
  if not isCollisionCheckPassed then
    return false
  end

  if self.spriteChild then
    -- Calculate ideal X & Y for child
    local isMovingDown = movement > 0 and self.fields.orientation == ORIENTATION.Vertical
    local childX, childY = getPositionChildIdeal(self, x, y, isMovingDown)

    if not skipCollisionCheck then
      -- Check collisions for child
      local isCollisionCheckPassed
      isCollisionCheckPassed, childX, childY = checkIfCollides(self.spriteChild, childX, childY, { [self] = true })

      -- Skip movement if collision happened
      if not isCollisionCheckPassed then
        return false
      end
    end

    -- Update child position
    if isMovingDown then
      self.spriteChild:moveTo(childX, childY)
    else
      self.spriteChild:moveWithCollisions(
        childX,
        childY
      )
    end
  end

  -- Move to new displacement

  setDisplacement(self, self.displacement + movement)

  -- Update checkpoint state

  self.checkpointHandler:pushState({ displacement = self.displacement })

  return true
end

---
---
--- Private Static methods
---

class("Elevator").extends(gfx.sprite)

function Elevator:init(entity)
  Elevator.super.init(self, imageElevator)

  self:setTag(TAGS.Elevator)
  self:setCenter(0.5, 1)

  -- Set Displacement initial, start and end scalars (1D) based on entity fields

  -- The initial displacement can be greater than 0.
  self.displacementInitial = (entity.fields.initialDistance or 0) * TILE_SIZE
  self.displacementEnd = entity.fields.distance * TILE_SIZE

  -- RigidBody config

  self.rigidBody = RigidBody(self)

  -- Elevator-specific fields

  self.deactivatedSpeed = 3.5
  self.speed = 7                    -- Constant, but could be modified on a per-elevator basis in the future.
  self.movement = 0                 -- Update scalar for movement.
  self.didActivationSuccess = false -- Update value for checking if activation was successful

  -- Create elevator track

  self.spriteElevatorTrack = ElevatorTrack(entity.fields.distance, entity.fields.orientation)
end

function Elevator:postInit()
  self:setCollideRect(0, 16, 32, 16)

  -- Save initial position

  if self.fields.orientation == ORIENTATION.Horizontal then
    self.initialPosition = gmt.point.new(self.x - self.displacementInitial, self.y)
    self.finalPosition = gmt.point.new(self.initialPosition.x + self.displacementEnd, self.y)
  else
    self.initialPosition = gmt.point.new(self.x, self.y - self.displacementInitial)
    self.finalPosition = gmt.point.new(self.x, self.initialPosition.y + self.displacementEnd)
  end

  -- Positon elevator track

  self.spriteElevatorTrack:setInitialPosition(self.initialPosition)
  self.spriteElevatorTrack:add()

  -- Load displacement from previous data or initial LDtk setup

  if self.fields.displacement then
    self.displacement = self.fields.displacement
  else
    self.displacement = self.displacementInitial
  end

  -- Set position based on displacement

  setDisplacement(self, self.displacement)

  -- Checkpoint Handling setup

  self.checkpointHandler = CheckpointHandler.getOrCreate(self.id, self, { displacement = self.displacement })
end

function Elevator:collisionResponse(other)
  if other:getTag() == TAGS.Dialog or other:getTag() == TAGS.SavePoint or other:getTag() == TAGS.Ability then
    return gfx.sprite.kCollisionTypeOverlap
  end

  return gfx.sprite.kCollisionTypeSlide
end

---
---
--- Public class Methods
---

--- Sets movement to be executed in the next update() call using vector.
--- *param* key - the player input key direction (KEYNAMES)
--- *returns* the distance covered in the activation.
function Elevator:activate(sprite, key)
  -- Gets applied movement using key, self.speed and self.orientation
  local activationMovement = getActivationMovement(self, key)

  if not activationMovement then
    -- No key to handle.
    return
  end

  -- Clamp movement to distance remaining

  if activationMovement ~= 0 then
    activationMovement = getMovementRemaining(self, activationMovement)
  end

  -- If activated, set update variables for movement
  if activationMovement ~= 0 then
    -- Set movement update scalar
    self.movement = activationMovement
  end

  return activationMovement
end

function Elevator:update()
  Elevator.super.update(self)

  -- Reset update variables (Pre-update)

  self.didActivationSuccess = false

  -- Get if elevator has been activated
  local movement = self.movement

  if movement == 0 then
    -- If not active, adjust for pixel-perfect tile position

    local adjustmentRemaining = getDistanceToNearestTile(self)

    if adjustmentRemaining ~= 0 then
      if adjustmentRemaining > 0 then
        adjustmentRemaining = math.min(self.deactivatedSpeed, adjustmentRemaining)
      else
        adjustmentRemaining = math.max(-self.deactivatedSpeed, adjustmentRemaining)
      end

      -- If movement is very small, don't multiply by delta_time.
      if not (math.abs(adjustmentRemaining) < 0.1) then
        adjustmentRemaining = adjustmentRemaining * _G.delta_time
      end

      updateMovement(self, adjustmentRemaining)
    end

    --[[
    movement = getAdjustmentToTile(self)

    if movement ~= 0 then
      -- Call without delta_time to avoid very small, inconsequential movements

      updateMovement(self, movement)
    end]]
  else
    -- If any movement occurs, update elevator position based on movement * delta_time

    -- If movement is very small, don't multiply by delta_time.
    if not (math.abs(movement) < 0.1) then
      movement = movement * _G.delta_time
    end

    self.didActivationSuccess = updateMovement(self, movement)
  end

  -- Reset collisions if disabled

  if self.isCollisionsDisabledForFrame then
    self:setCollisionsEnabled(true)

    self.isCollisionsDisabledForFrame = false
  end

  -- Reset update variables

  self.movement = 0
  self.spriteChild = nil
end

--- Used specifically for when jumping while moving up with elevator.
function Elevator:disableCollisionsForFrame()
  self:setCollisionsEnabled(false)

  self.isCollisionsDisabledForFrame = true
end

function Elevator:wasActivationSuccessful()
  return self.didActivationSuccess
end

function Elevator:handleCheckpointRevert(state)
  self.movement = 0

  setDisplacement(self, state.displacement)
end

function Elevator:setChild(sprite)
  self.spriteChild = sprite
end
