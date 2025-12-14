local pd <const> = playdate
local sound <const> = pd.sound
local gmt <const> = pd.geometry
local gfx <const> = pd.graphics

local imagetablePlayer <const> = assert(gfx.imagetable.new(assets.imageTables.player))

local spJump <const> = assert(sound.sampleplayer.new(assets.sounds.jump))
local spError <const> = assert(sound.sampleplayer.new(assets.sounds.errorAction))
local spDrill <const> = assert(sound.sampleplayer.new(assets.sounds.drill))

-- Level Bounds for camera movement (X,Y coords areas in global (world) coordinates)

local levelBounds

-- Timer for handling cooldown on checkpoint revert

local warpCooldown

-- Boolean to keep overlapping with GUI state

local isOverlappingWithGUI = false

-- Crank variables

local crankThreshold = 30
local crankWatch = CrankWatch("player", crankThreshold)
local crankValue = 0
local crankIncrememntAdditionalThreshold = 30
local crankValueDecreaseCoefficient = 0.45
local trimCollisionRectWidth, trimCollisionRectTop = 6, 8

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

local VELOCITY_FALL_ANIMATION <const> = 6
local jumpSpeedDrilledBlock <const> = -14
local preBreakJumpTicks <const> = 6

-- Setup

--- @class Player : EntityAnimated, Moveable
Player = Class("Player", EntityAnimated)

Player:implements(Moveable)

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
    -- return not Player.getInstance()

    -- Return true, following should be a savepoint
    return true
end

-----------------------
-- LIFECYCLE METHODS --
-----------------------

function Player:init(entityData, levelName, ...)
    -- If Instance exists, then create a savepoint instead.
    if _instance then
        return SavePoint(entityData, levelName, ...)
    end

    _instance = self

    Player.super.init(self, entityData, levelName, imagetablePlayer)

    Moveable.init(self, {
        gravity = 8,
        movement = {
            air = {
                acceleration = 0.9,
                friction = -0.00035
            },
            ground = {
                acceleration = 3.5,
                friction = -0.8
            }
        },
        jump = {
            speed = 27,
            doubleJump = true,
            coyoteFrames = 5
        },
        dash = {
            frames = 4,
            speed = 27
        }
    })

    -- Set original spawn property on LDtk data

    entityData.isOriginalPlayerSpawn = true

    -- AnimatedSprite states

    self:setupAnimationStates()

    -- Collisions

    self:setGroups(GROUPS.Player)
    self:setCollidesWithGroups({ GROUPS.Solid, GROUPS.SolidExceptElevator, GROUPS.ActivatePlayer })
    self:setTag(TAGS.Player)

    -- "Sub-States"

    ---@type Bot|false
    self.activeBot = false
    self.didPressedInvalidKey = false
    self.activations = {}
    self.activationsDown = {}
    self.activationsPrevious = {}

    -- Setup keys array and starting keys

    assert(entityData.fields.chipSet, "Error: no chipset was set!")

    Manager.emitEvent(EVENTS.ChipSetNew, entityData.fields.chipSet)

    -- Checkpoint config

    self.latestCheckpointPosition = gmt.point.new(self.x, self.y)

    -- Create child sprites

    self.questionMark = PlayerQuestionMark(self)
    self.particlesDrilling = PlayerParticlesDrilling(self)

    self.particlesWarp = ParticleCircle()
    self.particlesWarp:setMode(Particles.modes.DISAPPEAR)
    self.particlesWarp:setSize(1, 1)
    self.particlesWarp:setThickness(1, 2)
    self.particlesWarp:setSpeed(5, 10)
    self.particlesWarp:setLifespan(3, 10)
    self.particlesWarp:setColor(1)

    -- Utils

    self.synth = Synth(SCALES.PLAYER)

    -- Reduce hitbox sizes

    self:setCollideRect(trimCollisionRectWidth, trimCollisionRectTop, self.width - trimCollisionRectWidth * 2,
        self.height - trimCollisionRectTop)

    -- Add Checkpoint handling

    self.checkpointHandler = CheckpointHandler.getOrCreate(self.id, self)

    -- Workaround: Adjust player location by y = -5 (to avoid falling through the floor)
    self:moveBy(0, -5)
end

function Player:collisionResponse(other)
    if other:hasGroup(GROUPS.Solid) or other:hasGroup(GROUPS.SolidExceptElevator) then
        return gfx.sprite.kCollisionTypeSlide
    else
        return gfx.sprite.kCollisionTypeOverlap
    end
end

function Player:add()
    Player.super.add(self)

    if self.isActivatingDrillableBlock and self.particlesDrilling then
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

    if self.spriteParent and self.spriteParent:getTag() == TAGS.Elevator then
        local spriteParent = self.spriteParent

        ---@cast spriteParent Elevator
        spriteParent:freeze()
    end
