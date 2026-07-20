-- vendored from shmup/core/music.lua (MIT)
-- shmup core: step-sequencer music, grown tracker arms (the lore/tiles
-- design) because a campaign needs SONGS, not a loop. A track:
--
--   { bpm = 132, len = 16,               -- len optional (32 = longer)
--     patterns = {
--       A = { bass = { 36, 0, ... },     -- len steps, midi, 0 = rest
--             lead = { ... }, pad = { ... }, hat = { 1, 0, ... } },
--       B = { ... } },
--     order = { "A", "A", "B" } }        -- loops
--
-- The ORIGINAL one-loop form still works verbatim (a table with
-- bass/lead/hat at top level is wrapped into one pattern), so v1.0
-- content plays unchanged.
--
--   Music.set(track)            start (no-op if already playing it)
--   Music.stop()
--   Music.stinger(track, once)  interrupt; saves the playhead ONCE
--                               across chained stingers; once=true
--                               auto-resumes the saved track after a
--                               single pass (boss fanfare -> stage
--                               theme picks up mid-phrase)
--   Music.resume()
--
-- Clock-driven (accumulate dt, fire on beat boundaries — zero
-- drift). Mixed quiet under the sfx: in a shmup the sound effects
-- are information and the music is only weather.
-- Counters: musicBars, stingers.

Music = {}

local snd <const> = playdate.sound
local bass = snd.synth.new(snd.kWaveTriangle)
local lead = snd.synth.new(snd.kWaveSquare)
local pad = snd.synth.new(snd.kWaveSine)
local hat = snd.synth.new(snd.kWaveNoise)

function Music.midihz(n) return 440 * 2 ^ ((n - 69) / 12) end

local cur = nil   -- { track, orderI, stepI, clock, once, stinger }
local saved = nil

-- v1.0 one-loop tracks wrap into one pattern (cached on the track)
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

function Music.update(dt)
    local c = cur
    if not c then return end
    local track = c.track
    local stepDur = 60 / track.bpm / 4        -- sixteenth notes
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
            local n = pat.bass and pat.bass[c.stepI]
            if n and n > 0 then
                bass:playNote(Music.midihz(n), 0.10, stepDur * 1.8)
            end
            n = pat.lead and pat.lead[c.stepI]
            if n and n > 0 then
                lead:playNote(Music.midihz(n), 0.055, stepDur * 1.2)
            end
            n = pat.pad and pat.pad[c.stepI]
            if n and n > 0 then
                pad:playNote(Music.midihz(n), 0.045, stepDur * 1.6)
            end
            n = pat.hat and pat.hat[c.stepI]
            if n and n > 0 then hat:playNote(1600, 0.028, 0.02) end
        end
    end
end
