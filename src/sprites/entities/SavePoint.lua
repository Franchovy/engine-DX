local gfx <const> = playdate.graphics

local imageTableSprite <const> = assert(gfx.imagetable.new(assets.imageTables.guiRescueBots))
local spWin <const> = assert(playdate.sound.sampleplayer.new(assets.sounds.savepointActivate))
local spError <const> = assert(playdate.sound.sampleplayer.new(assets.sounds.errorSavePoint))

---@class SavePont: Entity
SavePoint = Class("SavePoint", Entity)

function SavePoint:init(entityData, levelName)
    SavePoint.super.init(self, entityData, levelName, imageTableSprite[1])

    -- Entity Config

    self.blueprints = entityData.fields.blueprints

    -- Sprite Config

    self:setCenter(0, 0.5)
    self:setScale(2)

    -- Collisions

    self:setTag(TAGS.SavePoint)
    self:setGroups(GROUPS.Overlap)

    -- State properties

    self.isActivated = entityData.fields.isActivated or false
    self.blueprintsCurrentError = nil
end

function SavePoint:postInit()
    self:setZIndex(Z_INDEX.Level.Neutral)

    -- Update

    self:updateImage()

    -- Update collision rect
    self:setCollideRect(0, 0, self:getSize())
end

function SavePoint:update()
    if self.blinkerError then
        if self.blinkerError.on then
            self:setImage(imageTableSprite[1])
        else
            self:setImage(imageTableSprite[2])
        end

        if not self.blinkerError.running then
            self.blinkerError = nil
        end
    end
end

function SavePoint:activate()
    if self.isActivated then
        return
    end

    local player = Player.getInstance()
    local blueprintsPlayer = player.blueprints

    if self.blueprintsCurrentError == blueprintsPlayer then
        return
    end

    -- Check if blueprints match

    if self:isMatchBlueprints(blueprintsPlayer) then
        -- Activate / save game
        self.isActivated = true
        self.fields.isActivated = true

        spWin:play(1)

        self:updateImage()

        Manager.emitEvent(EVENTS.SavePointSet)
    else
        self.blueprintsCurrentError = blueprintsPlayer

        self.blinkerError = gfx.animation.blinker.new(30, 40, false, 14, true)
        self.blinkerError:start()

        spError:play(1)
    end
end

function SavePoint:updateImage()
    if self.fields.isActivated then
        self:setImage(imageTableSprite[2])
    else
        self:setImage(imageTableSprite[1])
    end
end

function SavePoint:isMatchBlueprints(blueprints)
    local isMatchBlueprints = #blueprints == #self.blueprints

    if isMatchBlueprints then
        for i, blueprint in ipairs(self.blueprints) do
            isMatchBlueprints = isMatchBlueprints and blueprints[i] == blueprint
        end
    end

    return isMatchBlueprints
end
