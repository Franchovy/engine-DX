import "player/dash"

local pd <const> = playdate
local sound <const> = pd.sound
local gmt <const> = pd.geometry
local gfx <const> = pd.graphics

local imagetablePlayer <const> = assert(gfx.imagetable.new(assets.imageTables.player))
local imagetablePlayerDarkness <const> = assert(gfx.imagetable.new(assets.imageTables.playerDarkness))

local spJump <const> = assert(sound.sampleplayer.new(assets.sounds.jump))
local spError <const> = assert(sound.sampleplayer.new(assets.sounds.errorAction))
local spDrill <const> = assert(sound.sampleplayer.new(assets.sounds.drill))

-- Level Bounds for camera movement (X,Y coords areas in global (world) coordinates)

local levelBounds

-- Variables for double-jump

local hasDoubleJumpUnlocked = true
local hasDoubleJumpRemaining = true

-- Timer for handling cooldown on checkpoint revert

local warpCooldown
local crankMomentum = 0

-- Boolean to keep overlapping with GUI state

local isOverlappingWithGUI = false

-- Animation state flip handling

local isFlipAnimation = 0

--

local ANIMATION_STATES = {
    Idle = 1,
    Moving = 2,
    Jumping = 3,
    Drilling = 4,
    Falling = 5,
    PreFalling = 6,
    Unsure = 7,
    UnsureRun = 8,
    Impact = 9,
    ImpactRun = 10,
    IdlePowerUp = 11,
    MovingPowerUp = 12
}

KEYS = {
    [KEYNAMES.Up] = pd.kButtonUp,
    [KEYNAMES.Down] = pd.kButtonDown,
    [KEYNAMES.Left] = pd.kButtonLeft,
    [KEYNAMES.Right] = pd.kButtonRight,
    [KEYNAMES.A] = pd.kButtonA,
    [KEYNAMES.B] = pd.kButtonB
}

local coyoteFrames <const> = 5
local groundAcceleration <const> = 3.5
local airAcceleration <const> = 0.9
local dashSpeed <const> = 27.0
local framesPostDashNoGravity <const> = 4
local jumpSpeed <const> = 27
local jumpSpeedDrilledBlock <const> = -14
local jumpHoldTimeInTicks <const> = 4
local VELOCITY_FALL_ANIMATION <const> = 6

-- Setup

--- @class Player : EntityAnimated
Player = Class("Player", EntityAnimated)

-- Static Reference

local _instance

---@return Player
function Player.getInstance() return _instance end

function Player.destroy()
    if _instance then
        _instance:remove()
        _instance = nil
    end
end

function Player.shouldSpawn(entityData, levelName)
    --- Return false if player instance already exists.
    return not Player.getInstance()
end

-----------------------
-- LIFECYCLE METHODS --
-----------------------

function Player:init(entityData, levelName)
    _instance = self

    local imagetable = CONFIG.ADD_SUPER_DARKNESS_EFFECT and imagetablePlayerDarkness or imagetablePlayer
    Player.super.init(self, entityData, levelName, imagetable)

    -- Set original spawn property on LDtk data

    entityData.isOriginalPlayerSpawn = true

    -- AnimatedSprite states

    self:setupAnimationStates()

    -- Collisions

    self:setGroups(GROUPS.Player)
    self:setCollidesWithGroups({ GROUPS.Solid, GROUPS.Overlap })
    self:setTag(TAGS.Player)

    -- "Sub-States"

    ---@type Dialog|false
    self.activeDialog = false
    self.didPressedInvalidKey = false
    self.activations = {}
    self.activationsDown = {}
    self.activationsPrevious = {}

    -- Jumping mechanic variables

    self.jumpTimeLeftInTicks = jumpHoldTimeInTicks
    self.coyoteFramesRemaining = coyoteFrames

    -- Setup keys array and starting keys

    assert(entityData.fields.chipSet, "Error: no chipset was set!")

    Manager.emitEvent(EVENTS.ChipSetNew, entityData.fields.chipSet)

    -- RigidBody config

    self.rigidBody = RigidBody(self, {})

    self.latestCheckpointPosition = gmt.point.new(self.x, self.y)

    -- Load abilities

    self:loadAbilities()

    -- Create child sprites

    self.crankWarpController = PlayerCrankWarpController()
    self.questionMark = PlayerQuestionMark(self)
    self.particlesDrilling = PlayerParticlesDrilling(self)

    -- Utils

    self.synth = Synth(SCALES.PLAYER)

    -- Reduce hitbox sizes

    local trimWidth, trimTop = 6, 8
    self:setCollideRect(trimWidth, trimTop, self.width - trimWidth * 2, self.height - trimTop)

    -- Add Checkpoint handling

    self.checkpointHandler = CheckpointHandler.getOrCreate(self.id, self)

    -- Adjust for super darkness

    if CONFIG.ADD_SUPER_DARKNESS_EFFECT then
        self:setZIndex(Z_INDEX.HUD.Main)
    end
