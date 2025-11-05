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
            local gamepoint = self.args["activate"]

            local player = Player.getInstance()
            if player then
                print("Moving player to gamepoint: " .. gamepoint)
            end
        end
    }
}
