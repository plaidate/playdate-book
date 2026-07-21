-- Figure script: five 120-frame screens. The 17-level ramp
-- chart, the 3-band light compositor with two Light.at probes
-- (the script walks probe A from a lit core into the dark),
-- the Super Scaler pond with a bend and depth haze, the Bayer
-- transitions (iris in, dissolve out) over a night glade, and
-- the sweeping cone with a wall and a crate casting shadows.
Shots = {
    seed = 1,
    last = 600,
    shots = {
        ["ramp-chart"] = 50,
        ["light-bands"] = 160,
        ["light-probe"] = 225,
        ["scaler-pond"] = 300,
        ["fade-iris"] = 385,
        ["fade-dissolve"] = 450,
        ["light-occluder"] = 540,
    },
    script = function(f)
        local t = {}
        if f > 120 and f <= 240 then t.mx = 1 end
        return t
    end,
}
