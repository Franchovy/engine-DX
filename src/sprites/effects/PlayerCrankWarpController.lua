local pd <const> = playdate
local gfx <const> = playdate.graphics

local spWarpAmbient <const> = assert(playdate.sound.sampleplayer.new(assets.sounds.warpAmbient))

local imageTableWarp <const> = assert(gfx.imagetable.new(assets.imageTables.warp))
local angleCrankToWarpTotal <const> = 300
local coefficientCrankResistance <const> = 0.3
local maxCrankResistanceStart <const> = 15
local maxCrankResistanceLoop <const> = 25
local ACTIVATED_INDEX <const> = 80

local animationStates = {
    start = "start",
    loop = "loop",
    finish = "finish",
    none = "none"
}

--- Indexes in the `totalCrankAngleToWarp` imagetable. Imagetable
--- works in inverse order, starting at the end and working back to the start.
--- @type {number:number}
local indexesImageTableWarp = {
    [animationStates.none] = 99,
    [animationStates.start] = 91,
    [animationStates.loop] = 60,
    [animationStates.finish] = 30,
}

local function setState(self, state)
    self.index = indexesImageTableWarp[state]
    self.state = state
end

---@class CrankWarpController: _Sprite
PlayerCrankWarpController = Class("PlayerCrankWarpController", gfx.sprite)

function PlayerCrankWarpController:init()
    PlayerCrankWarpController.super.init(self, imageTableWarp[1])

    self:setScale(2)
    self:add()
    self:setZIndex(Z_INDEX.Level.Overlay)

    self.state = animationStates.none
    self.index = indexesImageTableWarp[animationStates.start]
    self.crankMomentum = 0
    self.isLoopingMode = false
end

function PlayerCrankWarpController:remove()
    PlayerCrankWarpController.super.remove(self)

    spWarpAmbient:stop()
end

function PlayerCrankWarpController:isActive()
    return self.state == animationStates.loop
end

function PlayerCrankWarpController:update()
    local crankChange = self.crankChange

    if not crankChange then
        return
    end

    local crankDirection = (crankChange > 0.1 and 1) or (crankChange < -0.1 and -1) or 0
    local crankChangeAbsolute = math.abs(crankChange)

    -- If crank has not started yet, then set crank direction.
    if self.state == animationStates.none and math.abs(self.crankMomentum) < 1 then
        self.crankDirection = crankDirection
    end

    if self.crankDirection == 0 then
        return
    end

    if self.isLoopingMode and self.state == animationStates.loop then
        -- In looping mode, we keep crank momentum constant

        self.crankMomentum = 90
    elseif self.state ~= animationStates.finish then
        -- Increment totalCrankAngleToWarp

        if self.crankDirection ~= crankDirection then
            self.crankMomentum -= crankChangeAbsolute
        else
            self.crankMomentum += crankChangeAbsolute
        end

        -- If in state start, apply resistance backwards.
        local resistanceCrankMomentum = (self.crankMomentum) * coefficientCrankResistance
        local maxCrankResistance = self.state == animationStates.start and maxCrankResistanceStart or
            maxCrankResistanceLoop
        self.crankMomentum = math.max(0, self.crankMomentum - math.min(resistanceCrankMomentum, maxCrankResistance))
    end

    local previousState = self.state

    if self.state == animationStates.none and self.crankMomentum > 15 then
        self.state = animationStates.start
    elseif self.state == animationStates.start then
        -- Update index
        self.index = indexesImageTableWarp[animationStates.start] -
            math.floor(self.crankMomentum / angleCrankToWarpTotal * 30)

        if self.index <= indexesImageTableWarp[animationStates.loop] then
            -- Transition to loop state
            setState(self, animationStates.loop)

            -- Reset momentum - ensure the player is cranking
            self.crankMomentum = 0
        elseif self.crankMomentum < 1 then
            -- Reset
            setState(self, animationStates.none)

            self.crankMomentum = 0
        end
    elseif self.state == animationStates.loop then
        self.index -= 1

        if self.index <= indexesImageTableWarp[animationStates.finish] then
            -- Transition to next state

            -- If crank momentum is high enough, loop again.
            if self.crankMomentum > 60 then
                setState(self, animationStates.loop)

                -- Reset momentum - ensures the player is still cranking
                self.crankMomentum = 0
            else
                setState(self, animationStates.finish)

                self.crankMomentum = 60
            end
        end
    elseif self.state == animationStates.finish then
        self.index -= 1

        -- Fade out crank momentum
        self.crankMomentum -= 2.2

        if self.index <= 0 then
            setState(self, animationStates.none)

            self.crankMomentum = 0
        end
    end

    self:updateImage()

    -- Update audio according to state

    local volume = math.min(self.crankMomentum / 60, 1)

    if self.state ~= animationStates.loop then
        -- Don't set volume while in loop (the crank momentum gets set to 0)
        spWarpAmbient:setVolume(volume)
    end

    if not spWarpAmbient:isPlaying() and self.state == animationStates.start then
        spWarpAmbient:play(0)
    elseif self.state == animationStates.finish and previousState == animationStates.loop then
        --
    elseif self.state == animationStates.none and spWarpAmbient:isPlaying() then
        spWarpAmbient:stop()
    end

    -- Return whether a warp has happened

    self.didTrigger = self.index == indexesImageTableWarp[animationStates.loop]
end

function PlayerCrankWarpController:addCrankMovement(crankChange)
    self.crankChange = crankChange
end

function PlayerCrankWarpController:getDirection()
    return self.crankDirection
end

function PlayerCrankWarpController:hasTriggered()
    return self.didTrigger
end

function PlayerCrankWarpController:isActivated()
    return self.index < ACTIVATED_INDEX
end

function PlayerCrankWarpController:reset()
    self.didTrigger = false
end

function PlayerCrankWarpController:updateImage()
    self:setImage(imageTableWarp[self.index])
end

function PlayerCrankWarpController:setIsLooping()
    self.isLoopingMode = true
end

function PlayerCrankWarpController:getCrankMomentum()
    return self.crankMomentum
end