end

function Player:unfreeze()
    self.isFrozen = false

    if self.spriteParent and self.spriteParent:getTag() == TAGS.Elevator then
        local spriteParent = self.spriteParent

        ---@cast spriteParent Elevator
        spriteParent:unfreeze()
    end

    -- Perform refresh on activations / update variables

    self.didPressedInvalidKey = false
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

    local offsetX, offsetY = 0, 0

    if direction == DIRECTION.RIGHT then
        offsetX = 15
    elseif direction == DIRECTION.LEFT then
        offsetX = -15
    elseif direction == DIRECTION.BOTTOM then
        offsetY = 15
    elseif direction == DIRECTION.TOP then
        -- Additional movement when jumping into bottom of level for reaching bottom tile
        -- ... except if moving up with elevator.

        offsetY = -32
    end

    self:moveBy(offsetX, offsetY)

    -- Bring any parents with player (for elevator)

    if self.spriteParent and self.spriteParent:getTag() == TAGS.Elevator then
        local spriteParent = self.spriteParent
        ---@cast spriteParent Elevator
        spriteParent:moveBy(offsetX, offsetY)

        spriteParent:enterLevel(levelName, direction)
    end

    -- Push level position
    self.checkpointHandler:pushState({
        x = self.x,
        y = self.y,
    })
end

--------------------
-- PRIVATE METHODS --
--------------------

function Player:revertCheckpoint()
    -- Emit the event for the rest of the scene

    Manager.emitEvent(EVENTS.CheckpointRevert)

    -- Reset Moveable velocities

    self:setVelocityX(0)
    self:setVelocityY(0)
end

function Player:animateInvalidKey()
    self.questionMark:play()
    ScreenShake.performScreenShake(3, 1)

    self.didPressedInvalidKey = true

    spError:play(1)
end

---comment
---@return Elevator?
function Player:getElevatorActivating()
    if self.isActivatingElevator then
        return self.isActivatingElevator
    end
end

function Player:getIsDoubleJumpEnabled()
    local chipSet = GUIChipSet.getInstance()
    if not chipSet then return end

    return chipSet:hasDoubleKey(KEYNAMES.A)
end

function Player:getIsDashEnabled(direction)
    local chipSet = GUIChipSet.getInstance()
    if not chipSet then return end

    if direction == playdate.kButtonLeft then
        return chipSet:hasDoubleKey(KEYNAMES.Left)
    elseif direction == playdate.kButtonRight then
        return chipSet:hasDoubleKey(KEYNAMES.Right)
    end
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

    if not crankWatch:getDidPassThreshold() then
        Moveable.update(self)
    end

    -- Checkpoint Handling

    self:updateWarp()

    -- Update variables set by collisions

    self.didPressedInvalidKey = false

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

function Player:updateParent()
    if not self.spriteParent then return end

    if self.spriteParent.class == Elevator then
        local elevator = self.spriteParent

        local orientation = ((self.didMoveLeft or self.didMoveRight) and ORIENTATION.Horizontal) or
            ((self.didMoveUp or self.didMoveDown) and ORIENTATION.Vertical)

        ---@cast elevator Elevator
        if orientation and elevator:getDirectionsAvailable()[orientation] then
            -- Check-ahead on the left, right, up or down of the elevator to see if there's an overlapping sprite

            local sprites

            if self.didMoveLeft then
                local x = elevator:left() - 1

                sprites = gfx.sprite.querySpritesAlongLine(x, elevator:top(), x, elevator:bottom())
            elseif self.didMoveRight then
                local x = elevator:right() + 1

                sprites = gfx.sprite.querySpritesAlongLine(x, elevator:top(), x, elevator:bottom())
            elseif self.didMoveUp then
                local y = elevator:top() - 1

                sprites = gfx.sprite.querySpritesAlongLine(elevator:left() + 1, y, elevator:right() - 1, y)
            elseif self.didMoveDown then
                local y = elevator:bottom() + 1

                sprites = gfx.sprite.querySpritesAlongLine(elevator:left(), y, elevator:right(), y)
            end

            for _, sprite in pairs(sprites) do
                -- Check for collision
                if sprite ~= elevator and sprite:hasGroup(GROUPS.Solid) then
                    return
                end
            end

            local track = elevator:getTrackForDirection(orientation)

            if self.didMoveRight and track:right() - 8 < elevator:centerX() then
                return
            elseif self.didMoveLeft and track:left() + 8 > elevator:centerX() then
                return
            end
        else
            -- Elevator not able to move in this direction. Cancel passing update to parent
            return
        end
    end

    -- Transfer movement to parent
    Moveable.updateParent(self)
end

