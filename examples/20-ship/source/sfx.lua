-- Four voices, built once at load (Chapter 12): construction
-- allocates, playNote is cheap.

Sfx = {}

local snd = playdate.sound

-- snip: sfx
local fire = snd.synth.new(snd.kWaveSquare)
fire:setADSR(0.002, 0.05, 0.30, 0.06)

local hit = snd.synth.new(snd.kWaveNoise)
hit:setADSR(0.005, 0.18, 0.25, 0.30)

local lose = snd.synth.new(snd.kWaveSawtooth)
lose:setADSR(0.010, 0.30, 0.40, 0.40)

-- two synths so the record fanfare can be a chord
local bestA = snd.synth.new(snd.kWaveSquare)
bestA:setADSR(0.003, 0.08, 0.50, 0.25)
local bestB = snd.synth.new(snd.kWaveSquare)
bestB:setADSR(0.003, 0.08, 0.50, 0.25)

function Sfx.fire()
    fire:playNote(620, 0.30, 0.08)
end

function Sfx.hit()
    hit:playNote(110, 0.50, 0.20)
end

function Sfx.lose()
    lose:playNote(131, 0.45, 0.6)
end

function Sfx.best()
    bestA:playNote(523, 0.30, 0.5)
    bestB:playNote(784, 0.30, 0.5)
end
-- endsnip
