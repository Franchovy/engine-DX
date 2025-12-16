local fileplayer <const> = playdate.sound.fileplayer

---@alias FileToPlay {file: string, loopCount: number, next: number}

---comment
---@param fileplayer _FilePlayer
---@param self FilePlayer
local function _finishCallback(fileplayer, self)
    if #self.fileQueue > 0 then
        ---@type FileToPlay
        local fileNext = table.remove(self.fileQueue, 1)

        self:play(fileNext)
    else
        -- Keep repeating this loop
        local loopCount = self.fileCurrent.loopCount

        if not self.isPaused and self.fileplayer then
            self.fileplayer:play(loopCount or 1)
        end
    end
end

---@class FilePlayer
---@field fileplayer playdate.sound.fileplayer
---@field fileCurrent FileToPlay currently playing file
---@field fileQueue FileToPlay[]
---@field files FileToPlay[]
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
    self = _instance

    if config.title then
        self.files = MUSIC_CONFIG[config.title].assets
        self:clear()
    end

    if config.loop
        and self.files -- Ensure a track is loaded.
    then
        if self.isPaused then
            -- If paused, remove current fileplayer and queue

            self:clear()
            self:play(self.files[config.loop])
        elseif self.fileplayer == nil then
            -- Load and play this track.

            self:play(self.files[config.loop])
        else
            -- Add this track to queue.

            if not self.fileQueue then
                self.fileQueue = {}
            end

            table.insert(self.fileQueue, self.files[config.loop])
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
    self.fileQueue = {}
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
---@param fileConfig FileToPlay?
function FilePlayer:play(fileConfig)
    if fileConfig then
        self.fileCurrent = fileConfig
    end

    local fileplayer = fileplayer.new(self.fileCurrent.file)
    fileplayer:setVolume(self.volume)

    local loopCount = self.fileCurrent.loopCount
    local next = self.fileCurrent.next

    -- Switch over to next track
    if not self.isPaused then
        fileplayer:play(loopCount or 1)
    end

    fileplayer:setFinishCallback(_finishCallback, self)

    self.fileplayer = fileplayer

    if next then
        -- Add next to queue
        table.insert(self.fileQueue, self.files[next])
    end
end
