local gfx <const> = playdate.graphics

---@class ParentSprite : _Sprite
ParentSprite = {}

local function _performOnChildren(sprite, fun, ...)
    if not sprite.children then
        return
    end

    for _, child in pairs(sprite.children) do
        child[fun](child, ...)
    end
end

function ParentSprite:addChild(childSprite)
    if not self.children then
        self.children = {}
    end

    table.insert(self.children, childSprite)
end

function ParentSprite:add()
    gfx.sprite.add(self)

    _performOnChildren(self, "add")
end

function ParentSprite:remove()
    gfx.sprite.remove(self)

    _performOnChildren(self, "remove")
end

function ParentSprite:moveTo(x, y)
    gfx.sprite.moveTo(self, x, y)

    _performOnChildren(self, "moveTo")
end

function ParentSprite:moveBy(dx, dy)
    gfx.sprite.moveBy(self, dx, dy)

    _performOnChildren(self, "moveBy")
end

function ParentSprite:moveWithCollisions(goalX, goalY)
    local actualX, actualY, collisions, collisionCount = gfx.sprite.moveWithCollisions(self, goalX, goalY)

    _performOnChildren(self, "moveTo", actualX, actualY)

    return actualX, actualY, collisions, collisionCount
end
