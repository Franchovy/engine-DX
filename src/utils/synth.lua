Synth = Class("Synth")

function Synth:init(scale, bleepsPerSecond)
    -- Set scale
    self.scale = scale or SCALES.DEFAULT
    self.tempo = bleepsPerSecond or 9

    -- Create synth
    self.synth = playdate.sound.synth.new()

    -- Create sequence
    self.sequence = playdate.sound.sequence.new()
    self.sequence:setTempo(self.tempo)

    -- Create track
    self.track = self.sequence:addTrack()
    self.track:setInstrument(self.synth)
end

function Synth:setVoice(scale)
    self.scale = scale or SCALES.DEFAULT
end

function Synth:play(note)
    local note = note or math.random(1, 12)

    self.synth:playNote(self.scale[note], 1.0, 0.1)
end

function Synth:playNotes(notes, bleepsPerSecond)
    local notesToPlay
    if type(notes) == "number" then
        -- Fill out `notes` number of notes to play.
        notesToPlay = {}

        for i = 1, notes do
            table.insert(notesToPlay, math.random(1, 12))
        end
    else
        notesToPlay = notes
    end

    -- Clear track, add notes to track

    self.track:clearNotes()
    self.sequence:setTempo(bleepsPerSecond or self.tempo)

    for i, note in ipairs(notesToPlay) do
        self.track:addNote(i, self.scale[note], 1)
    end

    -- Add track to sequence and play

    self.sequence:play()
end

function Synth:stop()
    self.synth:noteOff()
end
