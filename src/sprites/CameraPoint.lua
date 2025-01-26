local gfx <const> = playdate.graphics

--- @class CameraPoint : playdate.graphics.sprite
CameraPoint = Class("CameraPoint", gfx.sprite)

function CameraPoint:init()
    CameraPoint.super.init(self)

    self.isActive = true
end

function CameraPoint:update()
    if self.isActive then
        Camera.goToPoint(self.x - 200, self.y - 120)

        self.isActive = false
    end
end
