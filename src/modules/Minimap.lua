local gfx <const> = playdate.graphics
local geo <const> = playdate.geometry

MinimapDrawer = {}

local x, y
---@type _Image?
local image

-- Create minimap
function MinimapDrawer.initialize(minX, minY, width, height)
    x = minX or -1000
    y = minY or -1000
    width = width or 1000
    height = height or 1000

    -- Create image

    image = gfx.image.new(width - x, height - y, gfx.kColorBlack)
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
    elseif mapX - x > image.width then
        -- Too small!
        return
    elseif mapY - y > image.height then
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

---@class Minimap : _Sprite
Minimap = Class("Minimap", gfx.sprite)

local insetMapContent <const> = 32
local speedNavigation <const> = 4

function Minimap:init()
    Minimap.super.init(self)

    self:setIgnoresDrawOffset(true)
    self:setZIndex(Z_INDEX.HUD.Main)
    self:setCenter(0, 0)
    self:setSize(400, 240)
    self:moveTo(0, 0)

    self.imageBorder = gfx.image.new(assets.images.guiMinimap)
    self.rectSourceImageBorder = geo.rect.new(0, 0, 400 - insetMapContent * 2, 240 - insetMapContent * 2)

    self.mapPosition = geo.point.new(0, 0)
end

function Minimap:draw(x, y, width, height)
    if not image then
        return
    end

    -- Draw map contents
    self.rectSourceImageBorder.x = self.mapPosition.x - 200
    self.rectSourceImageBorder.y = self.mapPosition.y - 120

    image:draw(insetMapContent, insetMapContent, 0, self.rectSourceImageBorder)

    -- Draw map border
    self.imageBorder:draw(0, 0)
end

function Minimap:centerOnPlayer()
    local player = Player.getInstance()
    if not player or not image then return end

    local scale = MinimapDrawer.getScale()

    self.mapPosition.x = player.x / scale - x
    self.mapPosition.y = player.y / scale - y
end

function Minimap:navigate(dX, dY)
    self.mapPosition.x -= dX * speedNavigation
    self.mapPosition.y -= dY * speedNavigation
end
