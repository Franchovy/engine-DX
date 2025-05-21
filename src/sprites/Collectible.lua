local gfx <const> = playdate.graphics

local imageTableCollectibles <const> = gfx.imagetable.new(assets.imageTables.collectibles)
local spCollectiblePickup <const> = playdate.sound.sampleplayer.new(assets.sounds.collectiblePickup)

--- @class Collectible : ConsumableSprite
Collectible = Class("Collectible", ConsumableSprite)

function Collectible:init(entity)
    Collectible.super.init(self)

    self:setTag(TAGS.Collectible)

    local index = entity.fields.index

    assert(index, "Missing identifier for index")
    assert(index ~= 0, "Collectible index cannot be 0")

    self:setImage(imageTableCollectibles[index])

    self.collisionResponse = gfx.sprite.kCollisionTypeOverlap
end

function Collectible:postInit()
    Collectible.super.postInit(self)

    -- Center collide rect on sprite

    local spriteSizeWidth, spriteSizeHeight = self:getSize()
    local ldtkSize = self.entity.size
    local offsetWidth, offsetHeight = (spriteSizeWidth - ldtkSize.width) / 2, (spriteSizeHeight - ldtkSize.height) / 2

    self:setCollideRect(offsetWidth, offsetHeight, ldtkSize.width, ldtkSize.height)
end

function Collectible:activate()
    -- Emit event for collectible pickup

    -- Play sound

    spCollectiblePickup:play()

    -- Consume / disappear

    self:consume()
end
