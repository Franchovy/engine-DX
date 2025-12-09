CollisionZoneScripts = {
    gamepoint = {
        activate = function(self)
            self.super.activate(self)

            if self.isActivatedPrevious then
                return
            end

            local idGamepoint = self.args["activate"]
            if idGamepoint and LDtk.entitiesById[idGamepoint] and LDtk.entitiesById[idGamepoint].sprite then
                ---@type GamePoint
                local gamepoint = LDtk.entitiesById[idGamepoint].sprite
                gamepoint:load()
            end
        end
    },
    loadConfig = {
        activate = function(self)
            self.super.activate(self)

            if self.isActivatedPrevious then
                return
            end

            ConfigHandler.loadConfig(self.args["activate"])
        end
    },
    loadConfigOnExit = {
        onExit = function(self)
            ConfigHandler.loadConfig(self.args["onExit"])
        end
    },
    powerwall = {
        activate = function(self)
            self.super.activate(self)

            Manager.emitEvent(EVENTS.ChipSetPower, true)
        end
    },
    levelEnd = {
        activate = function(self)
            self.super.activate(self)

            -- Trigger level end
            Manager.emitEvent(
                EVENTS.WorldComplete,
                self.args["activate"] ~= true
                and self.args["activate"]
                or nil
            )
        end
    },
    restart = {
        activate = function(self)
            self.super.activate(self)

            if self.isActivatedPrevious then
                return
            end

            local gamepointId = self.args["activate"]

            if not gamepointId then return end

            local gamepoint = LDtk.entitiesById[gamepointId]

            if not gamepoint or not gamepoint.sprite then return end

            local player = Player.getInstance()
            if not player then return end

            Game.enableLevelChange = false

            Transition.getInstance():fadeOut(1000, function()
                playdate.timer.performAfterDelay(2000, function()
                    player:moveTo(gamepoint.sprite.x, gamepoint.sprite.y)
                    Camera.setOffsetInstantaneous()

                    Transition.getInstance():fadeIn(500, function()
                        Game.enableLevelChange = true

                        player:unfreeze()

                        self.isActivated = false
                    end)
                end
                )
            end)
        end
    },
    showCrankIndicator = {
        activate = function(self)
            self.super.activate(self)

            _G.showCrankIndicator = true
        end
    },
    activateBot = {
        activate = function(self)
            self.super.activate(self)

            if self.isActivatedPrevious then
                return
            end

            local botId = self.args["activate"].id
            local bot = botId and LDtk.entitiesById[botId]
            local part = self.args["activate"].part
            local spriteBot = bot and bot.sprite

            if spriteBot then
                if part then
                    spriteBot:setPart(part)
                end

                spriteBot.dialogState = 'unopened'
                spriteBot:activate()
            end
        end
    }
}