end

function Player:collisionResponse(other)
    if other:getGroupMask() & GROUPS.Solid ~= 0 then
        return gfx.sprite.kCollisionTypeSlide
    else
        return gfx.sprite.kCollisionTypeOverlap
    end
end

function Player:add()
    Player.super.add(self)

    if self.crankWarpController then
        self.crankWarpController:add()
    end

    if self.particlesDrilling then
        self.particlesDrilling:add()
    end

    if self.questionMark then
        self.questionMark:add()
    end

    -- Add lighting effect

    GUILightingEffect:getInstance():addEffect(self, GUILightingEffect.imageLargeCircle)
end

function Player:remove()
    Player.super.remove(self)

    if self.crankWarpController then
        self.crankWarpController:remove()
    end

    if self.particlesDrilling then
        self.particlesDrilling:remove()
    end

    if self.questionMark then
        self.questionMark:remove()
    end

    -- Remove lighting effect

    GUILightingEffect:getInstance():removeEffect(self)
end

function Player:setupAnimationStates()
    self:addState(ANIMATION_STATES.Idle, 1, 4, { tickStep = 3 }).asDefault()
    self:addState(ANIMATION_STATES.Jumping, 5, 8, { tickStep = 2 })
    self:addState(ANIMATION_STATES.Moving, 9, 12, { tickStep = 2 })
    self:addState(ANIMATION_STATES.Drilling, 12, 16, { tickStep = 2 })
    self:addState(ANIMATION_STATES.Falling, 19, 20, { tickStep = 2 }) --thanks filigrani!
    self:addState(ANIMATION_STATES.PreFalling, 17, 18,
        { tickStep = 3 })
    self:addState(ANIMATION_STATES.Unsure, 24, 30, { tickStep = 2, nextAnimation = ANIMATION_STATES.Idle })
    self:addState(ANIMATION_STATES.UnsureRun, 46, 49,
        { tickStep = 3, nextAnimation = ANIMATION_STATES.Idle })
    self:addState(ANIMATION_STATES.Impact, 21, 23, { tickStep = 2, nextAnimation = ANIMATION_STATES.Idle })
    self:addState(ANIMATION_STATES.ImpactRun, 43, 45, { tickStep = 2, nextAnimation = ANIMATION_STATES.Idle })
    self:addState(ANIMATION_STATES.IdlePowerUp, 50, 53, { tickStep = 3 })
    self:addState(ANIMATION_STATES.MovingPowerUp, 54, 57, { tickStep = 2 })

    self.isAnimationFlip = 0

    self:playAnimation()
end

--------------------
-- PUBLIC METHODS --
--------------------

function Player:freeze()
    self.isFrozen = true
end

function Player:unfreeze()
    self.isFrozen = false

    -- Perform refresh on activations / update variables

    self.isTouchingGroundPrevious = false
    self.didPressedInvalidKey = false
    self.activationsDown = {}
    self.activations = {}
end

function Player:handleCheckpointRevert(state)
    self:moveTo(state.x, state.y)

    self.latestCheckpointPosition.x = state.x
    self.latestCheckpointPosition.y = state.y
end

-- Enter Level

