local gfx <const> = playdate.graphics

---@class Decoration : EntityAnimated
Decoration = Class("Decoration", EntityAnimated)

function Decoration:init(data, levelName)
    self.config = DECORATION_ASSETS[data.fields.asset]

    local imagetable = gfx.imagetable.new(self.config.path)
    if not imagetable then
        local image = gfx.image.new(self.config.path)

        ---@cast image _Image
        assert(imagetable or image, "Asset for decoration entity not found!")

        imagetable = gfx.imagetable.new(1)
        imagetable:setImage(1, image)
    end

    EntityAnimated.init(self, data, levelName, imagetable)

    self:addState("d", self.config.startFrame or 1, self.config.endFrame or 1, self.config.animationParams or {})
        .asDefault()

    self:playAnimation()
end

function Decoration:add()
    Decoration.super.add(self)

    if self.config.lightSource then
        GUILightingEffect:addEffect(self, GUILightingEffect.imageSmallCircle)
    end
end

function Decoration:remove()
    Decoration.super.remove(self)

    if self.config.lightSource then
        GUILightingEffect:removeEffect(self)
    end
end
