import "player/crank"
import "player/questionMark"
import "player/particlesDrilling"

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

function Player:init(entity)
    _instance = self

    local imagetable = CONFIG.ADD_SUPER_DARKNESS_EFFECT and imagetablePlayerDarkness or imagetablePlayer
    Player.super.init(self, imagetable)

    entity.isOriginalPlayerSpawn = true

    -- AnimatedSprite states

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
    self.didPressedInvalidKey = false

    self:playAnimation()

    self:setTag(TAGS.Player)

    self.isDroppingItem = false
    self.isActivatingDrillableBlock = false
    self.isActivatingElevator = false

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

    -- Add child animation sprites

    self.crankWarpController = CrankWarpController()
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
end

function Player:remove()
    Player.super.remove(self)

    if self.crankWarpController then
        self.crankWarpController:remove()
    end
end

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

-- Collision Response

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
local activeDrillableBlock
local activeDialog

function Player:handleCollision(collisionData)
    local other = collisionData.other
    local tag = other:getTag()

    -- If Drilling
    if tag == TAGS.DrillableBlock and self:isMovingDown() and collisionData.normal.y == -1 then
        -- Play drilling sound
        if not spDrill:isPlaying() then
            spDrill:play(1)

            self.particlesDrilling:play(other.x, other.y)
        end

        self.isActivatingDrillableBlock = other
    end

    if tag == TAGS.Elevator then
        if collisionData.normal.y == -1 then
            other:setChild(self)

            local key
            if self:isMovingDown() then
                key = KEYNAMES.Down
            elseif self:isMovingUp() then
                key = KEYNAMES.Up
            elseif self:isMovingLeft() then
                key = KEYNAMES.Left
            elseif self:isMovingRight() then
                key = KEYNAMES.Right
            end

            if key then
                -- Elevator checks if it makes sense to activate
                local activationDistance = other:activate(self, key)

                if activationDistance and math.abs(activationDistance) ~= 0 then
                    -- If so, mark as activating elevator
                    self.isActivatingElevator = other
                end
            else
                self.elevator = other
            end
        end
    end

    if tag == TAGS.Ability then
        -- [FRANCH] This condition is useful in case there is more than one blueprint being picked up. However
        -- we should be handling the multiple blueprints as a single checkpoint.
        -- But it's also useful for debugging.

        if not timerCooldownCheckpoint then
            other:updateStatePickedUp()

            self:pickUpBlueprint(other.abilityName)
        end
    end

    if tag == TAGS.Dialog and not activeDialog then
        activeDialog = other
    end

    if tag == TAGS.SavePoint then
        other:activate()
    end
end

function Player:update()
    -- Sprite update

    Player.super.update(self)

    if self.isFrozen then
        return
    end

    -- Update question mark

    self.questionMark:update()

    -- Checkpoint Handling

    local hasWarped = self.crankWarpController:handleCrankChange()

    if hasWarped then
        self:revertCheckpoint()
    end

    -- Skip movement handling if timer cooldown is active

    if not self.crankWarpController:isActive() then
        -- Movement handling (update velocity X and Y)

        -- Velocity X

        if self.isActivatingElevator and self.isActivatingElevator:wasActivationSuccessful() then
            -- Skip horizontal movement
        elseif not self.isActivatingDrillableBlock then
            self:handleHorizontalMovement()
        end

        -- Velocity Y

        if self.rigidBody:getIsTouchingGround() or CONFIG.INFINITE_JUMP then
            local isJumpStart = self:handleJumpStart()

            if isJumpStart then
                -- Disable collisions with elevator for this frame to avoid
                -- jump / moving elevator up collisions glitch.
                if self.isActivatingElevator then
                    self.isActivatingElevator:disableCollisionsForFrame()
                elseif self.elevator then
                    self.elevator:disableCollisionsForFrame()
                end

                -- Cancel any digging if jumping
                if self.isActivatingDrillableBlock then
                    self.particlesDrilling:endAnimation()

                    self.isActivatingDrillableBlock = nil
                end
            end
        else
            self:handleJump()
        end

        -- Drilling

        if self.isActivatingDrillableBlock then
            -- Activate block drilling

            local isConsumed = self.isActivatingDrillableBlock:activate()

            if isConsumed then
                spDrill:stop()
                self.particlesDrilling:endAnimation()
            end

            -- Move player to Center on top of the drilled block

            local centerBlockX = self.isActivatingDrillableBlock.x + self.isActivatingDrillableBlock.width / 2

            self:moveTo(
                centerBlockX - self.width / 2,
                self.isActivatingDrillableBlock.y - self.height
            )

            if not isConsumed and playdate.buttonJustReleased(playdate.kButtonDown) then
                spDrill:stop()
                self.particlesDrilling:endAnimation()
            end
        end

        -- Record previous "is touching ground" for impact animation

        self.isTouchingGroundPrevious = self.rigidBody:getIsTouchingGround()

        -- Reset update variables before update

        self.isActivatingElevator = false
        self.isActivatingDrillableBlock = false
        self.elevator = false


        -- RigidBody update

        local collisions = self.rigidBody:update()

        for _, collision in pairs(collisions) do
            self:handleCollision(collision)
        end
    end

    -- B Button interaction

    if activeDialog then
        if self:isInteracting() and activeDialog:hasKey() then
            -- Get key
            self:pickUpBlueprint(activeDialog:getKey())
        end
    end

    -- Update dialog

    if activeDialog then
        activeDialog:activate()

        if self:isInteracting() then
            activeDialog:showNextLine()
        end

        -- Consume variable
        activeDialog = nil
    end

    -- Update state for checkpoint

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

    -- Animation Handling

    self:updateAnimationState()

    -- Reset animation unsure state trigger
    self.didPressedInvalidKey = false

    -- Update warp overlay

    if self.crankWarpController then
        self.crankWarpController:moveTo(self.x, self.y)
    end

    -- Check if player is in top-left of level (overlap with GUI)

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

    -- Check if player has moved into another level

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

