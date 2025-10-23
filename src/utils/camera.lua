local geo <const> = playdate.geometry
local gfx <const> = playdate.graphics

Camera = {}

local viewpoint
local animatorViewpoint
local levelBounds
--- @type playdate.graphics.animator | nil
local offsetAnimator
local xOffsetTarget, yOffsetTarget = 0, 0

function Camera.goToPoint(x, y)
    viewpoint = geo.point.new(-x, -y)
end

function Camera.enterLevel(levelNew)
    levelBounds = LDtk.get_rect(levelNew)
end

function Camera.setOffset(x, y)
    -- Skip if target offset is the same as current.

    if xOffsetTarget == x and yOffsetTarget == y then
        return
    end

    ---@type number|_Point
    local currentPoint = geo.point.new(0, 0)

    if offsetAnimator then
        currentPoint = offsetAnimator:currentValue()
    end

    -- Else, add an animator from current offset point to target.

    xOffsetTarget, yOffsetTarget = x, y
    offsetAnimator = gfx.animator.new(
        600,
        currentPoint,
        geo.point.new(xOffsetTarget, yOffsetTarget),
        playdate.easingFunctions.outExpo
    )
end

function Camera.update()
    -- Fix on player

    local player = Player.getInstance()

    if not player then
        return
    end

    local xPlayer, yPlayer = player.x, player.y
    local xIdeal, yIdeal = xPlayer - 200, yPlayer - 100

    if offsetAnimator then
        local value = offsetAnimator:currentValue()
        xIdeal, yIdeal = xIdeal - value.x, yIdeal - value.y
    end

    -- Positon camera within level bounds

    local xCameraOffset = math.max(math.min(xIdeal, levelBounds.right - 400), levelBounds.x)
    local yCameraOffset = math.max(math.min(yIdeal, levelBounds.bottom - 240), levelBounds.y)

    -- Center offset for small levels

    local xLevelBounds = levelBounds.width < 400 and (400 - levelBounds.width) / 2 or 0
    local yLevelBounds = levelBounds.height < 240 and (240 - levelBounds.height) / 2 or 0

    local xCameraOffsetBounded = -xCameraOffset + xLevelBounds
    local yCameraOffsetBounded = -yCameraOffset + yLevelBounds

    if viewpoint and not animatorViewpoint then
        -- Interpolate between player camera point and viewpoint
        local playerCameraPoint = geo.point.new(xCameraOffsetBounded, yCameraOffsetBounded)
        animatorViewpoint = gfx.animator.new(1200, playerCameraPoint, viewpoint, playdate.easingFunctions.inOutQuad, 500)
    end

    if animatorViewpoint then
        local offset = animatorViewpoint:currentValue()
        ---@cast offset -number
        gfx.setDrawOffset(offset:unpack())

        if animatorViewpoint:ended() then
            playdate.timer.performAfterDelay(2500, function()
                animatorViewpoint = nil
                viewpoint = nil
            end)
        end
    else
        gfx.setDrawOffset(xCameraOffsetBounded, yCameraOffsetBounded)
    end
end
