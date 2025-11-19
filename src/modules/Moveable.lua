local pd <const> = playdate
local gmt <const> = pd.geometry
local gfx <const> = pd.graphics

--- @class Moveable: _Sprite
Moveable = {}

local gravity <const> = 8
local airFrictionCoefficient <const> = -0.00035
local groundFrictionCoefficient <const> = -0.8
local coyoteFrames <const> = 5
local groundAcceleration <const> = 3.5
local airAcceleration <const> = 0.9
local dashSpeed <const> = 27.0
local framesPostDashNoGravity <const> = 4
local jumpSpeed <const> = 27

function Moveable:init(config)
    config = config or {}

    -- Config variables

    self.gravityMax = config.gravity or gravity
    self.airFrictionCoefficient = config.airFrictionCoefficient or airFrictionCoefficient
    self.groundFrictionCoefficient = config.groundFrictionCoefficient or groundFrictionCoefficient
    self.enableDash = config.enableDash or false
    self.enableDoubleJump = config.enableDoubleJump or false
    self.coyoteFramesMax = config.coyoteFramesMax or 0
    self.speedJump = config.speedJump or jumpSpeed
    self.dashFramesFloat = config.dashFramesFloat or framesPostDashNoGravity
    self.dashSpeed = config.dashSpeed or dashSpeed
    self.groundAcceleration = config.groundAcceleration or groundAcceleration
    self.airAcceleration = config.airAcceleration or airAcceleration

    -- Dynamic variables

    self.gravity = self.gravityMax
    self.velocity = gmt.vector2D.new(0, 0)
    self.coyoteFramesRemaining = self.coyoteFramesMax
    self.hasDoubleJumpRemaining = self.enableDoubleJump

    self.onGround = false
    self.onGroundPrevious = false
    self.didMoveLeft = false
    self.didMoveRight = false
    self.didJump = false
end

function Moveable:getIsTouchingGround()
    return self.onGround
end

function Moveable:getCurrentVelocity()
    return self.velocity
end

function Moveable:addVelocityX(dX)
    self.velocity.dx += dX
end

function Moveable:setVelocityX(dX)
    self.velocity.dx = dX
end

function Moveable:setVelocityY(dY)
    self.velocity.dy = dY
end

function Moveable:setGravity(g)
    self.gravity = g or self.gravityMax or gravity
end

function Moveable:moveLeft()
    self.didMoveLeft = true
end

function Moveable:moveRight()
    self.didMoveRight = true
end

function Moveable:jump()
    self.didJump = true
end

function Moveable:update()
    -- calculate new position by adding velocity to current position
    local newPos = gmt.vector2D.new(self.x, self.y) + (self.velocity * _G.delta_time)

    local _, _, sdkCollisions = self:moveWithCollisions(newPos:unpack())

    -- Update/Reset ground variables

    self.onGroundPrevious = self.onGround
    self.onGround = false

    for _, c in pairs(sdkCollisions) do
        local tag = c.other:getTag()
        local normal = c.normal
        local collisionType = c.type

        if collisionType == gfx.sprite.kCollisionTypeSlide then
            -- Detect if ground collision

            if normal.y == -1 then
                self.onGround = true
            elseif normal.y == 1 then
                self.velocity.dy = 0
            end

            if normal.x ~= 0 then
                self.velocity.dx = 0
            end
        end
    end

    -- incorporate gravity

    if self.onGround then
        -- Resets velocity, still applying gravity vector

        local dx, _ = self.velocity:unpack()
        self.velocity = gmt.vector2D.new(dx, self.gravity * _G.delta_time)

        -- Apply Ground Friction to x-axis movement

        self.velocity.dx = self.velocity.dx +
            (self.velocity.dx * self.groundFrictionCoefficient * _G.delta_time)
    else
        -- Adds gravity vector to current velocity

        self.velocity.dy = self.velocity.dy + (self.gravity * _G.delta_time)

        -- Apply Air Friction

        self.velocity.dx = self.velocity.dx +
            (self.velocity.dx ^ 3 * self.airFrictionCoefficient * _G.delta_time)
        self.velocity.dy = self.velocity.dy +
            (self.velocity.dy ^ 3 * self.airFrictionCoefficient * _G.delta_time)
    end

    -- If x velocity is very small, reduce to zero.
    if math.abs(self.velocity.dx) < 0.1 then
        self.velocity.dx = 0
    end

    self:updateMovement()

    self.collisions = sdkCollisions

    self:updateCollisions()

    if self.updateActivations then
        self:updateActivations()
    end

    -- Reset movement variables
    self.didMoveLeft = false
    self.didMoveRight = false
    self.didJump = false
end

