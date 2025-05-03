import "player/PlayerCrankWarpController"
import "player/PlayerQuestionMark"
import "player/PlayerParticlesDrilling"

local pd <const> = playdate
local sound <const> = pd.sound
local gmt <const> = pd.geometry
local gfx <const> = pd.graphics

local imagetablePlayer <const> = gfx.imagetable.new(assets.imageTables.player)
local imagetablePlayerDarkness <const> = gfx.imagetable.new(assets.imageTables.playerDarkness)
local spJump <const> = sound.sampleplayer.new("assets/sfx/Jump")
local spError <const> = sound.sampleplayer.new(assets.sounds.errorAction)
local spDrill <const> = sound.sampleplayer.new(assets.sounds.drill)
local spCollect <const> = sound.sampleplayer.new("assets/sfx/Collect")

-- Level Bounds for camera movement (X,Y coords areas in global (world) coordinates)

local levelBounds

-- Timer for handling cooldown on checkpoint revert

local timerCooldownCheckpoint

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
}

KEYS = {
    [KEYNAMES.Up] = pd.kButtonUp,
    [KEYNAMES.Down] = pd.kButtonDown,
    [KEYNAMES.Left] = pd.kButtonLeft,
    [KEYNAMES.Right] = pd.kButtonRight,
    [KEYNAMES.A] = pd.kButtonA,
    [KEYNAMES.B] = pd.kButtonB
}

local groundAcceleration <const> = 3.5
local airAcceleration <const> = 1.4
local jumpSpeed <const> = 27
local jumpHoldTimeInTicks <const> = 4
local VELOCITY_FALL_ANIMATION <const> = 6

-- TODO: [Franch]
-- Set timer to pause movement when doing checkpoint resets (0.5s probably)
-- Abilities (blueprints) should come from a single source, read from panel (or game)

-- Setup

Player = Class("Player", AnimatedSprite)

-- Static Reference

local _instance

function Player.getInstance() return _instance end

function Player.destroy() _instance = nil end

-----------------------
-- LIFECYCLE METHODS --
-----------------------

function Player:init(entity)
    _instance = self

    local imagetable = CONFIG.ADD_SUPER_DARKNESS_EFFECT and imagetablePlayerDarkness or imagetablePlayer
    Player.super.init(self, imagetable)

    entity.isOriginalPlayerSpawn = true

    -- AnimatedSprite states

    self:setupAnimationStates()

    self:setTag(TAGS.Player)

    self.activeDialog = false
    self.didPressedInvalidKey = false
    self.activations = {}
    self.activationsBottom = {}
    self.activationsPrevious = {}

    -- Setup keys array and starting keys

    self.blueprints = {}

    local startingKeys = entity.fields.blueprints
    for _, key in ipairs(startingKeys) do
        table.insert(self.blueprints, key)
    end

    Manager.emitEvent(EVENTS.UpdateBlueprints)

    -- RigidBody config

    local rigidBodyConfig = {
        groundFriction = 2,
        airFriction = 2,
        gravity = 5
    }

    self.rigidBody = RigidBody(self, rigidBodyConfig)

    self.latestCheckpointPosition = gmt.point.new(self.x, self.y)

    -- Create child sprites

    self.crankWarpController = PlayerCrankWarpController()
    self.questionMark = PlayerQuestionMark(self)
    self.particlesDrilling = PlayerParticlesDrilling(self)
end

function Player:postInit()
    -- Add Checkpoint handling

    self.checkpointHandler = CheckpointHandler.getOrCreate(self.id, self)

    if CONFIG.ADD_SUPER_DARKNESS_EFFECT then
        self:setZIndex(Z_INDEX.HUD.Main)
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
end

function Player:handleCheckpointRevert(state)
    self:moveTo(state.x, state.y)

    self.latestCheckpointPosition.x = state.x
    self.latestCheckpointPosition.y = state.y
    self.blueprints = state.blueprints

    Manager.emitEvent(EVENTS.UpdateBlueprints)
end

-- Enter Level

