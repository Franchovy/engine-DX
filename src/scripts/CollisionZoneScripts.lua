CollisionZoneScripts = {
    powerwall = {
        activate = function(self)
            Manager.emitEvent(EVENTS.ChipSetPower, true)
        end
    },
    levelEnd = {
        activate = function(self)
            -- Trigger level end
            Manager.emitEvent(EVENTS.WorldComplete)
        end
    },
    restart = {
        activate = function(self)
            if self.isActivated then
                return
            end

            self.isActivated = true

            local gamepointId = self.args["activate"].gamepoint

            if not gamepointId then return end

            local gamepoint = LDtk.entitiesById[gamepointId]

            if not gamepoint or not gamepoint.sprite then return end

            local player = Player.getInstance()
            if not player then return end

            Game.enableLevelChange = false

            Transition.getInstance():fadeOut(500, function()
                player:moveTo(gamepoint.sprite.x, gamepoint.sprite.y)

                Transition.getInstance():fadeIn(500, function()
                    Game.enableLevelChange = true

                    player:unfreeze()

                    self.isActivated = false
                end)
            end)
        end
    }
}
