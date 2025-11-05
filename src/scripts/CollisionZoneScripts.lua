CollisionZoneScripts = {
    loadConfig = {
        activate = function(self)
            self.super.activate(self)

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

            local gamepointId = self.args["activate"].gamepoint

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
    }
}
