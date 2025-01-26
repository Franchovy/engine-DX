local geo <const> = playdate.geometry
local gfx <const> = playdate.graphics

Camera = {}

local viewpoint
local animatorViewpoint
local levelBounds

function Camera.goToPoint(x, y)
    viewpoint = geo.point.new(-x, -y)
end

function Camera.enterLevel(levelNew)
    levelBounds = LDtk.get_rect(levelNew)
end

function Camera.update()
    -- Fix on player
    local player = Player.getInstance()

    if not player then
        return
    end

    local playerX, playerY = player.x, player.y
    local idealX, idealY = playerX - 200, playerY - 100

    -- Positon camera within level bounds

    local cameraOffsetX = math.max(math.min(idealX, levelBounds.right - 400), levelBounds.x)
    local cameraOffsetY = math.max(math.min(idealY, levelBounds.bottom - 240), levelBounds.y)

    -- Center offset for small levels

    local centerOffsetX = levelBounds.width < 400 and (400 - levelBounds.width) / 2 or 0
    local centerOffsetY = levelBounds.height < 240 and (240 - levelBounds.height) / 2 or 0

    local playerCameraX = -cameraOffsetX + centerOffsetX
    local playerCameraY = -cameraOffsetY + centerOffsetY

    if viewpoint and not animatorViewpoint then
        -- Interpolate between player camera point and viewpoint
        local playerCameraPoint = geo.point.new(playerCameraX, playerCameraY)
        animatorViewpoint = gfx.animator.new(1200, playerCameraPoint, viewpoint, playdate.easingFunctions.inOutQuad, 500)
    end

    if animatorViewpoint then
        gfx.setDrawOffset(animatorViewpoint:currentValue():unpack())

        if animatorViewpoint:ended() then
            playdate.timer.performAfterDelay(2500, function()
                animatorViewpoint = nil
                viewpoint = nil
            end)
        end
    else
        gfx.setDrawOffset(playerCameraX, playerCameraY)
    end
end
