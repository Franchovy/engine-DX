local gfx <const> = playdate.graphics

MinimapDrawer = {}

local x, y
---@type _Image?
local image

-- Create minimap
function MinimapDrawer.initialize(minX, minY, width, height)
    x = minX or -1000
    y = minY or -1000
    width = width or 2000
    height = height or 2000

    -- Create image

    image = gfx.image.new(width, height, gfx.kColorBlack)
end

function MinimapDrawer.clear()
    if not image then
        MinimapDrawer.initialize()
    else
        MinimapDrawer.initialize(x, y, image:getSize())
    end
end

function MinimapDrawer.setPoint(mapX, mapY, color)
    assert(image)

    if mapX < x then
        -- Too small!
        return
    elseif mapY < y then
        -- Too small!
        return
    elseif mapX > x + image.width then
        -- Too small!
        return
    elseif mapY > y + image.height then
        -- Too small!
        return
    end

    gfx.pushContext(image)
    gfx.setColor(color)
    gfx.drawPixel(mapX - x, mapY - y)
    gfx.popContext()
end

function MinimapDrawer.getImage()
    return image
end

function MinimapDrawer.getScale()
    return 8
end
