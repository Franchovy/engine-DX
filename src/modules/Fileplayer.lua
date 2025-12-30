local fileplayer <const> = playdate.sound.fileplayer

---@alias Loop {asset: integer, count: integer}[]

-- Local functions

---comment
---@param fileplayer _FilePlayer
---@param self FilePlayer
local function _finishCallback(fileplayer, self)
    local loop = self.loops[self.loop]
    local track = loop[self.loopIndex]

    if track.count and self.loopCount < track.count then
        -- Track in progress
        self.loopCount += 1
    else
        -- Track finished

        self.loopCount = 1

        if self.loopIndex < #loop then
            -- Go to next track
            self.loopIndex += 1
        else
            self.loopIndex = 1

            if #self.queue > 0 then
                -- Play next loop

                local nextLoop = table.remove(self.queue, 1)
                self.loop = nextLoop
                self.loopIndex = 1
            end
        end
    end

    self:play()
end

---@class FilePlayer
---@field fileplayer _FilePlayer
---@field fileplayers _FilePlayer[]
---@field loops Loop[]
---@field loop integer
---@field loopIndex integer
---@field queue number[]
FilePlayer = Class("FilePlayer")

local _instance

---@return FilePlayer
function FilePlayer.getInstance()
    return assert(_instance)
end

function FilePlayer.destroy()
    _instance = nil
end

function FilePlayer.load(config)
    --- Load instance since this is a static call
    local self = _instance

    if config.title then
        self:clearTrack()

        -- Load files into fileplayers
        for i, asset in ipairs(MUSIC_CONFIG[config.title].assets) do
            local fileplayerNew = fileplayer.new(asset)
            table.insert(self.fileplayers, fileplayerNew)

            -- Trigger initial load for fileplayer
            fileplayerNew:play()
            fileplayerNew:pause()
        end

        self.loops = MUSIC_CONFIG[config.title].loops
    end

    if config.loop
        and self.fileplayers and self.loops -- Ensure a track is loaded.
    then
        if self.fileplayer == nil or self.isPaused then
            -- If paused / not started, remove current fileplayer and play first loop

            self.loop = config.loop

            if not self.isPaused then
                self:play()
            else
                -- Reset to new loop head
                self:resetLoop()
            end
        else
            -- Add this loop to queue.

            table.insert(self.queue, config.loop)
        end
    end
end

function FilePlayer:init()
    self.volume = 0.7
    self.isPaused = false

    self:clearTrack()

    ---@type _FilePlayer?
    self.fileplayer = nil

    _instance = self
end

function FilePlayer:fadeOut(durationInMs)
    if self.fileplayer then
        self.fileplayer:setVolume(0.0, 0.0, durationInMs / 1000, self.stop, self)
    end
end

function FilePlayer:stop()
    if self.fileplayer then
        self.fileplayer:stopWithoutCallback()
        self.fileplayer = nil
    end
end

function FilePlayer:clearTrack()
    self.fileplayer = nil
    self.fileplayers = {}
    self.loops = {}
    self.queue = {}

    self.loop = 1
    self.loopIndex = 1
    self.loopCount = 1
end

function FilePlayer:resetLoop()
    -- Clear queue
    self.queue = {}

    -- Set track to loop head
    self.loopIndex = 1
    self.loopCount = 1
end

function FilePlayer:setPaused(shouldPause, shouldPlay)
    self.isPaused = shouldPause

    if shouldPause then
        if self.fileplayer then
            self.fileplayer:pause()
        end
    end

    if not shouldPause and shouldPlay then
        self:play()
    end
end

function FilePlayer:isPlaying()
    return self.fileplayer and self.fileplayer:isPlaying()
end

---comment
---@param file string
function FilePlayer:playFile(file)
    self:clearTrack()

    self.fileplayer = fileplayer.new(file)

    self.fileplayers = { self.fileplayer }

    self.loops = { { { asset = 1 } } }

    self:play()
end

function FilePlayer:play()
    local loop = self.loops[self.loop][self.loopIndex]
    self.fileplayer = self.fileplayers[loop.asset]

    self.fileplayer:play(1)
    self.fileplayer:setFinishCallback(_finishCallback, self)
end
