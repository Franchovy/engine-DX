local gfx <const> = playdate.graphics

---@class Decoration : EntityAnimated
Decoration = Class("Decoration", EntityAnimated)

function Decoration:init(data, levelName)
    self.config = DECORATION_ASSETS[data.fields.asset]

    local imagetable = assert(gfx.imagetable.new(self.config.path),
        "Asset for decoration entity not found!")

    EntityAnimated.init(self, data, levelName, imagetable)

    self:addState("d", self.config.startFrame, self.config.endFrame, self.config.animationParams).asDefault()

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
