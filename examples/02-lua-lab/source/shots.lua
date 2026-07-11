-- Figure script: sit on each lab page long enough to shoot it,
-- then flip to the next with a synthetic right-press.
Shots = {
    seed = 1,
    last = 240,
    shots = {
        ["lab-shared"] = 40,
        ["lab-sandbox"] = 100,
        ["lab-class"] = 160,
        ["lab-traps"] = 220,
    },
    script = function(frame)
        local flip = frame == 70 or frame == 130 or frame == 190
        return { right = flip }
    end,
}
