-- snip: gamestate
-- One global table for all mutable state (Chapter 3).
G = {
    mode = "title",   -- "title" | "play" | "gameover"
    modeT = 0,        -- seconds in the current mode
    t = 0,            -- seconds since launch
    score = 0,
    best = 0,         -- loaded from the datastore at boot
    newBest = false,  -- did this run set the record?
    aim = -90,        -- barrel angle, degrees; -90 = up
    cool = 0,         -- frames until the turret can fire
    shots = {},       -- live rounds { x, y, dx, dy }
    targets = {},     -- descending squares { x, y, ph }
    spawnT = 0,       -- countdown to the next target
}

function G.setMode(m)
    G.mode = m
    G.modeT = 0
end
-- endsnip
