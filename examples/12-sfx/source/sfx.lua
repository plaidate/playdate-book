-- Chapter 12: the sfx module. One synth per named voice, envelopes
-- set once at load, and a deferred queue for layered effects.

Sfx = {}

local snd = playdate.sound

-- snip: lfo
-- A vibrato LFO for the siren, wired into its frequency. Depth is
-- a fraction of the note frequency; rate is cycles per second.
local vib = snd.lfo.new(snd.kLFOTriangle)
vib:setRate(8)
vib:setDepth(0.06)
-- endsnip

-- snip: voices
-- Every voice the game can make, as data: waveform, envelope, note
-- length, and the notes to play. `at` delays layered notes.
Sfx.voices = {
    { name = "blip", wave = snd.kWaveSquare, len = 0.12,
      env = { a = 0.005, d = 0.04, s = 0.40, r = 0.09 },
      notes = { { at = 0, freq = 880, vol = 0.40 } } },
    { name = "pickup", wave = snd.kWaveTriangle, len = 0.14,
      env = { a = 0.002, d = 0.06, s = 0.55, r = 0.22 },
      notes = { { at = 0, freq = 659, vol = 0.35 },
                { at = 0.07, freq = 988, vol = 0.30 } } },
    { name = "hurt", wave = snd.kWaveSawtooth, len = 0.10,
      env = { a = 0.004, d = 0.05, s = 0.50, r = 0.12 },
      notes = { { at = 0, freq = 220, vol = 0.35 },
                { at = 0.06, freq = 165, vol = 0.30 } } },
    { name = "boom", wave = snd.kWaveNoise, len = 0.45,
      env = { a = 0.010, d = 0.25, s = 0.30, r = 0.60 },
      notes = { { at = 0, freq = 90, vol = 0.55 } } },
    { name = "fanfare", wave = snd.kWaveSquare, len = 0.10,
      env = { a = 0.003, d = 0.05, s = 0.60, r = 0.18 },
      notes = { { at = 0, freq = 392, vol = 0.35 },
                { at = 0.11, freq = 523, vol = 0.35 },
                { at = 0.22, freq = 659, vol = 0.35 },
                { at = 0.33, freq = 784, vol = 0.35 } } },
    { name = "siren", wave = snd.kWaveSquare, len = 0.60,
      env = { a = 0.020, d = 0.10, s = 0.70, r = 0.25 },
      mod = vib,
      notes = { { at = 0, freq = 494, vol = 0.30 } } },
}

-- Build each synth ONCE, at load. Construction allocates; playNote
-- is cheap and safe to call every frame.
for _, v in ipairs(Sfx.voices) do
    v.synth = snd.synth.new(v.wave)
    v.synth:setADSR(v.env.a, v.env.d, v.env.s, v.env.r)
    if v.mod then v.synth:setFrequencyMod(v.mod) end
end
-- endsnip

-- snip: after
-- A deferred queue: a layered effect is just notes scheduled a few
-- ticks apart. Sfx.update drains the queue with the fixed DT.
local queue = {}

local function after(delay, fn)
    queue[#queue + 1] = { t = delay, fn = fn }
end

function Sfx.update(dt)
    for i = #queue, 1, -1 do
        local q = queue[i]
        q.t = q.t - dt
        if q.t <= 0 then
            table.remove(queue, i)
            q.fn()
        end
    end
end
-- endsnip

-- snip: play
function Sfx.play(v)
    for _, n in ipairs(v.notes) do
        if n.at == 0 then
            v.synth:playNote(n.freq, n.vol, v.len)
        else
            after(n.at, function()
                v.synth:playNote(n.freq, n.vol, v.len)
            end)
        end
    end
    Harness.count("plays")
    Harness.count(v.name)
end
-- endsnip
