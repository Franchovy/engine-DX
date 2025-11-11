local debugDrawCalls = {}

DebugDrawer = {}

function DebugDrawer.addDebugDrawCall(callback)
    table.insert(debugDrawCalls, callback)
end

function playdate.debugDraw()
    for _, drawCalls in pairs(debugDrawCalls) do
        drawCalls()
    end

    --debugDrawCalls = {}
end
