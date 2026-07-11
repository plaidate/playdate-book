-- Figure script: the crank turns 3 degrees a frame; the solid
-- changes every 80 frames. Two cube shots prove the rotation,
-- then one each of the pyramid and the icosahedron.
Shots = {
    seed = 1,
    last = 240,
    shots = {
        ["wf-cube-a"] = 40,
        ["wf-cube-b"] = 75,
        ["wf-pyramid"] = 140,
        ["wf-icosa"] = 220,
    },
    script = function(frame)
        return { crank = frame * 3 }
    end,
}
