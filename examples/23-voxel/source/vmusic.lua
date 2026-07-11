-- vendored from voxel/core/vmusic.lua (MIT)
-- Voxel core: step-sequencer music. A track is a table the game authors:
--
--   { bpm = 104,
--     bass = { 48, 0, 43, 0, ... },  -- 16 steps, midi notes, 0 = rest
--     lead = { 72, 0, 76, 0, ... },  -- 16 steps, midi notes, 0 = rest
--     hat  = { 1, 0, 0, 0, ... } }   -- 16 steps, nonzero = noise tick
--
-- Clock-driven: accumulate dt and fire steps on beat boundaries — zero
-- drift. All synth, mixed quiet under the sfx.

Music = {}

local snd = playdate.sound
local bass = snd.synth.new(snd.kWaveTriangle)
local lead = snd.synth.new(snd.kWaveSquare)
local hat = snd.synth.new(snd.kWaveNoise)

-- midi note -> Hz
function Music.midihz(n)
    return 440 * 2 ^ ((n - 69) / 12)
end

local cur
local clock, stepI = 0, 0

function Music.set(track)
    if track == cur then return end
    cur = track
    clock, stepI = 0, 0
end

function Music.stop()
    cur = nil
end

-- snip: music-step
function Music.update(dt)
    if not cur then return end
    local stepDur = 60 / cur.bpm / 4 -- sixteenth notes
    clock = clock + dt
    while clock >= stepDur do
        clock = clock - stepDur
        stepI = stepI % 16 + 1
        local b = cur.bass and cur.bass[stepI]
        if b and b ~= 0 then
            bass:playNote(Music.midihz(b), 0.12, stepDur * 1.8)
        end
        local l = cur.lead and cur.lead[stepI]
        if l and l ~= 0 then
            lead:playNote(Music.midihz(l), 0.07, stepDur * 0.9)
        end
        local h = cur.hat and cur.hat[stepI]
        if h and h ~= 0 then
            hat:playNote(4000, 0.04, stepDur * 0.3)
        end
        if stepI == 1 then Harness.count("musicBars") end
    end
end
-- endsnip
