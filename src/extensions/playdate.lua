playdate.geometry.vector2D.ZERO = playdate.geometry.vector2D.new(0, 0)

--- Class - creates a class object globally.
--- @param name string name of the class
--- @param parentClass? table (optional) parent class to inherit
--- @return table NewClass class instance.
function Class(name, parentClass)
    local newClass = class(name)
    newClass.extends(parentClass)

    return _G[name]
end

function playdate.graphics.sprite:centerOffsetX()
    return self:getCenterPoint().x * self.width
end

function playdate.graphics.sprite:centerOffsetY()
    return self:getCenterPoint().y * self.height
end

function playdate.graphics.sprite:right()
    return self.x - self:centerOffsetX() + self.width
end

function playdate.graphics.sprite:left()
    return self.x - self:centerOffsetX()
end

function playdate.graphics.sprite:top()
    return self.y - self:centerOffsetY()
end

function playdate.graphics.sprite:bottom()
    return self.y - self:centerOffsetY() + self.height
end

function playdate.graphics.sprite:centerX()
    return self.x - self:centerOffsetX() + self.width / 2
end

function playdate.graphics.sprite:centerY()
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