function Moveable:updateMovement()
    -- Movement handling (update velocity X and Y)

    -- Handle Horizontal Movement

    local didActivateElevatorSuccess = self.isActivatingElevator and self.isActivatingElevator:wasActivationSuccessful()

    if self.isActivatingDrillableBlock or didActivateElevatorSuccess then
        -- Skip horizontal movement if activating a bottom block
        self:setVelocityX(0.0)
    elseif self.isActivatingElevator and self.isActivatingElevator:getDirectionsAvailable()[ORIENTATION.Horizontal]
        and (pd.buttonJustPressed(pd.kButtonLeft) or pd.buttonJustPressed(pd.kButtonRight)) then
        -- Skip upon pressing left or right to give collisions a frame to calculate horizontal elevator movement.
        self:setVelocityX(0.0)
    elseif self.isActivatingElevator and self.isActivatingElevator:getDirectionsAvailable()[ORIENTATION.Horizontal]
        and (not self.onGroundPrevious and self:getIsTouchingGround()) then
        -- Skip upon landing on a horizontal elevator
        self:setVelocityX(0.0)
    else
        -- Register key press for dash

        if self.didMoveLeft and playdate.buttonJustPressed(KEYNAMES.Left) then
            Dash:registerKeyPressed(KEYNAMES.Left)
        elseif self.didMoveRight and playdate.buttonJustPressed(KEYNAMES.Right) then
            Dash:registerKeyPressed(KEYNAMES.Right)
        end

        -- Set dash velocity if active

        if self:isDashActivated() then
            -- Apply dash acceleration
            local directionScalar = Dash:getLastKey() == KEYNAMES.Left and -1 or 1
            self:setVelocityX(directionScalar * self.dashSpeed)
        else
            local acceleration =
                self.onGround and self.groundAcceleration or self.airAcceleration

            -- Add horizontal acceleration to velocity

            if self.didMoveLeft and not self.didMoveRight then
                self:addVelocityX(-acceleration)
            elseif self.didMoveRight and not self.didMoveLeft then
                self:addVelocityX(acceleration)
            end
        end
    end

    -- Handle coyote frames

    if self.coyoteFramesRemaining > 0 and not self.onGround then
        -- Reduce coyote frames remaining
        self.coyoteFramesRemaining -= 1
    elseif self:getIsTouchingGround() then
        -- Reset coyote frames
        self.coyoteFramesRemaining = self.coyoteFramesMax

        -- Reset double jump
        self.hasDoubleJumpRemaining = self.enableDoubleJump

        -- Reset dash (only one per air-time)
        Dash:recharge()
    end

    -- Handle Vertical Movement

    if (self:isDashActivated() or self:isDashCoolingDown()) then
        -- Dash movement (ignores gravity and removes vertical movement)

        self:setVelocityY(0)
        self:setGravity(0)
    else
        self:setGravity()

        local isFirstJump = self:getIsTouchingGround() or self.coyoteFramesRemaining > 0
        if isFirstJump or self.hasDoubleJumpRemaining then
            -- Handle jump start

            if self.didJump then
                if not isFirstJump then
                    self.hasDoubleJumpRemaining = false
                end

                self:setVelocityY(-self.speedJump)

                self.coyoteFramesRemaining = 0
            end
        end
    end

    -- Dash cooldown / update

    Dash:updateFrame()
end

function Moveable:updateCollisions()
    function Player:updateCollisions()
        -- Check for special case event
        local horizontalCornerBlock = false

        for _, collisionData in pairs(self.collisions) do
            local other = collisionData.other
            local tag = other:getTag()
            local normal = collisionData.normal

            -- Special case/corner check for horizontal collisions

            if collisionData.normal.x ~= 0 and collisionData.otherRect.y == collisionData.spriteRect.y + collisionData.spriteRect.height then
                horizontalCornerBlock = collisionData.other
            end

            -- Bottom activations
            if normal.y == -1 and other.activateDown then
                -- If colliding with bottom, activate
                table.insert(self.activationsDown, other)
            elseif other.activate then
                -- Other activations
                table.insert(self.activations, other)
            end
        end

        -- Special case move - this may be an SDK bug?
        -- When player is on top of a block, and x coordinate is exactly on the tile +
        -- There is a separate "wall" (like drillable block) corner touching drillbot corner
        -- this appears to make the "slide" fail and no movement occurs.

        if horizontalCornerBlock and self:getIsTouchingGround() then
            local isMovingLeft = self.velocity.x < 0

            self:moveBy(isMovingLeft and 1 or -1, 0)
        end
    end
end

function Moveable:updateActivations()
    --- Override me! :)
end

-- Stateless checks

function Moveable:isDashActivated()
    return Dash:getIsActivated()
end

function Moveable:isDashCoolingDown()
    return Dash:getFramesSinceCooldownStarted() < self.dashFramesFloat
end

--------------------------
--- Dash
--------------------------

Dash = {}

-- Local constants

local framesDashRemainingMax <const> = 2
local framesDashCooldownMax <const> = 25
local msCooldownTime <const> = 500

-- Local variables

local lastKeyPressed
local timeLastKeyPressed
local framesDashCooldown = 0
local framesDashRemaining = framesDashRemainingMax
local isActivated = false

function Dash:registerKeyPressed(key)
    local currentTime = playdate.getCurrentTimeMilliseconds()

    -- Check if:
    -- key press is same as last
    -- key press is within timeframe
    -- cooldown is finished
    -- dash is not in progress

    if key == lastKeyPressed
        and timeLastKeyPressed > currentTime - msCooldownTime
        and framesDashCooldown == 0
        and framesDashRemaining > 0 then
        isActivated = true
    end

    -- Log latest key press

    lastKeyPressed = key
    timeLastKeyPressed = currentTime
end

function Dash:getLastKey()
    return lastKeyPressed
end

function Dash:getIsActivated()
    return isActivated
end

function Dash:getIsCooldownActive()
    return framesDashCooldown > 0
end

function Dash:getFramesSinceCooldownStarted()
    return framesDashCooldownMax - framesDashCooldown
end

function Dash:recharge()
    -- Reset dash frames remaining

    if framesDashRemaining == 0 and framesDashCooldown == 0 then
        framesDashRemaining = framesDashRemainingMax
    end
end

function Dash:finish()
    isActivated = false
    framesDashCooldown = framesDashCooldownMax
end

function Dash:updateFrame()
    -- Update variables for in-progress dash or cooldown if activated

    if isActivated and framesDashRemaining == 0 then
        -- End dash, set cooldown

        self:finish()
    elseif isActivated and framesDashRemaining > 0 then
        -- If activated, reduce dash frames

        framesDashRemaining -= 1
    elseif framesDashCooldown > 0 then
        -- If not activated, reduce cooldown if active

        framesDashCooldown -= 1
    end
end
