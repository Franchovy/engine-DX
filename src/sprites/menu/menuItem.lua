local gfx <const> = playdate.graphics

local image <const> = assert(gfx.image.new(assets.images.menuItem))

---@class MenuItem : _Sprite
MenuItem = Class("MenuItem", gfx.sprite)

function MenuItem:init(menuItemText, callback)
    local textImage = gfx.imageWithText(menuItemText, 190, 40, nil, nil, nil, kTextAlignment.left, Fonts.Menu.Medium)
    local image = image:copy()

    gfx.pushContext(image)
    textImage:draw(22, 10)
    gfx.popContext()

    self.baseImage = image

    self.callback = callback

    MenuItem.super.init(self, self.baseImage:invertedImage())

    self:setZIndex(Z_INDEX.HUD.Main)
end

function MenuItem:setSelected(shouldSelect)
    local image = shouldSelect and self.baseImage or self.baseImage:invertedImage()

    self:setImage(image)
end

function MenuItem:performCallback()
    self.callback()
end
