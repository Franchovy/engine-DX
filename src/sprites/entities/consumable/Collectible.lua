local gfx <const> = playdate.graphics

local imageTableCollectibles <const> = assert(gfx.imagetable.new(assets.imageTables.collectibles))
local spCollectiblePickup <const> = assert(playdate.sound.sampleplayer.new(assets.sounds.collectiblePickup))

--- @class Collectible : Consumable
Collectible = Class("Collectible", Consumable)

function Collectible:init(entityData, levelName)
    Collectible.super.init(self, entityData, levelName)

    -- Collision Setup

    self:setTag(TAGS.Collectible)
    self:setGroups(GROUPS.Overlap)

    -- Setup image using index provided in LDtk

    local index = entityData.fields.index

    assert(index, "Missing identifier for index")
    assert(index ~= 0, "Collectible index cannot be 0")

    self:setImage(imageTableCollectibles[index])

    -- Generate hash from image

    self:generateImageHash()

    -- Center collide rect on sprite

    local spriteSizeWidth, spriteSizeHeight = self:getSize()
    local ldtkSize = self.entity.size
    local offsetWidth, offsetHeight = (spriteSizeWidth - ldtkSize.width) / 2, (spriteSizeHeight - ldtkSize.height) / 2

    self:setCollideRect(offsetWidth, offsetHeight, ldtkSize.width, ldtkSize.height)
end

function Collectible:activate()
    -- Emit event for collectible pickup

    Manager.emitEvent(EVENTS.CollectiblePickup, self.fields.index, self.imageHash)

    -- Play sound

    spCollectiblePickup:play()

    -- Consume / disappear

    self:consume()
end

function Collectible:generateImageHash()
    local image = self:getImage()


    self.imageHash = image:getImageHash()
end
