local gfx <const> = playdate.graphics
local geo <const> = playdate.geometry

-- Globally defined enum

BOT_ANIMATION_STATES = {
    Idle = 'idle',
    Talking = 'talking',
    Happy = 'happy',
    Sad = 'sad',
}

local DIALOG_STATES = {
    Unopened = 'unopened',
    Expanded = 'expanded',
    Finished = 'finished'
}

-- Local Variables

-- Assets

local nineSliceSpeech <const> = assert(gfx.nineSlice.new(assets.images.speech, 7, 7, 17, 17))
local spCollect <const> = assert(playdate.sound.sampleplayer.new(assets.sounds.collect))
local imageIndicatorRescue <const> = assert(gfx.image.new(assets.images.indicatorBotRescue))
local imageIndicatorRescueBlank <const> = assert(gfx.image.new(imageIndicatorRescue.width, imageIndicatorRescue.height,
    gfx.kColorClear))

-- Constants

local textMarginX <const> = 10
local distanceAboveSprite <const> = 6
local durationDialog <const> = 2000
local collideRectSize <const> = 64
local distanceMinNextNode <const> = 24
local distanceMinFinalNode <const> = 5
local dialogMargin <const> = 5

--- Update method for the dialog bubble, to position itself in view
local function _dialogUpdate(self)
    self.super.update(self)

    local offsetX, offsetY = gfx.getDrawOffset()
    local x, y = self.x, self.y
    local width, height = self.width, self.height

    if self:left() < -offsetX + dialogMargin then
        x = -offsetX + dialogMargin + width / 2
    elseif self:right() > -offsetX + 400 - dialogMargin * 2 then
        x = -offsetX + 400 - dialogMargin * 2 - width / 2
    end

    if self:top() < -offsetY + dialogMargin then
        y = -offsetY + dialogMargin - self:centerOffsetY()
    elseif self:bottom() > -offsetY + 240 - dialogMargin * 2 then
        y = -offsetY + 240 - dialogMargin * 2 - height / 2
    end

    self:moveTo(x, y)
end

---@alias DialogLine fun():boolean

---@class Bot: EntityAnimated, Moveable, ParentSprite
---@property timer _Timer|nil
---@property config BotConfig
---@property lines DialogLine[]
Bot = Class("Bot", EntityAnimated)

Bot:implements(Moveable)
Bot:implements(ParentSprite)

function Bot:init(entityData, levelName)
    Moveable.init(self, {
        gravity = 6,
        movement = {
            air = {
                acceleration = 0.5,
                friction = -0.0008
            },
            ground = {
                acceleration = 2,
                friction = -0.5
            }
        },
        jump = {
            speed = 30,
            coyoteFrames = 6
        }
    })

    -- Load bot using asset, set default asset if empty

    entityData.fields.asset = entityData.fields.asset or "RUD"

    -- Grab the imagetable corresponding to this sprite
    local imagetable = assert(gfx.imagetable.new(assets.imageTables.bots[entityData.fields.asset]),
        "No bot asset found matching: " .. entityData.fields.asset)

    -- Super init call

    Bot.super.init(self, entityData, levelName, imagetable)

    -- Bot config

    self.config = BotConfig[entityData.fields.asset]

    if self.config then
        -- Add animation states

        for name, frames in pairs(self.config.animations) do
            local state = self:addState(name, frames[1], frames[2], { tickStep = self.config.animationSpeed or 2 })

            if name == BOT_ANIMATION_STATES.Idle then
                state.asDefault()
            end
        end

        -- Offset sprite position by "offset".
        if self.config.offset then
            local x, y = self.config.offset.x or 0, self.config.offset.y or 0
            self:moveBy(x, y)
        end
    end

    self:updateAnimationState()

    self:playAnimation()

    -- Utils

    self:setupVoiceSynth()

    -- Collision config

    self:setCollideRect(4, 4, self.width - 8, self.height - 4)
    self:setCollidesWithGroups({ GROUPS.Solid, GROUPS.SolidExceptElevator, GROUPS.ActivateBot })
    self:setTag(TAGS.Bot)

    -- Create activateable collision field

    self.collisionField = gfx.sprite.new()
    self.collisionField:setSize(collideRectSize, collideRectSize)
    self.collisionField:setCollideRect(0, 0, collideRectSize, collideRectSize)
    self.collisionField:setGroups(GROUPS.ActivatePlayer)
    self.collisionField:moveTo(self.x, self.y)
    self.collisionField:setTag(TAGS.Bot)
    self.collisionField:add()

    self.collisionField.activate = function() self.activate(self) end

    self:addChild(self.collisionField)

    -- Set whether is "rescuable"

    self.isRescuable = entityData.fields.saveNumber ~= nil
    self.rescueNumber = entityData.fields.saveNumber
    self.isRescued = entityData.fields.isRescued or false

    if self.isRescuable and not self.isRescued then
        self.spriteRescueIndicator = gfx.sprite.new(imageIndicatorRescue)
        self.spriteRescueIndicator:setZIndex(Z_INDEX.Level.Active)
        self.spriteRescueIndicator:setCenter(0.5, 2)
        self.spriteRescueIndicator:moveTo(self.x, self.y)

        self:addChild(self.spriteRescueIndicator)
        self.spriteRescueIndicator:add()

        self.blinkerSpriteRescueIndicator = gfx.animation.blinker.new(400, 200, true)
        self.blinkerSpriteRescueIndicator:startLoop()
    end

    -- Break up text into lines

    self:setupDialogLines(entityData.fields.text)

    -- Bot variables

    self.dialogState = DIALOG_STATES.Unopened
    self.repeatLine = self.fields.repeatLine
    self.currentLine = self.fields.currentLine

    -- "Part" setup

    self.part = self.fields.part or 1

    -- Variables to be consumed in update

    self.isActivated = false

    -- Timer placeholder

    ---@type _Timer|nil
    self.timer = nil

    -- Set flip value

    self:setFlip(self.fields.flip or false)

    -- Config additional init call

    if self.config.init then
        self.config.init(self)
    end
