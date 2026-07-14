-- vendored from shmup/core/music.lua (MIT)
-- shmup core: step-sequencer music. A track is a table the game authors:
--
--   { bpm = 132,
--     bass = { 36, 0, 36, 0, ... },   -- 16 steps, midi notes, 0 = rest
--     lead = { 72, 0, 76, 0, ... },
--     hat  = { 1, 0, 1, 0, ... } }    -- 16 steps, nonzero = a noise tick
--
-- Clock-driven: accumulate dt and fire a step when the accumulated time crosses
-- a step boundary. Counting FRAMES per step would drift, because a step is not
-- a whole number of frames; counting SECONDS cannot drift. Mixed quiet, under
-- the sfx -- in a shmup the sound effects are information and the music is only
-- weather.

Music = {}

local snd <const> = playdate.sound
local bass = snd.synth.new(snd.kWaveTriangle)
local lead = snd.synth.new(snd.kWaveSquare)
local hat = snd.synth.new(snd.kWaveNoise)

local cur, clock, stepI = nil, 0, 0

function Music.midihz(n) return 440 * 2 ^ ((n - 69) / 12) end

function Music.set(track)
    if track == cur then return end
    cur = track
    clock, stepI = 0, 0
end

function Music.stop() cur = nil end

function Music.update(dt)
    if not cur then return end
    local stepDur = 60 / cur.bpm / 4        -- sixteenth notes
    clock = clock + dt
    while clock >= stepDur do
        clock = clock - stepDur
        stepI = stepI % 16 + 1
        local n = cur.bass and cur.bass[stepI]
        if n and n > 0 then bass:playNote(Music.midihz(n), 0.10, stepDur * 1.8) end
        n = cur.lead and cur.lead[stepI]
        if n and n > 0 then lead:playNote(Music.midihz(n), 0.055, stepDur * 1.2) end
        n = cur.hat and cur.hat[stepI]
        if n and n > 0 then hat:playNote(1600, 0.028, 0.02) end
    end
end