function Player:enterLevel(levelName, direction)
    levelBounds = LDtk.get_rect(levelName)

    -- For convenience, add "right" and "bottom" accessors to bounds
    levelBounds.right = levelBounds.x + levelBounds.width
    levelBounds.bottom = levelBounds.y + levelBounds.height

    -- Position player based on direction of entry

    if direction == DIRECTION.RIGHT then
        self:moveTo(levelBounds.x + 15, self.y)
    elseif direction == DIRECTION.LEFT then
        self:moveTo(levelBounds.right - 15, self.y)
    elseif direction == DIRECTION.BOTTOM then
        self:moveTo(self.x, levelBounds.y + 15)
    elseif direction == DIRECTION.TOP then
        -- Additional movement when jumping into bottom of level for reaching bottom tile
        -- ... except if moving up with elevator.

        local additionalBottomOffset = self.isActivatingElevator and 0 or 15
        self:moveTo(self.x, levelBounds.bottom - 15 - additionalBottomOffset)
    end

    -- Bring any parents with player (for elevator)

    if self.isActivatingElevator then
        self.isActivatingElevator:enterLevel(levelName, direction)
    end

    -- Push level position
    self.checkpointHandler:pushState({
        x = self.x,
        y = self.y,
    })

    -- TODO: - Can this code be removed?
    -- Set a cooldown timer to prevent key presses on enter

    warpCooldown = playdate.timer.new(50)
    warpCooldown.timerEndedCallback = function(timer)
        timer:remove()

        -- Since there can be multiple checkpoint-reverts in sequence, we want to
        -- ensure we're not removing a timer that's not this one.
        if warpCooldown == timer then
            warpCooldown = nil
        end
    end
end

--------------------
-- PRIVATE METHODS --
--------------------

function Player:revertCheckpoint()
    -- Emit the event for the rest of the scene

    Manager.emitEvent(EVENTS.CheckpointRevert)

    -- Cooldown timer for checkpoint revert

    warpCooldown = playdate.timer.new(200)
    warpCooldown.timerEndedCallback = function(timer)
        timer:remove()

        -- Since there can be multiple checkpoint-reverts in sequence, we want to
        -- ensure we're not removing a timer that's not this one.
        if warpCooldown == timer then
            warpCooldown = nil
        end
    end
end

function Player:loadAbilities()
    self.abilities = MemoryCard.getAbilities() or {}
end

function Player:unlockAbility(ability)
    -- Save ability to memory card

    MemoryCard.setAbilities({ [ability] = true })

    -- Reload abilities

    self:loadAbilities()
end

function Player:animateInvalidKey()
    self.questionMark:play()
    ScreenShake.performScreenShake(3, 1)

    self.didPressedInvalidKey = true

    spError:play(1)
end

--------------------
-- UPDATE METHODS --
--------------------

-- Update Method

function Player:update()
    -- Sprite update

    Player.super.update(self)

    if self.isFrozen then
        return
    end

    -- Checkpoint Handling

    self:updateWarp()

    -- Activatable sprite interactions

    self.isActivatingElevator = false
    self.isActivatingDrillableBlock = false
    self.activeDialog = false

    self:updateActivations()

    -- Dialog / Interactions

    self:updateInteractions()

    -- Skip movement handling if:
    -- timer cooldown is active
    -- cooldown for warp is active

    if not warpCooldown and
        not (self.crankWarpController and self.crankWarpController:isActive()) and
        not playdate.buttonIsPressed(KEYNAMES.B)
    then
        self:updateMovement()
    end

    -- Update variables set by collisions

    self.isTouchingGroundPrevious = self.rigidBody:getIsTouchingGround()
    self.didPressedInvalidKey = false
    self.activationsDown = {}
    self.activations = {}

    -- RigidBody update

    self:updateRigidBody()

    self.rigidBody:setForcesCoefficient(1)

    -- Collisions Update

    self:updateCollisions()

    -- Update state for checkpoint

    self:updateCheckpointState()

    -- Animation Handling

    self:updateAnimationState()

    -- GUI Overlap, Camera

    self:updateGUI()

    -- Check if player has moved into another level

    if not warpCooldown then
        self:updateLevelChange()
    end
end

