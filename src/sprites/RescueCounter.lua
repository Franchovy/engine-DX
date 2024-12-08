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
local stateSpriteCounters <const> = {}

---@class SpriteRescueCounter: playdate.graphics.sprite
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
        spriteCounter:setZIndex(Z_INDEX.HUD.Main)

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
        -- Reset image state
        spriteCounter:setImage(imagetableSprite[1])

        if i <= count then
            -- Set rescuable
            stateSpriteCounters[i] = false

            spriteCounter:add()
        else
            -- Set not rescuable
            stateSpriteCounters[i] = nil

            spriteCounter:remove()
        end
    end
end

function SpriteRescueCounter:setSpriteRescued(number, spriteImageIndex)
    local indexSpriteCounter = self.rescueSpriteCount - number + 1

    -- Set state
    stateSpriteCounters[indexSpriteCounter] = true

    local spriteCounter = spriteCounters[indexSpriteCounter]

    -- Set image
    local imageRescued = imageSpriteRescued[spriteImageIndex]
    spriteCounter:setImage(imageRescued)
end

function SpriteRescueCounter:getRescuedSprites()
    return stateSpriteCounters
end

function SpriteRescueCounter:isAllSpritesRescued()
    for _, state in ipairs(stateSpriteCounters) do
        if state == false then
            return false
        end
    end

    return true
end
