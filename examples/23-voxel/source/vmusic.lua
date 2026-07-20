-- vendored from voxel/core/vmusic.lua (MIT)
-- Voxel core: step-sequencer music, grown tracker arms (the proven
-- lore/tiles/shmup design) — a campaign needs SONGS, not a loop.
--
--   { bpm = 104, len = 16,             -- len optional (32 = longer)
--     patterns = {
--       A = { bass = { 48, 0, ... },   -- len steps, midi, 0 = rest
--             lead = { ... }, pad = { ... }, hat = { 1, 0, ... } },
--       B = { ... } },
--     order = { "A", "A", "B" } }      -- loops
--
-- The ORIGINAL one-loop form (bass/lead/hat at top level) still plays
-- verbatim. Clock-driven — zero drift. Counters: musicBars, stingers.
--
--   Music.set(track)            start (no-op if already playing it)
--   Music.stop()
--   Music.stinger(track, once)  interrupt; saves the playhead ONCE
--                               across chained stingers; once=true
--                               auto-resumes after a single pass
--                               (fanfare -> the level theme resumes
--                               mid-phrase)
--   Music.resume()

Music = {}

local snd = playdate.sound
local bass = snd.synth.new(snd.kWaveTriangle)
local lead = snd.synth.new(snd.kWaveSquare)
local pad = snd.synth.new(snd.kWaveSine)
local hat = snd.synth.new(snd.kWaveNoise)

-- midi note -> Hz
function Music.midihz(n)
    return 440 * 2 ^ ((n - 69) / 12)
end

local cur = nil   -- { track, orderI, stepI, clock, once, stinger }
local saved = nil

local function normalize(track)
    if track.patterns then return track end
    track.patterns = { A = { bass = track.bass, lead = track.lead,
        pad = track.pad, hat = track.hat } }
    track.order = { "A" }
    return track
end

local function start(track, once, stinger)
    cur = { track = normalize(track), orderI = 1, stepI = 0,
        clock = 0, once = once or false, stinger = stinger or false }
end

function Music.set(track)
    if cur and cur.track == track and not cur.stinger then return end
    saved = nil
    start(track)
end

function Music.stop()
    cur, saved = nil, nil
end

function Music.stinger(track, once)
    Harness.count("stingers")
    if cur and not cur.stinger then saved = cur end
    start(track, once, true)
end

function Music.resume()
    cur = saved
    saved = nil
end

function Music.playing() return cur ~= nil end

-- snip: music-step
function Music.update(dt)
    local c = cur
    if not c then return end
    local track = c.track
    local stepDur = 60 / track.bpm / 4 -- sixteenth notes
    local len = track.len or 16
    c.clock = c.clock + dt
    while c.clock >= stepDur do
        c.clock = c.clock - stepDur
        c.stepI = c.stepI + 1
        if c.stepI > len then
            c.stepI = 1
            c.orderI = c.orderI + 1
            if c.orderI > #track.order then
                if c.once then
                    Music.resume()
                    return
                end
                c.orderI = 1
            end
        end
        if c.stepI == 1 then Harness.count("musicBars") end
        local pat = track.patterns[track.order[c.orderI]]
        if pat then
            local b = pat.bass and pat.bass[c.stepI]
            if b and b ~= 0 then
                bass:playNote(Music.midihz(b), 0.12, stepDur * 1.8)
            end
            local l = pat.lead and pat.lead[c.stepI]
            if l and l ~= 0 then
                lead:playNote(Music.midihz(l), 0.07, stepDur * 0.9)
            end
            local p = pat.pad and pat.pad[c.stepI]
            if p and p ~= 0 then
                pad:playNote(Music.midihz(p), 0.05, stepDur * 1.5)
            end
            local h = pat.hat and pat.hat[c.stepI]
            if h and h ~= 0 then
                hat:playNote(4000, 0.04, stepDur * 0.3)
            end
        end
    end
end
-- endsnip
