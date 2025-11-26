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

local VELOCITY_FALL_ANIMATION <const> = 6
local jumpSpeedDrilledBlock <const> = -14

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

    local imagetable = CONFIG.ADD_SUPER_DARKNESS_EFFECT and imagetablePlayerDarkness or imagetablePlayer

    Player.super.init(self, entityData, levelName, imagetable)

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
    self.activeDialog = false
    self.didPressedInvalidKey = false
    self.activations = {}
    self.activationsDown = {}
    self.activationsPrevious = {}

    -- Setup keys array and starting keys

    assert(entityData.fields.chipSet, "Error: no chipset was set!")

    Manager.emitEvent(EVENTS.ChipSetNew, entityData.fields.chipSet)

    -- Checkpoint config

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

    -- Workaround: Adjust player location by y = -5 (to avoid falling through the floor)
    self:moveBy(0, -5)

    -- Unlock warp ability
    Player:unlockAbility(ABILITIES.CrankToWarp)
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

    if self.isActivatingElevator then
        self.isActivatingElevator:freeze()
    end
end

function Player:unfreeze()
    self.isFrozen = false

    if self.isActivatingElevator then
        self.isActivatingElevator:unfreeze()
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
        self:moveTo(self.x, levelBounds.bottom - 32 - additionalBottomOffset)
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

    -- Activatable sprite interactions before collisions

    self.isActivatingElevator = false
    self.isActivatingDrillableBlock = false
    self.activeDialog = false

    Moveable.update(self)

    if self.isFrozen then
        return
    end

    -- Checkpoint Handling

    self:updateWarp()

    -- Bot / Interactions

    self:updateInteractions()

    -- Skip movement handling if:
    -- timer cooldown is active
    -- cooldown for warp is active

    if not warpCooldown and
        not (self.crankWarpController and self.crankWarpController:isActive()) and
        not playdate.buttonIsPressed(KEYNAMES.B)
    then
        --self:updateMovement()
    end

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

    if not self.evelatorSkipMovement then
        self.evelatorSkipMovement = {}
    end

    -- Encode horizontal direction into a bit (b01 or b10)
    local direction = self.didMoveLeft and 1 or self.didMoveRight and 2 or 0

    -- If movement previously failed in the direction of movement
    if self.spriteParent.didMoveSuccess == false or self.evelatorSkipMovement[self.spriteParent] and (self.evelatorSkipMovement[self.spriteParent] & direction ~= 0) then
        -- Set movement bit for elevator if nil
        if not self.evelatorSkipMovement[self.spriteParent] then
            self.evelatorSkipMovement = {
                [self.spriteParent] = 0
            }
        end

        -- Add direction for elevator movement
        self.evelatorSkipMovement[self.spriteParent] |= direction

        -- Skip parent update (child moves and parent does not)
        return
    end

    -- Reset movement bit for elevator if movement success / changed position
    if self.spriteParent.didMoveSuccess == true then
        self.evelatorSkipMovement = {
            [self.spriteParent] = 0
        }
    end

    -- Transfer movement to parent
    Moveable.updateParent(self)
end

function Player:updateActivations()
    ---@type Elevator?
    local elevatorParent = nil
    local drillableBlockActive = nil

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

                drillableBlockActive = self.particlesDrilling

                self.isActivatingDrillableBlock = otherSprite

                -- Activate block drilling

                otherSprite:activateDown()

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

        if tag == TAGS.Elevator then
            elevatorParent = otherSprite
        end

        ::continue::
    end

    -- Set elevator parent if exists
    self:setParent(elevatorParent)
    self.isActivatingElevator = elevatorParent

    for i, otherSprite in ipairs(self.activations) do
        local tag = otherSprite:getTag()

        if tag == TAGS.Chip then
            -- [FRANCH] This condition is useful in case there is more than one blueprint being picked up. However
            -- we should be handling the multiple blueprints as a single checkpoint.
            -- But it's also useful for debugging.

            if not warpCooldown then
                otherSprite:activate()
            end
        elseif tag == TAGS.Bot and not self.activeDialog then
            self.activeDialog = otherSprite

            self.activeDialog:activate()
        else
            otherSprite:activate()
        end
    end

    -- Cancel any digging if jumping or releasing dig key
    if self.isActivatingDrillableBlock and (self.didJump or pd.buttonJustReleased(pd.kButtonDown)) then
        self.particlesDrilling:endAnimation()

        self.isActivatingDrillableBlock = nil
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
        end
    end
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
        if self.crankWarpController.crankMomentum > 20 then
            animationState = ANIMATION_STATES.Falling
        elseif self.onGround then
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