function Player:enterLevel(direction, levelBoundsNew)
    levelBounds = levelBoundsNew

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
        self:moveTo(self.x, levelBounds.bottom - 15)
    end

    -- Bring any parents with player (for elevator)

    if self.isActivatingElevator then
        self.isActivatingElevator:enterLevel()
    end

    -- Push level position
    self.checkpointHandler:pushState({
        x = self.x,
        y = self.y,
        blueprints = table.deepcopy(self.blueprints)
    })

    -- TODO: - Can this code be removed?
    -- Set a cooldown timer to prevent key presses on enter

    timerCooldownCheckpoint = playdate.timer.new(50)
    timerCooldownCheckpoint.timerEndedCallback = function(timer)
        timer:remove()

        -- Since there can be multiple checkpoint-reverts in sequence, we want to
        -- ensure we're not removing a timer that's not this one.
        if timerCooldownCheckpoint == timer then
            timerCooldownCheckpoint = nil
        end
    end
end

function Player:setBlueprints(blueprints)
    self.blueprints = blueprints
end

function Player:setLevelEndReady()
    self.crankWarpController:setEndGameLoop()
end

--------------------
-- PRIVATE METHODS --
--------------------

function Player:revertCheckpoint()
    -- Emit the event for the rest of the scene

    Manager.emitEvent(EVENTS.CheckpointRevert)

    -- Cooldown timer for checkpoint revert

    timerCooldownCheckpoint = playdate.timer.new(500)
    timerCooldownCheckpoint.timerEndedCallback = function(timer)
        timer:remove()

        -- Since there can be multiple checkpoint-reverts in sequence, we want to
        -- ensure we're not removing a timer that's not this one.
        if timerCooldownCheckpoint == timer then
            timerCooldownCheckpoint = nil
        end
    end
end

function Player:pickUpBlueprint(blueprint)
    -- Emit pickup event for abilty panel

    spCollect:play(1)

    -- Update blueprints list

    -- Keeping blueprints in separate table for checkpoint state purpose
    local blueprintsNew = table.deepcopy(self.blueprints)

    if #blueprintsNew == 3 then
        table.remove(blueprintsNew, 1)
    end

    table.insert(blueprintsNew, blueprint)

    self.blueprints = blueprintsNew

    self.checkpointHandler:pushState({
        x = self.x,
        y = self.y,
        blueprints = self.blueprints
    })

    Manager.emitEvent(EVENTS.UpdateBlueprints)

    -- Update checkpoints

    --Manager.emitEvent(EVENTS.CheckpointIncrement)
end

--------------------
-- UPDATE METHODS --
--------------------

function Player:collisionResponse(other)
    local tag = other:getTag()
    if tag == TAGS.Wall or
        tag == TAGS.ConveyorBelt or
        tag == TAGS.Box or
        tag == TAGS.DrillableBlock or
        tag == TAGS.Elevator then
        return gfx.sprite.kCollisionTypeSlide
    else
        return gfx.sprite.kCollisionTypeOverlap
    end
end

-- Update Method

local jumpTimeLeftInTicks = jumpHoldTimeInTicks

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

    -- Skip movement handling if timer cooldown is active

    self:updateMovement()

    -- Update variables set by collisions

    self.isTouchingGroundPrevious = self.rigidBody:getIsTouchingGround()
    self.isTouchingPower = false
    self.didPressedInvalidKey = false
    self.activationsBottom = {}
    self.activations = {}

    -- RigidBody update

    self:updateRigidBody()

    -- Collisions Update

    self:updateCollisions()

    -- Update state for checkpoint

    self:updateCheckpointState()

    -- Animation Handling

    self:updateAnimationState()

    -- Update warp overlay

    if self.crankWarpController then
        self.crankWarpController:moveTo(self.x, self.y)
    end

    -- Check if player is in top-left of level (overlap with GUI)

    self:updateGUIOverlap()

    -- Check if player has moved into another level

    self:updateLevelChange()
end

function Player:updateWarp()
    if self.crankWarpController:hasTriggeredWarp() then
        self:revertCheckpoint()

        self.crankWarpController:resetWarp()
    end
end