end

---comment
---@param other _Sprite
function Bot:collisionResponse(other)
    if other:hasGroup(GROUPS.Solid) or other:hasGroup(GROUPS.SolidExceptElevator) then
        return gfx.sprite.kCollisionTypeSlide
    end

    return gfx.sprite.kCollisionTypeOverlap
end

function Bot:add()
    Bot.super.add(self)
    ParentSprite.add(self)

    GUILightingEffect:getInstance():addEffect(self, GUILightingEffect.imageSmallCircle)
end

function Bot:remove()
    Bot.super.remove(self)
    ParentSprite.remove(self)

    GUILightingEffect:getInstance():removeEffect(self)
end

function Bot:changeState(stateNew)
    -- Get state if available, fallback on Idle
    local stateNewActual = self.config.animations[stateNew] and stateNew or
        BOT_ANIMATION_STATES.Idle

    Bot.super.changeState(self, stateNewActual)
end

function Bot:setPart(part)
    self.part = part
    self.fields.part = self.part
end

function Bot:moveWithCollisions(destX, destY)
    return ParentSprite.moveWithCollisions(self, destX, destY)
end

function Bot:moveTo(destX, destY)
    return ParentSprite.moveTo(self, destX, destY)
end

function Bot:moveBy(x, y)
    return ParentSprite.moveBy(self, x, y)
end

function Bot:setupDialogLines(rawText)
    -- Initialize empty dialog array
    self.lines = {}

    -- If no text is provided, simply return.
    if not rawText then
        return
    end

    -- Condition, if used, is repeated for every line until changed.
    ---@type (fun(): boolean)?
    local condition
    ---@type fun()?
    local props

    for lineRaw in string.gmatch(rawText, "([^\n]+)") do
        local action

        if string.match(lineRaw, "^%$") then
            -- Parse bot condition

            condition = self:parseCondition(lineRaw)
        elseif string.match(lineRaw, "^%{") then
            -- Props / Dynamic Properties to apply

            local _, data = pcall(json.decode, lineRaw)

            props = function()
                self:executeProps(data)
            end
        elseif string.match(lineRaw, "^%:") then
            -- Actions
            if string.match(lineRaw, "^%:walkTo%:") then
                local props = props
                local condition = condition

                -- Walk-to action
                local numberOrName = string.match(lineRaw, "^%:walkTo%:.+(%w+)$")
                local targetPoint = numberOrName and self:getDestinationPoint(numberOrName)

                if targetPoint then
                    action = function()
                        -- Check condition
                        if condition and not condition() then
                            return false
                        end

                        -- Execute props if any
                        if props then
                            props()
                        end

                        self.walkDestination = targetPoint

                        self:closeDialogSprite()
                        self.dialogState = DIALOG_STATES.Finished

                        return true
                    end
                end
            end
        else
            local _, data = pcall(json.decode, lineRaw)
            local props = props
            local condition = condition

            action = function()
                -- Check condition
                if condition and not condition() then
                    return false
                end

                -- Execute props if any
                if props then
                    props()
                end

                -- Show dialog line
                self:addDialogSprite(lineRaw)

                -- Play dialog sound
                self:playDialogSound()

                return true
            end
        end

        if action then
            table.insert(self.lines, action)

            -- Clear props if any
            if props then
                props = nil
            end
        end
    end
