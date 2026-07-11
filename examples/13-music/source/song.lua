-- Chapter 13: the song, as data. Both engines read these arrays.
-- Eight bars of sixteen sixteenth-note steps, I-V-vi-IV in C.

Song = {}

-- snip: song-data
Song.bpm = 112
Song.steps = 128         -- 8 bars x 16 sixteenth-note steps

-- Two bars per chord: C, G, Am, F. Roots are MIDI notes; tones are
-- the chord notes the lead melody is allowed to sing.
Song.chords = {
    { name = "C",  root = 36, tones = { 72, 76, 79 } },
    { name = "G",  root = 43, tones = { 71, 74, 79 } },
    { name = "Am", root = 45, tones = { 69, 72, 76 } },
    { name = "F",  root = 41, tones = { 69, 72, 77 } },
}

-- One bar of rhythm per voice. Bass plays the root (1) or the
-- fifth (5); the lead indexes into the chord tones (0 = rest);
-- the hat clicks on the offbeats.
local BASS   = { 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,5,0 }
local LEAD_A = { 1,0,0,0, 2,0,0,0, 3,0,0,2, 0,0,1,0 }
local LEAD_B = { 3,0,0,0, 2,0,3,0, 1,0,0,0, 2,0,0,0 }
local HAT    = { 0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0 }
-- endsnip

-- snip: expand
-- Expand the compact patterns into flat per-step arrays of MIDI
-- notes (0 = rest). Everything downstream reads only these.
Song.bass, Song.lead, Song.hat = {}, {}, {}
for bar = 0, 7 do
    local ch = Song.chords[bar // 2 + 1]
    local leadPat = (bar % 2 == 0) and LEAD_A or LEAD_B
    for i = 1, 16 do
        local s = bar * 16 + i
        local b = BASS[i]
        if b == 0 then Song.bass[s] = 0
        elseif b == 5 then Song.bass[s] = ch.root + 7
        else Song.bass[s] = ch.root end
        local l = leadPat[i]
        Song.lead[s] = (l == 0) and 0 or ch.tones[l]
        Song.hat[s] = (HAT[i] == 0) and 0 or 96
    end
end

function Song.stepsPerSecond()
    return Song.bpm / 60 * 4   -- four sixteenths per beat
end

function Song.midihz(n)
    return 440 * 2 ^ ((n - 69) / 12)
end
-- endsnip
