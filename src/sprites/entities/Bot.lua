local gfx <const> = playdate.graphics
local geo <const> = playdate.geometry

-- Globally defined enum

BOT_ANIMATION_STATES = {
    Idle = 'idle',
    Talking = 'talking',
    Happy = 'happy',
    Sad = 'sad',
}

-- Local Variables

-- Assets

local nineSliceSpeech <const> = assert(gfx.nineSlice.new(assets.images.speech, 7, 7, 17, 17))
local spCollect <const> = assert(playdate.sound.sampleplayer.new(assets.sounds.collect))

-- Constants

local textMarginX <const> = 10
local distanceAboveSprite <const> = 6
local durationDialog <const> = 2000
local collideRectSize <const> = 90

local lettersToActions <const> = {
    ["A"] = KEYNAMES.A,
    ["U"] = KEYNAMES.Up,
    ["L"] = KEYNAMES.Left,
    ["R"] = KEYNAMES.Right,
    ["D"] = KEYNAMES.Down,
}

---@class Bot: EntityAnimated
---@property timer _Timer|nil
---@property config BotConfig
Bot = Class("Bot", EntityAnimated)

function Bot:init(entityData, levelName)
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
    end

    -- Set up animation states (Sad / Happy) if needs rescue

    if entityData.fields.saveNumber then
        if entityData.fields.isRescued then
            self:changeState(BOT_ANIMATION_STATES.Happy)
        else
            self:changeState(BOT_ANIMATION_STATES.Sad)
        end
    end

    self:playAnimation()

    -- Utils

    self:setupVoiceSynth()

    -- Sprite setup

    self:setGroups(GROUPS.Overlap)
    self:setTag(TAGS.Bot)

    -- Set whether is "rescuable"

    self.isRescuable = entityData.fields.saveNumber ~= nil
    self.rescueNumber = entityData.fields.saveNumber

    -- Get text from LDtk entity

    local text = entityData.fields.text

    -- Break up text into lines

    self:setupDialogLines(text)

    -- Bot variables

    self.repeatLine = nil

    -- Self state

    self.isRescued = false

    -- Set state

    self.isStateExpanded = false
    self.currentLine = 1

    -- Variables to be consumed in update

    self.isActivated = false

    -- Timer placeholder

    ---@type _Timer|nil
    self.timer = nil

    -- Set flip value

    if self.fields.flip ~= nil then
        self:setFlip(self.fields.flip)
    end

    -- Set collide rect to full size, centered on current center.
    self:setCollideRect(
        (self.width - collideRectSize) / 2,
        (self.height - collideRectSize) / 2,
        collideRectSize,
        collideRectSize
    )

    -- Config additional init call

    if self.config.init then
        self.config.init(self)
    end
end

function Bot:add()
    Bot.super.add(self)

    GUILightingEffect:getInstance():addEffect(self, GUILightingEffect.imageSmallCircle)
end

function Bot:remove()
    Bot.super.remove(self)

    GUILightingEffect:getInstance():removeEffect(self)
end

function Bot:changeState(stateNew)
    -- Get state if available, fallback on Idle
    local stateNewActual = self.config.animations[stateNew] and stateNew or
        BOT_ANIMATION_STATES.Idle

    Bot.super.changeState(self, stateNewActual)
end

function Bot:setupDialogLines(text)
    -- Initialize empty dialog array or map
    self.dialogs = {}

    -- If no text is provided, simply return.
    if not text then
        return
    end

    -- Get font used for calculating text size

    local font = gfx.getFont()

    -- Condition, if used, is repeated for every line until changed.
    local condition
    local props

    for lineRaw in string.gmatch(text, "([^\n]+)") do
        -- Bot Action condition

        if string.match(lineRaw, "%$") then
            local conditionChipset = string.match(lineRaw, "%$%u%u%u")

            if conditionChipset then
                condition = {
                    chipSet = self:parseCondition(conditionChipset)
                }

                goto continue
            else
                condition = {
                    state = string.sub(lineRaw, 2)
                }
                goto continue
            end
        end

        -- JSON for dynamic properties

        if string.match(lineRaw, "^%{") then
            local _, data = pcall(json.decode, lineRaw)

            props = data

            goto continue
        end

        -- Else, create dialog object

        local dialog = {
            text = lineRaw,
            props = props,
            condition = condition,
            width = 0,
        }

        -- Clear dynamic properties after use

        if props then
            props = nil
        end

        -- Calculate width and height of dialog box

        local textWidth = font:getTextWidth(lineRaw)
        dialog.width = math.min(textWidth, 200)

        -- Add dialog to list

        table.insert(self.dialogs, dialog)

        ::continue::
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
end

