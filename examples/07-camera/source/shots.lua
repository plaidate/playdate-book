-- Figure script: the rover drives right on its own. Three shots
-- during the pan show the camera trailing it past the numbered
-- markers; a fourth catches the scripted screen shake.
Shots = {
    seed = 1,
    last = 170,
    shots = {
        ["pan-1"] = 60,
        ["pan-2"] = 90,
        ["pan-3"] = 120,
        ["cam-shake"] = 152,
    },
    script = function(frame)
        return { move = 4, shake = (frame == 150) }
    end,
}
