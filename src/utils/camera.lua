local geo <const> = playdate.geometry
local gfx <const> = playdate.graphics

Camera = {}

-- Local constants

local viewOffsetXDefault <const> = 200
local viewOffsetYDefault <const> = 140

-- Local variables

---@type {x:number, y:number}
local offsetTarget = { x = 0, y = 0 }

---@type {x:number, y:number}?
local focusPoint
local isSoftFocus = false

---@type {x:number, y:number}
local offsetView = {
    x = viewOffsetXDefault,
    y = viewOffsetYDefault
}

local zoom = 1

local drawOffsetTarget = geo.point.new(0, 0)

-- Independently track level bounds and draw offset.

local levelBounds
local xDrawOffset, yDrawOffset = 0, 0

-- Static Methods

function Camera.enterLevel(levelNew)
    levelBounds = LDtk.get_rect(levelNew)

    -- Set draw offset without animation
    Camera.setOffsetInstantaneous()
end

function Camera.reset()
    -- Reset config values.

    focusPoint = nil
    offsetView.x = viewOffsetXDefault
    offsetView.y = viewOffsetYDefault
end

function Camera.load(config)
    if config.offset then
        offsetView.x = viewOffsetXDefault + (config.offset.x or 0)
        offsetView.y = viewOffsetYDefault + (config.offset.y or 0)
    else
        offsetView.x = viewOffsetXDefault
        offsetView.y = viewOffsetYDefault
    end

    if config.focus or config.softFocus then
        -- Load gamepoint x, y
        local gamepoint = LDtk.entitiesById[config.focus or config.softFocus]

        if gamepoint and gamepoint.sprite then
            focusPoint = { x = gamepoint.sprite.x, y = gamepoint.sprite.y }
            isSoftFocus = config.softFocus ~= nil
        end
    else
        focusPoint = nil
    end
end

function Camera.setZoom(zoomNew)
    assert(zoomNew == 1 or zoomNew == 2 or zoomNew == 4 or zoomNew == 8,
        "Error: Only powers of 2 are supported for now.")
    zoom = zoomNew

    playdate.display.setScale(zoomNew)
end

function Camera.setOffset(x, y)
    -- Skip if target offset is the same as current.

    offsetTarget.x = x
    offsetTarget.y = y

    --[[
        xOffsetTarget, yOffsetTarget = x, y
    offsetAnimator = gfx.animator.new(
        600,
        currentPoint,
        geo.point.new(xOffsetTarget, yOffsetTarget),
        playdate.easingFunctions.outExpo
    )
    ]]
end

function Camera.update()
    -- Update tracking values

    xDrawOffset, yDrawOffset = gfx.getDrawOffset()

    -- Calculate draw offset target

    Camera.calculateDrawOffsetTarget()

    local xDrawOffsetSmoothed, yDrawOffsetSmoothed =
        xDrawOffset + (drawOffsetTarget.x - xDrawOffset) * 0.2,
        yDrawOffset + (drawOffsetTarget.y - yDrawOffset) * 0.2

    gfx.setDrawOffset(xDrawOffsetSmoothed, yDrawOffsetSmoothed)
end

function Camera.setOffsetInstantaneous()
    Camera.calculateDrawOffsetTarget()

    gfx.setDrawOffset(drawOffsetTarget:unpack())
end

function Camera.getDrawOffset()
    return xDrawOffset, yDrawOffset
end

function Camera.calculateDrawOffsetTarget()
    -- Camera Focus

    local xIdeal, yIdeal
    local player = Player.getInstance()

    local offsetViewX, offsetViewY = offsetView.x / zoom, offsetView.y / zoom
    local displayWidth, displayHeight = 400 / zoom, 240 / zoom

    if focusPoint then
        if isSoftFocus and player then
            -- Balance Focus point and Player

            xIdeal, yIdeal = (focusPoint.x + player.x) / 2 - offsetViewX, (focusPoint.y + player.y) / 2 - offsetViewY
        else
            -- Fix on Focus point

            xIdeal, yIdeal = focusPoint.x - offsetViewX, focusPoint.y - offsetViewY
        end
    elseif player then
        -- Fix on Player

        xIdeal, yIdeal = player.x - offsetViewX, player.y - offsetViewY
    else
        -- Nothing to focus on. Skip altogether.

        return
    end

    -- If no focus point is active, then allow panning up/down

    if not focusPoint then
        xIdeal, yIdeal = xIdeal - offsetTarget.x, yIdeal - offsetTarget.y
    end

    -- Positon camera within level bounds

    local xCameraOffset = math.max(math.min(xIdeal, levelBounds.right - displayWidth), levelBounds.x)
    local yCameraOffset = math.max(math.min(yIdeal, levelBounds.bottom - displayHeight), levelBounds.y)

    -- Center offset for small levels

    local xLevelBounds = levelBounds.width < displayWidth and (displayWidth - levelBounds.width) / 2 or 0
    local yLevelBounds = levelBounds.height < displayHeight and (displayHeight - levelBounds.height) / 2 or 0

    local xCameraOffsetBounded = -xCameraOffset + xLevelBounds
    local yCameraOffsetBounded = -yCameraOffset + yLevelBounds

    drawOffsetTarget.x, drawOffsetTarget.y = xCameraOffsetBounded, yCameraOffsetBounded
end
