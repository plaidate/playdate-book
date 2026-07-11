-- snip: gamestate
-- One global table holds ALL mutable game state. Every module
-- reads and writes G; nothing hides state in file-locals.
G = {
    mode = "title",  -- "title" | "play" | "pause" | "gameover"
    modeT = 0,       -- seconds spent in the current mode
    t = 0,           -- seconds since launch
    score = 0,       -- blocks survived this run
    best = 0,        -- best score this session
    player = { x = 200 },
    blocks = {},     -- falling { x, y } squares
    spawnT = 0,      -- countdown to the next block
    spawned = 0,     -- how many blocks have spawned this run
}

-- The only sanctioned way to change mode: it resets the mode
-- clock that drives blinking prompts and input lockouts.
function G.setMode(m)
    G.mode = m
    G.modeT = 0
end
-- endsnip
