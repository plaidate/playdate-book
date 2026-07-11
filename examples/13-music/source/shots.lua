-- Figure script: shoot the grid under each engine, plus one shot
-- mid-duck. The sequence engine runs on the audio clock, which the
-- unthrottled capture run outpaces, so a scripted seek pins the
-- playhead to a known step right before each shot.
Shots = {
    seed = 1,
    last = 260,
    shots = {
        ["music-sequence"] = 110,
        ["music-duck"] = 66,
        ["music-conductor"] = 200,
    },
    script = function(frame)
        local seek = nil
        if frame == 65 then seek = 5 end
        if frame == 109 or frame == 199 then seek = 27 end
        return {
            a = (frame == 60 or frame == 220),
            b = (frame == 130),
            seek = seek,
        }
    end,
}