-- Animation Handling

function Player:updateAnimationState()
    local animationState
    local velocity = self.rigidBody:getCurrentVelocity()
    local isMoving = math.floor(math.abs(velocity.dx)) > 0
    local isMovingActive = self:isMovingRight() or self:isMovingLeft()

    -- "Skip" states

    local shouldSkipStateCheck = self.states[self.currentState].nextAnimation == ANIMATION_STATES.Idle

    if not shouldSkipStateCheck then
        if self.rigidBody:getIsTouchingGround() then
            if self.isActivatingDrillableBlock then
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
            elseif isMoving and not self.isActivatingElevator then
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

-- Input Handlers --

function Player:handleCheckpoint()
    if self:justPressedCheckpoint() then
        self:revertCheckpoint()
    end
end

-- Jump

function Player:handleJumpStart()
    if pd.buttonJustPressed(KEYNAMES.A) and self:isJumping() then
        spJump:play(1)

        self.rigidBody:setVelocityY(-jumpSpeed)

        jumpTimeLeftInTicks -= 1

        return true
    end

    return false
end

function Player:handleJump()
    if self:isJumping() and jumpTimeLeftInTicks > 0 then
        -- Hold Jump

        self.rigidBody:setVelocityY(-jumpSpeed)

        jumpTimeLeftInTicks -= 1
    elseif pd.buttonJustReleased(KEYNAMES.A) or jumpTimeLeftInTicks > 0 then
        -- Released Jump

        jumpTimeLeftInTicks = 0
    end
end

-- Directional

function Player:handleHorizontalMovement()
    local acceleration = self.rigidBody:getIsTouchingGround() and groundAcceleration or airAcceleration
    if self:isMovingLeft() then
        self.rigidBody:addVelocityX(-acceleration)
    elseif self:isMovingRight() then
        self.rigidBody:addVelocityX(acceleration)
    end
end

-- Input Handlers

function Player:justPressedCheckpoint()
    -- No key gating on checkpoint
    return pd.buttonJustPressed(KEYNAMES.B)
end

function Player:isJumping()
    return self:isKeyPressedGated(KEYNAMES.A)
end

function Player:isMovingRight()
    return self:isKeyPressedGated(KEYNAMES.Right)
end

function Player:isMovingLeft()
    return self:isKeyPressedGated(KEYNAMES.Left)
end

function Player:isMovingUp()
    return self:isKeyPressedGated(KEYNAMES.Up)
end

function Player:isMovingDown()
    return self:isKeyPressedGated(KEYNAMES.Down)
end

function Player:isInteracting()
    return playdate.buttonJustPressed(KEYNAMES.B)
end

-- Generic gated input handler

local shouldSkipKeyGate = false
function Player:isKeyPressedGated(key)
    --debug
    if shouldSkipKeyGate then
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
