-- SuperFilePlayer, by Franchovy
-- Written on Sunday 21 April 2024 at 7:41 AM with no sleep
-- Hooray for Game Jams!!

local fileplayer <const> = playdate.sound.fileplayer

SuperFilePlayer = Class("SuperFilePlayer")

local function finishedCallback(self, i)
    local nextIndex = #self.fileplayers < i + 1 and 1 or i + 1

    self.currentFilePlayer = self.fileplayers[nextIndex]
    self.currentFilePlayer:play(self.playConfig[i].repeatCount)
end

function SuperFilePlayer:init()
    self.fileplayers = {}
    self.playConfig = {}
    self.currentFilePlayer = nil
end

function SuperFilePlayer:loadFiles(...)
    for i, path in ipairs({ ... }) do
        local fileplayer = assert(fileplayer.new(path), "No sound file found in " .. path)
        fileplayer:setFinishCallback(function() finishedCallback(self, i) end)

        self.fileplayers[i] = fileplayer
    end
end

function SuperFilePlayer:setPlayConfig(...)
    for i, repeatCount in ipairs({ ... }) do
        local config = {
            repeatCount = repeatCount
        }

        self.playConfig[i] = config
    end
end

function SuperFilePlayer:play()
    assert(#self.fileplayers > 0, "No files to play.")
    assert(#self.fileplayers == #self.playConfig, "Invalid Config Files.")

    self.currentFilePlayer = self.fileplayers[1]
    self.currentFilePlayer:play(self.playConfig[1].repeatCount)
end

function SuperFilePlayer:stop()
    if self.currentFilePlayer then
        self.currentFilePlayer:stopWithoutCallback()
    end

    self.currentFilePlayer = nil
end
