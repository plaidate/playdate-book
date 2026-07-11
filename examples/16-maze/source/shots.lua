-- Figure script: the game plays itself (that is the chapter),
-- so the script only picks the moments to look at it.
Shots = {
    seed = 16,
    last = 300,
    shots = {
        ["maze-paths"] = 12,   -- both plans drawn, near-full
        ["maze-chase"] = 210,  -- mid-game: pellets thinned out
    },
    script = function(frame)
        return {}
    end,
}
