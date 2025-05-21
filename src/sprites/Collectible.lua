local gfx <const> = playdate.graphics

local imageTableCollectibles <const> = gfx.imagetable.new(assets.imageTables.collectibles)
local spCollectiblePickup <const> = playdate.sound.sampleplayer.new(assets.sounds.collectiblePickup)

--- @class Collectible : ConsumableSprite
Collectible = Class("Collectible", ConsumableSprite)

function Collectible:init(entity)
    Collectible.super.init(self)

    -- Collision Setup

    self:setTag(TAGS.Collectible)
    self.collisionResponse = gfx.sprite.kCollisionTypeOverlap

    -- Setup image using index provided in LDtk

    local index = entity.fields.index

    assert(index, "Missing identifier for index")
    assert(index ~= 0, "Collectible index cannot be 0")

    self:setImage(imageTableCollectibles[index])

    -- Generate hash from image

    self:generateImageHash()

    print(self.imageHash)
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

    Manager.emitEvent(EVENTS.CollectiblePickup, self.fields.index, self.imageHash)

    -- Play sound

    spCollectiblePickup:play()

    -- Consume / disappear

    self:consume()
end

function Collectible:generateImageHash()
    local image = self:getImage()
    local width, height = image:getSize()
    local prime = 16777619 -- A large prime number

    local hash = 0
    for y = 0, width do
        for x = 0, height do
            local pixelValue = image:sample(x, y) + 1

            -- Combine the current hash with the pixel value using bitwise operations and modular arithmetic
            hash = math.tointeger(hash * prime) ~ math.tointeger(pixelValue * prime)
            hash %= 100000000 -- Modulo to keep the hash within 32 bits
        end
    end

    self.imageHash = hash
end
