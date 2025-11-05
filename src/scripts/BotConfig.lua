local indexFflyMovement = 0
local speedRotationFfly <const> = 3
local speedOscillationFfly <const> = 7
local radiusFflyMovement <const> = 15
local radiusFflyOscillation <const> = 0.3

local function initFfly(self)
    self.positionOriginal = { x = self.x, y = self.y }
end

local function updateFflyMovement(self)
    local angleArc = math.rad(indexFflyMovement) * speedRotationFfly
    local angleOffset = math.rad(indexFflyMovement) * speedOscillationFfly

    local xOffset, yOffset =
        math.cos(angleArc) * radiusFflyMovement * (1 + math.cos(angleOffset) * radiusFflyOscillation),
        math.sin(angleArc) * radiusFflyMovement * (1 + math.cos(angleOffset) * radiusFflyOscillation)

    self:moveTo(self.positionOriginal.x + xOffset, self.positionOriginal.y + yOffset)

    indexFflyMovement += 1
end

---@alias BotConfig {animationSpeed:number, animations: {string:[number, number][]}[]}
---@type {string: BotConfig}
BotConfig = {
    BKPK = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    ELDR = { animationSpeed = 4, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 }, [BOT_ANIMATION_STATES.Happy] = { 9, 12 }, [BOT_ANIMATION_STATES.Sad] = { 13, 16 } } },
    GRN = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    JPL = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    MOP = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 }, [BOT_ANIMATION_STATES.Happy] = { 9, 12 }, [BOT_ANIMATION_STATES.Sad] = { 13, 16 } } },
    SNTRY = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    WOP = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 }, [BOT_ANIMATION_STATES.Happy] = { 9, 12 }, [BOT_ANIMATION_STATES.Sad] = { 13, 16 } } },
    BTL = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    ELF = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 }, [BOT_ANIMATION_STATES.Happy] = { 9, 12 }, [BOT_ANIMATION_STATES.Sad] = { 13, 16 } } },
    HGHT = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    LFS = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    PNG = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 }, [BOT_ANIMATION_STATES.Happy] = { 9, 12 }, [BOT_ANIMATION_STATES.Sad] = { 13, 16 } } },
    SPL = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    YNGR = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    BZ = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    EYES = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    HGL = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    LPL = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    PONY = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    SPR = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    ZUG = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 }, [BOT_ANIMATION_STATES.Happy] = { 9, 12 }, [BOT_ANIMATION_STATES.Sad] = { 13, 16 } } },
    CMT = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    FFLY = { init = initFfly, update = updateFflyMovement, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 2 } } },
    INF = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 }, [BOT_ANIMATION_STATES.Happy] = { 9, 12 }, [BOT_ANIMATION_STATES.Sad] = { 13, 16 } } },
    MIPA = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    RKD = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 } } },
    VRP = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    DGR = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    GPL = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    JPK = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    MNTS = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } },
    RUD = { animationSpeed = 2, animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 4 }, [BOT_ANIMATION_STATES.Talking] = { 5, 8 } } },
    WGHT = { animations = { [BOT_ANIMATION_STATES.Idle] = { 1, 1 } } }
}
