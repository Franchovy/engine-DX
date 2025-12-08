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

-- Constants

local textMarginX <const> = 10
local distanceAboveSprite <const> = 6
local durationDialog <const> = 2000
local collideRectSize <const> = 64

local lettersToActions <const> = {
    ["A"] = KEYNAMES.A,
    ["U"] = KEYNAMES.Up,
    ["L"] = KEYNAMES.Left,
    ["R"] = KEYNAMES.Right,
    ["D"] = KEYNAMES.Down,
}

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
                acceleration = 1,
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
    end

    self:updateAnimationState()

    self:playAnimation()

    -- Utils

    self:setupVoiceSynth()

    -- Collision config

    self:setCollideRect(4, 4, self.width - 8, self.height - 4)
    self:setCollidesWithGroups({ GROUPS.Solid, GROUPS.SolidExceptElevator })
    self:setTag(TAGS.Bot)

    -- Create activateable collision field

    self.collisionField = gfx.sprite.new()
    self.collisionField:setCollideRect(0, 0, collideRectSize, collideRectSize)
    self.collisionField:setGroups(GROUPS.ActivatePlayer)
    self.collisionField:moveTo(self.x - collideRectSize / 2, self.y - collideRectSize / 2)

    ---@diagnostic disable-next-line: inject-field
    self.collisionField.activate = function() self.activate(self) end

    self:addChild(self.collisionField)

    -- Set whether is "rescuable"

    self.isRescuable = entityData.fields.saveNumber ~= nil
    self.rescueNumber = entityData.fields.saveNumber
    self.isRescued = entityData.fields.isRescued or false

    -- Break up text into lines

    self:setupDialogLines(entityData.fields.text)

    -- Bot variables

    self.repeatLine = nil
    self.dialogState = DIALOG_STATES.Unopened
    self.currentLine = nil

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
    if other:getGroupMask() & GROUPS.Solid ~= 0 then
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
            -- Actions (e.g. walk-to)
            action = function() return true end
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

    if self.isRescuable and not self.isRescued then
        self:setRescued()
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
            self.dialogState = DIALOG_STATES.Expanded
        end
    else
        -- Close dialog
        self:closeDialogSprite()

        self.currentLine = nil
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

        Manager.emitEvent(EVENTS.BotRescued, self, self.rescueNumber)
    end
end

function Bot:getIsRescuable()
    return self.isRescuable
end

function Bot:update()
    Bot.super.update(self)

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

    -- Reset update variable

    self.isActivated = false

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

function Bot:updateMovement()
    if self.walkToPlayer and not self.walkPath then
        self.walkToPlayer()
    end

    if self.walkPath and #self.walkPath > 0 then
        local nextPoint
        local xMovement, yMovement
        local speed = 3

        repeat
            nextPoint = self.walkPath[1]
            xMovement, yMovement = nextPoint.x - self.x, nextPoint.y - self.y
            if not (math.abs(xMovement) > 3 or math.abs(yMovement) > 3) then
                table.remove(self.walkPath, 1)
            end
        until math.abs(xMovement) > 3 or math.abs(yMovement) > 3 or #self.walkPath == 0

        if #self.walkPath > 0 then
            -- Move towards next point
            if yMovement < 0 and math.abs(xMovement) < 33 then
                -- Jump and move left/right
                self:jump()
            end

            if xMovement > 0 then
                self:moveRight()
            elseif xMovement < 0 then
                self:moveLeft()
            end
        else
            self.walkPath = nil
        end
    elseif self.walkPath and #self.walkPath == 0 then
        self.walkPath = nil
    end

    Moveable.update(self)
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
    local width = math.min(font:getTextWidth(text), 200)

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

function Bot:closeDialogSprite()
    if self.dialogSprite then
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
            table.insert(chips, lettersToActions[c])
        end

        return function()
            local guiChipSet = GUIChipSet.getInstance()

            -- Return if condition passed
            return guiChipSet.chipSet[1] == chips[1]
                and guiChipSet.chipSet[2] == chips[2]
                and guiChipSet.chipSet[3] == chips[3]
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

        Manager.emitEvent(EVENTS.ChipSetAdd, props.giveChip, self)
    end

    if props.worldComplete then
        Manager.emitEvent(EVENTS.WorldComplete)
    end

    if props.flip ~= nil then
        self:setFlip(props.flip)
    end

    if props.walkTo then
        local walkToPointNumber = props.walkTo

        if props.walkTo == "player" then
            self.startWalkToPlayer = function()
                local player = Player.getInstance()
                local finalX, finalY = player.x, player.y

                local pathNodes = LDTkPathFinding.getPath(Game.getLevelName(), self.x, self.y, finalX, finalY)
                self.walkPath = pathNodes
            end
        elseif self.fields.points and self.fields.points[walkToPointNumber] then
            local destinationPoint = self.fields.points[walkToPointNumber]
            local levelBounds = Game.getLevelBounds()
            local finalX, finalY = levelBounds.x + destinationPoint.cx * TILE_SIZE + TILE_SIZE / 2,
                levelBounds.y + destinationPoint.cy * TILE_SIZE + TILE_SIZE / 2

            local pathNodes = LDTkPathFinding.getPath(Game.getLevelName(), self.x, self.y, finalX, finalY)

            self.startWalkPath = function()
                self.walkPath = pathNodes
            end

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
