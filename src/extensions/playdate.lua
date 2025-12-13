playdate.geometry.vector2D.ZERO = playdate.geometry.vector2D.new(0, 0)

--- Class - creates a class object globally.
--- @param name string name of the class
--- @param parentClass? table (optional) parent class to inherit
--- @return table NewClass class instance.
function Class(name, parentClass, ...)
    local newClass = class(name, ...)
    newClass.extends(parentClass)

    return _G[name]
end

function Object:implements(module)
    -- Simply loop over the functionality in "module" and assign to the object.

    for k, v in pairs(module) do
        -- Check we are not overriding other functionality
        -- assert(self[k], "Error: Overriding existing functionality!")
        if not self[k] then
            -- Assign value to class using key.
            self[k] = v
        end
    end
end

-- Shortcut for checking if sprite has group

function playdate.graphics.sprite:hasGroup(group)
    return self:getGroupMask() & 2 ^ (group - 1) ~= 0
end

-- Shortcut layout methods for playdate.graphics.sprite

function playdate.graphics.sprite:centerOffsetX()
    ---@cast self _Sprite
    return self:getCenterPoint().x * self.width
end

function playdate.graphics.sprite:centerOffsetY()
    ---@cast self _Sprite
    return self:getCenterPoint().y * self.height
end

function playdate.graphics.sprite:right()
    ---@cast self _Sprite
    return self.x - self:centerOffsetX() + self.width
end

function playdate.graphics.sprite:left()
    ---@cast self _Sprite
    return self.x - self:centerOffsetX()
end

function playdate.graphics.sprite:top()
    ---@cast self _Sprite
    return self.y - self:centerOffsetY()
end

function playdate.graphics.sprite:bottom()
    ---@cast self _Sprite
    return self.y - self:centerOffsetY() + self.height
end

function playdate.graphics.sprite:centerX()
    ---@cast self _Sprite
    return self.x - self:centerOffsetX() + self.width / 2
end

function playdate.graphics.sprite:centerY()
    ---@cast self _Sprite
    return self.y - self:centerOffsetY() + self.height / 2
end

function playdate.graphics.image:getImageHash()
    local width, height = self:getSize()
    local prime = 16777619 -- A large prime number

    local hash = 0
    for y = 0, width do
        for x = 0, height do
            local pixelValue = self:sample(x, y) + 1

            -- Combine the current hash with the pixel value using bitwise operations and modular arithmetic
            hash = math.tointeger(hash * prime) ~ math.tointeger(pixelValue * prime)
            hash %= 100000000 -- Modulo to keep the hash within 32 bits
        end
    end

    return hash
end

--- Animator stubs
--- 

---@class _Animator
---@field endValue _Point|number
---@field startValue _Point|number
---@field change _Point|number