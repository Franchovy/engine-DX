local fileplayer <const> = playdate.sound.fileplayer

---@alias FileToPlay {file: string, loopCount: number, next: number}

---@class FilePlayer
---@field fileplayer playdate.sound.fileplayer
---@field fileCurrent FileToPlay currently playing file
---@field fileQueue FileToPlay[]
---@field files FileToPlay[]
FilePlayer = Class("FilePlayer")


--- Used so that static class syntax looks like it uses instance.
local self = FilePlayer

---@type FileToPlay[]
FilePlayer.fileQueue = {}

---comment
---@param fileplayer _FilePlayer
---@param self FilePlayer
local function _finishCallback(fileplayer, self)
    if #self.fileQueue > 0 then
        ---@type FileToPlay
        local fileNext = table.remove(self.fileQueue, 1)

        local fileplayerNext = fileplayer.new(fileNext.file)

        print("Switching track...")

        local loopCount = fileNext.loopCount
        local next = fileNext.next

        -- Switch over to next track
        fileplayerNext:play(loopCount or 1)
        fileplayerNext:setFinishCallback(_finishCallback, self)

        self.fileplayer = fileplayerNext

        if next then
            -- Add next to queue
            table.insert(self.fileQueue, self.files[next])
        end
    else
        -- Keep repeating this loop
        local loopCount = self.fileCurrent.loopCount

        self.fileplayer:play(loopCount or 1)
    end
end

function FilePlayer.load(config)
    if config.title then
        self.files = MUSIC_CONFIG[config.title].assets
    end

    if config.loop then
        if self.fileplayer == nil then
            -- Load and play this track.
            print("Playing: " .. self.files[config.loop].file)

            self.fileCurrent = self.files[config.loop]
            self.fileplayer = fileplayer.new(self.fileCurrent.file)
        else
            -- Add this track to queue.

            print("Loading: " .. self.files[config.loop].file)

            -- For now, by default just pop the rest of the queue.

            self.fileQueue = {}
            table.insert(self.fileQueue, self.files[config.loop])
        end

        if not self.fileplayer:isPlaying() then
            local loopCount = self.fileCurrent.loopCount
            self.fileplayer:play(loopCount or 1)

            self.fileplayer:setFinishCallback(_finishCallback, self)
        end
    end
end

function FilePlayer.playFiles()
    local file = self.files[1]

    self.fileplayer = fileplayer.new(file)
    self.fileplayer:play(0)
end

function FilePlayer.play(file)
    if self.fileCurrent == file and self.fileplayer:isPlaying() then
        return
    end

    if file == nil and self.fileplayer then
        self.fileplayer:play(0)
        return
    end

    self.fileCurrent = file
    self.fileplayer = fileplayer.new(file)
    self.fileplayer:play(0)
end

function FilePlayer:fadeOut(durationInMs)
    if self.fileplayer then
        self.fileplayer:setVolume(0.0, 0.0, durationInMs / 1000, self.stop, self)
    end
end

function FilePlayer.stop()
    if self.fileplayer then
        self.fileplayer:stop()
    end
end

function FilePlayer.isPlaying()
    return self.fileplayer and self.fileplayer:isPlaying()
end
