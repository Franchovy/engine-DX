local pd <const> = playdate
local gmt <const> = pd.geometry
local gfx <const> = pd.graphics

RigidBody = Class("RigidBody")

local gravity <const> = 8
local airFrictionCoefficient <const> = -0.2
local groundFrictionCoefficient <const> = -0.8

function RigidBody:init(sprite, config)
  self.sprite = sprite

  -- Dynamic variables

  self.velocity = gmt.vector2D.new(0, 0)
  self.onGround = false
end

function RigidBody:getIsTouchingGround()
  return self.onGround
end

function RigidBody:getCurrentVelocity()
  return self.velocity
end

function RigidBody:addVelocityX(dX)
  self.velocity.dx += dX
end

function RigidBody:setVelocityY(dY)
  self.velocity.dy = dY
end

function RigidBody:update()
  local sprite = self.sprite

  -- calculate new position by adding velocity to current position
  local newPos = gmt.vector2D.new(sprite.x, sprite.y) + (self.velocity * _G.delta_time)

  local _, _, sdkCollisions = sprite:moveWithCollisions(newPos:unpack())

  -- Reset variables

  self.onGround = false

  for _, c in pairs(sdkCollisions) do
    local tag = c.other:getTag()
    local normal = c.normal
    local collisionType = c.type

    if collisionType == gfx.sprite.kCollisionTypeSlide then
      -- Detect if ground collision

      if normal.y == -1 and PROPS.Ground[tag] then
        self.onGround = true
      elseif normal.y == 1 then
        self.velocity.y = 0
      end

      if normal.x ~= 0 then
        self.velocity.x = 0
      end
    end
  end

  -- incorporate gravity

  if self.onGround then
    -- Resets velocity, still applying gravity vector

    local dx, _ = self.velocity:unpack()
    self.velocity = gmt.vector2D.new(dx, gravity * _G.delta_time)

    -- Apply Ground Friction to x-axis movement

    self.velocity.x = self.velocity.x + (self.velocity.x * groundFrictionCoefficient * _G.delta_time)
  else
    -- Adds gravity vector to current velocity

    self.velocity.y = self.velocity.y + (gravity * _G.delta_time)

    -- Apply Air Friction

    self.velocity.x = self.velocity.x + (self.velocity.x * airFrictionCoefficient * _G.delta_time)
    self.velocity.y = self.velocity.y + (self.velocity.y * airFrictionCoefficient * _G.delta_time)
  end

  -- If x velocity is very small, reduce to zero.
  if math.abs(self.velocity.x) < 0.1 then
    self.velocity.x = 0
  end

  return sdkCollisions
end