function Player:updateActivations()
    ---@type Elevator?
    local elevatorParent = nil
    ---@type DrillableBlock?
    local drillableBlockActive = nil
    ---@type Bot?
    local botActive = nil

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

                drillableBlockActive = otherSprite

                -- Activate block drilling

                otherSprite:activateDown(self)

                -- If consumed or player stopped pressing, end animation.
                if otherSprite:isConsumed() then
                    spDrill:stop()

                    self.particlesDrilling:endAnimation()

                    self:setVelocityY(jumpSpeedDrilledBlock)
                else
                    -- Move particles to same location

                    self.particlesDrilling:moveTo(self:centerX(), self:bottom())
                end
            end

            -- Handle releasing the down key
            if pd.buttonJustReleased(pd.kButtonDown) then
                spDrill:stop()

                self.particlesDrilling:endAnimation()
            end
        end

        if tag == TAGS.Elevator and isBelowCenter then
            ---@cast otherSprite Elevator
            elevatorParent = otherSprite

            -- If elevator direction is horizontal and player edges are within edges of elevator, then don't force move.

            elevatorParent.forceMoveWithoutChild = self:left() + trimCollisionRectWidth < elevatorParent:left() or
                self:right() - trimCollisionRectWidth > elevatorParent:right()
        end

        ::continue::
    end

    -- Set elevator parent if exists
    self:setParent(elevatorParent)
    self.isActivatingElevator = elevatorParent

    -- Perform "Jump check" on drillable block BEFORE updating isActivatingDrillableBlock reference

    if self.isActivatingDrillableBlock then
        ---@type DrillableBlock
        local drillableBlock = self.isActivatingDrillableBlock

        if self.didJump and drillableBlock:getTicksToDrillLeft() <= preBreakJumpTicks then
            -- Consume block (early break with jump)
            drillableBlock:consume()
            self.particlesDrilling:playEndAnimation()
        elseif self.didJump or pd.buttonJustReleased(pd.kButtonDown) then
            -- Cancel any digging if jumping or releasing dig key
            self.particlesDrilling:endAnimation()

            drillableBlockActive = nil
        end
    end

    self.isActivatingDrillableBlock = drillableBlockActive

    for i, otherSprite in ipairs(self.activations) do
        local tag = otherSprite:getTag()

        if tag == TAGS.Chip then
            -- [FRANCH] This condition is useful in case there is more than one blueprint being picked up. However
            -- we should be handling the multiple blueprints as a single checkpoint.
            -- But it's also useful for debugging.

            if not warpCooldown then
                otherSprite:activate(self)
            end
        elseif tag == TAGS.Bot then
            botActive = otherSprite.spriteParent

            botActive:activate(self)
        else
            otherSprite:activate(self)
        end
    end

    self.activeBot = botActive
end

function Player:updateWarp()
    -- Update warp particles to originate at player pos

    self.particlesWarp:moveTo(self.x, self.y)

    local timeCoefficient = 1

    -- Revert checkpoint if crank change is larger than threshold

    if crankWatch:getDidPassThreshold() then
        crankValue += playdate.getCrankChange()
        local warpCount = 1 + math.floor((crankValue - crankThreshold) / crankIncrememntAdditionalThreshold)

        for i = 1, warpCount do
            self:revertCheckpoint()
        end

        self.particlesWarp:add(2)
        timeCoefficient = 0

        warpCooldown = playdate.frameTimer.new(3, function(timer)
            if timer == warpCooldown then
                warpCooldown = nil
            end
        end)
    else
        timeCoefficient = crankWatch:getThresholdProportion()
    end

    crankValue = crankValue * crankValueDecreaseCoefficient

    -- How fast game time should move based on crank speed

    Moveable.setTimeCoefficient(timeCoefficient)
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
    local velocity = self:getCurrentVelocity()
    local isMoving = math.floor(math.abs(velocity.dx)) > 0
    local isMovingActive = self:isHoldingRightKeyGated() or self:isHoldingLeftKeyGated()

    -- "Skip" states

    local shouldSkipStateCheck = self.states[self.currentState].nextAnimation == ANIMATION_STATES.Idle

    if not shouldSkipStateCheck then
        if self.onGround then
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
            elseif not self.onGroundPrevious then
                if isMoving and isMovingActive then
                    -- Moving Impact
                    animationState = ANIMATION_STATES.ImpactRun
                else
                    -- Static Impact
                    animationState = ANIMATION_STATES.Impact
                end
            elseif isMoving and not (self.spriteChild and self.spriteChild:getTag() == TAGS.Elevator and self.spriteChild.didMoveSuccess) then
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

-- Generic gated input handler

function Player:isKeyPressedGated(key)
    if not pd.buttonIsPressed(key) then
        -- Button is not pressed.
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

function Player.__debugModifyCrankValue(value)
    crankValue = value
end

function Player.__getCrankThreshold()
    return crankThreshold
end

function Player.__getCrankThresholdIncrementAdditional()
    return crankIncrememntAdditionalThreshold
end
