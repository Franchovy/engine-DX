local gfx <const> = playdate.graphics


-- Local Variables

-- Assets

local nineSliceSpeech <const> = assert(gfx.nineSlice.new(assets.images.speech, 7, 7, 17, 17))
local imageSpeechBButton <const> = assert(gfx.image.new(assets.images.speechBButton))
local spSpeech <const> = assert(playdate.sound.sampleplayer.new(assets.sounds.speech))

-- Constants

local defaultSize <const> = 16
local textMarginX <const>, textMarginY <const> = 10, 8
local textMarginSpacing <const> = 4
local distanceAboveSprite <const> = 20
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

---@class Dialog: playdate.graphics.sprite
Dialog = Class("Dialog", AnimatedSprite)

function Dialog:init(entity)
    -- Load image based on rescuable & entity ID

    local botAnimationSpeed = 2
    local imagetable

    if entity.fields.noSprite then
        self:setVisible(false)
    end

    if entity.fields.save and not entity.fields.spriteNumber then
        -- Set a random sprite number for rescuable bots without a spriteNumber
        entity.fields.spriteNumber = math.random(1, 7)
    end

    if entity.fields.spriteNumber then
        -- Set the rate at which the bot should animate
        botAnimationSpeed = botAnimationSpeeds[entity.fields.spriteNumber]

        -- Grab the imagetable corresponding to this sprite
        imagetable = assert(gfx.imagetable.new(assets.imageTables.bots[entity.fields.spriteNumber]))
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

    if entity.fields.save then
        self:addState(ANIMATION_STATES.NeedsRescue, 9, 12, { tickStep = botAnimationSpeed })
        self:addState(ANIMATION_STATES.Rescued, 12, 16, { tickStep = botAnimationSpeed })

        if entity.fields.isRescued then
            self:changeState(ANIMATION_STATES.Rescued)
        else
            self:changeState(ANIMATION_STATES.NeedsRescue)
        end
    end

    if entity.fields.flip then
        self.states[ANIMATION_STATES.Idle].flip = 1
        self.states[ANIMATION_STATES.Talking].flip = 1

        if entity.fields.save then
            self.states[ANIMATION_STATES.NeedsRescue].flip = 1
            self.states[ANIMATION_STATES.Rescued].flip = 1
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

    self:setTag(TAGS.Dialog)

    -- Set whether is "rescuable"

    self.isRescuable = entity.fields.save
    self.rescueNumber = entity.fields.saveNumber

    -- Get text from LDtk entity

    local text = entity.fields.text

    -- Break up text into lines

    self:parseTextIntoDialog(text)

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
    -- Set collide rect to full size, centered on current center.
    self:setCollideRect(
        (self.width - collideRectSize) / 2,
        (self.height - collideRectSize) / 2,
        collideRectSize,
        collideRectSize
    )
end

function Dialog:updateDialog()
    -- If line is greater than current lines, mimic collapse.
    if self.isStateExpanded and not (self.currentLine > #self.dialogs) then
        -- Update sprite size using dialog size

        local dialog = self.dialogs[self.currentLine]

        if dialog.condition then
            local player = Player.getInstance()

            if player.blueprints[1] == dialog.condition[1]
                and player.blueprints[2] == dialog.condition[2]
                and player.blueprints[3] == dialog.condition[3] then
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
        local width, height = dialog.width + textMarginX * 2, dialog.height + textMarginY * 2 + 8

        self:setupDialogBubble(
            dialog.text,
            self.x - width / 2,
            self.y - distanceAboveSprite - height,
            width,
            height
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

function Dialog:setupDialogBubble(text, x, y, width, height)
    local config = {
        x = x,
        y = y,
        z = Z_INDEX.Level.Overlay, -- z-index not implemented.
        width = width,
        height = height,
        padding = 8,
        nineSlice = nineSliceSpeech,
        speed = 2,
        onPageComplete = function()
            self.timer = playdate.timer.performAfterDelay(durationDialog, self.showNextLine, self)
        end
    }

    pdDialogue.say(text, config)
end

function Dialog:showNextLine()
    -- Show next line
    self.currentLine += 1

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

--- Called from the player class on collide.
function Dialog:activate()
    self.isActivated = true

    if not self.isRescued and self.isRescuable then
        local indexSfx = math.random(1, #assets.sounds.robotSave)
        local spRescue = playdate.sound.sampleplayer.new(assets.sounds.robotSave[indexSfx])
        spRescue:play(1)

        -- Animate to rescued animation state
        self:changeState(ANIMATION_STATES.Rescued)

        -- Send message that has been rescued
        self.isRescued = true
        self.fields.isRescued = true

        Manager.emitEvent(EVENTS.BotRescued, self, self.rescueNumber, self.fields.levelEnd)
    end
end

function Dialog:getShouldFreeze()
    return self.fields.freeze == true
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

    if self.dialogs then
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
end

function Dialog:hasKey()
    return self.fields.button ~= nil
end

function Dialog:getKey()
    local key = self.fields.button
    self.fields.button = nil

    return key
end

function Dialog:parseTextIntoDialog(text)
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
            condition = self:parseConditionIntoActions(conditionRaw)
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
            height = 0
        }

        -- Clear dynamic properties after use

        if props then
            props = nil
        end

        -- Calculate width and height of dialog box

        local lineCount = 0
        for line in string.gmatch(lineRaw, "[^/]+") do
            -- Get dialog width by getting max width of all lines
            local textWidth = font:getTextWidth(line)
            if dialog.width < textWidth then
                dialog.width = textWidth
            end

            lineCount += 1
        end

        -- Add dialog height based on num. lines
        dialog.height = (font:getHeight() + textMarginSpacing) * lineCount

        -- Add dialog to list

        table.insert(self.dialogs, dialog)

        ::continue::
    end
end

local lettersToActions = {
    ["A"] = KEYNAMES.A,
    ["B"] = KEYNAMES.B,
    ["U"] = KEYNAMES.Up,
    ["L"] = KEYNAMES.Left,
    ["R"] = KEYNAMES.Right,
    ["D"] = KEYNAMES.Down,
}

function Dialog:parseConditionIntoActions(conditionRaw)
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

    -- Unlockables

    if props.unlockCrank then
        local player = Player.getInstance()
        player:unlockCrank()
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
