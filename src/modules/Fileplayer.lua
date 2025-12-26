local fileplayer <const> = playdate.sound.fileplayer

---@alias FileToPlay {file: string}
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
---@field fileplayer playdate.sound.fileplayer
---@field fileCurrent FileToPlay currently playing file
---@field files FileToPlay[]
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
        self:clear()

        self.files = MUSIC_CONFIG[config.title].assets
        self.loops = MUSIC_CONFIG[config.title].loops
    end

    if config.loop
        and self.files and self.loops -- Ensure a track is loaded.
    then
        if self.isPaused then
            self:clear()
        end

        if self.fileplayer == nil then
            -- If paused / not started, remove current fileplayer and play first loop

            self.loop = config.loop

            self:play()
        else
            -- Add this loop to queue.

            table.insert(self.queue, config.loop)
        end
    end
end

function FilePlayer:init()
    self.volume = 0.7
    self.isPaused = false

    self:clear()

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

function FilePlayer:clear()
    self.fileCurrent = nil
    self.fileplayer = nil
    self.loops = {}
    self.files = {}
    self.queue = {}

    self.loop = 1
    self.loopIndex = 1
    self.loopCount = 1
end

function FilePlayer:setPaused(shouldPause)
    self.isPaused = shouldPause

    if self.fileplayer then
        if shouldPause then
            self.fileplayer:pause()
        else
            self:play()
        end
    end
end

function FilePlayer:isPlaying()
    return self.fileplayer and self.fileplayer:isPlaying()
end

---comment
---@param file string
function FilePlayer:playFile(file)
    self:clear()

    self.fileplayer = fileplayer.new(file)

    self.files = {
        { file = file }
    }

    self.loops = { { { asset = 1 } } }

    self:play()
end

function FilePlayer:play()
    local loop = self.loops[self.loop][self.loopIndex]
    local file = self.files[loop.asset].file

    self.fileplayer = fileplayer.new(file)
    self.fileplayer:play(1)
    self.fileplayer:setFinishCallback(_finishCallback, self)
end
