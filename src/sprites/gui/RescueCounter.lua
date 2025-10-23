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

local maxSpriteCounters <const> = 7
local spriteCounters <const> = {}

---@type {number:{value:boolean?, indexSpriteImage:number}}
local stateSpriteCounters = {}

---@class SpriteRescueCounter : _Sprite
SpriteRescueCounter = Class("SpriteRescueCounter", gfx.sprite)

-- Static Methods

function SpriteRescueCounter.loadProgressData(progressDataRescues)
    if progressDataRescues.rescuedSprites then
        local spriteRescueCounter = SpriteRescueCounter.getInstance()

        spriteRescueCounter:loadRescuedSprites(progressDataRescues.rescuedSprites)

        spriteRescueCounter:setPositionsSpriteCounter()
    end
end

-- Instance Methods

local _instance

function SpriteRescueCounter.getInstance() return _instance end

function SpriteRescueCounter:init()
    SpriteRescueCounter.super.init(self)

    _instance = self

    local image = imagetableSprite[1]
    for i = 1, maxSpriteCounters do
        local spriteCounter = gfx.sprite.new(image)

        -- Sprite config for each rescuable sprite

        spriteCounter:setCenter(0, 0)
        spriteCounter:setIgnoresDrawOffset(true)
        spriteCounter:setZIndex(Z_INDEX.HUD.Main)

        table.insert(spriteCounters, i, spriteCounter)
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
    assert(count < maxSpriteCounters,
        "max rescuable sprites does not support a number higher than " .. maxSpriteCounters .. ".")

    self.rescueSpriteCount = count

    for i, spriteCounter in ipairs(spriteCounters) do
        -- Reset image state
        spriteCounter:setImage(imagetableSprite[1])

        if i <= count then
            -- Set rescuable
            stateSpriteCounters[i] = { value = false }

            spriteCounter:add()
        else
            -- Set not rescuable
            stateSpriteCounters[i] = nil

            spriteCounter:remove()
        end
    end
end

function SpriteRescueCounter:setPositionsSpriteCounter()
    local spriteWidth = imagetableSprite[1]:getSize()
    local startX = 400 - self.rescueSpriteCount * (spriteWidth + padding)
    for i = 1, self.rescueSpriteCount do
        local spriteCounter = spriteCounters[i]

        spriteCounter:moveTo(startX + (i - 1) * (spriteWidth + padding), padding)
    end
end

function SpriteRescueCounter:resetSpriteRescued(indexSpriteCounter)
    -- Create state table if not exists
    if not stateSpriteCounters[indexSpriteCounter] then
        stateSpriteCounters[indexSpriteCounter] = {}
    end

    -- Reset states
    stateSpriteCounters[indexSpriteCounter].value = false
    stateSpriteCounters[indexSpriteCounter].indexSpriteImage = nil

    local spriteCounter = spriteCounters[indexSpriteCounter]

    -- Reset image

    spriteCounter:setImage(imagetableSprite[1])
end

function SpriteRescueCounter:setSpriteRescued(number, spriteImageIndex)
    local indexSpriteCounter = number

    -- Create state table if not exists
    if not stateSpriteCounters[indexSpriteCounter] then
        stateSpriteCounters[indexSpriteCounter] = {}
    end

    -- Set states
    stateSpriteCounters[indexSpriteCounter].value = true
    stateSpriteCounters[indexSpriteCounter].indexSpriteImage = spriteImageIndex

    local spriteCounter = spriteCounters[indexSpriteCounter]

    -- Set image
    local imageRescued = imageSpriteRescued[spriteImageIndex]
    spriteCounter:setImage(imageRescued)
end

function SpriteRescueCounter:loadRescuedSprites(rescuedSprites)
    self:setRescueSpriteCount(#rescuedSprites)

    -- Clear current rescue states
    for i = 1, #stateSpriteCounters do
        stateSpriteCounters[i] = nil
    end

    -- Set new rescue states
    for i, state in pairs(rescuedSprites) do
        if state.value then
            self:setSpriteRescued(i, state.indexSpriteImage)
        else
            self:resetSpriteRescued(i)
        end
    end
end

function SpriteRescueCounter:reset()
    -- Clear rescued sprites
    stateSpriteCounters = {}

    self.rescueSpriteCount = 0
end

function SpriteRescueCounter:getRescuedSprites()
    return stateSpriteCounters
end

function SpriteRescueCounter:isAllSpritesRescued()
    for _, state in ipairs(stateSpriteCounters) do
        if not state or state.value == false then
            return false
        end
    end

    return true
end
