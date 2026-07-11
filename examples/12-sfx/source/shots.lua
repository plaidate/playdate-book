-- Figure script: play three contrasting voices and shoot each one
-- mid-note, so the playhead is visible on the envelope. The later
-- presses exercise fanfare's deferred queue and the siren's LFO.
Shots = {
    seed = 1,
    last = 240,
    shots = {
        ["sfx-blip"] = 13,
        ["sfx-pickup"] = 52,
        ["sfx-boom"] = 96,
    },
    script = function(frame)
        return {
            a = (frame == 10 or frame == 46 or frame == 84
                or frame == 126 or frame == 166),
            down = (frame == 40 or frame == 70 or frame == 76
                or frame == 120 or frame == 156),
        }
    end,
}
