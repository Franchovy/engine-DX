local gfx <const> = playdate.graphics

---@class GuiSprite : _Sprite
---@field instance GuiSprite
GuiSprite = Class("GuiSprite", gfx.sprite)

function GuiSprite:init()
    -- Instance already exists!
    if self.super.instance then return self.super.instance end

    GuiSprite.super.init(self)

    -- Create static reference to self
    self.super.instance = self
end

-- Static Methods

--- Returns the singleton instance of the GuiSprite.
--- @return GuiSprite
function GuiSprite:getInstance() return assert(self.instance, "Instance of GUI class needs to be created!") end

function GuiSprite:destroy()
    if self.instance then
        self.instance:remove()
        self.instance = nil
    end
end