function Player:updateWarp()
    local crankChange = playdate.getCrankChange()
    local direction = self.crankWarpController:getDirection()

    -- If reverse direction but no dialog active, do nothing
    if (direction == -1 or crankChange < 0) and not (self.activeDialog and self.activeDialog:getIsRescuable()) then
        return
    end

    -- If forward direction but ability is not yet unlocked, do nothing
    if not self.abilities[ABILITIES.CrankToWarp] and (direction == 1 or crankChange > 0) then
        return
    end

    -- Add crank movement

    self.crankWarpController:addCrankMovement(crankChange)

    -- Re-read crank direction

    local directionNew = self.crankWarpController:getDirection()

    if directionNew == 0 then
        return
    end

    -- Position warp controller

    if directionNew == -1 then
        self.crankWarpController:moveTo(self.activeDialog.x, self.activeDialog.y)
    elseif directionNew == 1 then
        self.crankWarpController:moveTo(self.x, self.y)
    end

    -- Handle trigger

    if self.crankWarpController:hasTriggered() then
        if directionNew == -1 then
            -- Rescue bot
            self.activeDialog:setRescued()
        end
    elseif directionNew == 1 and self.crankWarpController:isActivated() then
        crankMomentum = (crankChange + crankMomentum) * 0.85

        local crankThresholdWarp = 100
        if crankMomentum >= crankThresholdWarp then
            local warpSpeedFinal = math.min(crankMomentum / crankThresholdWarp, 10)

            for i = 1, math.floor(warpSpeedFinal) do
                self:revertCheckpoint()
            end

            self.rigidBody:setForcesCoefficient(0.1)
        elseif crankMomentum > 1 and crankMomentum < crankThresholdWarp then
            local coefficient = ((crankThresholdWarp - crankMomentum) / crankThresholdWarp) ^ 2

            self.rigidBody:setForcesCoefficient(coefficient)
        end
    end
end

function Player:updateActivations()
    for i, otherSprite in ipairs(self.activationsDown) do
        local tag = otherSprite:getTag()
        local isBelowCenter = self:centerX() < otherSprite:right() and self:centerX() > otherSprite:left()

        -- If there are two bottom activations, choose only the one that is directly below the player.
        if #self.activationsDown > 1 and not isBelowCenter then
            goto continue
        end

        -- If Drilling
        if tag == TAGS.DrillableBlock then
            if self:isHoldingDownKeyGated() and isBelowCenter then
                -- Play drilling sound
                if not spDrill:isPlaying() then
                    spDrill:play(1)

                    self.particlesDrilling:startAnimation()
                end

                self.isActivatingDrillableBlock = otherSprite

                -- Activate block drilling

                otherSprite:activateDown()

                -- If consumed or player stopped pressing, end animation.
                if otherSprite:isConsumed() then
                    spDrill:stop()

                    self.particlesDrilling:endAnimation()

                    self.rigidBody:setVelocityY(jumpSpeedDrilledBlock)
                end

                -- Move particles to same location

                self.particlesDrilling:moveTo(self:centerX(), self:bottom())
            end

            -- Handle releasing the down key
            if pd.buttonJustReleased(pd.kButtonDown) then
                spDrill:stop()

                self.particlesDrilling:endAnimation()
            end
        end

        if tag == TAGS.Elevator then
            local key
            local directionsAvailable = otherSprite:getDirectionsAvailable()

            if directionsAvailable[ORIENTATION.Horizontal] then
                -- If horizontal, then the player must be near the center for the elevator to start.
                local marginWithinCenterRange <const> = 12

                if self:isHoldingLeftKeyGated() and self:centerX() < otherSprite:right() - marginWithinCenterRange then
                    key = KEYNAMES.Left
                elseif self:isHoldingRightKeyGated() and self:centerX() > otherSprite:left() + marginWithinCenterRange then
                    key = KEYNAMES.Right
                end
            end

            if directionsAvailable[ORIENTATION.Vertical] then
                if self:isHoldingDownKeyGated() then
                    key = KEYNAMES.Down
                elseif self:isHoldingUpKeyGated() then
                    key = KEYNAMES.Up
                end
            end

            if self:didJumpStart() then
                -- Disable collisions with elevator for this frame to avoid
                -- jump / moving into elevator collision glitch.
                otherSprite:disableCollisionsForFrame()
            else
                -- Otherwise, activate elevator (set self as child)
                otherSprite:activateDown(self, key)

                if key or (not self.isActivatingElevator and otherSprite:hasMovedRemaining()) then
                    -- If activation happened or elevator is still moving with player
                    self.isActivatingElevator = otherSprite
                end
            end
        end

        ::continue::
    end

    for i, otherSprite in ipairs(self.activations) do
        local tag = otherSprite:getTag()

        if tag == TAGS.Chip then
            -- [FRANCH] This condition is useful in case there is more than one blueprint being picked up. However
            -- we should be handling the multiple blueprints as a single checkpoint.
            -- But it's also useful for debugging.

            if not warpCooldown then
                otherSprite:activate()
            end
        elseif tag == TAGS.Dialog and not self.activeDialog then
            self.activeDialog = otherSprite

            self.activeDialog:activate()
        else
            otherSprite:activate()
        end
    end

    -- Cancel any digging if jumping or releasing dig key
    if self.isActivatingDrillableBlock and (self:didJumpStart() or pd.buttonJustReleased(pd.kButtonDown)) then
        self.particlesDrilling:endAnimation()

        self.isActivatingDrillableBlock = nil
    end
