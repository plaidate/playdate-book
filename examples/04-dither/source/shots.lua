-- Figure script: hold each demo screen for 30 frames and shoot it.
Shots = {
    seed = 1,
    last = 120,
    shots = {
        ["dither-ladder"] = 25,
        ["dither-patterns"] = 55,
        ["primitives"] = 85,
        ["ui-kit"] = 115,
    },
    script = function(frame)
        return { screen = math.min(4, math.ceil(frame / 30)) }
    end,
}
