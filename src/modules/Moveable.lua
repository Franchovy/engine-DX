local pd <const> = playdate
local gmt <const> = pd.geometry
local gfx <const> = pd.graphics

--- @class Moveable: _Sprite
Moveable = {}

---@alias Config {gravity: number?, movement:number|{air: {acceleration:number,friction:number?}, ground: {acceleration:number,friction:number?}},dash: {frames:integer,speed:number}?,jump: {speed:number, doubleJump:boolean?, coyoteFrames: integer?}?}

---@param config Config
function Moveable:init(config)
    config = config or {}

    -- Config variables

    if config.gravity then
        self.gravityMax = config.gravity
    end

    if config.movement and type(config.movement) == "number" then
        -- Flat 4-direction movement
        self.speedMovement = config.movement
    elseif config.movement then
        self.frictionAir = config.movement.air.friction or 0
        self.frictionGround = config.movement.ground.friction or 0
        self.accelerationAir = config.movement.air.acceleration
        self.accelerationGround = config.movement.ground.acceleration
    end


    if config.dash then
        self.isEnabledDash = true
        self.speedDash = config.dash.speed
        self.framesDash = config.dash.frames
    end

    if config.jump then
        self.framesCoyote = config.jump.coyoteFrames
        self.speedJump = config.jump.speed
        self.isEnabledDoubleJump = config.jump.doubleJump
    end

    -- Dynamic variables

    self.gravity = self.gravityMax
    self.velocity = gmt.vector2D.new(0, 0)
    self.framesCoyoteRemaining = self.framesCoyote
    self.hasDoubleJumpRemaining = self.isEnabledDoubleJump

    self.onGround = true
    self.onGroundPrevious = false
    self.didMoveLeft = false
    self.didMoveRight = false
    self.didJump = false

    self.didMoveSuccess = false
    self.activationsDown = {}
    self.activations = {}

    ---@type Moveable?
    self.spriteParent = nil
    ---@type Moveable?
    self.spriteChild = nil
end

function Moveable:getIsDoubleJumpEnabled()
    return self.isEnabledDoubleJump or false
end

function Moveable:getIsDashEnabled(direction)
    return self.isEnabledDash or false
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
    self.gravity = g or self.gravityMax
end

function Moveable:moveLeft()
    self.didMoveLeft = true
end

function Moveable:moveRight()
    self.didMoveRight = true
end

function Moveable:moveUp()
    self.didMoveUp = true
end

function Moveable:moveDown()
    self.didMoveDown = true
end

function Moveable:jump()
    self.didJump = true
end

---comment
---@param spriteParent Moveable?
function Moveable:setParent(spriteParent)
    self.spriteParent = spriteParent

    if spriteParent then
        spriteParent.spriteChild = self
    end
end

function Moveable:update()
    if self.spriteParent then
        -- As a child, this sprite should not initiate movement.

        self:updateParent()
    end

    -- Apply forces to velocity

    -- incorporate gravity

    if self.gravity then
        if self.onGround then
            -- Resets velocity, still applying gravity vector

            local dx, _ = self.velocity:unpack()
            self.velocity = gmt.vector2D.new(dx, self.gravity * _G.delta_time)

            -- Apply Ground Friction to x-axis movement

            self.velocity.dx = self.velocity.dx +
                (self.velocity.dx * self.frictionGround * _G.delta_time)
        else
            -- Adds gravity vector to current velocity

            self.velocity.dy = self.velocity.dy + (self.gravity * _G.delta_time)

            -- Apply Air Friction

            self.velocity.dx = self.velocity.dx +
                (self.velocity.dx ^ 3 * self.frictionAir * _G.delta_time)
            self.velocity.dy = self.velocity.dy +
                (self.velocity.dy ^ 3 * self.frictionAir * _G.delta_time)
        end
    end

    -- If x velocity is very small, reduce to zero.
    if math.abs(self.velocity.dx) < 0.1 then
        self.velocity.dx = 0
    end

    self:updateMovement()

    -- calculate new position by adding velocity to current position
    local xPrevious, yPrevious = self.x, self.y
    local newPos = gmt.vector2D.new(self.x, self.y) + (self.velocity * _G.delta_time)

    local actualX, actualY
    local sdkCollisions

    if self.constrainMovement then
        newPos.x, newPos.y = self:constrainMovement(newPos.x, newPos.y)
    end

    if self.spriteChild then
        actualX, actualY, sdkCollisions = self:moveWithChild(newPos)
    else
        actualX, actualY, sdkCollisions = self:moveWithCollisions(newPos:unpack())
    end

    self.collisions = sdkCollisions

    -- Update movement success flag

    if self.didMoveLeft or self.didMoveRight or self.didMoveUp or self.didMoveDown then
        self.didMoveSuccess = self.x ~= xPrevious or self.y ~= yPrevious
    else
        self.didMoveSuccess = nil
    end

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

    -- Reset activations

    self.activationsDown = {}
    self.activations = {}

    self:updateCollisions()

    if self.updateActivations then
        self:updateActivations()
    end

    -- Reset movement variables
    self.didMoveLeftPrevious = self.didMoveLeft
    self.didMoveRightPrevious = self.didMoveRight
    self.didMoveUpPrevious = self.didMoveUp
    self.didMoveDownPrevious = self.didMoveDown
    self.didMoveLeft = false
    self.didMoveRight = false
    self.didMoveUp = false
    self.didMoveDown = false
    self.didJump = false

    -- Update parent

    if not self.spriteParent and self.spriteParentPrevious then
        -- Remove child
        self.spriteParentPrevious.spriteChild = nil
    end

    self.spriteParentPrevious = self.spriteParent
