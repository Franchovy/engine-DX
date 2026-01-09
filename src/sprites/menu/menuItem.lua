local gfx <const> = playdate.graphics

local image <const> = assert(gfx.image.new(assets.images.menuItem))

---@class MenuItem : _Sprite
MenuItem = Class("MenuItem", gfx.sprite)

function MenuItem:init(menuItemText)
    local textImage = gfx.imageWithText(menuItemText, 170, 40, nil, nil, nil, kTextAlignment.left, Fonts.Menu.Medium)
    local image = image:copy()

    gfx.pushContext(image)
    textImage:draw(22, 10)
    gfx.popContext()

    self.baseImage = image

    MenuItem.super.init(self, self.baseImage:invertedImage())
end

function MenuItem:setSelected(shouldSelect)
    local image = shouldSelect and self.baseImage or self.baseImage:invertedImage()

    self:setImage(image)
end
