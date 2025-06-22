local gfx <const> = playdate.graphics
local geo <const> = playdate.geometry

-- Local Variables

-- Assets

local nineSliceSpeech <const> = assert(gfx.nineSlice.new(assets.images.speech, 7, 7, 17, 17))
local imageSpeechBButton <const> = assert(gfx.image.new(assets.images.speechBButton))
local spSpeech <const> = assert(playdate.sound.sampleplayer.new(assets.sounds.speech))
local spCollect <const> = playdate.sound.sampleplayer.new(assets.sounds.collect)

-- Constants

local defaultSize <const> = 16
local textMarginX <const>, textMarginY <const> = 10, 8
local textMarginSpacing <const> = 4
local distanceAboveSprite <const> = 6
local durationDialog <const> = 2000
local collideRectSize <const> = 90

local yOffset <const> = 16
local botAnimationSpeeds <const> = botAnimationSpeeds

local ANIMATION_STATES <const> = {
    Idle = 1,
    Talking = 2,
    NeedsRescue = 3,
    Rescued = 4
}

local lettersToActions <const> = {
    ["A"] = KEYNAMES.A,
    ["U"] = KEYNAMES.Up,
    ["L"] = KEYNAMES.Left,
    ["R"] = KEYNAMES.Right,
    ["D"] = KEYNAMES.Down,
}

---@class Dialog: playdate.graphics.sprite
Dialog = Class("Dialog", AnimatedSprite)

function Dialog:init(entity)
    -- Load image based on rescuable & entity ID

    local botAnimationSpeed = 2
    local imagetable

    -- Choose imagetable using sprite number

    if entity.fields.saveNumber and not entity.fields.asset then
        -- Set a random sprite number for rescuable bots without a spriteNumber
        entity.fields.asset = math.random(1, 7)
    end

    if entity.fields.asset then
        -- Set the rate at which the bot should animate
        botAnimationSpeed = botAnimationSpeeds[entity.fields.asset]

        -- Grab the imagetable corresponding to this sprite
        imagetable = assert(gfx.imagetable.new(assets.imageTables.bots[entity.fields.asset]))
    else
        -- Set imagetable to Helper Bot
        imagetable = assert(gfx.imagetable.new(assets.imageTables.bots.helper))
    end

    -- Super init call

    Dialog.super.init(self, imagetable)

    -- Add animation states

    self:addState(ANIMATION_STATES.Idle, 1, 4, { tickStep = botAnimationSpeed }).asDefault()
    self:addState(ANIMATION_STATES.Talking, 5, 8, { tickStep = botAnimationSpeed })

    -- Set up animation states (Sad / Happy) if needs rescue

    if entity.fields.saveNumber then
        self:addState(ANIMATION_STATES.NeedsRescue, 9, 12, { tickStep = botAnimationSpeed })
        self:addState(ANIMATION_STATES.Rescued, 12, 16, { tickStep = botAnimationSpeed })

        if entity.fields.isRescued then
            self:changeState(ANIMATION_STATES.Rescued)
        else
            self:changeState(ANIMATION_STATES.NeedsRescue)
        end
    end

    self:playAnimation()

    -- Utils

    local num = math.random(3)
    local voices = {
        SCALES.BOT_LOW,
        SCALES.BOT_MEDIUM,
        SCALES.BOT_HIGH,
    }
    self.synth = Synth(
        voices[num], 6 + num)

    -- Sprite setup

    self:setGroups(GROUPS.Overlap)
    self:setTag(TAGS.Dialog)

    -- Set whether is "rescuable"

    self.isRescuable = entity.fields.saveNumber ~= nil
    self.rescueNumber = entity.fields.saveNumber

    -- Get text from LDtk entity

    local text = entity.fields.text

    -- Break up text into lines

    self:setupDialogLines(text)

    -- Dialog variables

    self.repeatLine = nil

    -- Self state

    self.isRescued = false

    -- Set state

    self.isStateExpanded = false
    self.currentLine = 1

    -- Variables to be consumed in update

    self.isActivated = false
end

function Dialog:postInit()
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
end

