local gfx <const> = playdate.graphics

-- bot rescue counter

local imagetableSprite <const> = assert(gfx.imagetable.new(assets.imageTables.guiRescueBots))
local imageSpriteRescued <const> = {
    [1] = assert(gfx.image.new(assets.images.botFaces[1])),
    [2] = assert(gfx.image.new(assets.images.botFaces[2])),
    [3] = assert(gfx.image.new(assets.images.botFaces[3])),
    [4] = assert(gfx.image.new(assets.images.botFaces[4])),
    [5] = assert(gfx.image.new(assets.images.botFaces[5])),
    [6] = assert(gfx.image.new(assets.images.botFaces[6])),
    [7] = assert(gfx.image.new(assets.images.botFaces[7])),
}
local padding <const> = 3

local maxSpriteCounters <const> = 16
local spriteCounters <const> = {}

local function isSet(self)
    return self:getImage() ~= imagetableSprite[1]
end

---@class CrankWarpController: playdate.graphics.sprite
SpriteRescueCounter = Class("SpriteRescueCounter", gfx.sprite)

local _instance

function SpriteRescueCounter.getInstance() return _instance end

function SpriteRescueCounter.destroy() _instance = nil end

function SpriteRescueCounter:init()
    SpriteRescueCounter.super.init(self)

    _instance = self

    local image = imagetableSprite[1]
    local spriteWidth = image:getSize()
    for i = 1, maxSpriteCounters do
        local spriteCounter = gfx.sprite.new(image)

        -- Sprite config for

        spriteCounter:setCenter(0, 0)
        spriteCounter:moveTo(400 - i * (spriteWidth + padding), padding)
        spriteCounter:setIgnoresDrawOffset(true)
        spriteCounter:setZIndex(100)

        -- Provide helper function for checking if state set or not set
        spriteCounter.isSet = isSet

        table.insert(spriteCounters, spriteCounter)
    end

    self.rescueSpriteCount = 1
end

function SpriteRescueCounter:add()
    SpriteRescueCounter.super.add(self)

    for i = 1, self.rescueSpriteCount do
        spriteCounters[i]:add()
    end
end

function SpriteRescueCounter:remove()
    SpriteRescueCounter.super.remove(self)

    for i = 1, self.rescueSpriteCount do
        spriteCounters[i]:remove()
    end
end

function SpriteRescueCounter:setRescueSpriteCount(count)
    assert(count < maxSpriteCounters, "max rescuable sprites does not support a number higher than 7.")

    self.rescueSpriteCount = count

    for i, spriteCounter in ipairs(spriteCounters) do
        spriteCounter:setImage(imagetableSprite[1])

        if i <= count then
            spriteCounter:add()
        else
            spriteCounter:remove()
        end
    end
end

function SpriteRescueCounter:setSpriteRescued(number, spriteImageIndex)
    local imageRescued = imageSpriteRescued[spriteImageIndex]
    spriteCounters[self.rescueSpriteCount - number + 1]:setImage(imageRescued)
end

function SpriteRescueCounter:isAllSpritesRescued()
    for i = 1, self.rescueSpriteCount do
        if not spriteCounters[i]:isSet() then
            return false
        end
    end

    return true
end
