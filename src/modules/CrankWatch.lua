CrankWatch = {
    crankMaxThreshold = 30,
    crankChange = 0
}

function CrankWatch.update()
    CrankWatch.crankChange = playdate.getCrankChange()
end

function CrankWatch.getDidPassThreshold()
    return math.abs(CrankWatch.crankChange) > CrankWatch.crankMaxThreshold
end

function CrankWatch.getThresholdProportion()
    return math.max(0, 1 - (math.abs(CrankWatch.crankChange) / CrankWatch.crankMaxThreshold))
end
