local notes = {
    [1] = "C5",
    [2] = "D5",
    [3] = "Eb5",
    [4] = "F5",
    [5] = "Gb5",
    [6] = "Ab5",
    [7] = "Bb5",
    [8] = "C6",
    [9] = "D6",
    [10] = "Eb6",
    [11] = "F6",
    [12] = "Gb6",
}

Synth = Class("Synth")

function Synth:init()
    self.synth = playdate.sound.synth.new()
end

function Synth:play(note)
    local note = note or math.random(1, 12)

    self.synth:playNote(notes[note])
end

function Synth:stop()
    self.synth:noteOff()
end