function Dialog:setupDialogLines(text)
    if not text then
        return
    end

    -- Get font used for calculating text size

    local font = gfx.getFont()

    -- Initialize empty dialog array or map
    self.dialogs = {}

    -- Condition, if used, is repeated for every line until changed.
    local condition
    local props

    for lineRaw in string.gmatch(text, "([^\n]+)") do
        -- Dialog Action condition

        local conditionRaw = string.match(lineRaw, "%$%u%u%u")

        if conditionRaw then
            condition = self:parseCondition(conditionRaw)
            goto continue
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

function Dialog:setFlip(shouldFlip)
    local flipValue = shouldFlip and 1 or 0
    self.states[ANIMATION_STATES.Idle].flip = flipValue
    self.states[ANIMATION_STATES.Talking].flip = flipValue

    if self.fields.saveNumber then
        self.states[ANIMATION_STATES.NeedsRescue].flip = flipValue
        self.states[ANIMATION_STATES.Rescued].flip = flipValue
    end
end

--- Called from the player class on collide.
function Dialog:activate()
    self.isActivated = true
end

function Dialog:getShouldFreeze()
    return self.fields.freeze == true
end

function Dialog:setRescued()
    if not self.isRescued and self.isRescuable then
        local indexSfx = math.random(1, #assets.sounds.robotSave)
        local spRescue = playdate.sound.sampleplayer.new(assets.sounds.robotSave[indexSfx])
        spRescue:play(1)

        -- Animate to rescued animation state
        self:changeState(ANIMATION_STATES.Rescued)

        -- Send message that has been rescued
        self.isRescued = true
        self.fields.isRescued = true

        Manager.emitEvent(EVENTS.BotRescued, self, self.rescueNumber)
    end
end

function Dialog:getIsRescuable()
    return self.isRescuable
end

function Dialog:expand()
    if self.isStateExpanded then
        return
    end

    -- Show speech bubble
    self.isStateExpanded = true

    -- Play SFX

    --self:playDialogSound()

    -- Play speaking animation if not a rescue bot
    self:changeState(ANIMATION_STATES.Talking)
end

function Dialog:collapse()
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
        self:changeState(ANIMATION_STATES.Idle)
    end
end

function Dialog:update()
    Dialog.super.update(self)

    if self.timerMovement and not self.timerMovement.paused then
        return
    end

    if not self.dialogs then
        return
    end

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
        self:updateDialog()
    end

    self.isStateExpandedPrevious = self.isStateExpanded
    self.currentLinePrevious = self.currentLine
end

function Dialog:updateDialog()
    -- If line is greater than current lines, mimic collapse.
    if self.isStateExpanded and not (self.currentLine > #self.dialogs) then
        -- Update sprite size using dialog size

        local dialog = self.dialogs[self.currentLine]

        if dialog.condition then
            local guiChipSet = GUIChipSet.getInstance()

            if guiChipSet.chipSet[1] == dialog.condition[1]
                and guiChipSet.chipSet[2] == dialog.condition[2]
                and guiChipSet.chipSet[3] == dialog.condition[3] then
                -- Condition passed
            else
                -- Condition failed
                self:showNextLine()
                self:updateDialog()
                return
            end
        end

        -- Read props
        if dialog.props then
            self:parseProps(dialog.props)
        end

        -- Set timer to handle next line / collapse
        if self.timer then
            self.timer:remove()
        end

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
    else
        -- If line is last one, send event
        if #self.dialogs < self.currentLine and self.fields.levelEnd then
            -- If level end sprite, show level end prompt
            Manager.emitEvent(EVENTS.LevelEnd)
        end

        self:changeState(ANIMATION_STATES.Idle)
    end
end

function Dialog:addDialogSprite(text, x, y, width)
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

function Dialog:showNextLine()
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

function Dialog:playDialogSound()
    self.synth:playNotes(
        self.bleepCount or 6,
        9 / (self.bleepDuration or 1)
    )
end

function Dialog:parseCondition(conditionRaw)
    local actions = {}

    for c in string.gmatch(string.sub(conditionRaw, 2), ".") do
        table.insert(actions, lettersToActions[c])
    end

    return actions
end

function Dialog:parseProps(props)
    -- Repeating line

    if props.repeats then
        self.repeatLine = self.currentLine
    end

    -- Player Interactions

    if props.unlockCrank then
        local player = Player.getInstance()
        player:unlockCrank()
    end

    if props.giveChip then
        spCollect:play()

        Manager.emitEvent(EVENTS.UpdateChipSet, props.giveChip)
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
