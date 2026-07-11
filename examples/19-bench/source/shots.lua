-- Figure script: let the meters settle, then step through the
-- three screens. The EMAs need ~50 frames to mean anything.
Shots = {
    seed = 19,
    last = 330,
    shots = {
        ["bench-table"] = 180,
        ["tiles-loop"] = 250,
        ["one-blit"] = 320,
    },
    script = function(frame)
        return { next = (frame == 200 or frame == 270) }
    end,
}
