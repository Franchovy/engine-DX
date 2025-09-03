local gfx <const> = playdate.graphics

--- @class CameraPoint : Entity
CameraPoint = Class("CameraPoint", Entity)

function CameraPoint:init(entityData, levelName)
    CameraPoint.super.init(self, entityData, levelName)

    self.isActive = true
end

function CameraPoint:update()
    if self.isActive then
        Camera.goToPoint(self.x - 200, self.y - 120)

        self.isActive = false
    end
end