end

---comment
---@param targetPosition _Point
---@return number, number, _SpriteCollisionData
function Moveable:moveWithChild(targetPosition)
    assert(self.spriteChild)

    local xTarget, yTarget = targetPosition:unpack()

    self.spriteChild:setCollisionsEnabled(false)

    local xActual, yActual, collisions = self:checkCollisions(xTarget, yTarget)
    local xDiff, yDiff = xActual - self.x, yActual - self.y
    local xChild, yChild = self.spriteChild.x, self.spriteChild.y

    self.spriteChild:setCollisionsEnabled(true)

    self:setCollisionsEnabled(false)

    local xActualChild, yActualChild, collisionsChild = self.spriteChild:checkCollisions(xChild + xDiff, yChild + yDiff)
    local xDiffChild, yDiffChild = xActualChild - xChild, yActualChild - yChild

    self:setCollisionsEnabled(true)

    self:moveBy(xDiffChild, yDiffChild)
    self.spriteChild:moveBy(xDiffChild, yDiffChild)

    return self.x + xDiffChild, self.y + yDiffChild, collisions
end

function Moveable:updateMovement()
    -- Movement handling (update velocity X and Y)

    -- Register key press for dash

    local dashDirection = ((self.didMoveLeft and not self.didMoveLeftPrevious and self:getIsDashEnabled(playdate.kButtonLeft)) and
            KEYNAMES.Left)
        or
        ((self.didMoveRight and not self.didMoveRightPrevious and self:getIsDashEnabled(playdate.kButtonRight)) and
            KEYNAMES.Right)

    if dashDirection then
        Dash:registerKeyPressed(dashDirection)
    end

    -- Set dash velocity if active

    if dashDirection and self:isDashActivated() then
        -- Apply dash acceleration
        local directionScalar = Dash:getLastKey() == KEYNAMES.Left and -1 or 1
        self:setVelocityX(directionScalar * self.speedDash)
    else
        -- Handle Horizontal Movement

        if self.speedMovement then
            -- Linear 4-directional movement

            if self.didMoveLeft and not self.didMoveRight then
                self:setVelocityX(-self.speedMovement)
            elseif self.didMoveRight and not self.didMoveLeft then
                self:setVelocityX(self.speedMovement)
            else
                self:setVelocityX(0)
            end

            if self.didMoveUp and not self.didMoveDown then
                self:setVelocityY(-self.speedMovement)
            elseif self.didMoveDown and not self.didMoveUp then
                self:setVelocityY(self.speedMovement)
            else
                self:setVelocityY(0)
            end
        else
            local acceleration =
                self.onGround and self.accelerationGround or self.accelerationAir

            -- Add horizontal acceleration to velocity

            if self.didMoveLeft and not self.didMoveRight then
                self:addVelocityX(-acceleration)
            elseif self.didMoveRight and not self.didMoveLeft then
                self:addVelocityX(acceleration)
            end
        end
    end

    -- Handle coyote frames

    if self.framesCoyoteRemaining then
        if self.framesCoyoteRemaining > 0 and not self.onGround then
            -- Reduce coyote frames remaining
            self.framesCoyoteRemaining -= 1
        elseif self:getIsTouchingGround() then
            -- Reset coyote frames
            self.framesCoyoteRemaining = self.framesCoyote

            -- Reset double jump
            self.hasDoubleJumpRemaining = self:getIsDoubleJumpEnabled()

            -- Reset dash (only one per air-time)
            Dash:recharge()
        end
    end

    -- Handle Vertical Movement

    if self.isEnabledDash and (self:isDashActivated() or self:isDashCoolingDown()) then
        -- Dash movement (ignores gravity and removes vertical movement)

        self:setVelocityY(0)
        self:setGravity(0)
    else
        self:setGravity()

        local isFirstJump = self:getIsTouchingGround() or (self.framesCoyote and self.framesCoyoteRemaining > 0)
        if isFirstJump or self.hasDoubleJumpRemaining then
            -- Handle jump start

            if self.didJump then
                if not isFirstJump then
                    self.hasDoubleJumpRemaining = false
                end

                self:setVelocityY(-self.speedJump)

                if self.framesCoyote then
                    self.framesCoyoteRemaining = 0
                end
            end
        end
    end

    -- Dash cooldown / update

    Dash:updateFrame()
end

function Moveable:updateCollisions()
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
        local isMovingLeft = self.velocity.dx < 0

        self:moveBy(isMovingLeft and 1 or -1, 0)
    end
end

function Moveable:updateParent()
    -- Transfer movement from self to parent

    self.spriteParent.didMoveLeft = self.didMoveLeft
    self.spriteParent.didMoveRight = self.didMoveRight
    self.spriteParent.didMoveUp = self.didMoveUp
    self.spriteParent.didMoveDown = self.didMoveDown

    self.didMoveLeft = false
    self.didMoveRight = false
    self.didMoveUp = false
    self.didMoveDown = false

    -- Cancel any dash keystrokes
    Dash:cancel()
end

---comment
---@param xTarget number
---@param yTarget number
---@return number, number
function Moveable:constrainMovement(xTarget, yTarget)
    --- Override me! :)
    ---
    return xTarget, yTarget
end

function Moveable:updateActivations()
    --- Override me! :)
end

-- Stateless checks

function Moveable:isDashActivated()
    return Dash:getIsActivated()
end

function Moveable:isDashCoolingDown()
    return Dash:getFramesSinceCooldownStarted() < self.framesDash
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

function Dash:cancel()
    lastKeyPressed = nil
    timeLastKeyPressed = nil
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
