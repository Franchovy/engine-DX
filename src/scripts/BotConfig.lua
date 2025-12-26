---@alias BotConfig {animationSpeed:number, animations: {string:[number, number][]}[]}
BotConfig = {
    BPK = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 8 }, [BOT_ANIMATION_STATES.Talking] = { 9, 11 } } },
    ELR = { animationSpeed = 4, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 }, [BOT_ANIMATION_STATES.Sad] = { 9, 12 }, [BOT_ANIMATION_STATES.Happy] = { 13, 16 } } },
    GRN = { animationSpeed = 4, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 } } },
    JPL = { animationSpeed = 4, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 } } },
    MOP = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 }, [BOT_ANIMATION_STATES.Sad] = { 9, 12 }, [BOT_ANIMATION_STATES.Happy] = { 13, 16 } } },
    SNT = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 7 } } },
    WOP = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 }, [BOT_ANIMATION_STATES.Sad] = { 9, 12 }, [BOT_ANIMATION_STATES.Happy] = { 13, 16 } } },
    BTL = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 7 } } },
    ELF = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 }, [BOT_ANIMATION_STATES.Sad] = { 9, 12 }, [BOT_ANIMATION_STATES.Happy] = { 13, 16 } } },
    HGH = { animationSpeed = 3, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 } } },
    LFS = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 } } },
    PNG = { voice = "BOT_HIGH", animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 }, [BOT_ANIMATION_STATES.Sad] = { 9, 12 }, [BOT_ANIMATION_STATES.Happy] = { 13, 16 } } },
    SPL = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 7 } } },
    YGR = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    BZ = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    EYZ = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 } } },
    HGL = { animationSpeed = 3, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 } } },
    LPL = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 } } },
    PNY = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 6 }, [BOT_ANIMATION_STATES.Talking] = { 7, 9 } } },
    SPR = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    ZUG = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 }, [BOT_ANIMATION_STATES.Sad] = { 9, 12 }, [BOT_ANIMATION_STATES.Happy] = { 13, 16 } } },
    CMT = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 } } },
    FLT = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 2 } } },
    INF = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 }, [BOT_ANIMATION_STATES.Sad] = { 9, 12 }, [BOT_ANIMATION_STATES.Happy] = { 13, 16 } } },
    MIPA = { animationSpeed = 3, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 } } },
    RKD = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 } } },
    VRP = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    DGR = { animationSpeed = 3, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 } } },
    GPL = { animationSpeed = 4, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 } } },
    JPK = { animationSpeed = 3, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 } } },
    MNT = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 12 } } },
    RUD = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 } } },
    WGT = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 7 } } },
    RWBT = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 } } },
    ["TVR-A"] = { animationSpeed = 3, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 6 }, [BOT_ANIMATION_STATES.Talking] = { 6, 10 } }, offset = { y = -7 } },
    PONG = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 15 } } },
    DRZ = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } }
}

--- FFLY (firefly) Movement on-update

local indexFflyMovement = 0
local speedRotationFfly <const> = 3
local speedOscillationFfly <const> = 7
local radiusFflyMovement <const> = 15
local radiusFflyOscillation <const> = 0.3

function BotConfig.FLT.init(self)
    self.positionOriginal = { x = self.x, y = self.y }
end

function BotConfig.FLT.update(self)
    if self.isActivated or self.isStateExpanded then
        return
    end

    local angleArc = math.rad(indexFflyMovement) * speedRotationFfly
    local angleOffset = math.rad(indexFflyMovement) * speedOscillationFfly

    local xOffset, yOffset =
        math.cos(angleArc) * radiusFflyMovement * (1 + math.cos(angleOffset) * radiusFflyOscillation),
        math.sin(angleArc) * radiusFflyMovement * (1 + math.cos(angleOffset) * radiusFflyOscillation)

    self:moveTo(self.positionOriginal.x + xOffset, self.positionOriginal.y + yOffset)

    for _, child in pairs(self.children) do
        child:moveTo(self.positionOriginal.x, self.positionOriginal.y)
    end

    indexFflyMovement += 1
end