function Bot:getShouldFreeze()
    return self.fields.freeze == true
end

function Bot:setRescued()
    if not self.isRescued and self.isRescuable then
        local indexSfx = math.random(1, #assets.sounds.robotSave)
        local spRescue = playdate.sound.sampleplayer.new(assets.sounds.robotSave[indexSfx])
        spRescue:play(1)

        -- Animate to rescued animation state
        self:changeState(BOT_ANIMATION_STATES.Happy)

        -- Send message that has been rescued
        self.isRescued = true
        self.fields.isRescued = true

        Manager.emitEvent(EVENTS.BotRescued, self, self.rescueNumber)

        -- Force dialog to move on to enable next dialog lines
        self:updateDialog()
    end
end

function Bot:getIsRescuable()
    return self.isRescuable
end

function Bot:expand()
    if self.isStateExpanded then
        return
    end

    -- Show speech bubble
    self.isStateExpanded = true

    -- Play SFX

    --self:playDialogSound()

    -- Play speaking animation if not a rescue bot
    self:changeState(BOT_ANIMATION_STATES.Talking)
end

function Bot:collapse()
    if self.dialogSprite then
        self.dialogSprite:remove()
        self.dialogSprite = nil
    end

    -- Hide speech bubble
    self.isStateExpanded = false

    -- Reset dialog progress
    self.currentLine = self.repeatLine or 1

    -- Stop any ongoing timers
    if self.timer then
        self.timer:pause()
    end

    -- Play idle animation if not a rescue bot
    if not self.isRescuable then
        self:changeState(BOT_ANIMATION_STATES.Idle)
    end
end

function Bot:update()
    Bot.super.update(self)

    if self.timerMovement and not self.timerMovement.paused then
        return
    end

    -- Update dialog

    self:updateDialog()

    -- Crank Indicator

    if self.isStateExpanded and not self.isRescued and self.showCrankIndicator then
        _G.showCrankIndicator = true
    else
        _G.showCrankIndicator = false
    end

    -- Custom update callback for this sprite

    if self.config.update then
        self.config.update(self)
    end
end

function Bot:updateDialog()
    if self.isActivated then
        -- Consume update variable
        self.isActivated = false

        if not self.isStateExpanded then
            self:expand()
        end
    elseif self.isStateExpanded then
        self:collapse()
    end

    if self.isStateExpandedPrevious ~= self.isStateExpanded
        or self.currentLinePrevious ~= self.currentLine then
        self:executeProps()

        self:incrementDialog()
    end

    self.isStateExpandedPrevious = self.isStateExpanded
    self.currentLinePrevious = self.currentLine
end

function Bot:executeProps()
    local dialog = self.dialogs[self.currentLine]
    -- Read props
    if dialog and dialog.props then
        self:parseProps(dialog.props)
    end
end

function Bot:incrementDialog()
    local dialog = self.dialogs[self.currentLine]

    local shouldIncrement = not (self.currentLine > #self.dialogs)
        and (self.isStateExpanded or (dialog.text == "--no text--"))

    -- If line is greater than current lines, mimic collapse.
    if shouldIncrement then
        -- Update sprite size using dialog size

        if dialog.condition then
            local guiChipSet = GUIChipSet.getInstance()

            local conditionFailed = false

            if dialog.condition.chipSet then
                -- Condition passed
                if not (guiChipSet.chipSet[1] == dialog.condition.chipSet[1]
                        and guiChipSet.chipSet[2] == dialog.condition.chipSet[2]
                        and guiChipSet.chipSet[3] == dialog.condition.chipSet[3]) then
                    conditionFailed = true
                end
            elseif dialog.condition.state then
                if dialog.condition.state == "NEEDS_RESCUE" and (not self.isRescuable and self.isRescued) then
                    conditionFailed = true
                end

                if dialog.condition.state == "IS_RESCUED" and (self.isRescuable and not self.isRescued) then
                    conditionFailed = true
                end
            end

            if conditionFailed then
                -- Condition failed
                self:showNextLine()
                self:incrementDialog()

                return
            end
        end

        -- Set timer to handle next line / collapse
        if self.timer then
            self.timer:remove()
        end

        if dialog.text ~= "--no text--" then
            -- Set size and position
            local width = dialog.width + textMarginX * 2

            self:addDialogSprite(
                dialog.text,
                self.x - width / 2,
                self.y - distanceAboveSprite,
                width
            )

            -- Speak dialog

            self:playDialogSound()
        end
    else
        -- If line is last one, send event
        if #self.dialogs < self.currentLine and self.fields.levelEnd then
            -- If level end sprite, show level end prompt
            Manager.emitEvent(EVENTS.LevelEnd)
        end

        self:changeState(BOT_ANIMATION_STATES.Idle)
    end
end

function Bot:addDialogSprite(text, x, y, width)
    local config = {
        x = x,
        y = y,
        z = Z_INDEX.Level.Overlay, -- z-index not implemented.
        width = width,
        padding = 8,
        nineSlice = nineSliceSpeech,
        speed = 4.5,
        onPageComplete = function()
            self.timer = playdate.timer.performAfterDelay(durationDialog, self.showNextLine, self)
        end
    }

    -- Clear previous dialog sprite

    if self.dialogSprite then
        self.dialogSprite:remove()
    end

    -- Create and add new dialog sprite

    local dialogBox = pdDialogue.create(text, config)

    self.dialogSprite = dialogBox:asSprite()

    self.dialogSprite:setZIndex(Z_INDEX.HUD.Background)
    self.dialogSprite:setCenter(0.5, 1)
    self.dialogSprite:moveTo(self:centerX(), self:top() - distanceAboveSprite)
    self.dialogSprite:add()
end

function Bot:showNextLine()
    -- Increment current line
    self.currentLine += 1

    -- If a movement is programmed, handle movement before next line.
    if self.timerMovement then
        -- Enable movement

        self.timerMovement:start()

        -- Set line to repeat at next line
        self.repeatLine = self.currentLine

        -- Collapse bubble
        self:collapse()
    end

    -- Reset timer

    if self.timer then
        self.timer:reset()
    end
end

function Bot:playDialogSound()
    self.synth:playNotes(
        self.bleepCount or 6,
        9 / (self.bleepDuration or 1)
    )
end

function Bot:parseCondition(conditionRaw)
    local actions = {}

    for c in string.gmatch(string.sub(conditionRaw, 2), ".") do
        table.insert(actions, lettersToActions[c])
    end

    return actions
end

function Bot:parseProps(props)
    -- Repeating line

    if props.repeats then
        self.repeatLine = self.currentLine
    end

    -- Player Interactions

    if props.unlockCrank then
        local player = Player.getInstance()
        player:unlockAbility(ABILITIES.CrankToWarp)
    end

    if props.giveChip then
        spCollect:play()

        Manager.emitEvent(EVENTS.ChipSetAdd, props.giveChip)
    end

    if props.worldComplete then
        Manager.emitEvent(EVENTS.WorldComplete)
    end

    if props.flip ~= nil then
        self:setFlip(props.flip)
    end

    if props.walkTo then
        local walkToPointNumber = props.walkTo
        if self.fields.points and self.fields.points[walkToPointNumber] then
            local destinationPoint = self.fields.points[walkToPointNumber]
            local levelBounds = Game.getLevelBounds()
            local finalX, finalY = levelBounds.x + destinationPoint.cx * TILE_SIZE + TILE_SIZE / 2,
                levelBounds.y + destinationPoint.cy * TILE_SIZE + TILE_SIZE / 2

            local distance = math.sqrt((self.x - finalX) ^ 2 + (self.y - finalY) ^ 2)
            local speed = props.speed or (TILE_SIZE / 8) -- 1/8th tile per frame

            local vectorStart = geo.vector2D.new(self.x, self.y)
            local vectorEnd = geo.vector2D.new(finalX, finalY)

            -- Move slowly to point.
            self.timerMovement = playdate.frameTimer.new(distance / speed, function(pointStart, pointEnd)
                self.timerMovement:remove()
                self.timerMovement = nil
            end)

            self.timerMovement.updateCallback = function()
                local completion = self.timerMovement.frame / self.timerMovement.duration
                local vectorDestination = vectorStart * (1 - completion) + vectorEnd * completion
                self:moveTo(vectorDestination.dx, vectorDestination.dy)
            end

            self.timerMovement:pause()

            -- Set repeat line not to repeat previous text.
            self.repeatLine = self.currentLine + 1
        end
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