function Player:updateActivations()
    for i, otherSprite in ipairs(self.activationsBottom) do
        local tag = otherSprite:getTag()
        local isBelowCenter = self:centerX() < otherSprite:right() and self:centerX() > otherSprite:left()

        -- If Drilling
        if tag == TAGS.DrillableBlock then
            if self:isHoldingDownKey() and isBelowCenter then
                -- Play drilling sound
                if not spDrill:isPlaying() then
                    spDrill:play(1)

                    self.particlesDrilling:startAnimation()
                end

                self.isActivatingDrillableBlock = otherSprite

                -- Activate block drilling

                otherSprite:activate()

                -- If consumed or player stopped pressing, end animation.
                if otherSprite:isConsumed() or pd.buttonJustReleased(pd.kButtonDown) then
                    spDrill:stop()
                    self.particlesDrilling:endAnimation()
                end

                -- Move particles to same location

                self.particlesDrilling:moveTo(self:centerX(), self:bottom())
            elseif pd.buttonJustReleased(pd.kButtonDown) then
                spDrill:stop()

                self.particlesDrilling:endAnimation()
            end
        end

        if tag == TAGS.Elevator then
            local key
            local direction = otherSprite:getDirection()
            if direction == ORIENTATION.Horizontal then
                if self:isHoldingLeftKey() then
                    key = KEYNAMES.Left
                elseif self:isHoldingRightKey() then
                    key = KEYNAMES.Right
                end
            elseif direction == ORIENTATION.Vertical then
                if self:isHoldingDownKey() then
                    key = KEYNAMES.Down
                elseif self:isHoldingUpKey() then
                    key = KEYNAMES.Up
                end
            end

            otherSprite:activate(self, key)

            self.isActivatingElevator = otherSprite
        end
    end

    for i, otherSprite in ipairs(self.activations) do
        local tag = otherSprite:getTag()

        if tag == TAGS.Ability then
            -- [FRANCH] This condition is useful in case there is more than one blueprint being picked up. However
            -- we should be handling the multiple blueprints as a single checkpoint.
            -- But it's also useful for debugging.

            if not timerCooldownCheckpoint then
                otherSprite:updateStatePickedUp()

                self:pickUpBlueprint(otherSprite.abilityName)
            end
        end

        if tag == TAGS.Dialog and not self.activeDialog then
            self.activeDialog = otherSprite

            self.activeDialog:activate()

            if self:justPressedInteractionKey() then
                self.activeDialog:showNextLine()

                if self.activeDialog:hasKey() then
                    -- Get key
                    self:pickUpBlueprint(self.activeDialog:getKey())
                end
            end
        end

        if tag == TAGS.SavePoint then
            otherSprite:activate()
        end
    end

    if self:didJumpStart() then
        -- Disable collisions with elevator for this frame to avoid
        -- jump / moving elevator up collisions glitch.
        if self.isActivatingElevator then
            self.isActivatingElevator:disableCollisionsForFrame()
        end
    end

    -- Cancel any digging if jumping or releasing dig key
    if self.isActivatingDrillableBlock and (self:didJumpStart() or pd.buttonJustReleased(pd.kButtonDown)) then
        self.particlesDrilling:endAnimation()

        self.isActivatingDrillableBlock = nil
    end
end

function Player:updateMovement()
    -- If cooldown for warp is active, then skip movement update.
    if self.crankWarpController:isActive() then
        return
    end

    -- Movement handling (update velocity X and Y)

    -- Handle Horizontal Movement

    local didActivateElevatorSuccess = self.isActivatingElevator and self.isActivatingElevator:wasActivationSuccessful()

    if self.isActivatingDrillableBlock or didActivateElevatorSuccess then
        -- Skip horizontal movement if activating a bottom block
    elseif self.isActivatingElevator and self.isActivatingElevator:getDirection() == ORIENTATION.Horizontal
        and (pd.buttonJustPressed(pd.kButtonLeft) or pd.buttonJustPressed(pd.kButtonRight)) then
        -- Skip upon pressing left or right to give collisions a frame to calculate horizontal elevator movement.
    else
        local acceleration = self.rigidBody:getIsTouchingGround() and groundAcceleration or airAcceleration

        local isHoldingLeft = self:isHoldingLeftKey()
        local isHoldingRight = self:isHoldingRightKey()

        if isHoldingLeft and not isHoldingRight then
            self.rigidBody:addVelocityX(-acceleration)
        elseif isHoldingRight and not isHoldingLeft then
            self.rigidBody:addVelocityX(acceleration)
        end
    end

    -- Handle Vertical Movement

    if self.rigidBody:getIsTouchingGround() or CONFIG.INFINITE_JUMP then
        -- Handle jump start

        if self:didJumpStart() then
            spJump:play(1)

            self.rigidBody:setVelocityY(-jumpSpeed)

            jumpTimeLeftInTicks -= 1
        end
    elseif self:isHoldingJumpKey() and jumpTimeLeftInTicks > 0 then
        -- Handle Jump Hold

        self.rigidBody:setVelocityY(-jumpSpeed)

        jumpTimeLeftInTicks -= 1
    elseif pd.buttonJustReleased(KEYNAMES.A) or jumpTimeLeftInTicks > 0 then
        -- Handle Jump Release

        jumpTimeLeftInTicks = 0
    end