end

function Bot:setupVoiceSynth()
    local voice
    local bleepsPerSecond

    if self.config.voice then
        voice = SCALES[self.config.voice]
    else
        local num = math.random(3)
        local voices = {
            SCALES.BOT_LOW,
            SCALES.BOT_MEDIUM,
            SCALES.BOT_HIGH,
        }
        voice = voices[num]
    end

    if self.config.voiceBPS then
        bleepsPerSecond = self.config.voiceBPS
    else
        bleepsPerSecond = 6 + math.random(3)
    end

    self.synth = Synth(
        voice, bleepsPerSecond)
end

function Bot:setFlip(shouldFlip)
    self.globalFlip = shouldFlip and 1 or 0
end

--- Called from the player class on collide.
function Bot:activate()
    self.isActivated = true

    if self.isRescuable and not self.isRescued then
        self:setRescued()
    end
end

function Bot:onBButtonPress()
    if self.dialogState == DIALOG_STATES.Expanded then
        self:getNextLine()
    end
end

function Bot:getNextLine(currentLine)
    if #self.lines == 0 then
        return
    end

    ---@type integer?
    local currentLine = currentLine or self.currentLine
    if currentLine == nil then
        -- First line index
        currentLine = self.repeatLine or 1
    elseif currentLine <= #self.lines then
        -- Next line index
        currentLine += 1
    else
        -- No more lines, set nil
        currentLine = nil
    end

    local line = self.lines[currentLine]
    if line then
        local success = line()

        -- Check condition; if failed then move onto next line.
        if not success then
            self:getNextLine(currentLine)
        else
            -- Set current line
            self.currentLine = currentLine
            self.fields.currentLine = self.currentLine
        end
    else
        -- Close dialog
        self:closeDialogSprite()

        self.currentLine = nil
        self.fields.currentLine = self.currentLine
        self.dialogState = DIALOG_STATES.Finished
    end
end