end

function Player:updateMovement()
    -- Movement handling (update velocity X and Y)

    -- Handle Horizontal Movement

    local didActivateElevatorSuccess = self.isActivatingElevator and self.isActivatingElevator:wasActivationSuccessful()

    if self.isActivatingDrillableBlock or didActivateElevatorSuccess then
        -- Skip horizontal movement if activating a bottom block
        self.rigidBody:setVelocityX(0.0)
    elseif self.isActivatingElevator and self.isActivatingElevator:getDirectionsAvailable()[ORIENTATION.Horizontal]
        and (pd.buttonJustPressed(pd.kButtonLeft) or pd.buttonJustPressed(pd.kButtonRight)) then
        -- Skip upon pressing left or right to give collisions a frame to calculate horizontal elevator movement.
        self.rigidBody:setVelocityX(0.0)
    elseif self.isActivatingElevator and self.isActivatingElevator:getDirectionsAvailable()[ORIENTATION.Horizontal]
        and (not self.isTouchingGroundPrevious and self.rigidBody:getIsTouchingGround()) then
        -- Skip upon landing on a horizontal elevator
        self.rigidBody:setVelocityX(0.0)
    else
        local isHoldingLeft = self:isHoldingLeftKeyGated()
        local isHoldingRight = self:isHoldingRightKeyGated()

        -- Register key press for dash

        if isHoldingLeft and playdate.buttonJustPressed(KEYNAMES.Left) then
            Dash:registerKeyPressed(KEYNAMES.Left)
        elseif isHoldingRight and playdate.buttonJustPressed(KEYNAMES.Right) then
            Dash:registerKeyPressed(KEYNAMES.Right)
        end

        -- Set dash velocity if active

        if self:isDashActivated() then
            -- Apply dash acceleration
            local directionScalar = Dash:getLastKey() == KEYNAMES.Left and -1 or 1
            self.rigidBody:setVelocityX(directionScalar * dashSpeed)
        else
            local acceleration =
                self.rigidBody:getIsTouchingGround() and groundAcceleration or
                airAcceleration

            -- Add horizontal acceleration to velocity

            if isHoldingLeft and not isHoldingRight then
                self.rigidBody:addVelocityX(-acceleration)
            elseif isHoldingRight and not isHoldingLeft then
                self.rigidBody:addVelocityX(acceleration)
            end
        end
    end

    -- Handle coyote frames

    if self.coyoteFramesRemaining > 0 and not self.rigidBody:getIsTouchingGround() then
        -- Reduce coyote frames remaining
        self.coyoteFramesRemaining -= 1
    elseif self.rigidBody:getIsTouchingGround() then
        -- Reset coyote frames
        self.coyoteFramesRemaining = coyoteFrames

        -- Reset double jump
        hasDoubleJumpRemaining = true

        -- Reset dash (only one per air-time)
        Dash:recharge()
    end

    -- Handle Vertical Movement

    if (self:isDashActivated() or self:isDashCoolingDown()) then
        -- Dash movement (ignores gravity and removes vertical movement)

        self.rigidBody:setVelocityY(0)
        self.rigidBody:setGravity(0)
    else
        self.rigidBody:setGravity()


        local isFirstJump = self.rigidBody:getIsTouchingGround() or self.coyoteFramesRemaining > 0
        if isFirstJump or self:canDoubleJump() then
            -- Handle jump start

            if self:didJumpStart() then
                if not isFirstJump then
                    hasDoubleJumpRemaining = false
                end

                spJump:play(1)

                self.rigidBody:setVelocityY(-jumpSpeed)

                self.jumpTimeLeftInTicks -= 1

                self.coyoteFramesRemaining = 0
            end
        elseif self:isHoldingJumpKeyGated() and self.jumpTimeLeftInTicks > 0 then
            -- Handle Jump Hold

            self.rigidBody:setVelocityY(-jumpSpeed)

            self.jumpTimeLeftInTicks -= 1
        elseif pd.buttonJustReleased(KEYNAMES.A) or self.jumpTimeLeftInTicks > 0 then
            -- Handle Jump Release

            self.jumpTimeLeftInTicks = 0
        end
    end

    -- Dash cooldown / update

    Dash:updateFrame()