end

function Player:updateRigidBody()
    self.collisions = self.rigidBody:update()
end

function Player:updateCollisions()
    for _, collisionData in pairs(self.collisions) do
        local other = collisionData.other
        local tag = other:getTag()
        local normal = collisionData.normal

        -- Bottom activations
        if normal.y == -1 and (tag == TAGS.DrillableBlock or tag == TAGS.Elevator) then
            -- If colliding with bottom, activate
            table.insert(self.activationsBottom, other)
        end

        -- Other activations
        if tag == TAGS.SavePoint or tag == TAGS.Dialog or tag == TAGS.Ability then
            table.insert(self.activations, other)
        end

        -- Other (passive)
        if tag == TAGS.Powerwall then
            self.isTouchingPower = true
        end
    end
end

function Player:updateCheckpointState()
    local state = self.checkpointHandler:getStateCurrent()
    if state then
        -- Update the state directly. No need to push new

        state.x = self.x
        state.y = self.y
        state.blueprints = self.blueprints
    else
        if self.x ~= self.latestCheckpointPosition.x or self.y ~= self.latestCheckpointPosition.y then
            self.latestCheckpointPosition.x = self.x
            self.latestCheckpointPosition.y = self.y
            self.checkpointHandler:pushState({
                x = self.latestCheckpointPosition.x,
                y = self.latestCheckpointPosition.y,
                blueprints = table.deepcopy(self.blueprints)
            })
        end
    end
end

function Player:updateAnimationState()
    local animationState
    local velocity = self.rigidBody:getCurrentVelocity()
    local isMoving = math.floor(math.abs(velocity.dx)) > 0
    local isMovingActive = self:isHoldingRightKey() or self:isHoldingLeftKey()

    -- "Skip" states

    local shouldSkipStateCheck = self.states[self.currentState].nextAnimation == ANIMATION_STATES.Idle

    if not shouldSkipStateCheck then
        if self.rigidBody:getIsTouchingGround() then
            if self.isActivatingDrillableBlock and self:isHoldingDownKey() then
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
                animationState = ANIMATION_STATES.Moving
            else
                animationState = ANIMATION_STATES.Idle
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

function Player:updateGUIOverlap()
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
    return pd.buttonJustPressed(KEYNAMES.A) and self:isHoldingJumpKey()
end

-- Input Handlers

-- TODO: Replace implementation of button & blueprints check with blueprint check using button mask + playdate.getButtonState()
-- Replace didPressedInvalidKey with stateless check

function Player:isHoldingJumpKey()
    return self:isKeyPressedGated(KEYNAMES.A)
end

function Player:isHoldingRightKey()
    return self:isKeyPressedGated(KEYNAMES.Right)
end

function Player:isHoldingLeftKey()
    return self:isKeyPressedGated(KEYNAMES.Left)
end

function Player:isHoldingUpKey()
    return self:isKeyPressedGated(KEYNAMES.Up)
end

function Player:isHoldingDownKey()
    return self:isKeyPressedGated(KEYNAMES.Down)
end

function Player:justPressedInteractionKey()
    return playdate.buttonJustPressed(KEYNAMES.B)
end

-- Generic gated input handler

function Player:isKeyPressedGated(key)
    if self.isTouchingPower then
        return pd.buttonIsPressed(key)
    end

    for _, abilityName in ipairs(self.blueprints) do
        if abilityName == key then
            return pd.buttonIsPressed(abilityName)
        end
    end
    if pd.buttonJustPressed(key) then
        self.questionMark:play()
        screenShake(3, 1)

        self.didPressedInvalidKey = true

        spError:play(1)
    end
    return false
end
