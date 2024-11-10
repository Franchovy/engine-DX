local gfx <const> = playdate.graphics


-- Local Variables

-- Assets

local nineSliceSpeech <const> = gfx.nineSlice.new(assets.images.speech, 7, 7, 17, 17)
local spSpeech <const> = playdate.sound.sampleplayer.new(assets.sounds.speech)

-- Constants

local defaultSize <const> = 16
local textMarginX <const>, textMarginY <const> = 10, 4
local durationDialog <const> = 3000
local collideRectSize <const> = 90
local yOffset <const> = 16

local botAnimationSpeeds <const> = botAnimationSpeeds
local ANIMATION_STATES <const> = {
    Idle = 1,
    Talking = 2,
    NeedsRescue = 3,
    Rescued = 4
}

-- Child class functions

local function drawSpeechBubble(self, x, y, w, h)
    -- Draw Speech Bubble

    nineSliceSpeech:drawInRect(0, 0, self.width, self.height)

    -- Draw Text

    if self.dialog then
        local font = gfx.getFont()

        for i, line in ipairs(self.dialog.lines) do
            font:drawText(line, textMarginX, textMarginY + (i - 1) * font:getHeight())
        end
    end
end

--

---@class Dialog: playdate.graphics.sprite
Dialog = Class("Dialog", AnimatedSprite)

function Dialog:init(entity)
    -- Load image based on rescuable & entity ID

    local imagetable
    local botAnimationSpeed = 2

    if entity.fields.save then
        -- Get or create the sprite to use
        local spriteNumber = entity.fields.spriteNumber or math.random(1, 7)

        -- Set the rate at which the bot should animate
        botAnimationSpeed = botAnimationSpeeds[spriteNumber]

        -- Set the sprite number on the LDtk entity
        entity.fields.spriteNumber = spriteNumber

        -- Grab the imagetable corresponding to this sprite
        imagetable = assert(gfx.imagetable.new(assets.imageTables.bots[spriteNumber]))
    else
        -- Helper bots have a set imagetable.
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

    self:playAnimation()

    -- Sprite setup

    self:setTag(TAGS.Dialog)

    -- Set whether is "rescuable"

    self.isRescuable = entity.fields.save
    self.rescueNumber = entity.fields.saveNumber

    -- Get text from LDtk entity

    local text = entity.fields.text

    -- Get font used for calculating text size

    local font = gfx.getFont()

    -- Break up text into lines

    if text then
        self.dialogs = {}
        for text in string.gmatch(text, "([^\n]+)") do
            local dialog = {
                text = text,
                lines = {},
                width = 0,
                height = 0
            }

            for text in string.gmatch(text, "[^/]+") do
                -- Get dialog width by getting max width of all lines
                local textWidth = font:getTextWidth(text)
                if dialog.width < textWidth then
                    dialog.width = textWidth
                end

                -- Add line to dialog lines
                table.insert(dialog.lines, text) -- Unchanged Case
                -- table.insert(dialog.lines, string.upper(text)) -- UPPERCASE
            end

            -- Add dialog height based on num. lines
            dialog.height = font:getHeight() * #dialog.lines

            -- Add dialog to list
            table.insert(self.dialogs, dialog)
        end
    end

    -- Set up child sprite

    self.spriteBubble = gfx.sprite.new()
    self.spriteBubble.draw = drawSpeechBubble
    self.spriteBubble:moveTo(self.x, self.y)
    self.spriteBubble:setZIndex(2)

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

        -- Set timer to handle next line / collapse
        self.timer = playdate.timer.performAfterDelay(durationDialog, self.showNextLine, self)

        -- Update child sprite dialog
        self.spriteBubble.dialog = dialog

        -- Set size and position
        local width, height = dialog.width + textMarginX * 2, dialog.height + textMarginY * 2
        self.spriteBubble:setSize(width, height)
        self.spriteBubble:moveTo(self.x, self.y - height - yOffset)
    else
        self.spriteBubble:remove()
        self:changeState(ANIMATION_STATES.Idle)
    end

    -- Mark dirty for redraw
    self.spriteBubble:markDirty()
end

function Dialog:showNextLine()
    -- Show next line
    self.currentLine += 1
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

        Manager.emitEvent(EVENTS.BotRescued, self, self.rescueNumber)
    end
end

function Dialog:expand()
    if self.isStateExpanded then
        return
    end

    -- Show speech bubble
    self.spriteBubble:add()
    self.isStateExpanded = true

    -- Play SFX
    spSpeech:play(1)

    -- Play speaking animation if not a rescue bot
    if not self.isRescuable then
        self:changeState(ANIMATION_STATES.Talking)
    end
end

function Dialog:collapse()
    -- Hide speech bubble
    self.spriteBubble:remove()
    self.isStateExpanded = false

    -- Reset dialog progress
    self.currentLine = 1

    -- Stop any ongoing timers
    self.timer:pause()

    -- Play idle animation if not a rescue bot
    if not self.isRescuable then
        self:changeState(ANIMATION_STATES.Idle)
    end
end

function Dialog:update()
    Dialog.super.update(self)

    if not self.isRescuable then
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