end

function Player:updateInteractions()
    if self.activeDialog and self:justPressedInteractionKey() then
        self.activeDialog:showNextLine()
    else
        if self:justPressedInteractionKey() then
            self.synth:play()
        elseif self:justReleasedInteractionKey() then
            self.synth:stop()
        end
    end
end

function Player:updateRigidBody()
    self.collisions = self.rigidBody:update()
end

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

    if horizontalCornerBlock and self.rigidBody:getIsTouchingGround() then
        local isMovingLeft = self.rigidBody.velocity.x < 0

        self:moveBy(isMovingLeft and 1 or -1, 0)
    end
end

function Player:updateCheckpointState()
    if self.x ~= self.latestCheckpointPosition.x or self.y ~= self.latestCheckpointPosition.y then
        self.latestCheckpointPosition.x = self.x
        self.latestCheckpointPosition.y = self.y

        self.checkpointHandler:pushState({
            x = self.latestCheckpointPosition.x,
            y = self.latestCheckpointPosition.y,
        })

        Checkpoint.increment()
    end
end

function Player:updateAnimationState()
    local animationState
    local velocity = self.rigidBody:getCurrentVelocity()
    local isMoving = math.floor(math.abs(velocity.dx)) > 0
    local isMovingActive = self:isHoldingRightKeyGated() or self:isHoldingLeftKeyGated()

    -- "Skip" states

    local shouldSkipStateCheck = self.states[self.currentState].nextAnimation == ANIMATION_STATES.Idle

    if not shouldSkipStateCheck then
        if self.crankWarpController.crankMomentum > 20 then
            animationState = ANIMATION_STATES.Falling
        elseif self.rigidBody:getIsTouchingGround() then
            if self.isActivatingDrillableBlock and self:isHoldingDownKeyGated() then
                animationState = ANIMATION_STATES.Drilling
            elseif self.didPressedInvalidKey then
                if isMoving and isMovingActive then
                    -- Moving Unsure
                    animationState = ANIMATION_STATES.UnsureRun
                else
                    -- Static Unsure
                    animationState = ANIMATION_STATES.Unsure
                end
            elseif not self.isTouchingGroundPrevious then
                if isMoving and isMovingActive then
                    -- Moving Impact
                    animationState = ANIMATION_STATES.ImpactRun
                else
                    -- Static Impact
                    animationState = ANIMATION_STATES.Impact
                end
            elseif isMoving and not (self.isActivatingElevator and self.isActivatingElevator:wasActivationSuccessful()) then
                if GUIChipSet.getInstance():getIsPowered() then
                    animationState = ANIMATION_STATES.MovingPowerUp
                else
                    animationState = ANIMATION_STATES.Moving
                end
            else
                if GUIChipSet.getInstance():getIsPowered() then
                    animationState = ANIMATION_STATES.IdlePowerUp
                else
                    animationState = ANIMATION_STATES.Idle
                end
            end
        else
            if velocity.dy > VELOCITY_FALL_ANIMATION then
                -- When falling past a certain speed
                animationState = ANIMATION_STATES.Falling
            elseif math.abs(velocity.dy) <= VELOCITY_FALL_ANIMATION then
                -- When floating in the air (not jumping)
                animationState = ANIMATION_STATES.PreFalling
            else
                -- When moving upwards in the air (jumping)
                animationState = ANIMATION_STATES.Jumping
            end
        end
    end

    if not animationState then
        animationState = self.currentState
    end

    -- Handle direction (flip)

    if velocity.dx < 0 then
        self.isAnimationFlip = 1
    elseif velocity.dx > 0 then
        self.isAnimationFlip = 0
    end

    self.states[animationState].flip = self.isAnimationFlip

    local nextAnimation = self.states[animationState].nextAnimation
    if nextAnimation then
        self.states[nextAnimation].flip = self.isAnimationFlip
    end

    -- Change State
    self:changeState(animationState)
