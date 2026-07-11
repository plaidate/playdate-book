-- Figure script: the scene runs on its own; B switches to the
-- draw-mode gallery. Shots catch two walk poses, a later stamp
-- rotation, and the gallery.
Shots = {
    seed = 1,
    last = 130,
    shots = {
        ["scene-a"] = 40,
        ["scene-b"] = 52,
        ["scene-c"] = 90,
        ["modes"] = 125,
    },
    script = function(frame)
        return { gallery = frame > 100 }
    end,
}