function Bot:setRescued()
    if not self.isRescued and self.isRescuable then
        local indexSfx = math.random(1, #assets.sounds.robotSave)
        local spRescue = playdate.sound.sampleplayer.new(assets.sounds.robotSave[indexSfx])
        spRescue:play(1)

        -- Send message that has been rescued
        self.isRescued = true
        self.fields.isRescued = true

        -- Clear rescue indicator

        self.blinkerSpriteRescueIndicator:stop()
        self.spriteRescueIndicator:remove()
        self.spriteRescueIndicator:setImage(imageIndicatorRescue)
        self:removeChild(self.spriteRescueIndicator)

        Manager.emitEvent(EVENTS.BotRescued, self, self.rescueNumber)
    end
end

function Bot:getIsRescuable()
    return self.isRescuable
end

function Bot:freeze()
    self.isFrozen = true
end

function Bot:unfreeze()
    self.isFrozen = false
end

function Bot:enterLevel(targetLevel)
    Bot.super.enterLevel(self, targetLevel)

    if self.isActivated then
        self.currentLine -= 1
        self:closeDialogSprite()
        self.isActivated = false
    end
end

function Bot:update()
    if self.isFrozen then
        return
    end

    Bot.super.update(self)

    if self.walkDestination then
        Moveable.update(self)

        -- Move Bot
        self:updateMoveToNextPoint()
    else
        -- Update dialog

        if self.isActivated and self.dialogState == DIALOG_STATES.Unopened then
            -- Show next dialog line

            self:getNextLine()
        elseif self.isActivated and self.dialogState == DIALOG_STATES.Expanded then
            -- Continue dialog
        elseif not self.isActivated then
            -- No longer activated, close dialog

            self:closeDialogSprite()

            self.dialogState = DIALOG_STATES.Unopened
        end
    end

    local performanceMode = Settings.get(SETTINGS.PerformanceMode)

    if not performanceMode then
        if self.collisions and #self.collisions > 0 then
            for i, collision in pairs(self.collisions) do
                if collision.other.activate then
                    collision.other:activate(self)
                end
            end
        end
    end

    if self.dialogSprite then
        self.dialogSprite:add()
        self.dialogSprite:moveTo(self.x, self.y)
    end

    -- Reset update variable

    self.isActivated = self.continueTalking or false

    -- Blinker / rescue indicator

    if self.isRescuable and not self.isRescued then
        if self.blinkerSpriteRescueIndicator.on then
            self.spriteRescueIndicator:setImage(imageIndicatorRescue)
        else
            self.spriteRescueIndicator:setImage(imageIndicatorRescueBlank)
        end
    end

    -- Animation state

    self:updateAnimationState()

    -- Crank Indicator

    if self.dialogState == DIALOG_STATES.Expanded and not self.isRescued and self.showCrankIndicator then
        _G.showCrankIndicator = true
    else
        _G.showCrankIndicator = false
    end

    -- Custom update callback for this sprite

    if self.config.update then
        self.config.update(self)
    end
end

function Bot:updateMoveToNextPoint()
    if not self.walkDestination then
        return
    end

    local targetPoint = self.walkDestination
    local distanceToNextNode = self.pathNodes and #self.pathNodes > 0 and #self.pathNodes > 1 and distanceMinNextNode or
        distanceMinFinalNode

    -- Check if at target point
    if math.abs(self.x - targetPoint.x) < distanceMinFinalNode and math.abs(self.y - targetPoint.y) < distanceMinFinalNode then
        -- If arrived, reset walk path
        self.walkDestination = nil
        self.pathNodes = nil
        self.nextPoint = nil

        -- Trigger next line by resetting vars

        self.dialogState = DIALOG_STATES.Unopened

        return
    elseif self.nextPoint and (math.abs(self.x - self.nextPoint.x) < distanceMinNextNode and math.abs(self.y - self.nextPoint.y) < distanceMinNextNode) then
        self.nextPoint = nil
    elseif not self.nextPoint then
        -- Get path to target point
        if not self.pathNodes then
            local pathNodes = LDTkPathFinding.getPath(Game.getLevelName(), self:centerX(), self:centerY(), targetPoint.x,
                targetPoint.y)

            if not pathNodes or #pathNodes == 0 then
                -- No path returned, interrupt movement
                self.walkDestination = nil
                return
            end

            self.pathNodes = pathNodes
        end

        local xMovement, yMovement

        if #self.pathNodes > 0 then
            repeat
                self.nextPoint = self.pathNodes[1]
                xMovement, yMovement = self.nextPoint.x - self.x, self.nextPoint.y - self.y
                if not (math.abs(xMovement) > distanceMinNextNode or math.abs(yMovement) > distanceMinNextNode) then
                    table.remove(self.pathNodes, 1)
                end
            until math.abs(xMovement) > distanceMinNextNode or math.abs(yMovement) > distanceMinNextNode or #self.pathNodes == 0
        end
    end

    -- Move to next point on path

    if self.nextPoint then
        local xMovement, yMovement = self.nextPoint.x - self.x, self.nextPoint.y - self.y

        if yMovement < 0 and math.abs(xMovement) < 33 then
            -- Jump and move left/right
            self:jump()
        end

        if xMovement > 0 then
            self:moveRight()
            self:setFlip(false)
        elseif xMovement < 0 then
            self:moveLeft()
            self:setFlip(true)
        end
    end
end

function Bot:updateAnimationState()
    if self.fields.saveNumber then
        if self.fields.isRescued then
            self:changeState(BOT_ANIMATION_STATES.Happy)
        else
            self:changeState(BOT_ANIMATION_STATES.Sad)
        end
    elseif self.dialogState == DIALOG_STATES.Expanded then
        self:changeState(BOT_ANIMATION_STATES.Talking)
    else
        self:changeState(BOT_ANIMATION_STATES.Idle)
    end
end

function Bot:addDialogSprite(text)
    local font = Fonts.Dialog
    local width = math.min(math.max(font:getTextWidth(text), 60), 200)

    local config = {
        x = self.x - width / 2,
        y = self.y - distanceAboveSprite,
        z = Z_INDEX.Level.Overlay, -- z-index not implemented.
        width = width,
        padding = 8,
        nineSlice = nineSliceSpeech,
        speed = 4.5,
        onPageComplete = function()
            self.timer = playdate.timer.performAfterDelay(durationDialog, self.getNextLine, self)
        end
    }

    -- Clear previous dialog sprite

    if self.dialogSprite then
        self:closeDialogSprite()
    end

    -- Create and add new dialog sprite

    local dialogBox = pdDialogue.create(text, config)

    self.dialogSprite = dialogBox:asSprite()

    self.dialogSprite:setZIndex(Z_INDEX.HUD.MainPlus)
    self.dialogSprite:setCenter(0.5, 1.5)
    self.dialogSprite:add()

    self.dialogSprite.update = _dialogUpdate

    self:addChild(self.dialogSprite)

    self.dialogState = DIALOG_STATES.Expanded
end

function Bot:closeDialogSprite()
    if self.dialogSprite then
        self:removeChild(self.dialogSprite)

        self.dialogSprite:remove()
        self.dialogSprite = nil
    end

    -- Stop any ongoing timers
    if self.timer then
        self.timer:pause()
    end
end

function Bot:playDialogSound()
    self.synth:playNotes(
        self.bleepCount or 6,
        9 / (self.bleepDuration or 1)
    )
end

---@param lineRaw string
---@return fun(): boolean
function Bot:parseCondition(lineRaw)
    if string.match(lineRaw, "%$%u%u%u") then
        -- CHIPSET CONDITION
        local chips = {}

        for c in string.gmatch(string.sub(lineRaw, 2), ".") do
            table.insert(chips, LETTERS_TO_KEYNAMES[c])
        end

        return function()
            local guiChipSet = GUIChipSet.getInstance()

            -- Return if condition passed
            return guiChipSet.chipSet[1] == chips[1]
                and guiChipSet.chipSet[2] == chips[2]
                and guiChipSet.chipSet[3] == chips[3]
        end
    elseif string.match(lineRaw, "%$%d") then
        -- PART CONDITION
        local part = string.match(lineRaw, "%$(%d+)")

        return function()
            -- Return if condition passed
            return self.part == part
        end
    else
        -- STATE CONDITION
        local keyword = string.sub(lineRaw, 2)

        return function()
            if keyword == "NEEDS_RESCUE" then
                return (self.isRescuable and not self.isRescued)
            elseif keyword == "IS_RESCUED" then
                return (self.isRescuable and self.isRescued)
            end

            return true
        end
    end
end

function Bot:executeProps(props)
    -- Repeating line

    if props.repeats and self.currentLine ~= nil then
        self.repeatLine = self.currentLine + 1
        self.fields.repeatLine = self.repeatLine
    end

    -- Player Interactions

    if props.giveChip then
        spCollect:play()

        Manager.emitEvent(EVENTS.ChipSetAdd, props.giveChip, self)
    end

    if props.continueTalking then
        self.continueTalking = true
    end

    if props.worldComplete then
        Manager.emitEvent(EVENTS.WorldComplete)
    end

    if props.flip ~= nil then
        self:setFlip(props.flip)
    end

    if props.showCrankIndicator then
        self.showCrankIndicator = true
    end

    -- Bleeps config

    if props.bleepsPerSecond then
        self.bleepsPerSecond = props.bleepsPerSecond
    end

    if props.bleepDuration then
        self.bleepDuration = props.bleepDuration
    end

    if props.bleepCount then
        self.bleepCount = props.bleepCount
    end

    if props.bleepVoice then
        self.synth:setVoice(SCALES[props.bleepVoice])
    end
end

---@param numberOrName number|string
---@return {x:number, y:number}|_Sprite|nil
function Bot:getDestinationPoint(numberOrName)
    if tonumber(numberOrName) then
        local numberOrName = tonumber(numberOrName)
        local point = self.fields.points and self.fields.points[numberOrName]

        if not point then
            return
        end

        -- Convert point to game coordinates
        local levelBounds = Game.getLevelBounds()
        local finalX, finalY = levelBounds.x + point.cx * TILE_SIZE + TILE_SIZE / 2,
            levelBounds.y + point.cy * TILE_SIZE + TILE_SIZE / 2

        return { x = finalX, y = finalY }
    elseif numberOrName == "player" then
        return Player.getInstance()
    end
end