end

function Player:updateGUI()
    -- Update camera if pressing a direction + B button

    if playdate.buttonIsPressed(KEYNAMES.B) then
        local directionX, directionY =
            playdate.buttonIsPressed(KEYNAMES.Left) and 1 or playdate.buttonIsPressed(KEYNAMES.Right) and -1 or 0,
            playdate.buttonIsPressed(KEYNAMES.Up) and 1 or playdate.buttonIsPressed(KEYNAMES.Down) and -1 or 0

        local panOffsetX, panOffsetY = 150, 100

        Camera.setOffset(directionX * panOffsetX, directionY * panOffsetY)
    else
        Camera.setOffset(0, 0)
    end

    -- GUI Overlap check

    local isOverlappingWithGUIPrevious = isOverlappingWithGUI
    local screenOffsetX, screenOffsetY = gfx.getDrawOffset()

    if self.x + screenOffsetX < 116 and self.y + screenOffsetY < 56 then
        isOverlappingWithGUI = true
    else
        isOverlappingWithGUI = false
    end

    if isOverlappingWithGUI ~= isOverlappingWithGUIPrevious then
        -- Signal to hide or show GUI based on overlap
        Manager.emitEvent(EVENTS.HideOrShowGUI, isOverlappingWithGUI)
    end
end

function Player:updateLevelChange()
    local direction

    if self.x > levelBounds.right then
        direction = DIRECTION.RIGHT
    elseif self.x < levelBounds.x then
        direction = DIRECTION.LEFT
    end

    if self.y > levelBounds.bottom then
        direction = DIRECTION.BOTTOM
    elseif self.y < levelBounds.y then
        direction = DIRECTION.TOP
    end

    if direction then
        Manager.emitEvent(EVENTS.LevelComplete,
            { direction = direction, coordinates = { x = self.x, y = self.y } })
    end
end

-------------------
-- INPUT METHODS --
-------------------

-- Stateless checks

function Player:didJumpStart()
    return pd.buttonJustPressed(KEYNAMES.A) and self:isHoldingJumpKeyGated()
end

function Player:canDoubleJump()
    return self.abilities[ABILITIES.DoubleJump] and hasDoubleJumpRemaining and
        GUIChipSet.getInstance():hasDoubleKey(KEYNAMES.A)
end

function Player:isDashActivated()
    return self.abilities[ABILITIES.Dash] and Dash:getIsActivated()
end

function Player:isDashCoolingDown()
    return self.abilities[ABILITIES.Dash] and Dash:getFramesSinceCooldownStarted() < framesPostDashNoGravity
end

-- Input Handlers

-- TODO: Replace implementation of button & blueprints check with blueprint check using button mask + playdate.getButtonState()
-- Replace didPressedInvalidKey with stateless check

function Player:isHoldingJumpKeyGated()
    return self:isKeyPressedGated(KEYNAMES.A)
end

function Player:isHoldingRightKeyGated()
    return self:isKeyPressedGated(KEYNAMES.Right)
end

function Player:isHoldingLeftKeyGated()
    return self:isKeyPressedGated(KEYNAMES.Left)
end

function Player:isHoldingUpKeyGated()
    return self:isKeyPressedGated(KEYNAMES.Up)
end

function Player:isHoldingDownKeyGated()
    return self:isKeyPressedGated(KEYNAMES.Down)
end

function Player:justPressedInteractionKey()
    return playdate.buttonJustPressed(KEYNAMES.B)
end

function Player:justReleasedInteractionKey()
    return playdate.buttonJustReleased(KEYNAMES.B)
end

-- Generic gated input handler

function Player:isKeyPressedGated(key)
    if not pd.buttonIsPressed(key) then
        -- Button is not pressed.
        return false
    end

    if playdate.buttonIsPressed(KEYNAMES.B) then
        -- If B is pressed, disable all input (movement)
        return false
    end

    -- Check whether chipset contains key or is otherwise disabled

    local chipset = GUIChipSet.getInstance()

    if chipset:getButtonEnabled(key) then
        return true
    elseif pd.buttonJustPressed(key) then
        self:animateInvalidKey()

        return false
    end
end
